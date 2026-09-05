import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../models/task_model.dart';
import '../widgets/task_reward_dialog.dart';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
  }

  /// جلب المهام وحالة تقدم المستخدم
  Future<List<TaskModel>> fetchTasks(String userId) async {
    final today = _getTodayKey();
    
    // 1. جلب التقدم اليومي للمستخدم
    Map<String, dynamic> userDailyData = {};
    try {
      final doc = await _db.collection('users').doc(userId).collection('tasks_progress').doc(today).get();
      if (doc.exists && doc.data() != null) {
        userDailyData = doc.data()!;
      }
    } catch (_) {}

    // 2. جلب التقدم لمهام النمو الدائمة
    Map<String, dynamic> userGrowthData = {};
    try {
      final doc = await _db.collection('users').doc(userId).collection('growth_tasks').doc('progress').get();
      if (doc.exists && doc.data() != null) {
        userGrowthData = doc.data()!;
      }
    } catch (_) {}

    // 3. جلب قائمة المهام من قاعدة البيانات مع وجود قائمة افتراضية كاملة
    List<Map<String, dynamic>> rawTasks = [];
    try {
      final snapshot = await _db.collection('tasks_config').get();
      if (snapshot.docs.isNotEmpty) {
        rawTasks = snapshot.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      }
    } catch (_) {}

    if (rawTasks.isEmpty) {
      rawTasks = _getDefaultTasks();
    }

    final List<TaskModel> result = [];
    for (final t in rawTasks) {
      final id = t['id']?.toString() ?? '';
      final group = t['group']?.toString() ?? 'daily';
      
      int progress = 0;
      bool isClaimed = false;

      if (group == 'growth') {
        progress = (userGrowthData['${id}_progress'] as num?)?.toInt() ?? 0;
        isClaimed = userGrowthData['${id}_claimed'] == true;
      } else {
        progress = (userDailyData['${id}_progress'] as num?)?.toInt() ?? 0;
        isClaimed = userDailyData['${id}_claimed'] == true;
      }

      result.add(TaskModel.fromMap(t, userProgress: progress, claimed: isClaimed));
    }

    return result;
  }

  /// زيادة تقدم المستخدم في مهمة معينة
  Future<void> recordTaskAction(String userId, String taskId, {int amount = 1, bool isGrowth = false}) async {
    if (userId.isEmpty) return;
    final today = _getTodayKey();

    try {
      if (isGrowth) {
        final ref = _db.collection('users').doc(userId).collection('growth_tasks').doc('progress');
        await ref.set({
          '${taskId}_progress': FieldValue.increment(amount),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final ref = _db.collection('users').doc(userId).collection('tasks_progress').doc(today);
        await ref.set({
          '${taskId}_progress': FieldValue.increment(amount),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// استلام مكافأة المهمة وإيداع الجوائز فوراً
  Future<bool> claimTaskReward(BuildContext context, String userId, TaskModel task) async {
    if (!task.canClaim) return false;
    final today = _getTodayKey();
    final isGrowth = task.group == 'growth';

    try {
      // 1. تحديث حالة الاستلام
      if (isGrowth) {
        await _db.collection('users').doc(userId).collection('growth_tasks').doc('progress').set({
          '${task.id}_claimed': true,
        }, SetOptions(merge: true));
      } else {
        await _db.collection('users').doc(userId).collection('tasks_progress').doc(today).set({
          '${task.id}_claimed': true,
        }, SetOptions(merge: true));
      }

      // 2. إيداع العملات ونقاط EXP في حساب المستخدم
      final userUpdates = <String, dynamic>{};
      if (task.coinsReward > 0) {
        userUpdates['coins'] = FieldValue.increment(task.coinsReward);
      }
      if (task.expReward > 0) {
        userUpdates['exp'] = FieldValue.increment(task.expReward);
      }
      if (userUpdates.isNotEmpty) {
        await _db.collection('users').doc(userId).update(userUpdates);
      }

      // 3. إيداع عنصر المتجر في حقيبة المستخدم إذا وجد
      if (task.storeItemId != null && task.storeItemId!.isNotEmpty) {
        await _db.collection('users').doc(userId).collection('backpack').doc(task.storeItemId).set({
          'itemId': task.storeItemId,
          'itemName': task.storeItemName ?? '',
          'itemIcon': task.storeItemIcon ?? '',
          'count': FieldValue.increment(1),
          'acquiredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 4. تحديث بروفايدر المستخدم
      if (context.mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUser(userId);

        // 5. عرض نافذة استلام المكافآت الاحتفالية
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => TaskRewardDialog(task: task),
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// جلب رابط بانر الفعالية لمركز المهام
  Future<String?> fetchEventBanner() async {
    try {
      final doc = await _db.collection('settings').doc('tasks_event_config').get();
      if (doc.exists && doc.data() != null) {
        return doc.data()?['banner_url']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// المهام الافتراضية المطابقة للتطبيق الأصلي
  List<Map<String, dynamic>> _getDefaultTasks() {
    return [
      // 🌟 مهام النشاط اليومي (Daily Tasks)
      {
        'id': 'daily_login',
        'title_ar': 'تسجيل الدخول اليومي',
        'title_en': 'Daily Check-in',
        'description_ar': 'قم بفتح التطبيق يومياً للحصول على المكافأة',
        'description_en': 'Open the app daily to claim reward',
        'group': 'daily',
        'target_count': 1,
        'coins_reward': 200,
        'exp_reward': 20,
        'action_route': 'none',
      },
      {
        'id': 'daily_mic_time',
        'title_ar': 'التحدث على المايك 10 دقائق',
        'title_en': 'Speak on Mic for 10 Mins',
        'description_ar': 'اصعد وتحدث في أي غرفة صوتية لمدة 10 دقائق',
        'description_en': 'Speak on any room mic for 10 minutes',
        'group': 'daily',
        'target_count': 1,
        'coins_reward': 500,
        'exp_reward': 50,
        'action_route': 'room',
      },
      {
        'id': 'daily_send_messages',
        'title_ar': 'إرسال 5 رسائل في شات الروم',
        'title_en': 'Send 5 Room Chat Messages',
        'description_ar': 'تفاعل وأرسل 5 رسائل نصية في الدردشة العامة',
        'description_en': 'Send 5 chat messages in room public chat',
        'group': 'daily',
        'target_count': 5,
        'coins_reward': 300,
        'exp_reward': 30,
        'action_route': 'room',
      },
      {
        'id': 'daily_room_stay',
        'title_ar': 'التواجد في الغرف لمدة 20 دقيقة',
        'title_en': 'Stay in Rooms for 20 Mins',
        'description_ar': 'استمع واستمتع داخل الغرف الصوتية',
        'description_en': 'Stay and listen inside voice rooms',
        'group': 'daily',
        'target_count': 1,
        'coins_reward': 400,
        'exp_reward': 40,
        'action_route': 'room',
      },

      // 🌱 مهام النمو والمستوى (Growth Tasks)
      {
        'id': 'growth_profile_complete',
        'title_ar': 'إكمال بيانات الملف الشخصي',
        'title_en': 'Complete Profile Info',
        'description_ar': 'قم بتعيين صورتك الرمزية واسمك والتوقيع',
        'description_en': 'Set avatar, nickname, and signature',
        'group': 'growth',
        'target_count': 1,
        'coins_reward': 1000,
        'exp_reward': 100,
        'action_route': 'profile',
      },
      {
        'id': 'growth_follow_friends',
        'title_ar': 'متابعة 5 أصدقاء ومستخدمين',
        'title_en': 'Follow 5 Users',
        'description_ar': 'تابع 5 أشخاص لتوسيع دائرة أصدقائك',
        'description_en': 'Follow 5 users to expand friends',
        'group': 'growth',
        'target_count': 5,
        'coins_reward': 600,
        'exp_reward': 60,
        'action_route': 'room',
      },
      {
        'id': 'growth_reach_level_5',
        'title_ar': 'الوصول إلى المستوى 5',
        'title_en': 'Reach User Level 5',
        'description_ar': 'ارفع مستواك عبر النشاط والإهداء',
        'description_en': 'Level up to level 5 through activity',
        'group': 'growth',
        'target_count': 1,
        'coins_reward': 2000,
        'exp_reward': 200,
        'action_route': 'none',
      },

      // 🍀 مهام الحظ والفعاليات (Lucky Tasks)
      {
        'id': 'lucky_send_gift',
        'title_ar': 'إرسال هدية حظ واحدة في الروم',
        'title_en': 'Send 1 Lucky Gift',
        'description_ar': 'جرب حظك وأرسل أي هدية حظ لمضاعفة كوينزك',
        'description_en': 'Send 1 lucky gift to try multipliers',
        'group': 'lucky',
        'target_count': 1,
        'coins_reward': 800,
        'exp_reward': 80,
        'action_route': 'gift',
      },
      {
        'id': 'lucky_first_recharge',
        'title_ar': 'أول شحن رصيد عملات اليوم',
        'title_en': 'First Coin Recharge of Today',
        'description_ar': 'اشحن أي باقة عملات واحصل على مكافأة مضاعفة',
        'description_en': 'Recharge any coin package today',
        'group': 'lucky',
        'target_count': 1,
        'coins_reward': 3000,
        'exp_reward': 300,
        'action_route': 'recharge',
      },
    ];
  }
}
