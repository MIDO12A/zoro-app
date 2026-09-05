import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  String? _bannerUrl;
  List<TaskModel> _tasks = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final uid = userProvider.currentUser?.uid ?? '';

    final banner = await TaskService().fetchEventBanner();
    final list = await TaskService().fetchTasks(uid);

    if (mounted) {
      setState(() {
        _bannerUrl = banner;
        _tasks = list;
        _loading = false;
      });
    }
  }

  List<TaskModel> _filterByGroup(String group) {
    return _tasks.where((t) => t.group == group).toList();
  }

  void _handleTaskAction(TaskModel task) {
    if (task.canClaim) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final uid = userProvider.currentUser?.uid ?? '';
      TaskService().claimTaskReward(context, uid, task).then((ok) {
        if (ok) _loadData();
      });
      return;
    }

    if (task.isCompleted) return;

    // توجيه المستخدم حسب نوع المهمة (Go)
    Navigator.of(context).pop();
    switch (task.actionRoute) {
      case 'room':
        // العودة للرومات
        break;
      case 'gift':
      case 'lucky_gift':
        // فتح الروم لإرسال هدية
        break;
      case 'recharge':
        // فتح صفحة الشحن
        break;
      case 'store':
        // فتح المتجر
        break;
      case 'profile':
        // فتح تعديل البروفايل
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF13111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191624),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'مركز المهام والمكافآت',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFFD700),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 1. بانر الفعالية العلوي
                    _buildTopBanner(),

                    // 2. بطاقة معلومات رصيد المستخدم ومستواه
                    _buildUserHeader(user),

                    // 3. تبويبات مجموعات المهام
                    _buildTabs(),

                    // 4. قائمة المهام للمجموعة المحددة
                    SizedBox(
                      height: 520,
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildTaskList(_filterByGroup('daily'), 'daily'),
                          _buildTaskList(_filterByGroup('growth'), 'growth'),
                          _buildTaskList(_filterByGroup('lucky'), 'lucky'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopBanner() {
    if (_bannerUrl != null && _bannerUrl!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            _bannerUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => _buildDefaultBanner(),
          ),
        ),
      );
    }
    return _buildDefaultBanner();
  }

  Widget _buildDefaultBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A2A82), Color(0xFF2D144A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  '🌟 مركز المهام اليومية',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
                ),
                SizedBox(height: 4),
                Text(
                  'أنجز المهام يومياً واحصل على كوينز وجوائز وهدايا حصرية!',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            ),
            child: const Center(child: Text('🎁', style: TextStyle(fontSize: 28))),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(dynamic user) {
    final coins = user?.coins ?? 0;
    final exp = user?.experience ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('العملات المتوفرة', style: TextStyle(fontSize: 10, color: Colors.white54)),
                  Text('$coins', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
                ],
              ),
            ],
          ),
          Container(width: 1, height: 26, color: Colors.white10),
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نقاط الخبرة EXP', style: TextStyle(fontSize: 10, color: Colors.white54)),
                  Text('$exp', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64B5F6))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1728),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9900), Color(0xFFFF5500)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: '🌟 النشاط اليومي'),
          Tab(text: '🌱 النمو والمستوى'),
          Tab(text: '🍀 فعاليات الحظ'),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> list, String group) {
    if (list.isEmpty) {
      return const Center(
        child: Text('لا توجد مهام حالياً', style: TextStyle(color: Colors.white54, fontSize: 13)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final task = list[idx];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.canClaim
              ? const Color(0xFFFFD700).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: task.canClaim
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // أيقونة المهمة
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2A243D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                task.group == 'lucky' ? '🍀' : (task.group == 'growth' ? '🌱' : '⭐'),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // تفاصيل المهمة والمكافأة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.titleAr.isNotEmpty ? task.titleAr : task.titleEn,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  task.descriptionAr.isNotEmpty ? task.descriptionAr : task.descriptionEn,
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // شريط التقدم
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            task.isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF9900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${task.currentCount}/${task.targetCount}',
                      style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // الجوائز المكتسبة
                Row(
                  children: [
                    if (task.coinsReward > 0) ...[
                      const Text('🪙', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 2),
                      Text('+${task.coinsReward}', style: const TextStyle(fontSize: 11, color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                    ],
                    if (task.expReward > 0) ...[
                      const Text('⭐', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 2),
                      Text('+${task.expReward}', style: const TextStyle(fontSize: 11, color: Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                    ],
                    if (task.storeItemName != null && task.storeItemName!.isNotEmpty) ...[
                      const Text('🎁', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 2),
                      Text(task.storeItemName!, style: const TextStyle(fontSize: 10, color: Color(0xFFFF4081))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // زر الحالة التفاعلي (اذهب / استلام / مكتمل)
          _buildActionButton(task),
        ],
      ),
    );
  }

  Widget _buildActionButton(TaskModel task) {
    if (task.isClaimed) {
      return Container(
        width: 64,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'مكتمل ✓',
          style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (task.canClaim) {
      return GestureDetector(
        onTap: () => _handleTaskAction(task),
        child: Container(
          width: 68,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Text(
            'استلام 🎁',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      );
    }

    // زر اذهب (Go)
    return GestureDetector(
      onTap: () => _handleTaskAction(task),
      child: Container(
        width: 64,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9900), Color(0xFFFF5500)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'اذهب ➜',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
