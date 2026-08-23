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
import 'screens/agency_leaderboard_screen.dart';
import 'screens/agency_profile_screen.dart';
import 'screens/agency_supervisor_dashboard_screen.dart';

import '../../core/cache/encrypted_image_provider.dart';

// ── palette ──────────────────────────────────────────────────────────────────
const _bgDeep    = Color(0xFF03030A);
const _bgCard    = Color(0x800A0820);
const _border    = Color(0x2D9C6BFF);
const _purple    = Color(0xFF9C6BFF);
const _gold      = Color(0xFFF6C453);
const _cyan      = Color(0xFF00D4FF);
const _textMain  = Color(0xFFE8E6FF);
const _textMuted = Color(0xFF8A88AA);

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
    if (_loading) {
      return Scaffold(
        backgroundColor: _bgDeep,
        body: const Center(
          child: CircularProgressIndicator(color: _purple),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: FadeTransition(
          opacity: _anim,
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(child: _buildHeroSection()),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildActionButtons()),
              if (_showForm) ...[
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildCreateForm()),
              ],
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildTopAgenciesHeader()),
              _buildTopAgenciesList(),
              SliverToBoxAdapter(child: const SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: _bgDeep,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textMain, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text('وكالات المضيفين',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.w600, fontSize: 17)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.leaderboard_rounded, color: _gold, size: 22),
          tooltip: 'التصنيف الكامل',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyLeaderboardScreen())),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0A3E), Color(0xFF0A1A3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
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
                gradient: const LinearGradient(
                  colors: [_purple, _cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 20)],
              ),
              child: const Icon(Icons.business_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          const Text('لست في وكالة بعد',
            style: TextStyle(color: _textMain, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'انضم لوكالة لتعزيز أرباحك وتحقيق أهداف مشتركة،\nأو أنشئ وكالتك الخاصة وقُد فريقك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMuted, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Browse leaderboard
          Expanded(
            child: _GlassButton(
              label: 'تصفح الوكالات',
              icon: Icons.search_rounded,
              color: _cyan,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyLeaderboardScreen())),
            ),
          ),
          const SizedBox(width: 12),
          // Create agency
          Expanded(
            child: _GlassButton(
              label: _showForm ? 'إخفاء النموذج' : 'إنشاء وكالة',
              icon: _showForm ? Icons.keyboard_arrow_up_rounded : Icons.add_business_rounded,
              color: _gold,
              onTap: () => setState(() => _showForm = !_showForm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إنشاء وكالة جديدة',
            style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          _field(_nameCtrl, 'اسم الوكالة *', Icons.badge_rounded),
          const SizedBox(height: 12),
          _field(_descCtrl, 'وصف الوكالة (اختياري)', Icons.description_rounded, maxLines: 3),
          const SizedBox(height: 12),
          // الدولة
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: InputDecoration(
              hintText: 'الدولة (اختياري)',
              hintStyle: TextStyle(color: _textMuted.withOpacity(0.6), fontSize: 13),
              prefixIcon: const Icon(Icons.flag_rounded, color: _textMuted, size: 18),
              filled: true,
              fillColor: const Color(0x1A9C6BFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _purple),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            dropdownColor: const Color(0xFF0A0820),
            style: const TextStyle(color: _textMain, fontSize: 13),
            items: _countries.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            )).toList(),
            onChanged: (v) => setState(() => _selectedCountry = v),
          ),
          const SizedBox(height: 12),
          _field(_phoneCtrl, 'رقم الهاتف (اختياري)', Icons.phone_rounded,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 4),
          Text('الوكالة تبدأ بدرجة Bronze — ترتفع بأداء الفريق',
            style: TextStyle(color: _textMuted.withOpacity(0.7), fontSize: 11)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _creating ? null : _createAgency,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _creating
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('إنشاء الوكالة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textMuted.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _textMuted, size: 18),
        filled: true,
        fillColor: const Color(0x1A9C6BFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _purple),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildTopAgenciesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('أفضل الوكالات',
            style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyLeaderboardScreen())),
            child: const Text('عرض الكل', style: TextStyle(color: _purple, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAgenciesList() {
    if (_loadingList) {
      return const SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: _purple),
        )),
      );
    }
    if (_topAgencies.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد وكالات بعد', style: TextStyle(color: _textMuted)),
        )),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final agency = _topAgencies[i];
          return _AgencyCard(agency: agency, rank: i + 1, onTap: () {
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
          color: _bgCard,
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
                style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            // Logo
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl != null
                ? Image(image: EncryptedImageProvider(photoUrl), fit: BoxFit.cover)
                : Center(
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first,
                      style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _textMain, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      if (isHOF) ...[
                        const SizedBox(width: 4),
                        const Text('🏆', style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tier, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people_rounded, color: _textMuted, size: 13),
                      const SizedBox(width: 3),
                      Text('$members', style: const TextStyle(color: _textMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            // Diamonds
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('♦', style: TextStyle(color: _cyan, fontSize: 16)),
                const SizedBox(height: 2),
                Text(_fmt(diamonds),
                  style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13)),
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
