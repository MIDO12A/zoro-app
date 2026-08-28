// lib/features/host_agency/agency_dashboard_screen.dart
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Glassmorphic 2035 Agency Dashboard
// â€¢ Team aggregation: total diamonds, top earner
// â€¢ Weekly leaderboard with animated rank bars
// â€¢ Agency milestone progress
// â€¢ Auto-reward display when milestone unlocked
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_compat.dart';
import 'package:provider/provider.dart';
import '../../services/dynamic_config_service.dart';

import '../../core/realtime/realtime_subscription.dart';
import '../../core/realtime/supabase_realtime_bridge.dart';
import '../../core/ui/in_app_toast.dart';
import 'screens/agency_join_requests_screen.dart';
import 'screens/agency_chat_screen.dart';
import 'screens/agency_invite_by_id_screen.dart';
import 'screens/agency_owner_wallet_screen.dart';
import 'data/agency_chat_models.dart';

// â”€â”€ palette (same design system as host_dashboard_screen) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
_bgDeep    = Color(0xFF03030A);
_bgCard    = Color(0x800A0820);
_border    = Color(0x2D9C6BFF);
_purple    = Color(0xFF9C6BFF);
_gold      = Color(0xFFF6C453);
_cyan      = Color(0xFF00D4FF);
_green     = Color(0xFF00E5A0);
_red       = Color(0xFFFF4D6D);
_textMain  = Color(0xFFE8E6FF);
_textMuted = Color(0xFF8A88AA);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AgencyDashboardScreen extends StatefulWidget {
  /// Pass either an explicit agencyId or leave null to auto-detect from the
  /// current user's host_agency_members row.
  const AgencyDashboardScreen({super.key, this.agencyId});
  final String? agencyId;

  @override
  State<AgencyDashboardScreen> createState() => _AgencyDashboardScreenState();
}

