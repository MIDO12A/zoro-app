// lib/features/host_agency/host_agency_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Smart Agency Gateway Screen
// • Detects user role via host_agency_members
// • owner / supervisor  → AgencyDashboardScreen
// • host (member)       → HostDashboardScreen
// • no membership       → Browse + Create screen
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_compat.dart';

import '../../core/auth/auth_service.dart';
import '../../core/ui/in_app_toast.dart';
import 'agency_dashboard_screen.dart';
import 'host_dashboard_screen.dart';
import 'data/agency_models.dart';
import 'screens/agency_leaderboard_screen.dart';
import 'screens/agency_profile_screen.dart';
import 'screens/agency_supervisor_dashboard_screen.dart';

import '../../core/cache/encrypted_image_provider.dart';
import 'package:provider/provider.dart';
import '../../services/dynamic_config_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
class HostAgencyScreen extends StatefulWidget {
  const HostAgencyScreen({super.key});

  @override
  State<HostAgencyScreen> createState() => _HostAgencyScreenState();
}

class _HostAgencyScreenState extends State<HostAgencyScreen> {
  bool  _loading = true;
  _UserAgencyRole _role = _UserAgencyRole.none;
  String? _agencyId;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  // ── detect role ─────────────────────────────────────────────────────────────
  Future<void> _detect() async {
    final uid = AuthService.currentSession?.user.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('host_agency_members')
          .select('role, agency_id')
          .eq('user_id', uid)
          .eq('status', 'active')
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        setState(() { _role = _UserAgencyRole.none; _loading = false; });
      } else {
        final roleStr = row['role'] as String? ?? 'host';
        final aid     = row['agency_id'] as String?;
        _UserAgencyRole role;
        if (roleStr == 'owner') {
          role = _UserAgencyRole.owner;
        } else if (roleStr == 'supervisor') {
          role = _UserAgencyRole.supervisor;
        } else {
          role = _UserAgencyRole.host;
        }
        setState(() { _role = role; _agencyId = aid; _loading = false; });
      }
    } catch (e) {
debugPrint('[host_agency_screen] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<DynamicConfigService>();
    if (_loading) {
      return Scaffold(
        backgroundColor: cfg.agencyHeaderBg,
        body: Center(
          child: CircularProgressIndicator(color: cfg.agencyAccent),
        ),
      );
    }

    // Route to the right dashboard immediately (no wrapping shell needed)
    switch (_role) {
      case _UserAgencyRole.owner:
        return AgencyDashboardScreen(agencyId: _agencyId);
      case _UserAgencyRole.supervisor:
        return AgencySupervisorDashboardScreen(agencyId: _agencyId);
      case _UserAgencyRole.host:
        return const HostDashboardScreen();
      case _UserAgencyRole.none:
        return const _BrowseCreateScreen();
    }
  }
}

// ── role enum ─────────────────────────────────────────────────────────────────
enum _UserAgencyRole { owner, supervisor, host, none }

// ═══════════════════════════════════════════════════════════════════════════════
//  Browse + Create Screen  —  shown when user has no agency
// ═══════════════════════════════════════════════════════════════════════════════
class _BrowseCreateScreen extends StatefulWidget {
  const _BrowseCreateScreen();

  @override
  State<_BrowseCreateScreen> createState() => _BrowseCreateScreenState();
}

