import '../supabase_compat.dart';

import '../auth/auth_service.dart';
import '../auth/supabase_ready.dart';
import 'package:flutter/foundation.dart';

/// مصدر الحقيقة للمحفظة المزدوجة: ذهب (شحن/هدايا صادرة) + ألماس (أرباح/هدايا واردة).
abstract final class EconomyRepository {
  static Future<({int gold, int diamond})> fetchWallet(String userId) async {
    if (!isSupabaseReady()) return (gold: 0, diamond: 0);
    try {
      final row = await Supabase.instance.client
          .from('user_wallets')
          .select('gold_balance, diamond_balance')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return (gold: 0, diamond: 0);
      return (
        gold: (row['gold_balance'] as num?)?.toInt() ?? 0,
        diamond: (row['diamond_balance'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
debugPrint('[economy_repository] error: $e');
      return (gold: 0, diamond: 0);
    }
  }

  static Future<({int gold, int diamond})> fetchMyWallet() async {
    final uid = AuthService.currentSession?.user.id;
    if (uid == null) return (gold: 0, diamond: 0);
    return fetchWallet(uid);
  }

  /// رصيد محفظة الوكالة (للوكلاء المعتمدين فقط — RLS).
  static Future<int> fetchAgencyWalletGold(String agencyProfileId) async {
    if (!isSupabaseReady()) return 0;
    try {
      final row = await Supabase.instance.client
          .from('agency_wallets')
          .select('gold_balance')
          .eq('agency_profile_id', agencyProfileId)
          .maybeSingle();
      return (row?['gold_balance'] as num?)?.toInt() ?? 0;
    } catch (e) {
debugPrint('[economy_repository] error: $e');
      return 0;
    }
  }
}