class _AgencyDashboardScreenState extends State<AgencyDashboardScreen>
    with TickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  Map<String, dynamic>? _data;
  bool    _loading = true;
  String? _error;
  String? _resolvedAgencyId;

  // reward pop-up
  Map<String, dynamic>? _pendingReward;

  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _rewardCtrl;

  // Realtime â€” ÙŠØ­Ù„ Ù…Ø­Ù„ Timer.periodic
  RealtimeSubscription? _rtMembers;
  RealtimeSubscription? _rtTransactions;
  Timer? _debounce;   // debounce 800ms Ù„Ù…Ù†Ø¹ Ø§Ù„ØªØ­Ø¯ÙŠØ«Ø§Øª Ø§Ù„Ù…ØªÙƒØ±Ø±Ø©
  bool   _reloading = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat();

    _rewardCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );

    _loadData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _rewardCtrl.dispose();
    _debounce?.cancel();
    _rtMembers?.dispose();
    _rtTransactions?.dispose();
    super.dispose();
  }

  // â”€â”€ debounced reload â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!_reloading) _loadData();
    });
  }

  // â”€â”€ subscribe realtime Ø¨Ø¹Ø¯ Ù…Ø¹Ø±ÙØ© agencyId â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _bindRealtime(String agencyId) {
    _rtMembers?.dispose();
    _rtTransactions?.dispose();

    // ØªØºÙŠÙŠØ±Ø§Øª Ø£Ø¹Ø¶Ø§Ø¡ Ø§Ù„ÙˆÙƒØ§Ù„Ø©
    _rtMembers = SupabaseRealtimeBridge.subscribePostgres(
      topic: 'agency_members:$agencyId',
      event: PostgresChangeEvent.all,
      table: 'host_agency_members',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'agency_id',
        value: agencyId,
      ),
      onPayload: (_) => _scheduleReload(),
    );

    // âœ… ØªØºÙŠÙŠØ±Ø§Øª Ø¯ÙØªØ± Ø§Ù„Ø£Ù„Ù…Ø§Ø³ Ø§Ù„Ù…ÙˆØ­Ø¯ (Ø§Ù„Ø¬Ø¯ÙˆÙ„ Ø§Ù„ØµØ­ÙŠØ­: agency_diamond_ledger)
    _rtTransactions = SupabaseRealtimeBridge.subscribePostgres(
      topic: 'agency_ledger:$agencyId',
      event: PostgresChangeEvent.insert,
      table: 'agency_diamond_ledger',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'agency_id',
        value: agencyId,
      ),
      onPayload: (payload) {
        final amount    = (payload.newRecord['amount'] as num?)?.toInt() ?? 0;
        final direction = (payload.newRecord['direction'] as num?)?.toInt() ?? 1;
        if (amount > 0 && direction == 1) {
          KayanInAppToast.agency('Ø§Ù„ÙˆÙƒØ§Ù„Ø©: +$amount ðŸ’Ž Ù…Ù† Ø£Ø­Ø¯ Ø§Ù„Ø£Ø¹Ø¶Ø§Ø¡');
        }
        _scheduleReload();
      },
    );
  }

  // â”€â”€ data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadData() async {
    if (_reloading) return;
    _reloading = true;
    try {
      String? agencyId = widget.agencyId ?? _resolvedAgencyId;

      // auto-detect agency from current user membership
      if (agencyId == null) {
        final uid = _sb.auth.currentUser?.id;
        if (uid == null) throw Exception('not_authenticated');

        final row = await _sb
            .from('host_agency_members')
            .select('agency_id')
            .eq('user_id', uid)
            .maybeSingle();

        if (row == null) throw Exception('not_in_agency');
        agencyId = row['agency_id'] as String;
        _resolvedAgencyId = agencyId;

        // Ø§Ø¨Ø¯Ø£ Ø§Ù„Ù€ Realtime ÙÙˆØ± Ù…Ø¹Ø±ÙØ© agencyId (guard: widget Ù‚Ø¯ ÙŠÙƒÙˆÙ† ØªÙ„Ù Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ù€ await)
        if (!mounted) return;
        _bindRealtime(agencyId);
      }

      final res = await _sb.rpc('agency_get_dashboard',
          params: {'p_agency_id': agencyId});
      final parsed = Map<String, dynamic>.from(res as Map);

      // check for newly completed milestones â†’ show reward pop-up + toast
      final rawMilestones = (parsed['milestones'] as List?) ?? const [];
      for (final raw in rawMilestones) {
        final m = Map<String, dynamic>.from(raw as Map);
        if (m['just_completed'] == true && m['reward_type'] != null) {
          _pendingReward = m;
          KayanInAppToast.agency('Ø£ÙƒÙ…Ù„Øª Ù‡Ø¯Ù Ø§Ù„ÙˆÙƒØ§Ù„Ø©: ${m['name'] ?? ''}! ðŸŽ‰');
          break;
        }
      }

      if (mounted) {
        setState(() {
          _data    = parsed;
          _loading = false;
          _error   = null;
        });

        if (_pendingReward != null) {
          await Future.delayed(const Duration(milliseconds: 300));
          _rewardCtrl.forward(from: 0);
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    } finally {
      _reloading = false;
    }
  }

  // â”€â”€ format helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _fmt(dynamic v) {
    final n = (v is num ? v : num.tryParse(v.toString()) ?? 0).toInt();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}Ù…';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}Ùƒ';
    return n.toString();
  }

  // â”€â”€ build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: Stack(children: [
          _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildBody(),

          // reward pop-up overlay
          if (_pendingReward != null) _buildRewardOverlay(),
        ]),
      ),
    );
  }

  Widget _buildLoading() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _NeonSpinner(),
      SizedBox(height: 16),
      Text('Ø¬Ø§Ø±Ù ØªØ­Ù…ÙŠÙ„ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„ÙˆÙƒØ§Ù„Ø©â€¦',
          style: TextStyle(color: _textMuted, fontFamily: 'IBM Plex Sans Arabic')),
    ]),
  );

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, color: _red, size: 48),
      const SizedBox(height: 12),
      Text(_error ?? 'Ø®Ø·Ø£', style: TextStyle(color: _red,
          fontFamily: 'IBM Plex Sans Arabic')),
      const SizedBox(height: 16),
      _GlassButton(label: 'Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©', color: _purple,
          onTap: () { setState(() { _loading = true; _error = null; }); _loadData(); }),
    ]),
  );

  // â”€â”€ main body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBody() {
    final d          = _data!;
    final agency     = d['agency']     as Map? ?? {};
    final members    = (d['members']   as List?)?.cast<Map>() ?? [];
    final milestones = (d['milestones'] as List?)?.cast<Map>() ?? [];

    final name          = agency['name']             ?? 'Ø§Ù„ÙˆÙƒØ§Ù„Ø©';
    final spec          = agency['specialty']        ?? '';
    final rate          = agency['commission_rate']  ?? 0.05;
    final totalD        = agency['monthly_diamonds'] ?? 0;
    final agencyPubId   = agency['agency_public_id'] as String?;

    // sort members by diamonds desc for leaderboard
    final ranked = [...members]
      ..sort((a, b) => ((b['week_diamonds'] ?? 0) as num)
          .compareTo((a['week_diamonds'] ?? 0) as num));

    return RefreshIndicator(
      color: _purple,
      backgroundColor: _bgCard,
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // â”€ header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverAppBar(
            expandedHeight: 160,
            backgroundColor: Colors.transparent,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _AgencyHeader(
                name: name,
                spec: spec,
                rate: rate,
                totalDiamonds: totalD,
                memberCount: members.length,
                pulseCtrl: _pulseCtrl,
                agencyPublicId: agencyPubId,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // â”€ kpi row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Row(children: [
                  Expanded(child: _KpiTile(
                    label: 'Ù…Ø§Ø³Ø© Ø§Ù„Ø´Ù‡Ø±', value: _fmt(totalD),
                    icon: 'ðŸ’Ž', color: _cyan)),
                  const SizedBox(width: 10),
                  Expanded(child: _KpiTile(
                    label: 'Ø§Ù„Ø£Ø¹Ø¶Ø§Ø¡', value: '${members.length}',
                    icon: 'ðŸ‘¥', color: _purple)),
                  const SizedBox(width: 10),
                  Expanded(child: _KpiTile(
                    label: 'Ø§Ù„Ø¹Ù…ÙˆÙ„Ø©', value: '${(rate * 100).toStringAsFixed(0)}%',
                    icon: 'ðŸ’°', color: _gold)),
                ]),

                const SizedBox(height: 24),

                // â”€ weekly leaderboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (ranked.isNotEmpty) ...[
                  const _SectionHeader(label: 'Ù…ØªØµØ¯Ø±Ùˆ Ø§Ù„Ø£Ø³Ø¨ÙˆØ¹', icon: 'ðŸ…'),
                  const SizedBox(height: 12),
                  _LeaderboardList(
                    members:  ranked,
                    shimmer:  _shimmerCtrl,
                    fmtFn:    _fmt,
                  ),
                  const SizedBox(height: 24),
                ],

                // â”€ agency milestones â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (milestones.isNotEmpty) ...[
                  const _SectionHeader(label: 'Ø£Ù‡Ø¯Ø§Ù Ø§Ù„ÙˆÙƒØ§Ù„Ø©', icon: 'ðŸŽ¯'),
                  const SizedBox(height: 12),
                  ...milestones.map((m) => _AgencyMilestoneCard(
                    milestone: m,
                    shimmer:   _shimmerCtrl,
                    fmtFn:     _fmt,
                  )),
                  const SizedBox(height: 24),
                ],

                // â”€ quick actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                const _SectionHeader(label: 'Ø¥Ø¬Ø±Ø§Ø¡Ø§Øª Ø³Ø±ÙŠØ¹Ø©', icon: 'âš¡'),
                const SizedBox(height: 12),
                _AgencyQuickActions(
                  agencyId: _resolvedAgencyId ?? widget.agencyId ?? '',
                  agencyName: ((_data?['agency'] as Map?)?['name'] as String?) ?? 'Ø§Ù„ÙˆÙƒØ§Ù„Ø©',
                  pendingCount: ((_data?['pending_members_count'] as num?)?.toInt() ?? 0),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ reward pop-up â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildRewardOverlay() {
    final r = _pendingReward!;
    return AnimatedBuilder(
      animation: _rewardCtrl,
      builder: (_, child) {
        final t = Curves.elasticOut.transform(_rewardCtrl.value);
        return Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _pendingReward = null),
            child: Container(
              color: Colors.black.withOpacity(.7 * _rewardCtrl.value),
              child: Center(
                child: Transform.scale(
                  scale: t,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0A25),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _gold.withOpacity(.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: _gold.withOpacity(.2), blurRadius: 40),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ðŸŽ‰', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('ØªÙ‡Ø§Ù†ÙŠÙ†Ø§! Ø£ÙƒÙ…Ù„Øª Ø§Ù„Ù‡Ø¯Ù',
              style: TextStyle(color: _gold, fontSize: 18,
                  fontWeight: FontWeight.bold, fontFamily: 'IBM Plex Sans Arabic')),
          const SizedBox(height: 8),
          Text(r['name'] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 14,
                  fontFamily: 'IBM Plex Sans Arabic')),
          const SizedBox(height: 16),
          _RewardChip(type: r['reward_type'], value: r['reward_value']),
          const SizedBox(height: 20),
          _GlassButton(label: 'Ø±Ø§Ø¦Ø¹! ðŸš€', color: _gold,
              onTap: () => setState(() => _pendingReward = null)),
        ]),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Sub-widgets
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AgencyHeader extends StatelessWidget {
  const _AgencyHeader({
    required this.name,
    required this.spec,
    required this.rate,
    required this.totalDiamonds,
    required this.memberCount,
    required this.pulseCtrl,
    this.agencyPublicId,
  });
  final String name;
  final String spec;
  final double rate;
  final dynamic totalDiamonds;
  final int memberCount;
  final AnimationController pulseCtrl;
  final String? agencyPublicId;

  String _fmt(dynamic v) {
    final n = (v is num ? v : num.tryParse(v.toString()) ?? 0).toInt();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}Ù…';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}Ùƒ';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              _purple.withOpacity(.12 + .06 * pulseCtrl.value),
              const Color(0xFF03030A),
            ],
          ),
        ),
        padding: EdgeInsets.only(
          top:    MediaQuery.of(context).padding.top + 12,
          left:   20, right: 20, bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple.withOpacity(.4)),
                  boxShadow: [BoxShadow(
                      color: _purple.withOpacity(.3 + .2 * pulseCtrl.value),
                      blurRadius: 16)],
                ),
                child: const Center(child: Text('ðŸŽ™ï¸', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: TextStyle(color: _textMain, fontSize: 18,
                          fontWeight: FontWeight.bold, fontFamily: 'IBM Plex Sans Arabic')),
                  if (spec.isNotEmpty)
                    Text(spec, style: TextStyle(color: _textMuted, fontSize: 12,
                        fontFamily: 'IBM Plex Sans Arabic')),
                  if (agencyPublicId != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _gold.withOpacity(0.4)),
                      ),
                      child: Text(
                        'ID: $agencyPublicId',
                        style: const TextStyle(
                          color: _gold, fontSize: 11,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text('${_fmt(totalDiamonds)} ðŸ’Ž Ù‡Ø°Ø§ Ø§Ù„Ø´Ù‡Ø±',
                style: TextStyle(
                  color: _cyan, fontSize: 22, fontWeight: FontWeight.bold,
                  fontFamily: 'Space Grotesk',
                  shadows: [Shadow(color: _cyan.withOpacity(.6), blurRadius: 10)],
                )),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value,
      required this.icon, required this.color});
  final String label, value, icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(.25)),
      boxShadow: [BoxShadow(color: color.withOpacity(.08), blurRadius: 12)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontSize: 18,
          fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk',
          shadows: [Shadow(color: color.withOpacity(.5), blurRadius: 6)])),
      Text(label, style: TextStyle(color: _textMuted, fontSize: 10,
          fontFamily: 'IBM Plex Sans Arabic')),
    ]),
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.members,
    required this.shimmer,
    required this.fmtFn,
  });
  final List<Map> members;
  final AnimationController shimmer;
  final String Function(dynamic) fmtFn;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    // compute max for bar scaling
    final maxD = members.fold<double>(
      1,
      (prev, m) => math.max(prev, ((m['week_diamonds'] ?? 0) as num).toDouble()),
    );

    return Column(
      children: List.generate(members.length, (i) {
        final m     = members[i];
        final name  = m['display_name'] ?? 'â€”';
        final weekD = ((m['week_diamonds'] ?? 0) as num).toDouble();
        final pct   = (weekD / maxD).clamp(0.0, 1.0);
        final barC  = i == 0 ? _gold : i == 1 ? _textMuted : i == 2 ? _cyan : _purple;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: i == 0 ? _gold.withOpacity(.3) : _border),
          ),
          child: Row(children: [
            // rank badge
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: barC.withOpacity(.15),
                shape: BoxShape.circle,
                border: Border.all(color: barC.withOpacity(.4)),
              ),
              child: Center(child: Text('${i + 1}',
                  style: TextStyle(color: barC, fontSize: 12,
                      fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk'))),
            ),
            const SizedBox(width: 10),

            // name + bar
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: _textMain, fontSize: 13,
                    fontFamily: 'IBM Plex Sans Arabic')),
                const SizedBox(height: 6),
                Stack(children: [
                  Container(height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.06),
                        borderRadius: BorderRadius.circular(3),
                      )),
                  AnimatedFractionallySizedBox(
                    widthFactor: pct,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    child: AnimatedBuilder(
                      animation: shimmer,
                      builder: (_, __) => Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(colors: [
                            barC.withOpacity(.6), barC, barC.withOpacity(.6),
                          ]),
                          boxShadow: [BoxShadow(color: barC.withOpacity(.5), blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            )),

            const SizedBox(width: 10),
            Text('${fmtFn(weekD)} ðŸ’Ž',
                style: TextStyle(color: barC, fontSize: 12,
                    fontFamily: 'Space Grotesk', fontWeight: FontWeight.w600)),
          ]),
        );
      }),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AgencyMilestoneCard extends StatelessWidget {
  const _AgencyMilestoneCard({
    required this.milestone,
    required this.shimmer,
    required this.fmtFn,
  });
  final Map milestone;
  final AnimationController shimmer;
  final String Function(dynamic) fmtFn;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final name      = milestone['name']           ?? '';
    final target    = (milestone['target_value']  as num?)?.toDouble() ?? 1;
    final current   = (milestone['current_value'] as num?)?.toDouble() ?? 0;
    final completed = milestone['is_completed']   == true;
    final reward    = milestone['reward_type']    ?? '';
    final rewardVal = milestone['reward_value'];

    final pct    = (current / target).clamp(0.0, 1.0);
    final barC   = completed ? _gold : _green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: completed ? _gold.withOpacity(.4) : _border),
        boxShadow: completed
            ? [BoxShadow(color: _gold.withOpacity(.08), blurRadius: 16)]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name,
              style: TextStyle(color: completed ? _gold : _textMain,
                  fontSize: 14, fontWeight: FontWeight.w600,
                  fontFamily: 'IBM Plex Sans Arabic'))),
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

        Stack(children: [
          Container(height: 8, decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(4))),
          AnimatedFractionallySizedBox(
            widthFactor: pct,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) => Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [
                    barC.withOpacity(.7), barC, barC.withOpacity(.7),
                  ]),
                  boxShadow: [BoxShadow(color: barC.withOpacity(.5), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: barC, fontSize: 12,
                  fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold)),
          Text('${fmtFn(current)} / ${fmtFn(target)} ðŸ’Ž',
              style: TextStyle(color: _textMuted, fontSize: 11,
                  fontFamily: 'Space Grotesk')),
          if (rewardVal != null)
            _RewardChip(type: reward, value: rewardVal),
        ]),
      ]),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.type, required this.value});
  final String type;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final emoji = switch (type) {
      'gold'     => 'ðŸª™',
      'diamonds' => 'ðŸ’Ž',
      'vip_days' => 'ðŸ‘‘',
      'badge'    => 'ðŸ…',
      _          => 'ðŸŽ',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _gold.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withOpacity(.3)),
      ),
      child: Text('$emoji $value',
          style: TextStyle(color: _gold, fontSize: 11,
              fontFamily: 'Space Grotesk')),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared helpers
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label, icon;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 8),
    Text(label,
        style: TextStyle(color: _textMain, fontSize: 16,
            fontWeight: FontWeight.bold, fontFamily: 'IBM Plex Sans Arabic')),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 1, color: _border)),
  ]);
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(label, style: TextStyle(color: color,
          fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w600)),
    ),
  );
}

