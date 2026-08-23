import 'package:flutter/foundation.dart';
import '../../../core/supabase_compat.dart';

import 'role_perk_models.dart';

// ═══════════════════════════════════════════════════════════════
//  RolePerkRepository — مستودع بيانات حزم الأدوار
//  يجلب الأدوار الفعّالة للمستخدم + يستمع للتحديثات
// ═══════════════════════════════════════════════════════════════
abstract final class RolePerkRepository {
  static final _sb = Supabase.instance.client;

  /// جلب جميع حزم الأدوار الفعّالة لمستخدم معين
  /// يُعيد قائمة RolePerkConfig المفعّلة لهذا المستخدم
  static Future<List<RolePerkConfig>> getActivePerks(String userId) async {
    try {
      final resp = await _sb.rpc('get_user_active_role_perks', params: {'p_user_id': userId});
      if (resp == null) return [];
      final list = resp as List<dynamic>;
      return list
          .map((e) => RolePerkConfig.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.isActive)
          .toList();
    } catch (e) {
      debugPrint('[role_perk_repository] getActivePerks error: $e');
      return [];
    }
  }

  /// جلب أول شارة دور فعّالة للمستخدم (للعرض في البروفايل والغرفة)
  static Future<RolePerkConfig?> getFirstActiveBadge(String userId) async {
    final perks = await getActivePerks(userId);
    // الأولوية: manager → super_admin → admin → recharge_agent → agency_owner → host
    const priority = ['manager', 'super_admin', 'admin', 'recharge_agent', 'agency_owner', 'host', 'custom'];
    for (final key in priority) {
      final match = perks.where((p) => p.roleKey == key && p.badgeEnabled).firstOrNull;
      if (match != null) return match;
    }
    // fallback: أي دور عنده شارة مفعّلة
    return perks.where((p) => p.badgeEnabled).firstOrNull;
  }

  /// جلب أول إطار غرفة فعّال للمستخدم
  static Future<RolePerkConfig?> getActiveRoomFrame(String userId) async {
    final perks = await getActivePerks(userId);
    return perks.where((p) => p.roomFrameEnabled && p.roomFrameUrl != null).firstOrNull;
  }

  /// جلب أول فقاعة دردشة فعّالة للمستخدم
  static Future<RolePerkConfig?> getActiveChatBubble(String userId) async {
    final perks = await getActivePerks(userId);
    return perks.where((p) => p.chatBubbleEnabled && p.chatBubbleUrl != null).firstOrNull;
  }

  /// جلب إطار البروفايل الفعّال للمستخدم
  static Future<RolePerkConfig?> getActiveProfileFrame(String userId) async {
    final perks = await getActivePerks(userId);
    return perks.where((p) => p.profileFrameEnabled && p.profileFrameUrl != null).firstOrNull;
  }

  /// الاشتراك في تحديثات user_role_perks (Realtime)
  static RealtimeChannel subscribeToUserPerks(
    String userId,
    void Function() onUpdate,
  ) {
    return _sb
        .channel('user_role_perks_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_role_perks',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
