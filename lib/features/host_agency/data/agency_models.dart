// ═══════════════════════════════════════════════════════════════════
//  Agency Models — نظام الوكالات الشامل (v2 — موحد مع المحرك الجديد)
// ═══════════════════════════════════════════════════════════════════

import '../../../core/utils/server_time_service.dart';

// ─── درجة الوكالة ────────────────────────────────────────────────────────────
enum AgencyTier { bronze, silver, gold, platinum, diamond }

extension AgencyTierX on AgencyTier {
  String get label {
    switch (this) {
      case AgencyTier.bronze:   return 'برونز';
      case AgencyTier.silver:   return 'فضي';
      case AgencyTier.gold:     return 'ذهبي';
      case AgencyTier.platinum: return 'بلاتيني';
      case AgencyTier.diamond:  return 'ألماسي';
    }
  }

  static AgencyTier fromString(String s) {
    switch (s) {
      case 'silver':   return AgencyTier.silver;
      case 'gold':     return AgencyTier.gold;
      case 'platinum': return AgencyTier.platinum;
      case 'diamond':  return AgencyTier.diamond;
      default:         return AgencyTier.bronze;
    }
  }
}

// ─── إعدادات محرك الوكالة (من قاعدة البيانات) ───────────────────────────────
class AgencyEngineSettings {
  final int    hostSharePct;
  final int    agencySharePct;
  final int    platformSharePct;
  final double diamondToCoinRate;
  final int    dailyExchangeLimit;
  final double diamondToUsdRate;
  final double withdrawalFeePct;
  final double minWithdrawalUsd;
  final int    minDiamondsToWithdraw;
  final int    withdrawalCycleDays;
  final int    trialPeriodDays;
  final int    exitPenaltyCoins;
  final bool   engineEnabled;

  const AgencyEngineSettings({
    required this.hostSharePct,
    required this.agencySharePct,
    required this.platformSharePct,
    required this.diamondToCoinRate,
    required this.dailyExchangeLimit,
    required this.diamondToUsdRate,
    required this.withdrawalFeePct,
    required this.minWithdrawalUsd,
    required this.minDiamondsToWithdraw,
    required this.withdrawalCycleDays,
    required this.trialPeriodDays,
    required this.exitPenaltyCoins,
    required this.engineEnabled,
  });

  factory AgencyEngineSettings.fromMap(Map<String, dynamic> m) {
    return AgencyEngineSettings(
      hostSharePct:           (m['host_share_pct'] as num?)?.toInt()              ?? 70,
      agencySharePct:         (m['agency_share_pct'] as num?)?.toInt()            ?? 20,
      platformSharePct:       (m['platform_share_pct'] as num?)?.toInt()          ?? 10,
      diamondToCoinRate:      (m['diamond_to_coin_rate'] as num?)?.toDouble()     ?? 0.5,
      dailyExchangeLimit:     (m['daily_exchange_limit_diamonds'] as num?)?.toInt() ?? 500000,
      diamondToUsdRate:       (m['diamond_to_usd_rate'] as num?)?.toDouble()      ?? 0.0001,
      withdrawalFeePct:       (m['withdrawal_fee_pct'] as num?)?.toDouble()       ?? 10.0,
      minWithdrawalUsd:       (m['min_withdrawal_usd'] as num?)?.toDouble()       ?? 10.0,
      minDiamondsToWithdraw:  (m['min_diamonds_to_withdraw'] as num?)?.toInt()    ?? 100000,
      withdrawalCycleDays:    (m['withdrawal_cycle_days'] as num?)?.toInt()       ?? 30,
      trialPeriodDays:        (m['trial_period_days'] as num?)?.toInt()           ?? 7,
      exitPenaltyCoins:       (m['exit_penalty_coins'] as num?)?.toInt()          ?? 300000,
      engineEnabled:          m['engine_enabled'] as bool?                        ?? true,
    );
  }

  /// يحسب الكوينز المحصّلة من ألماس معين
  int coinsFromDiamonds(int diamonds) => (diamonds * diamondToCoinRate).floor();

  /// يحسب الدولارات قبل الرسوم
  double grossUsdFromDiamonds(int diamonds) => diamonds * diamondToUsdRate;

  /// يحسب الدولارات بعد الرسوم
  double netUsdFromDiamonds(int diamonds) {
    final gross = grossUsdFromDiamonds(diamonds);
    return gross * (1 - withdrawalFeePct / 100);
  }
}