class _NeonSpinner extends StatefulWidget {
  const _NeonSpinner();

  @override
  State<_NeonSpinner> createState() => _NeonSpinnerState();
}

class _NeonSpinnerState extends State<_NeonSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Transform.rotate(
      angle: _c.value * 2 * math.pi,
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Agency Quick Actions (HA7)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AgencyQuickActions extends StatelessWidget {
  final String agencyId;
  final String agencyName;
  final int pendingCount;

  const _AgencyQuickActions({
    required this.agencyId,
    required this.pendingCount,
    this.agencyName = 'Ø§Ù„ÙˆÙƒØ§Ù„Ø©',
  });

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    final actions = [
      _QuickAction(
        icon: 'ðŸ‘¥',
        label: 'Ø·Ù„Ø¨Ø§Øª Ø§Ù„Ø§Ù†Ø¶Ù…Ø§Ù…',
        badge: pendingCount,
        color: _cyan,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AgencyJoinRequestsScreen(agencyId: agencyId, canKick: true))),
      ),
      _QuickAction(
        icon: 'ðŸ’¬',
        label: 'Ù‚Ø±ÙˆØ¨ Ø§Ù„ÙˆÙƒØ§Ù„Ø©',
        badge: 0,
        color: _purple,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AgencyChatScreen(agencyId: agencyId, agencyName: agencyName, myRole: AgencyMemberRole.owner))),
      ),
      _QuickAction(
        icon: 'ðŸ”',
        label: 'Ø¯Ø¹ÙˆØ© Ø¨Ù€ ID',
        badge: 0,
        color: _green,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AgencyInviteByIdScreen(agencyId: agencyId, agencyName: agencyName))),
      ),
      _QuickAction(
        icon: 'ðŸ’Ž',
        label: 'Ù…Ø­ÙØ¸Ø© Ø§Ù„ÙˆÙƒØ§Ù„Ø©',
        badge: 0,
        color: _gold,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AgencyOwnerWalletScreen(agencyId: agencyId))),
      ),
    ];

    return Row(
      children: actions.map((a) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _QuickActionCard(action: a),
        ),
      )).toList(),
    );
  }
}

class _QuickAction {
  final String icon;
  final String label;
  final int badge;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon, required this.label, required this.badge,
    required this.color, required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action.color.withOpacity(0.3)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(action.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(action.label,
                style: TextStyle(color: action.color, fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ]),
            if (action.badge > 0)
              Positioned(
                top: 0, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${action.badge}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


