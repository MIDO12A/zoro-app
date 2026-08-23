import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_compat.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/supabase_ready.dart';
import '../../core/theme/brand_colors.dart';
import 'agent_recharge/agent_recharge_models.dart';
import 'agent_recharge/tabs/agent_dashboard_tab.dart';
import 'agent_recharge/tabs/agent_recharge_tab.dart';
import 'agent_recharge/tabs/agent_history_tab.dart';
import 'agent_recharge/tabs/agent_diamond_tab.dart';
import 'agent_recharge/tabs/agent_usd_tab.dart';
import 'agent_recharge_widgets.dart';

// ══════════════════════════════════════════════════════════════════════
//  AgentRechargePortalScreen — Orchestrator
//  ► Tab 0: 📊 لوحة التحكم   → AgentDashboardTab
//  ► Tab 1: 💸 شحن مستخدم   → AgentRechargeTab
//  ► Tab 2: 📋 سجل العمليات  → AgentHistoryTab
//  ► Tab 3: 💎 ألماسي        → AgentDiamondWalletTab
//  ► Tab 4: 💵 الدولار       → AgentUsdWalletTab
// ══════════════════════════════════════════════════════════════════════
class AgentRechargePortalScreen extends StatefulWidget {
  const AgentRechargePortalScreen({super.key});
  @override
  State<AgentRechargePortalScreen> createState() =>
      _AgentRechargePortalScreenState();
}

class _AgentRechargePortalScreenState extends State<AgentRechargePortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  bool _isAgent = false;
  AgentDashboardData? _dashboard;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = AuthService.currentSession?.user.id;
    if (!isSupabaseReady() || uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final res =
          await Supabase.instance.client.rpc('agent_get_dashboard');
      if (!mounted) return;
      if (res is Map && res['ok'] == true) {
        setState(() {
          _isAgent = true;
          _dashboard = AgentDashboardData.fromMap(
              Map<String, dynamic>.from(res));
          _loading = false;
        });
      } else {
        setState(() {
          _isAgent = false;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[agent_recharge] bootstrap error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAgent) return _buildLockedScreen();

    final dash = _dashboard!;
    if (!dash.enabled) return _buildDisabledScreen();
    if (!dash.pinSet) {
      return AgentPinSetupScreen(onDone: _bootstrap);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: Column(children: [
        AgentRechargeHeader(
          agencyGold: dash.agencyGold,
          agentPublicId: dash.agentPublicId,
          onBack: () => Navigator.of(context).pop(),
        ),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            indicatorColor: KayanBrandColors.logoPrimary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.tajawal(
                fontSize: 13, fontWeight: FontWeight.w800),
            unselectedLabelStyle: GoogleFonts.tajawal(
                fontSize: 13, fontWeight: FontWeight.w600),
            labelColor: KayanBrandColors.logoPrimary,
            unselectedLabelColor: Colors.black45,
            tabs: const [
              Tab(text: '📊 لوحة التحكم'),
              Tab(text: '💸 شحن'),
              Tab(text: '📋 السجل'),
              Tab(text: '💎 ألماسي'),
              Tab(text: '💵 الدولار'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              AgentDashboardTab(
                dashboard: dash,
                onRefresh: _loadDashboard,
                onGoRecharge: () => _tabs.animateTo(1),
              ),
              AgentRechargeTab(
                agencyGold: dash.agencyGold,
                dailyRemaining: dash.todayRemaining,
                quickAmounts: dash.quickAmounts,
                onSuccess: _loadDashboard,
                onQuickAmountsChanged: (newAmounts) {
                  if (mounted) {
                    setState(() {
                      _dashboard =
                          dash.copyWithQuickAmounts(newAmounts);
                    });
                  }
                },
              ),
              const AgentHistoryTab(),
              const AgentDiamondWalletTab(),
              const AgentUsdWalletTab(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildLockedScreen() => Scaffold(
        appBar: AppBar(
          title: Text('وكالة الشحن',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔒', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              Text('حسابك غير مفعّل كوكيل شحن',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('تواصل مع الإدارة لتفعيل الصلاحية',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                      fontSize: 13, color: Colors.black54)),
            ]),
          ),
        ),
      );

  Widget _buildDisabledScreen() => Scaffold(
        appBar: AppBar(
          title: Text('وكالة الشحن',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('⛔', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              Text('حسابك موقوف مؤقتاً',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.red)),
              const SizedBox(height: 8),
              Text('تواصل مع الإدارة لإعادة التفعيل',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                      fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _bootstrap,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('إعادة المحاولة',
                    style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
}
