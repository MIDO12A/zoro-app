// lib/features/host_agency/host_dashboard_screen.dart
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Glassmorphic 2035 Host Dashboard
// â€¢ Real-time diamond earnings (today / week / month)
// â€¢ Neon progress bars for monthly milestones
// â€¢ Agency membership card
// â€¢ Auto-refresh via StreamBuilder + periodic timer
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_compat.dart';

import '../../core/realtime/realtime_subscription.dart';
import '../../core/realtime/supabase_realtime_bridge.dart';
import '../../core/ui/in_app_toast.dart';
import 'data/agency_models.dart';
import 'data/agency_repository.dart';
import 'screens/agency_withdrawal_screen.dart';
import 'screens/agency_leaderboard_screen.dart';
import 'screens/agency_exit_screen.dart';
import 'package:flutter/foundation.dart';

import '../../core/cache/encrypted_image_provider.dart';
import 'package:provider/provider.dart';
import '../../services/dynamic_config_service.dart';

// â”€â”€ palette â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
_bgDeep     = Color(0xFF03030A);
_bgCard     = Color(0x800A0820);
_border     = Color(0x2D9C6BFF);
_purple     = Color(0xFF9C6BFF);
_gold       = Color(0xFFF6C453);
_cyan       = Color(0xFF00D4FF);
_red        = Color(0xFFFF4D6D);
_textMain   = Color(0xFFE8E6FF);
_textMuted  = Color(0xFF8A88AA);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen>
    with TickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  // data
  Map<String, dynamic>? _data;
  HostAgencyStats? _agencyStats;
  bool _loading = true;
  String? _error;

  // â”€â”€ v3 engine data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _engineV3Enabled = false;
  Map<String, dynamic>? _v3Data; // from get_host_dashboard_v3
  Timer? _countdownTimer;

  // animation controllers
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;

  // Realtime â€” ÙŠØ­Ù„ Ù…Ø­Ù„ Timer.periodic
  RealtimeSubscription? _rtDiamonds;
  RealtimeSubscription? _rtMilestones;
  RealtimeSubscription? _rtProgress;   // v3: monthly progress
  RealtimeSubscription? _rtV2Diamonds; // v2: host_agency_members diamonds_available
  Timer? _debounce;
  bool   _reloading = false;
  int    _prevMonthDiamonds = 0; // Ù„ÙƒØ´Ù Ø§Ù„ØªØºÙŠÙŠØ± ÙˆØ§Ù„Ø¥Ø´Ø¹Ø§Ø±

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1500),
    )..repeat();

    _loadData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _debounce?.cancel();
    _countdownTimer?.cancel();
    _rtDiamonds?.dispose();
    _rtMilestones?.dispose();
    _rtProgress?.dispose();
    _rtV2Diamonds?.dispose();
    super.dispose();
  }

  // â”€â”€ debounced reload â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!_reloading) _loadData();
    });
  }

  // â”€â”€ subscribe realtime Ø¨Ø¹Ø¯ Ù…Ø¹Ø±ÙØ© uid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _bindRealtime(String uid) {
    _rtDiamonds?.dispose();
    _rtMilestones?.dispose();
    _rtV2Diamonds?.dispose();

    // âœ… Ø§Ø´ØªØ±Ø§Ùƒ Ø¨Ø¯ÙØªØ± Ø§Ù„Ø£Ù„Ù…Ø§Ø³ (Ø§Ù„Ù…Ø­Ø±Ùƒ Ø§Ù„Ù‚Ø¯ÙŠÙ…)
    _rtDiamonds = SupabaseRealtimeBridge.subscribePostgres(
      topic: 'agency_ledger:$uid',
      event: PostgresChangeEvent.insert,
      table: 'agency_diamond_ledger',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      onPayload: (payload) {
        final amount    = (payload.newRecord['amount'] as num?)?.toInt() ?? 0;
        final direction = (payload.newRecord['direction'] as num?)?.toInt() ?? 1;
        if (amount > 0 && direction == 1) {
          KayanInAppToast.diamond('Ø­ØµÙ„Øª Ø¹Ù„Ù‰ ${_fmtN(amount)} ðŸ’Ž Ø¬Ø¯ÙŠØ¯!');
        }
        _scheduleReload();
      },
    );

    // âœ… Ø§Ø´ØªØ±Ø§Ùƒ Ø¨Ù€ host_agency_members (Ø§Ù„Ù…Ø­Ø±Ùƒ v2 â€” ÙŠÙƒØªØ¨ diamonds_available Ù‡Ù†Ø§)
    _rtV2Diamonds = SupabaseRealtimeBridge.subscribePostgres(
      topic: 'agency_member_v2:$uid',
      event: PostgresChangeEvent.update,
      table: 'host_agency_members',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      onPayload: (payload) {
        final newDiamonds = (payload.newRecord['diamonds_available'] as num?)?.toInt();
        final oldDiamonds = (payload.oldRecord['diamonds_available'] as num?)?.toInt();
        if (newDiamonds != null && oldDiamonds != null && newDiamonds > oldDiamonds) {
          final diff = newDiamonds - oldDiamonds;
          KayanInAppToast.diamond('ÙÙØªØ­ Ù…Ø³ØªÙˆÙ‰ Ø¬Ø¯ÙŠØ¯! +${_fmtN(diff)} ðŸ’Ž');
        }
        _scheduleReload();
        _loadV3Data(uid);
      },
    );

    // âœ… Ø§Ø´ØªØ±Ø§Ùƒ Ø¨ØªØºÙŠÙŠØ±Ø§Øª Ø§Ù„Ø¥Ù†Ø¬Ø§Ø²Ø§Øª (Ø§Ù„Ø¬Ø¯ÙˆÙ„ Ø§Ù„ØµØ­ÙŠØ­: agency_achieved_targets)
    _rtMilestones = SupabaseRealtimeBridge.subscribePostgres(
      topic: 'agency_achieved:$uid',
      event: PostgresChangeEvent.insert,
      table: 'agency_achieved_targets',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      onPayload: (_) => _scheduleReload(),
    );
  }

  // â”€â”€ v3 countdown ticker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _v3Data != null) setState(() {});
    });
  }

  // â”€â”€ v3 data load â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadV3Data(String uid) async {
    try {
      final res = await _sb.rpc('get_host_dashboard_v3', params: {'p_user_id': uid});
      if (res != null && res is Map) {
        final v3 = Map<String, dynamic>.from(res);
        if (mounted) {
          setState(() {
            _v3Data = v3;
            _engineV3Enabled = v3['engine_enabled'] == true;
          });
          _startCountdown();
          // Subscribe to progress changes
          if (_rtProgress == null) {
            _rtProgress = SupabaseRealtimeBridge.subscribePostgres(
              topic: 'host_progress:$uid',
              event: PostgresChangeEvent.update,
              table: 'host_monthly_progress',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              onPayload: (_) => _loadV3Data(uid),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[HostDashboardScreen] v3 load error: $e');
    }
  }

  Future<void> _loadData() async {
    if (_reloading) return;
    _reloading = true;
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) throw Exception('not_authenticated');

      // Ø§Ø¨Ø¯Ø£ Ø§Ù„Ù€ Realtime Ø£ÙˆÙ„ Ù…Ø±Ø© ÙÙ‚Ø·
      if (_rtDiamonds == null) _bindRealtime(uid);

      // ØªØ­Ù…ÙŠÙ„ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ù…Ø­Ø±Ùƒ v3 Ø¨Ø§Ù„ØªÙˆØ§Ø²ÙŠ
      _loadV3Data(uid);

      // âœ… Ø§Ø³ØªØ®Ø¯Ø§Ù… get_host_dashboard_v2 (Ø§Ù„Ù…ØµØ¯Ø± Ø§Ù„ÙˆØ­ÙŠØ¯ Ø§Ù„Ù…ÙˆØ­Ø¯)
      final results = await Future.wait<dynamic>([
        AgencyRepository.getHostStats(),
        _sb.from('profiles')
            .select('display_name, avatar_url, level, coins')
            .eq('id', uid)
            .maybeSingle(),
        _sb.from('agency_diamond_ledger')
            .select('amount, direction, created_at')
            .eq('user_id', uid)
            .eq('direction', 1)
            .gte('created_at', DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String()),
        _sb.from('agency_diamond_ledger')
            .select('amount, direction, created_at')
            .eq('user_id', uid)
            .eq('direction', 1)
            .gte('created_at', DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String()),
      ]);

      final agencyStats = results[0] as HostAgencyStats?;
      final profileRow  = results[1] as Map<String, dynamic>?;
      final todayRows   = (results[2] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final weekRows    = (results[3] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final todayD = todayRows.fold<int>(0, (sum, r) => sum + ((r['amount'] as num?)?.toInt() ?? 0));
      final weekD  = weekRows.fold<int>(0,  (sum, r) => sum + ((r['amount'] as num?)?.toInt() ?? 0));
      final monthD = agencyStats?.member.diamondsEarnedMonthly ?? 0;

      // Ø¨Ù†Ø§Ø¡ Ø®Ø±ÙŠØ·Ø© _data Ø§Ù„Ù…ÙˆØ­Ø¯Ø© Ù…Ù† Ø§Ù„Ù…ØµØ§Ø¯Ø± Ø§Ù„Ø¬Ø¯ÙŠØ¯Ø©
      final built = <String, dynamic>{
        'profile': {
          'display_name': profileRow?['display_name'] ?? 'â€”',
          'level':        profileRow?['level']        ?? 1,
          'avatar_url':   profileRow?['avatar_url'],
          'is_vip':       false,
        },
        'agency': agencyStats?.agency != null ? {
          'id':              agencyStats!.agency!.id,
          'name':            agencyStats.agency!.name,
          'commission_rate': 0.0,
        } : null,
        'milestones': (agencyStats?.targets ?? []).map((t) => <String, dynamic>{
          'id':           t.id,
          'title_ar':     t.title ?? 'â€”',
          'target':       t.targetDiamonds,
          'reward_type':  'coins',
          'reward_value': t.rewardCoins,
          'period_type':  'monthly',
          'earned':       t.earnedThisMonth,
          'is_completed': t.isAchieved,
          'reward_sent':  t.isAchieved,
          'progress_pct': t.progressPct,
        }).toList(),
        'month_diamonds': monthD,
        'week_diamonds':  weekD,
        'today_diamonds': todayD,
      };

      // ÙƒØ´Ù ØªØºÙŠÙŠØ± Ù…Ø§Ø³Ø§Øª Ø§Ù„Ø´Ù‡Ø± ÙˆØ¥Ø¸Ù‡Ø§Ø± toast
      final newMonthD = monthD;
      if (_prevMonthDiamonds > 0 && newMonthD > _prevMonthDiamonds) {
        final diff = newMonthD - _prevMonthDiamonds;
        KayanInAppToast.diamond('Ø£Ø±Ø¨Ø§Ø­Ùƒ Ø§Ù„Ø´Ù‡Ø±ÙŠØ©: +$diff ðŸ’Ž');
      }
      _prevMonthDiamonds = newMonthD;

      if (mounted) {
        setState(() {
          _data        = built;
          _agencyStats = agencyStats;
          _loading     = false;
          _error       = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    } finally {
      _reloading = false;
    }
  }

  // â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _fmt(dynamic v) {
    final n = (v is num ? v : num.tryParse(v.toString()) ?? 0).toInt();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}Ù…';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}Ùƒ';
    return n.toString();
  }

  static String _fmtN(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}Ù…';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}Ùƒ';
    return n.toString();
  }

  // â”€â”€ build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: _loading
            ? _buildSkeleton()
            : _error != null
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  // â”€â”€ skeleton â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSkeleton() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NeonSpinner(),
          SizedBox(height: 16),
          Text('Ø¬Ø§Ø±Ù ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øªâ€¦',
              style: TextStyle(color: _textMuted, fontFamily: 'IBM Plex Sans Arabic')),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: _red, size: 48),
          const SizedBox(height: 12),
          Text(_error ?? 'Ø®Ø·Ø£ ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ',
              style: TextStyle(color: _red, fontFamily: 'IBM Plex Sans Arabic')),
          const SizedBox(height: 16),
          _GlassButton(
            label: 'Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©',
            color: _purple,
            onTap: () { setState(() { _loading = true; _error = null; }); _loadData(); },
          ),
        ],
      ),
    );
  }

  // â”€â”€ main body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBody() {
    final d          = _data!;
    final profile    = d['profile']  as Map? ?? {};
    final agency     = d['agency']   as Map?;
    final milestones = (d['milestones'] as List?)?.cast<Map>() ?? [];

    final monthD = d['month_diamonds'] ?? 0;
    final weekD  = d['week_diamonds']  ?? 0;
    final todayD = d['today_diamonds'] ?? 0;

    return RefreshIndicator(
      color: _purple,
      backgroundColor: _bgCard,
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // â”€ app bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverAppBar(
            expandedHeight: 180,
            backgroundColor: Colors.transparent,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(profile, agency),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // â”€ stat row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                // v2 engine: Ø¹Ø±Ø¶ ÙƒÙˆÙŠÙ†Ø² Ø§Ù„Ø´Ù‡Ø± + Ø£Ù„Ù…Ø§Ø³ Ù…ØªØ§Ø­ + Ø§Ù„Ù…Ø³ØªÙˆÙ‰
                if (_engineV3Enabled && _v3Data != null) ...[
                  Row(children: [
                    Expanded(child: _StatCard(
                      label: 'ÙƒÙˆÙŠÙ†Ø² Ø§Ù„Ø´Ù‡Ø±',
                      value: _fmt(_v3Data!['received_coins_monthly'] ?? 0),
                      icon: 'ðŸª™', color: _cyan, pulse: _pulseCtrl,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      label: 'Ø£Ù„Ù…Ø§Ø³ Ù…ØªØ§Ø­',
                      value: _fmt(_v3Data!['diamonds_available'] ?? 0),
                      icon: 'ðŸ’Ž', color: _purple, pulse: _pulseCtrl,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      label: 'Ø§Ù„Ù…Ø³ØªÙˆÙ‰',
                      value: (_v3Data!['current_level_number'] ?? 0).toString(),
                      icon: 'ðŸ†', color: _gold, pulse: _pulseCtrl,
                    )),
                  ]),
                ] else ...[
                  // v1 engine: Ø¹Ø±Ø¶ Ø§Ù„Ø£Ù„Ù…Ø§Ø³ Ù…Ù† Ø¯ÙØªØ± Ø§Ù„ÙˆÙƒØ§Ù„Ø©
                  Row(children: [
                    Expanded(child: _StatCard(label: 'Ø§Ù„ÙŠÙˆÙ…',   value: _fmt(todayD), icon: 'ðŸ’Ž', color: _cyan,   pulse: _pulseCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(label: 'Ø§Ù„Ø£Ø³Ø¨ÙˆØ¹', value: _fmt(weekD),  icon: 'âš¡', color: _purple, pulse: _pulseCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(label: 'Ø§Ù„Ø´Ù‡Ø±',   value: _fmt(monthD), icon: 'ðŸ†', color: _gold,   pulse: _pulseCtrl)),
                  ]),
                ],

                const SizedBox(height: 24),

                // â”€ v3 engine cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (_engineV3Enabled && _v3Data != null) ...[
                  _EngineV3Banner(v3: _v3Data!),
                  const SizedBox(height: 16),
                  _CoinsProgressCard(v3: _v3Data!, shimmer: _shimmerCtrl),
                  const SizedBox(height: 16),
                  _UsdWalletCard(v3: _v3Data!),
                  const SizedBox(height: 16),
                  _MonthCountdownCard(v3: _v3Data!),
                  const SizedBox(height: 24),
                ],

                // â”€ agency card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (agency != null) ...[
                  _AgencyCard(agency: agency),
                  const SizedBox(height: 24),
                ],

                // â”€ milestones â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (milestones.isNotEmpty) ...[
                  _SectionHeader(label: 'Ø£Ù‡Ø¯Ø§Ù Ø§Ù„Ø´Ù‡Ø±', icon: 'ðŸŽ¯'),
                  const SizedBox(height: 12),
                  ...milestones.map((m) => _MilestoneCard(
                    milestone: m,
                    shimmer:   _shimmerCtrl,
                  )),
                  const SizedBox(height: 24),
                ],

                // â”€ agency wallet & targets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (_agencyStats != null) ...[
                  _AgencyWalletCard(
                    stats: _agencyStats!,
                    onExchange: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AgencyWithdrawalScreen())),
                    onWithdraw: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AgencyWithdrawalScreen())),
                    onLeaderboard: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AgencyLeaderboardScreen())),
                    onExit: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AgencyExitScreen())),
                  ),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader(Map profile, Map? agency) {
    final name     = profile['display_name'] ?? 'Ù…Ø¶ÙŠÙ';
    final level    = profile['level']         ?? 1;
    final avatar   = profile['avatar_url'];
    final isVip    = profile['is_vip'] == true;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end:   AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF1A0A3A), Color(0xFF03030A)],
        ),
      ),
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        left:   20,
        right:  20,
        bottom: 20,
      ),
      child: Row(
        children: [
          // avatar
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _purple, width: 2),
              boxShadow: [BoxShadow(color: _purple.withOpacity(.4), blurRadius: 16)],
            ),
            child: CircleAvatar(
              backgroundImage: avatar != null ? EncryptedImageProvider(avatar) : null,
              backgroundColor: _bgCard,
              child: avatar == null
                  ? Icon(Icons.person, color: _textMuted, size: 32)
                  : null,
            ),
          ),
          const SizedBox(width: 16),

          // info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Row(children: [
                  Text(name,
                      style: const TextStyle(
                        color: _textMain, fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'IBM Plex Sans Arabic',
                      )),
                  if (isVip) ...[
                    const SizedBox(width: 8),
                    _VipBadge(),
                  ],
                ]),
                const SizedBox(height: 4),
                Text('Ø§Ù„Ù…Ø³ØªÙˆÙ‰ $level',
                    style: TextStyle(color: _textMuted, fontSize: 13,
                        fontFamily: 'IBM Plex Sans Arabic')),
              ],
            ),
          ),

          // refresh icon
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _textMuted),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Sub-widgets
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.pulse,
  });

  final String label;
  final String value;
  final String icon;
  final Color  color;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final glow = pulse.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(.25 + .15 * glow)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.12 + .08 * glow),
                blurRadius: 16 + 8 * glow,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold,
                    fontFamily: 'Space Grotesk',
                    shadows: [Shadow(color: color.withOpacity(.6), blurRadius: 8)],
                  )),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(color: _textMuted, fontSize: 11,
                      fontFamily: 'IBM Plex Sans Arabic')),
            ],
          ),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AgencyCard extends StatelessWidget {
  const _AgencyCard({required this.agency});
  final Map agency;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final name    = agency['name']            ?? 'ÙˆÙƒØ§Ù„Ø©';
    final spec    = agency['specialty']       ?? '';
    final rate    = agency['commission_rate'] ?? 0.05;
    final members = agency['member_count']    ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gold.withOpacity(.08), _bgCard],
          begin: AlignmentDirectional.topStart,
          end:   AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(.3)),
        boxShadow: [BoxShadow(color: _gold.withOpacity(.08), blurRadius: 20)],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _gold.withOpacity(.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: Text('ðŸ¢', style: TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(color: _gold, fontSize: 15,
                    fontWeight: FontWeight.bold, fontFamily: 'IBM Plex Sans Arabic')),
            if (spec.isNotEmpty)
              Text(spec, style: TextStyle(color: _textMuted, fontSize: 12,
                  fontFamily: 'IBM Plex Sans Arabic')),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(rate * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: _gold, fontSize: 18,
                  fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk')),
          Text('$members Ø¹Ø¶Ùˆ',
              style: TextStyle(color: _textMuted, fontSize: 11,
                  fontFamily: 'IBM Plex Sans Arabic')),
        ]),
      ]),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone, required this.shimmer});
  final Map milestone;
  final AnimationController shimmer;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final name      = milestone['name']            ?? '';
    final target    = (milestone['target_value']   as num?)?.toDouble() ?? 1;
    final current   = (milestone['current_value']  as num?)?.toDouble() ?? 0;
    final completed = milestone['is_completed']    == true;
    final reward    = milestone['reward_type']     ?? '';
    final rewardVal = milestone['reward_value'];

    final pct = (current / target).clamp(0.0, 1.0);

    final barColor  = completed ? _gold : _purple;
    final rewardEmoji = _rewardEmoji(reward);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? _gold.withOpacity(.4) : _border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(name,
                style: TextStyle(
                  color: completed ? _gold : _textMain,
                  fontSize: 14, fontWeight: FontWeight.w600,
                  fontFamily: 'IBM Plex Sans Arabic',
                )),
          ),
          if (completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withOpacity(.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withOpacity(.4)),
              ),
              child: const Text('âœ… Ù…ÙƒØªÙ…Ù„',
                  style: TextStyle(color: _gold, fontSize: 11,
                      fontFamily: 'IBM Plex Sans Arabic')),
            ),
        ]),
        const SizedBox(height: 10),

        // progress bar
        Stack(children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          AnimatedFractionallySizedBox(
            widthFactor: pct,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) {
                return Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        barColor.withOpacity(.7),
                        barColor,
                        barColor.withOpacity(.7),
                      ],
                      stops: [
                        (shimmer.value - .3).clamp(0.0, 1.0),
                        shimmer.value.clamp(0.0, 1.0),
                        (shimmer.value + .3).clamp(0.0, 1.0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: barColor.withOpacity(.5), blurRadius: 6),
                    ],
                  ),
                );
              },
            ),
          ),
        ]),

        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: barColor, fontSize: 12,
                    fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold)),
            Text('${_fmt(current)} / ${_fmt(target)} ðŸ’Ž',
                style: TextStyle(color: _textMuted, fontSize: 11,
                    fontFamily: 'Space Grotesk')),
            if (rewardVal != null)
              Text('$rewardEmoji $rewardVal',
                  style: TextStyle(color: _gold, fontSize: 11,
                      fontFamily: 'Space Grotesk')),
          ],
        ),
      ]),
    );
  }

  String _rewardEmoji(String type) {
    switch (type) {
      case 'gold':     return 'ðŸª™';
      case 'diamonds': return 'ðŸ’Ž';
      case 'vip_days': return 'ðŸ‘‘';
      case 'badge':    return 'ðŸ…';
      default:         return 'ðŸŽ';
    }
  }

  String _fmt(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}Ù…';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}Ùƒ';
    return n.toStringAsFixed(0);
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared micro-widgets
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
            color: _textMain, fontSize: 16, fontWeight: FontWeight.bold,
            fontFamily: 'IBM Plex Sans Arabic',
          )),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 1, color: _border)),
    ]);
  }
}