// ─── بطاقة الوكالة (للعرض العام والتصنيف) ───────────────────────────────────
class AgencyCard {
  final String  id;
  final String? agencyPublicId;   // ≥ 5000 — المعرّف العام للوكالة
  final String  name;
  final String? description;
  final String? photoUrl;
  final String? country;
  final AgencyTier tier;
  final int? rank;
  final int memberCount;
  final int totalDiamondsMonthly;
  final int totalDiamondsCumulative;
  final bool isHallOfFame;
  final String status;
  final bool isMember;
  final bool canJoin;
  final String? ownerName;
  final String? ownerAvatarUrl;

  const AgencyCard({
    required this.id,
    this.agencyPublicId,
    required this.name,
    this.description,
    this.photoUrl,
    this.country,
    required this.tier,
    this.rank,
    required this.memberCount,
    required this.totalDiamondsMonthly,
    required this.totalDiamondsCumulative,
    required this.isHallOfFame,
    required this.status,
    this.isMember = false,
    this.canJoin = false,
    this.ownerName,
    this.ownerAvatarUrl,
  });

  factory AgencyCard.fromMap(Map<String, dynamic> m) {
    return AgencyCard(
      id:                       m['id'] as String,
      agencyPublicId:           m['agency_public_id'] as String?,
      name:                     m['name'] as String? ?? '—',
      description:              m['description'] as String?,
      photoUrl:                 m['photo_url'] as String?,
      country:                  m['country'] as String?,
      tier:                     AgencyTierX.fromString(m['tier'] as String? ?? 'bronze'),
      rank:                     (m['rank'] as num?)?.toInt(),
      memberCount:              (m['member_count'] as num?)?.toInt() ?? 0,
      totalDiamondsMonthly:     (m['total_diamonds_monthly'] as num?)?.toInt() ?? 0,
      totalDiamondsCumulative:  (m['total_diamonds_cumulative'] as num?)?.toInt() ?? 0,
      isHallOfFame:             m['is_hall_of_fame'] as bool? ?? false,
      status:                   m['status'] as String? ?? 'active',
      isMember:                 m['is_member'] as bool? ?? false,
      canJoin:                  m['can_join'] as bool? ?? false,
      ownerName:                m['owner_name'] as String?
                                  ?? (m['owner'] as Map<String, dynamic>?)?['display_name'] as String?,
      ownerAvatarUrl:           m['owner_avatar'] as String?
                                  ?? (m['owner'] as Map<String, dynamic>?)?['avatar_url'] as String?,
    );
  }
}

// ─── صف التصنيف ───────────────────────────────────────────────────────────────
class AgencyLeaderboardEntry {
  final int     rank;
  final String  agencyId;
  final String? agencyPublicId;   // ≥ 5000
  final String  name;
  final String? photoUrl;
  final AgencyTier tier;
  final int memberCount;
  final int totalDiamondsMonthly;
  final int totalDiamondsCumulative;
  final bool isHallOfFame;
  final String? country;

  const AgencyLeaderboardEntry({
    required this.rank,
    required this.agencyId,
    this.agencyPublicId,
    required this.name,
    this.photoUrl,
    required this.tier,
    required this.memberCount,
    required this.totalDiamondsMonthly,
    required this.totalDiamondsCumulative,
    required this.isHallOfFame,
    this.country,
  });

  factory AgencyLeaderboardEntry.fromMap(Map<String, dynamic> m) {
    return AgencyLeaderboardEntry(
      rank:                    (m['rank'] as num?)?.toInt() ?? 0,
      agencyId:                m['agency_id'] as String? ?? m['id'] as String,
      agencyPublicId:          m['agency_public_id'] as String?,
      name:                    m['name'] as String? ?? '—',
      photoUrl:                m['photo_url'] as String?,
      tier:                    AgencyTierX.fromString(m['tier'] as String? ?? 'bronze'),
      memberCount:             (m['member_count'] as num?)?.toInt() ?? 0,
      totalDiamondsMonthly:    (m['total_diamonds_monthly'] as num?)?.toInt() ?? 0,
      totalDiamondsCumulative: (m['total_diamonds_cumulative'] as num?)?.toInt() ?? 0,
      isHallOfFame:            m['is_hall_of_fame'] as bool? ?? false,
      country:                 m['country'] as String?,
    );
  }
}