class _BrowseCreateScreenState extends State<_BrowseCreateScreen>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  late final AnimationController _anim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 900),
  )..forward();

  List<Map<String, dynamic>> _topAgencies = [];
  bool _loadingList = true;
  bool _creating    = false;

  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  String? _selectedCountry;
  bool _showForm   = false;

  static const _countries = [
    'السعودية', 'الإمارات', 'الكويت', 'قطر', 'البحرين', 'عُمان',
    'مصر', 'الأردن', 'لبنان', 'العراق', 'سوريا', 'اليمن',
    'المغرب', 'تونس', 'الجزائر', 'ليبيا', 'السودان',
    'تركيا', 'إيران', 'باكستان', 'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _loadTop();
  }

  @override
  void dispose() {
    _anim.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTop() async {
    try {
      final rows = await _sb
          .from('host_agencies')
          .select('id, name, tier, photo_url, total_diamonds_monthly, member_count, is_hall_of_fame')
          .eq('is_active', true)
          .order('total_diamonds_monthly', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _topAgencies = List<Map<String, dynamic>>.from(rows as List);
          _loadingList  = false;
        });
      }
    } catch (e) {
debugPrint('[host_agency_screen] error: $e');
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _createAgency() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      KayanInAppToast.warning('أدخل اسم الوكالة');
      return;
    }
    final uid = AuthService.currentSession?.user.id;
    if (uid == null) return;

    setState(() => _creating = true);
    try {
      await _sb.rpc('agency_create', params: {
        'p_name':        name,
        'p_description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'p_photo_url':   null,
        'p_phone':       _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'p_country':     _selectedCountry,
      });
      if (!mounted) return;
      KayanInAppToast.agency('تم إنشاء الوكالة بنجاح! 🎉');
      // Pop and push fresh so the gateway re-detects the new owner role
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HostAgencyScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      KayanInAppToast.warning('تعذر إنشاء الوكالة: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<DynamicConfigService>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: cfg.agencyHeaderBg,
        body: FadeTransition(
          opacity: _anim,
          child: CustomScrollView(
            slivers: [
              _buildHeader(cfg),
              SliverToBoxAdapter(child: _buildHeroSection(cfg)),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildActionButtons(cfg)),
              if (_showForm) ...[
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildCreateForm(cfg)),
              ],
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildTopAgenciesHeader(cfg)),
              _buildTopAgenciesList(cfg),
              SliverToBoxAdapter(child: const SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DynamicConfigService cfg) {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: cfg.agencyHeaderBg,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: cfg.agencyTextColor, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text('وكالات المضيفين',
        style: TextStyle(color: cfg.agencyTextColor, fontWeight: FontWeight.w600, fontSize: 17)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.leaderboard_rounded, color: cfg.agencyTabActive, size: 22),
          tooltip: 'التصنيف الكامل',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyLeaderboardScreen())),
        ),
      ],
    );
  }

  Widget _buildHeroSection(DynamicConfigService cfg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cfg.agencyCardBg.withOpacity(0.8), cfg.agencyCardBg.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.agencyCardBorder),
      ),
      child: Column(
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [cfg.agencyAccent, cfg.agencyTabActive],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: cfg.agencyAccent.withOpacity(0.4), blurRadius: 20)],
              ),
              child: const Icon(Icons.business_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          Text('لست في وكالة بعد',
            style: TextStyle(color: cfg.agencyTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'انضم لوكالة لتعزيز أرباحك وتحقيق أهداف مشتركة،\nأو أنشئ وكالتك الخاصة وقُد فريقك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cfg.agencySubText, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DynamicConfigService cfg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Browse leaderboard
          Expanded(
            child: _GlassButton(
              label: 'تصفح الوكالات',
              icon: Icons.search_rounded,
              color: cfg.agencyTabActive,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyLeaderboardScreen())),
            ),
          ),
          const SizedBox(width: 12),
          // Create agency
          Expanded(
            child: _GlassButton(
              label: _showForm ? 'إخفاء النموذج' : 'إنشاء وكالة',
              icon: _showForm ? Icons.keyboard_arrow_up_rounded : Icons.add_business_rounded,
              color: cfg.agencyAccent,
              onTap: () => setState(() => _showForm = !_showForm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm(DynamicConfigService cfg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cfg.agencyCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg.agencyCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إنشاء وكالة جديدة',
            style: TextStyle(color: cfg.agencyTabActive, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          _field(cfg, _nameCtrl, 'اسم الوكالة *', Icons.badge_rounded),
          const SizedBox(height: 12),
          _field(cfg, _descCtrl, 'وصف الوكالة (اختياري)', Icons.description_rounded, maxLines: 3),
          const SizedBox(height: 12),
          // الدولة
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: InputDecoration(
              hintText: 'الدولة (اختياري)',
              hintStyle: TextStyle(color: cfg.agencySubText.withOpacity(0.6), fontSize: 13),
              prefixIcon: Icon(Icons.flag_rounded, color: cfg.agencySubText, size: 18),
              filled: true,
              fillColor: cfg.agencyCardBorder.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cfg.agencyCardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cfg.agencyCardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cfg.agencyAccent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            dropdownColor: cfg.agencyCardBg,
            style: TextStyle(color: cfg.agencyTextColor, fontSize: 13),
            items: _countries.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            )).toList(),
            onChanged: (v) => setState(() => _selectedCountry = v),
          ),
          const SizedBox(height: 12),
          _field(cfg, _phoneCtrl, 'رقم الهاتف (اختياري)', Icons.phone_rounded,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 4),
          Text('الوكالة تبدأ بدرجة برونز — ترتفع بأداء الفريق',
            style: TextStyle(color: cfg.agencySubText.withOpacity(0.7), fontSize: 11)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _creating ? null : _createAgency,
              style: FilledButton.styleFrom(
                backgroundColor: cfg.agencyTabActive,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _creating
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('إنشاء الوكالة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(DynamicConfigService cfg, TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: cfg.agencyTextColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cfg.agencySubText.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: cfg.agencySubText, size: 18),
        filled: true,
        fillColor: cfg.agencyCardBorder.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cfg.agencyCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cfg.agencyCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cfg.agencyAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildTopAgenciesHeader(DynamicConfigService cfg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('أفضل الوكالات',
            style: TextStyle(color: cfg.agencyTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyLeaderboardScreen())),
            child: Text('عرض الكل', style: TextStyle(color: cfg.agencyAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAgenciesList(DynamicConfigService cfg) {
    if (_loadingList) {
      return SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: cfg.agencyAccent),
        )),
      );
    }
    if (_topAgencies.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('لا توجد وكالات بعد', style: TextStyle(color: cfg.agencySubText)),
        )),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final agency = _topAgencies[i];
            return _AgencyGridCard(agency: agency, rank: i + 1, onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AgencyProfileScreen(agencyId: agency['id'] as String),
                ),
              );
            });
          },
          childCount: _topAgencies.length,
        ),
      ),
    );
  }
}

