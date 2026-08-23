import '../../../core/supabase_compat.dart';

import '../../../core/utils/server_time_service.dart';
import 'agency_models.dart';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════
//  AgencyRepository v2 — كل عمليات Supabase للوكالات
//  - يقرأ الإعدادات المالية من قاعدة البيانات (لا ثوابت مشفّرة)
//  - يستخدم get_host_dashboard_v2 كمصدر واحد للحقيقة
//  - جميع RPC بمعاملات موحدة مع المحرك الجديد
// ═══════════════════════════════════════════════════════════════════
abstract final class AgencyRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  // ─── إعدادات المحرك (مصدر الحقيقة الوحيد للأسعار) ──────────────
  // ✅ إصلاح: لا قيم مُشفَّرة — إذا فشل RPC نرفع استثناءً صريحاً
  // حتى لا تُجري العمليات المالية بمعدلات خاطئة بصمت
  static Future<AgencyEngineSettings> getEngineSettings() async {
    final resp = await _sb.rpc('agency_get_engine_settings');
    if (resp == null) {
      debugPrint('[AgencyRepository] ⚠️ CRITICAL: agency_get_engine_settings returned null');
      throw Exception('تعذّر جلب إعدادات المحرك المالي من الخادم. يرجى المحاولة مجدداً.');
    }
    return AgencyEngineSettings.fromMap(Map<String, dynamic>.from(resp as Map));
  }

  // ─── التصنيف ────────────────────────────────────────────────────
  static Future<List<AgencyLeaderboardEntry>> getLeaderboard({
    String? country,
    int limit  = 50,
    int offset = 0,
  }) async {
    final resp = await _sb.rpc('agency_get_leaderboard', params: {
      'p_country': country,
      'p_limit':   limit,
      'p_offset':  offset,
    });
    final list = (resp as List<dynamic>?) ?? [];
    return list
        .map((e) => AgencyLeaderboardEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── ملف الوكالة العام ──────────────────────────────────────────
  static Future<AgencyCard?> getProfile(String agencyId) async {
    final resp = await _sb.rpc('agency_get_profile', params: {
      'p_agency_id': agencyId,
    });
    if (resp == null) return null;
    return AgencyCard.fromMap(Map<String, dynamic>.from(resp as Map));
  }

  // ─── إنشاء وكالة ────────────────────────────────────────────────
  static Future<String> createAgency({
    required String name,
    String? description,
    String? country,
    String? photoUrl,
    String? phone,
  }) async {
    final resp = await _sb.rpc('agency_create', params: {
      'p_name':        name,
      'p_description': description,
      'p_country':     country,
      'p_photo_url':   photoUrl,
      'p_phone':       phone,
    });
    return (resp as Map<String, dynamic>)['agency_id'] as String;
  }

  // ─── طلب انضمام ─────────────────────────────────────────────────
  static Future<void> requestJoin(String agencyId) async {
    await _sb.rpc('agency_request_join', params: {'p_agency_id': agencyId});
  }

  // ─── لوحة المضيف الموحدة (v2) ───────────────────────────────────
  /// المصدر الوحيد لبيانات المضيف: أرصدة + أهداف + محفظة + إعدادات المحرك
  static Future<HostAgencyStats?> getHostStats() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return null;

    final resp = await _sb.rpc('get_host_dashboard_v2', params: {
      'p_user_id': uid,
    });
    if (resp == null) return null;
    final data = Map<String, dynamic>.from(resp as Map);
    if (data['status'] != 'ok') return null;

    final member = AgencyMemberInfo.fromMap({
      'member_id':                   data['member_id'],
      'user_id':                     uid,
      'agency_id':                   data['agency_id'],
      'role':                        data['role'],
      'status':                      'active',
      'diamonds_balance':            data['diamonds_balance'],
      'diamonds_available':          data['diamonds_available'],
      'diamonds_pending_withdrawal': data['diamonds_pending_withdrawal'],
      'diamonds_earned_monthly':     data['diamonds_earned_monthly'],
      'diamonds_earned_cumulative':  data['diamonds_earned_cumulative'],
      'join_date':                   data['join_date'],
      'is_in_trial':                 data['is_in_trial'],
      'trial_ends_at':               data['trial_ends_at'],
    });

    final targets = ((data['targets'] as List<dynamic>?) ?? [])
        .map((e) => AgencyTarget.fromDashboardMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final ledger = ((data['recent_ledger'] as List<dynamic>?) ?? [])
        .map((e) => AgencyLedgerEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final engineMap = data['engine'] as Map<String, dynamic>? ?? {};
    final engine = AgencyEngineSettings.fromMap(engineMap);

    final achievedIds = targets
        .where((t) => t.isAchieved)
        .map((t) => t.id)
        .toList();

    return HostAgencyStats(
      member:            member,
      targets:           targets,
      recentLedger:      ledger,
      engine:            engine,
      achievedTargetIds: achievedIds,
    );
  }

  // ─── طلب الخروج ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> requestExit() async {
    final resp = await _sb.rpc('agency_request_exit', params: {});
    return Map<String, dynamic>.from(resp as Map);
  }

  // ─── دفع غرامة الخروج ───────────────────────────────────────────
  static Future<void> payPenaltyExit() async {
    await _sb.rpc('agency_pay_penalty_exit', params: {});
  }

  // ─── تبادل الألماس بكوينز (معدل من قاعدة البيانات) ──────────────
  // ✅ إصلاح: DB signature = (p_diamonds bigint, p_idempotency_key text)
  //    auth.uid() يُحدَّد داخل الدالة تلقائياً — لا حاجة لإرسال p_user_id
  static Future<Map<String, dynamic>> exchangeDiamonds({
    required int    diamondsAmount,
    required String idempotencyKey,
  }) async {
    final resp = await _sb.rpc('agency_exchange_diamonds', params: {
      'p_diamonds':        diamondsAmount,
      'p_idempotency_key': idempotencyKey,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  // ─── طلب سحب نقدي (مع KYC وتجميد فوري) ─────────────────────────
  // ✅ إصلاح: DB signature = (p_diamonds bigint, p_bank_details jsonb, p_idempotency_key text)
  //    auth.uid() يُحدَّد داخل الدالة — bankDetails = {method, bank_name, iban, country}
  static Future<Map<String, dynamic>> requestWithdrawal({
    required int    diamondsAmount,
    required String paymentMethod,
    required Map<String, dynamic> paymentDetails,
    required String idempotencyKey,
  }) async {
    final bankDetails = <String, dynamic>{
      'method': paymentMethod,
      ...paymentDetails,
    };

    final resp = await _sb.rpc('agency_request_withdrawal', params: {
      'p_diamonds':        diamondsAmount,
      'p_bank_details':    bankDetails,
      'p_idempotency_key': idempotencyKey,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  // ─── تحويل إلى وكيل شحن (Legacy — يُفضَّل transferDiamondsToAgentWallet) ─────
  // ✅ إصلاح: DB signature = (p_agent_id uuid, p_diamonds bigint)
  //    auth.uid() يُحدَّد داخل الدالة — لا idempotency_key في هذه الدالة
  static Future<Map<String, dynamic>> transferToRecharge({
    required String agentUserId,
    required int    diamondsAmount,
  }) async {
    final resp = await _sb.rpc('agency_transfer_to_recharge', params: {
      'p_agent_id': agentUserId,
      'p_diamonds': diamondsAmount,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  /// تحويل ألماس لمحفظة وكيل الشحن الجديدة (host_transfer_diamonds_to_agent)
  /// p_source: 'host' للمضيف، 'agency_owner' لمالك الوكالة
  static Future<Map<String, dynamic>> transferDiamondsToAgentWallet({
    required String agentId,
    required int    diamonds,
    required String idempotencyKey,
    String source = 'host',
  }) async {
    final resp = await _sb.rpc('host_transfer_diamonds_to_agent', params: {
      'p_agent_id':         agentId,
      'p_diamonds':         diamonds,
      'p_idempotency_key':  idempotencyKey,
      'p_source':           source,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  // ─── سجل المعاملات الكامل ────────────────────────────────────────
  static Future<List<AgencyLedgerEntry>> getTransactionHistory({
    int limit  = 50,
    int offset = 0,
    String? type,
  }) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return [];

    var baseQuery = _sb
        .from('agency_diamond_ledger')
        .select('id, txn_type, amount, direction, balance_after, note, created_at')
        .eq('user_id', uid);

    if (type != null) {
      baseQuery = baseQuery.eq('txn_type', type);
    }

    final rows = await baseQuery
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List<dynamic>)
        .map((e) => AgencyLedgerEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── قائمة طلبات السحب ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getWithdrawalRequests() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return [];

    final resp = await _sb
        .from('agency_withdrawal_requests')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(20);
    return (resp as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ─── إرسال إعلان ─────────────────────────────────────────────────
  static Future<void> sendAnnouncement({
    required String agencyId,
    required String title,
    required String body,
  }) async {
    await _sb.rpc('agency_send_announcement', params: {
      'p_agency_id': agencyId,
      'p_title':     title,
      'p_body':      body,
    });
  }

  // ─── إعلانات الوكالة ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAnnouncements(String agencyId) async {
    final resp = await _sb
        .from('agency_announcements')
        .select()
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false)
        .limit(20);
    return (resp as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ─── الوكالة الحرة ───────────────────────────────────────────────
  static Future<bool> isCurrentUserFreeAgent() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    final resp = await _sb
        .from('agency_free_agents')
        .select('free_until')
        .eq('user_id', uid)
        .maybeSingle();
    if (resp == null) return false;
    final freeUntil = DateTime.tryParse(resp['free_until'] as String? ?? '');
    return freeUntil != null && ServerTimeService.instance.now().isBefore(freeUntil);
  }

  // ─── القائمة السوداء ─────────────────────────────────────────────
  static Future<bool> isBlacklisted(String agencyId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    final resp = await _sb
        .from('agency_blacklist')
        .select('id')
        .eq('agency_id', agencyId)
        .eq('user_id', uid)
        .maybeSingle();
    return resp != null;
  }

  // ─── أعضاء الوكالة ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMembers(
    String agencyId, {
    int limit = 50,
  }) async {
    final resp = await _sb
        .from('host_agency_members')
        .select('''
          id, user_id, role, status,
          diamonds_earned_monthly, diamonds_earned_cumulative,
          diamonds_balance, diamonds_pending_withdrawal,
          trial_ends_at,
          profile:profiles(display_name, avatar_url, kayan_id, level)
        ''')
        .eq('agency_id', agencyId)
        .eq('status', 'active')
        .order('diamonds_earned_monthly', ascending: false)
        .limit(limit);
    return (resp as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ─── لوحة المالك ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getDashboard(String agencyId) async {
    final resp = await _sb.rpc('agency_get_dashboard', params: {
      'p_agency_id': agencyId,
    });
    if (resp == null) return null;
    return Map<String, dynamic>.from(resp as Map);
  }

  // ─── محفظة مالك الوكالة ──────────────────────────────────────────

  /// لوحة تحكم المالك: محفظة + أسعار + آخر 20 حركة
  static Future<AgencyOwnerDashboard?> getOwnerDashboard(String agencyId) async {
    final resp = await _sb.rpc('agency_get_owner_dashboard', params: {
      'p_agency_id': agencyId,
    });
    if (resp == null) return null;
    return AgencyOwnerDashboard.fromMap(Map<String, dynamic>.from(resp as Map));
  }

  /// تبادل ألماس الوكالة → كوينز شخصية للمالك
  static Future<Map<String, dynamic>> ownerExchangeDiamonds({
    required String agencyId,
    required int    diamondsAmount,
    required String idempotencyKey,
  }) async {
    final resp = await _sb.rpc('agency_owner_exchange_diamonds', params: {
      'p_agency_id':       agencyId,
      'p_diamonds_amount': diamondsAmount,
      'p_idempotency_key': idempotencyKey,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  /// طلب سحب نقدي من محفظة الوكالة (يتطلب KYC)
  static Future<Map<String, dynamic>> ownerRequestWithdrawal({
    required String agencyId,
    required int    diamondsAmount,
    required String paymentMethod,
    required Map<String, dynamic> paymentDetails,
  }) async {
    final resp = await _sb.rpc('agency_owner_request_withdrawal', params: {
      'p_agency_id':       agencyId,
      'p_diamonds_amount': diamondsAmount,
      'p_payment_method':  paymentMethod,
      'p_payment_details': paymentDetails,
    });
    return Map<String, dynamic>.from(resp as Map);
  }

  // ─── البحث عن وكلاء الشحن ────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchRechargeAgents(String query) async {
    if (query.trim().length < 2) return [];
    final resp = await _sb
        .from('profiles')
        .select('id, display_name, avatar_url, kayan_id')
        .eq('is_recharge_agent', true)
        .or('display_name.ilike.%$query%,kayan_id.ilike.%$query%')
        .limit(10);
    return (resp as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