class _VipBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF6C453)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text('VIP',
          style: TextStyle(color: Colors.black, fontSize: 10,
              fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk')),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color  color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.4)),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontFamily: 'IBM Plex Sans Arabic',
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _NeonSpinner extends StatefulWidget {
  const _NeonSpinner();

  @override
  State<_NeonSpinner> createState() => _NeonSpinnerState();
}

class _NeonSpinnerState extends State<_NeonSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [_purple, _purple.withOpacity(0)]),
            boxShadow: [BoxShadow(color: _purple.withOpacity(.5), blurRadius: 12)],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Agency Wallet & Target Progress Card (HA7 â€” injected into HostDashboardScreen)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AgencyWalletCard extends StatelessWidget {
  final HostAgencyStats stats;
  final VoidCallback onExchange;
  final VoidCallback onWithdraw;
  final VoidCallback onLeaderboard;
  final VoidCallback onExit;

  const _AgencyWalletCard({
    required this.stats,
    required this.onExchange,
    required this.onWithdraw,
    required this.onLeaderboard,
    required this.onExit,
  });

  static String _fmtK(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  static const _tierColors = {
    AgencyTier.bronze:   Color(0xFFCD7F32),
    AgencyTier.silver:   Color(0xFFC0C0C0),
    AgencyTier.gold:     Color(0xFFD4AF37),
    AgencyTier.platinum: Color(0xFF6ADBF5),
    AgencyTier.diamond:  Color(0xFFB39DDB),
  };

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final m          = stats.member;
    final a          = stats.agency;
    final nextTarget = stats.nextTarget;
    final progress   = stats.nextTargetProgress;
    final tierColor  = _tierColors[a?.tier ?? AgencyTier.gold] ?? _gold;

    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: tierColor.withOpacity(0.08), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Text('â™¦ Ù…Ø­ÙØ¸Ø© Ø§Ù„ÙˆÙƒØ§Ù„Ø©', style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: onLeaderboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('ðŸ† Ø§Ù„ØªØµÙ†ÙŠÙ', style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),

          // Agency name + rank
          if (a != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(a.name,
                style: TextStyle(color: _textMain, fontWeight: FontWeight.w600, fontSize: 14))),
              if (a.rank != null)
                Text('#${a.rank} Ø¹Ø§Ù„Ù…ÙŠØ§Ù‹', style: TextStyle(color: tierColor.withOpacity(0.7), fontSize: 12)),
            ]),
          ),

          const SizedBox(height: 14),

          // Diamond wallet stats (âœ… ÙŠØ¹Ø±Ø¶ Ø§Ù„Ø±ØµÙŠØ¯ Ø§Ù„Ù…ØªØ§Ø­ Ø¨Ø¹Ø¯ Ø®ØµÙ… Ø§Ù„Ù…Ø¬Ù…Ù‘Ø¯)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _WalletStat(label: 'â™¦ Ø§Ù„Ø´Ù‡Ø±',    value: _fmtK(m.diamondsEarnedMonthly),  color: _purple),
              _WalletStat(label: 'â™¦ Ø§Ù„Ù…ØªØ§Ø­',   value: _fmtK(m.diamondsAvailable),       color: _cyan),
              _WalletStat(label: 'â™¦ Ø§Ù„ØªØ±Ø§ÙƒÙ…ÙŠ', value: _fmtK(m.diamondsEarnedCumulative),color: _gold),
            ]),
          ),
          if (m.diamondsPendingWithdrawal > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.lock_rounded, color: Color(0xFFFF9800), size: 12),
                const SizedBox(width: 4),
                Text('${_fmtK(m.diamondsPendingWithdrawal)} â™¦ Ù…Ø¬Ù…Ù‘Ø¯',
                    style: const TextStyle(color: Color(0xFFFF9800), fontSize: 11)),
              ]),
            ),
          const SizedBox(height: 4),

          const SizedBox(height: 14),

          // Target progress
          if (nextTarget != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('ðŸŽ¯ Ø§Ù„Ù‡Ø¯Ù Ø§Ù„ØªØ§Ù„ÙŠ: ', style: TextStyle(color: _textMuted, fontSize: 12)),
                    Text('${_fmtK(nextTarget.targetDiamonds)} â™¦', style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    const Spacer(),
                    Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: tierColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Ø§Ù„Ù…ÙƒØ§ÙØ£Ø©: ${nextTarget.rewardSummary}',
                    style: TextStyle(color: _textMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(children: [
              Expanded(child: _WalletBtn(label: 'ðŸ’± ØªØ¨Ø§Ø¯Ù„', color: _cyan, onTap: onExchange)),
              const SizedBox(width: 8),
              Expanded(child: _WalletBtn(label: 'ðŸ’¸ Ø³Ø­Ø¨', color: _gold, onTap: onWithdraw)),
              const SizedBox(width: 8),
              Expanded(child: _WalletBtn(label: 'ðŸšª Ø®Ø±ÙˆØ¬', color: _red, onTap: onExit)),
            ]),
          ),

          // Rank in agency
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            child: Text(
              'ØªØ±ØªÙŠØ¨Ùƒ ÙÙŠ Ø§Ù„ÙˆÙƒØ§Ù„Ø©: #${stats.rankInAgency} Ù…Ù† ${stats.totalMembersInAgency}',
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _WalletStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: _textMuted, fontSize: 10)),
        ]),
      ),
    );
  }
}