// ── glass action button ────────────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlassButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── agency card in top list ────────────────────────────────────────────────────
class _AgencyCard extends StatelessWidget {
  final Map<String, dynamic> agency;
  final int rank;
  final VoidCallback onTap;

  const _AgencyCard({required this.agency, required this.rank, required this.onTap});

  static const _tierColors = {
    'bronze':   Color(0xFFCD7F32),
    'silver':   Color(0xFFC0C0C0),
    'gold':     Color(0xFFD4AF37),
    'platinum': Color(0xFF6ADBF5),
    'diamond':  Color(0xFFB39DDB),
  };

  static const _rankEmoji = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<DynamicConfigService>();
    final name         = agency['name']                    as String? ?? '—';
    final tier         = agency['tier']                    as String? ?? 'bronze';
    final photoUrl     = agency['photo_url']               as String?;
    final diamonds     = (agency['total_diamonds_monthly'] as num?)?.toInt() ?? 0;
    final members      = (agency['member_count']           as num?)?.toInt() ?? 0;
    final isHOF        = agency['is_hall_of_fame']         as bool? ?? false;
    final color        = _tierColors[tier] ?? const Color(0xFFD4AF37);
    final rankLabel    = _rankEmoji[rank] ?? '#$rank';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cfg.agencyCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 32,
              child: Text(rankLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: cfg.agencyTextColor)),
            ),
            const SizedBox(width: 10),
            // Logo / Agency Photo from Agent device
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: (photoUrl != null && photoUrl.isNotEmpty)
                ? Image(
                    image: EncryptedImageProvider(photoUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        name.isEmpty ? '?' : name.characters.first,
                        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first,
                      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
            ),
            const SizedBox(width: 12),
            // Info: Name & Host Count circular badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cfg.agencyTextColor, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (isHOF) ...[
                        const SizedBox(width: 4),
                        const Text('🏆', style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(AgencyTierX.fromString(tier).label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      // Small circular host count badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, color: Colors.lightBlueAccent, size: 12),
                            const SizedBox(width: 4),
                            Text('$members مضيف', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Diamonds
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('♦', style: TextStyle(color: cfg.agencyTabInactive, fontSize: 16)),
                const SizedBox(height: 2),
                Text(_fmt(diamonds),
                  style: TextStyle(color: cfg.agencyTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── agency grid card (2-column layout) ─────────────────────────────────────────
class _AgencyGridCard extends StatelessWidget {
  final Map<String, dynamic> agency;
  final int rank;
  final VoidCallback onTap;

  const _AgencyGridCard({required this.agency, required this.rank, required this.onTap});

  static const _tierColors = {
    'bronze':   Color(0xFFCD7F32),
    'silver':   Color(0xFFC0C0C0),
    'gold':     Color(0xFFD4AF37),
    'platinum': Color(0xFF6ADBF5),
    'diamond':  Color(0xFFB39DDB),
  };

  static const _rankEmoji = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<DynamicConfigService>();
    final name         = agency['name']                    as String? ?? '—';
    final tier         = agency['tier']                    as String? ?? 'bronze';
    final photoUrl     = agency['photo_url']               as String?;
    final diamonds     = (agency['total_diamonds_monthly'] as num?)?.toInt() ?? 0;
    final members      = (agency['member_count']           as num?)?.toInt() ?? 0;
    final isHOF        = agency['is_hall_of_fame']         as bool? ?? false;
    final color        = _tierColors[tier] ?? const Color(0xFFD4AF37);
    final rankLabel    = _rankEmoji[rank] ?? '#$rank';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cfg.agencyCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            // Rank badge top-right
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Text(rankLabel, style: TextStyle(fontSize: 14, color: cfg.agencyTextColor)),
            ),
            const SizedBox(height: 4),
            // Logo
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? Image(
                      image: EncryptedImageProvider(photoUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(name.isEmpty ? '?' : name.characters.first,
                            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    )
                  : Center(
                      child: Text(name.isEmpty ? '?' : name.characters.first,
                          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(height: 8),
            // Name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cfg.agencyTextColor, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                if (isHOF) ...[const SizedBox(width: 2), const Text('🏆', style: TextStyle(fontSize: 10))],
              ],
            ),
            const SizedBox(height: 6),
            // Tier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(AgencyTierX.fromString(tier).label,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            // Members + Diamonds row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.lightBlueAccent, size: 11),
                    const SizedBox(width: 3),
                    Text('$members', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('♦', style: TextStyle(color: cfg.agencyTabInactive, fontSize: 11)),
                    const SizedBox(width: 3),
                    Text(_fmt(diamonds),
                        style: TextStyle(color: cfg.agencyTextColor, fontWeight: FontWeight.bold, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