// ─── معلومات العضو في الوكالة ────────────────────────────────────────────────
class AgencyMemberInfo {
  final String memberId;
  final String userId;
  final String agencyId;
  final String role;   // owner / supervisor / host
  final String status;
  final int diamondsEarnedMonthly;
  final int diamondsEarnedCumulative;
  final int diamondsBalance;
  final int diamondsPendingWithdrawal;
  final int diamondsAvailable;           // = balance - pending
  final DateTime? trialEndsAt;
  final DateTime? joinDate;

  const AgencyMemberInfo({
    required this.memberId,
    required this.userId,
    required this.agencyId,
    required this.role,
    required this.status,
    required this.diamondsEarnedMonthly,
    required this.diamondsEarnedCumulative,
    required this.diamondsBalance,
    required this.diamondsPendingWithdrawal,
    required this.diamondsAvailable,
    this.trialEndsAt,
    this.joinDate,
  });

  factory AgencyMemberInfo.fromMap(Map<String, dynamic> m) {
    final balance  = (m['diamonds_balance'] as num?)?.toInt()             ?? 0;
    final pending  = (m['diamonds_pending_withdrawal'] as num?)?.toInt()  ?? 0;
    final available= (m['diamonds_available'] as num?)?.toInt()           ?? (balance - pending).clamp(0, balance);
    return AgencyMemberInfo(
      memberId:                  (m['member_id'] ?? m['id']).toString(),
      userId:                    m['user_id'] as String,
      agencyId:                  m['agency_id'] as String,
      role:                      m['role'] as String? ?? 'host',
      status:                    m['status'] as String? ?? 'active',
      diamondsEarnedMonthly:     (m['diamonds_earned_monthly'] as num?)?.toInt()    ?? 0,
      diamondsEarnedCumulative:  (m['diamonds_earned_cumulative'] as num?)?.toInt() ?? 0,
      diamondsBalance:           balance,
      diamondsPendingWithdrawal: pending,
      diamondsAvailable:         available,
      trialEndsAt: m['trial_ends_at'] != null
          ? DateTime.tryParse(m['trial_ends_at'] as String)
          : null,
      joinDate: m['join_date'] != null
          ? DateTime.tryParse(m['join_date'] as String)
          : null,
    );
  }

  bool get isInTrial {
    if (trialEndsAt == null) return false;
    return ServerTimeService.instance.now().isBefore(trialEndsAt!);
  }
}

// ─── هدف المضيف (v2 — مكافآت متعددة + تقدم) ─────────────────────────────────
class AgencyTarget {
  final String id;
  final String? title;
  final int targetDiamonds;
  final int rewardCoins;
  final int rewardDiamonds;
  final int rewardSvipDays;
  final int? rewardBadgeId;
  final int? rewardMedalId;
  final int? rewardFrameId;
  // حالة التقدم (مُحسَبة من الـ API)
  final int earnedThisMonth;
  final int remaining;
  final double progressPct;
  final bool isAchieved;
  final int sortOrder;

  const AgencyTarget({
    required this.id,
    this.title,
    required this.targetDiamonds,
    this.rewardCoins     = 0,
    this.rewardDiamonds  = 0,
    this.rewardSvipDays  = 0,
    this.rewardBadgeId,
    this.rewardMedalId,
    this.rewardFrameId,
    this.earnedThisMonth = 0,
    this.remaining       = 0,
    this.progressPct     = 0,
    this.isAchieved      = false,
    this.sortOrder       = 0,
  });

  /// بناء من استجابة get_host_dashboard_v2 (نتيجة غنية مع التقدم)
  factory AgencyTarget.fromDashboardMap(Map<String, dynamic> m) {
    return AgencyTarget(
      id:              m['id'].toString(),
      title:           m['title'] as String?,
      targetDiamonds:  (m['target_diamonds'] as num?)?.toInt()  ?? 0,
      rewardCoins:     (m['reward_coins'] as num?)?.toInt()     ?? 0,
      rewardDiamonds:  (m['reward_diamonds'] as num?)?.toInt()  ?? 0,
      rewardSvipDays:  (m['reward_svip_days'] as num?)?.toInt() ?? 0,
      rewardBadgeId:   (m['reward_badge_id'] as num?)?.toInt(),
      rewardMedalId:   (m['reward_medal_id'] as num?)?.toInt(),
      rewardFrameId:   (m['reward_frame_id'] as num?)?.toInt(),
      earnedThisMonth: (m['earned_this_month'] as num?)?.toInt() ?? 0,
      remaining:       (m['remaining'] as num?)?.toInt()         ?? 0,
      progressPct:     (m['progress_pct'] as num?)?.toDouble()   ?? 0.0,
      isAchieved:      m['is_achieved'] as bool?                 ?? false,
      sortOrder:       (m['sort_order'] as num?)?.toInt()        ?? 0,
    );
  }