class _WalletBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final VoidCallback onTap;
  const _WalletBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  WIDGETS â€” Ø§Ù„Ù…Ø­Ø±Ùƒ Ø§Ù„Ø§Ù‚ØªØµØ§Ø¯ÙŠ v3
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// â”€ Ø¨Ø§Ù†Ø±: Ø§Ù„Ù…Ø­Ø±Ùƒ v3 Ù…ÙÙØ¹ÙŽÙ‘Ù„ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _EngineV3Banner extends StatelessWidget {
  final Map<String, dynamic> v3;
  const _EngineV3Banner({required this.v3});

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final dryRun = v3['dry_run'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dryRun
              ? [const Color(0xFF3D2A00), const Color(0xFF1A1000)]
              : [const Color(0xFF0A2A0A), const Color(0xFF030F03)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dryRun ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(dryRun ? 'ðŸ§ª' : 'ðŸš€', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dryRun ? 'Ø§Ù„Ù…Ø­Ø±Ùƒ v2 â€” ÙˆØ¶Ø¹ Ø§Ù„Ø§Ø®ØªØ¨Ø§Ø± (Ù„Ø§ Ù…Ø¯ÙÙˆØ¹Ø§Øª Ø­Ù‚ÙŠÙ‚ÙŠØ©)'
                     : 'Ø§Ù„Ù…Ø­Ø±Ùƒ Ø§Ù„Ø§Ù‚ØªØµØ§Ø¯ÙŠ v2 Ù…ÙÙØ¹ÙŽÙ‘Ù„ â€” ÙƒÙˆÙŠÙ†Ø² + Ù…Ø³ØªÙˆÙŠØ§Øª + USD',
              style: TextStyle(
                color: dryRun ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€ Ø¨Ø·Ø§Ù‚Ø©: ØªÙ‚Ø¯Ù… Ø§Ù„ÙƒÙˆÙŠÙ†Ø² Ù†Ø­Ùˆ Ø§Ù„Ù…Ø³ØªÙˆÙ‰ Ø§Ù„ØªØ§Ù„ÙŠ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CoinsProgressCard extends StatelessWidget {
  final Map<String, dynamic> v3;
  final AnimationController shimmer;
  const _CoinsProgressCard({required this.v3, required this.shimmer});

  String _fmt(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}Ù…';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}Ùƒ';
    return n.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final totalCoins   = (v3['received_coins_monthly'] as num?)?.toInt() ?? 0;
    final nextLevel    = v3['next_level'] as Map<String, dynamic>?;
    final levelsUnlocked = (v3['levels_unlocked'] as List?)?.cast<int>() ?? [];
    final curLevel     = (v3['current_level_number'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x800A0820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2D9C6BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('ðŸª™', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'ØªÙ‚Ø¯Ù… Ø§Ù„ÙƒÙˆÙŠÙ†Ø² Ø§Ù„Ø´Ù‡Ø±ÙŠ',
                style: TextStyle(
                  color: Color(0xFFE8E6FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (curLevel > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x33F6C453),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x66F6C453)),
                  ),
                  child: Text(
                    'Ø§Ù„Ù…Ø³ØªÙˆÙ‰ $curLevel ðŸ†',
                    style: const TextStyle(color: Color(0xFFF6C453), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Total coins earned this month
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(totalCoins),
                style: const TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                ' ÙƒÙˆÙŠÙ†Ø² Ù‡Ø°Ø§ Ø§Ù„Ø´Ù‡Ø±',
                style: TextStyle(color: Color(0xFF8A88AA), fontSize: 13),
              ),
            ],
          ),

          // Next level progress
          if (nextLevel != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nextLevel['level_name'] ?? 'Ø§Ù„Ù…Ø³ØªÙˆÙ‰ Ø§Ù„ØªØ§Ù„ÙŠ',
                  style: const TextStyle(color: Color(0xFFF6C453), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_fmt((nextLevel['remaining_coins'] as num?) ?? 0)} Ù…ØªØ¨Ù‚ÙŠ',
                  style: const TextStyle(color: Color(0xFF8A88AA), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ((nextLevel['pct_progress'] as num?)?.toDouble() ?? 0) / 100,
                backgroundColor: const Color(0x22FFFFFF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF6C453)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${nextLevel['pct_progress']?.toStringAsFixed(1) ?? 0}%',
                  style: const TextStyle(color: Color(0xFFF6C453), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Ù…ÙƒØ§ÙØ£Ø©: \$${nextLevel['host_cash_usd'] ?? 0} + ðŸ’Ž${_fmt((nextLevel['host_diamond_usd'] as num?) ?? 0)}',
                  style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11),
                ),
              ],
            ),
          ] else if (levelsUnlocked.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
                SizedBox(width: 6),
                Text(
                  'Ø£Ù†Ø¬Ø²Øª Ø¬Ù…ÙŠØ¹ Ø§Ù„Ù…Ø³ØªÙˆÙŠØ§Øª Ù‡Ø°Ø§ Ø§Ù„Ø´Ù‡Ø±! ðŸŽ‰',
                  style: TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],

          // Unlocked levels badges
          if (levelsUnlocked.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: levelsUnlocked.map((lvl) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1D3A00), Color(0xFF0A1A00)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF22C55E)),
                ),
                child: Text('âœ… Ù…Ø³ØªÙˆÙ‰ $lvl Ù…ÙƒØªÙ…Ù„',
                  style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// â”€ Ø¨Ø·Ø§Ù‚Ø©: Ù…Ø­ÙØ¸Ø© USD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _UsdWalletCard extends StatelessWidget {
  final Map<String, dynamic> v3;
  const _UsdWalletCard({required this.v3});

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final usdBalance  = (v3['usd_balance'] as num?)?.toDouble() ?? 0;
    final totalEarned = (v3['total_earned_usd'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1A0A), Color(0xFF030F03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4422C55E)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x2222C55E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('ðŸ’µ', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ù…Ø­ÙØ¸Ø© Ø§Ù„Ø¯ÙˆÙ„Ø§Ø±', style: TextStyle(color: Color(0xFF8A88AA), fontSize: 12)),
                Text(
                  '\$${usdBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…ÙƒØªØ³ÙŽØ¨: \$${totalEarned.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
              ],
            ),
          ),
          if (usdBalance > 0)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyWithdrawalScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x2222C55E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x6622C55E)),
                ),
                child: const Text('Ø³Ø­Ø¨ â†’', style: TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

// â”€ Ø¨Ø·Ø§Ù‚Ø©: Ø¹Ø¯Ø§Ø¯ ØªÙ†Ø§Ø²Ù„ÙŠ Ù„Ù†Ù‡Ø§ÙŠØ© Ø§Ù„Ø´Ù‡Ø± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MonthCountdownCard extends StatelessWidget {
  final Map<String, dynamic> v3;
  const _MonthCountdownCard({required this.v3});

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final secs = (v3['month_end_countdown_secs'] as num?)?.toInt() ?? 0;
    final days  = secs ~/ 86400;
    final hours = (secs % 86400) ~/ 3600;
    final mins  = (secs % 3600) ~/ 60;
    final s     = secs % 60;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x801A0820),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x449C6BFF)),
      ),
      child: Row(
        children: [
          const Text('â°', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ù…ØªØ¨Ù‚ÙŠ Ø­ØªÙ‰ Ø¥ØºÙ„Ø§Ù‚ Ø§Ù„Ø´Ù‡Ø±', style: TextStyle(color: Color(0xFF8A88AA), fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                '$days ÙŠÙˆÙ…  $hours:${mins.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Color(0xFF9C6BFF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