  /// بناء من صف الجدول المباشر (بدون تقدم — يُحسَب لاحقاً)
  factory AgencyTarget.fromMap(Map<String, dynamic> m) {
    return AgencyTarget(
      id:             m['id'].toString(),
      title:          m['title'] as String?,
      targetDiamonds: (m['target_diamonds']
                       ?? m['diamond_threshold'] as num?)?.toInt() ?? 0,
      rewardCoins:    (m['reward_coins'] as num?)?.toInt()         ?? 0,
      rewardDiamonds: (m['reward_diamonds'] as num?)?.toInt()      ?? 0,
      rewardSvipDays: (m['reward_svip_days'] as num?)?.toInt()     ?? 0,
      rewardBadgeId:  (m['reward_badge_id'] as num?)?.toInt(),
      rewardMedalId:  (m['reward_medal_id'] as num?)?.toInt(),
      rewardFrameId:  (m['reward_frame_id'] as num?)?.toInt(),
      sortOrder:      (m['sort_order'] as num?)?.toInt()           ?? 0,
    );
  }

  String get rewardSummary {
    final parts = <String>[];
    if (rewardCoins    > 0) parts.add('${_fmt(rewardCoins)} كوينز');
    if (rewardDiamonds > 0) parts.add('${_fmt(rewardDiamonds)} ألماس');
    if (rewardSvipDays > 0) parts.add('$rewardSvipDays يوم SVIP');
    if (rewardBadgeId  != null) parts.add('شارة');
    if (rewardMedalId  != null) parts.add('وسام');
    if (rewardFrameId  != null) parts.add('إطار');
    return parts.isEmpty ? 'مكافأة خاصة' : parts.join(' + ');
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

// ─── معاملة دفتر الألماس ─────────────────────────────────────────────────────
class AgencyLedgerEntry {
  final int id;
  final String txnType;
  final int amount;
  final int direction;   // 1 = دخل، -1 = خرج
  final int balanceAfter;
  final String? note;
  final DateTime createdAt;

  const AgencyLedgerEntry({
    required this.id,
    required this.txnType,
    required this.amount,
    required this.direction,
    required this.balanceAfter,
    this.note,
    required this.createdAt,
  });

  factory AgencyLedgerEntry.fromMap(Map<String, dynamic> m) {
    return AgencyLedgerEntry(
      id:           (m['id'] as num).toInt(),
      txnType:      m['type'] as String? ?? m['txn_type'] as String? ?? '',
      amount:       (m['amount'] as num?)?.toInt() ?? 0,
      direction:    (m['direction'] as num?)?.toInt() ?? 1,
      balanceAfter: (m['balance_after'] as num?)?.toInt() ?? 0,
      note:         m['note'] as String?,
      createdAt:    DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  bool get isCredit => direction == 1;

  String get typeLabel {
    switch (txnType) {
      case 'gift_commission':   return 'عمولة هدية';
      case 'exchange_out':      return 'تبادل ألماس';
      case 'withdrawal_lock':   return 'تجميد سحب';
      case 'withdrawal_unlock': return 'إلغاء تجميد';
      case 'withdrawal_paid':   return 'سحب مكتمل';
      case 'transfer_out':      return 'تحويل لوكيل';
      case 'bonus':             return 'مكافأة هدف';
      case 'adjustment':        return 'تعديل إداري';
      default:                  return txnType;
    }
  }
}

// ─── حالة المضيف الكاملة (من get_host_dashboard_v2) ─────────────────────────
class HostAgencyStats {
  final AgencyCard? agency;
  final AgencyMemberInfo member;
  final List<AgencyTarget> targets;
  final List<AgencyLedgerEntry> recentLedger;
  final AgencyEngineSettings engine;
  // للتوافق مع الكود القديم
  final List<String> achievedTargetIds;
  final int rankInAgency;
  final int totalMembersInAgency;

  const HostAgencyStats({
    this.agency,
    required this.member,
    required this.targets,
    required this.recentLedger,
    required this.engine,
    required this.achievedTargetIds,
    this.rankInAgency       = 0,
    this.totalMembersInAgency = 0,
  });

  /// الهدف التالي غير المحقق
  AgencyTarget? get nextTarget {
    for (final t in targets) {
      if (!t.isAchieved) return t;
    }
    return null;
  }

  /// نسبة التقدم نحو الهدف التالي (0.0 – 1.0)
  double get nextTargetProgress {
    final t = nextTarget;
    if (t == null) return 1.0;
    return (t.progressPct / 100).clamp(0.0, 1.0);
  }
}

// ─── محفظة مالك الوكالة ───────────────────────────────────────────────────────
class AgencyOwnerWallet {
  final int balance;       // إجمالي الألماس
  final int pending;       // مجمَّد في انتظار السحب
  final int available;     // = balance - pending
  final int earnedTotal;   // تراكمي منذ التأسيس

  const AgencyOwnerWallet({
    required this.balance,
    required this.pending,
    required this.available,
    required this.earnedTotal,
  });

  factory AgencyOwnerWallet.fromMap(Map<String, dynamic> m) {
    return AgencyOwnerWallet(
      balance:     (m['balance']      as num?)?.toInt() ?? 0,
      pending:     (m['pending']      as num?)?.toInt() ?? 0,
      available:   (m['available']    as num?)?.toInt() ?? 0,
      earnedTotal: (m['earned_total'] as num?)?.toInt() ?? 0,
    );
  }

  factory AgencyOwnerWallet.empty() =>
      const AgencyOwnerWallet(balance: 0, pending: 0, available: 0, earnedTotal: 0);
}

// ─── حركة دفتر مالك الوكالة ──────────────────────────────────────────────────
class AgencyOwnerLedgerEntry {
  final int id;
  final String txnType;
  final int amount;
  final int direction;   // 1 = دخل، -1 = خرج
  final int balanceAfter;
  final String? note;
  final DateTime createdAt;

  const AgencyOwnerLedgerEntry({
    required this.id,
    required this.txnType,
    required this.amount,
    required this.direction,
    required this.balanceAfter,
    this.note,
    required this.createdAt,
  });

  factory AgencyOwnerLedgerEntry.fromMap(Map<String, dynamic> m) {
    return AgencyOwnerLedgerEntry(
      id:           (m['id'] as num).toInt(),
      txnType:      m['txn_type'] as String? ?? '',
      amount:       (m['amount'] as num?)?.toInt() ?? 0,
      direction:    (m['direction'] as num?)?.toInt() ?? 1,
      balanceAfter: (m['balance_after'] as num?)?.toInt() ?? 0,
      note:         m['note'] as String?,
      createdAt:    DateTime.tryParse(m['created_at'] as String? ?? '') ??
                    ServerTimeService.instance.now(),
    );
  }

  bool get isCredit => direction == 1;

  String get typeLabel {
    switch (txnType) {
      case 'gift_commission': return 'عمولة وكالة';
      case 'target_bonus':    return 'مكافأة هدف';
      case 'exchange':        return 'تبادل بكوينز';
      case 'withdrawal':      return 'طلب سحب';
      case 'transfer':        return 'تحويل لوكيل';
      case 'adjustment':      return 'تعديل إداري';
      default:                return txnType;
    }
  }
}

// ─── لوحة تحكم مالك الوكالة الكاملة ─────────────────────────────────────────
class AgencyOwnerDashboard {
  final AgencyOwnerWallet wallet;
  final AgencyEngineSettings rates;
  final List<AgencyOwnerLedgerEntry> ledger;

  const AgencyOwnerDashboard({
    required this.wallet,
    required this.rates,
    required this.ledger,
  });

  factory AgencyOwnerDashboard.fromMap(Map<String, dynamic> m) {
    final walletMap = m['wallet'] as Map<String, dynamic>? ?? {};
    final ratesMap  = m['rates']  as Map<String, dynamic>? ?? {};
    final ledgerList = (m['ledger'] as List<dynamic>?) ?? [];

    return AgencyOwnerDashboard(
      wallet: AgencyOwnerWallet.fromMap(walletMap),
      rates:  AgencyEngineSettings.fromMap(ratesMap),
      ledger: ledgerList
          .map((e) => AgencyOwnerLedgerEntry.fromMap(
                Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
