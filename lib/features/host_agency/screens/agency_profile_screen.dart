import 'package:flutter/material.dart';

import '../data/agency_models.dart';
import '../data/agency_repository.dart';
import '../../../core/cache/encrypted_image_provider.dart';

// ═══════════════════════════════════════════════════════════════════
//  AgencyProfileScreen — الملف العام للوكالة
//  يعرض: اللوجو + الاسم + الوصف + الإحصائيات + زر انضمام + الأعضاء
// ═══════════════════════════════════════════════════════════════════
class AgencyProfileScreen extends StatefulWidget {
  final String agencyId;
  const AgencyProfileScreen({super.key, required this.agencyId});

  @override
  State<AgencyProfileScreen> createState() => _AgencyProfileScreenState();
}

class _AgencyProfileScreenState extends State<AgencyProfileScreen> {
  AgencyCard? _agency;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final agency = await AgencyRepository.getProfile(widget.agencyId);
    final members = agency != null
        ? await AgencyRepository.getMembers(widget.agencyId, limit: 20)
        : <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      _agency  = agency;
      _members = members;
      _loading = false;
    });
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await AgencyRepository.requestJoin(widget.agencyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إرسال طلب الانضمام'), backgroundColor: Color(0xFF2E7D32)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _agency == null
              ? Center(child: Text('لم يتم العثور على الوكالة', style: TextStyle(color: Colors.white.withOpacity(0.5))))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final a = _agency!;
    final tierColor = _tierColors[a.tier] ?? const Color(0xFFD4AF37);

    return CustomScrollView(
      slivers: [
        // ── Hero SliverAppBar ──────────────────────────────────────
        SliverAppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          foregroundColor: Colors.white,
          expandedHeight: 220,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Background gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [tierColor.withOpacity(0.3), const Color(0xFF0D0D1A)],
                    ),
                  ),
                ),
                // Logo
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 48),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tierColor.withOpacity(0.2),
                          border: Border.all(color: tierColor, width: 2.5),
                          image: a.photoUrl != null
                              ? DecorationImage(image: EncryptedImageProvider(a.photoUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: a.photoUrl == null
                            ? Center(child: Text(a.name.characters.first,
                                style: TextStyle(color: tierColor, fontSize: 32, fontWeight: FontWeight.bold)))
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(a.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        if (a.isHallOfFame) ...[
                          const SizedBox(width: 6),
                          const Text('🏆', style: TextStyle(fontSize: 16)),
                        ],
                      ]),
                      if (a.agencyPublicId != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                          ),
                          child: Text(
                            'ID: ${a.agencyPublicId}',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Body ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tier + rank chip row
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _InfoChip(label: a.tier.label, color: tierColor),
                  if (a.rank != null) _InfoChip(label: '#${a.rank} في التصنيف', color: Colors.white54),
                  if (a.country != null) _InfoChip(label: '📍 ${a.country}', color: Colors.white38),
                ]),

                const SizedBox(height: 16),

                // Description
                if (a.description != null && a.description!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(a.description!,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.6),
                    ),
                  ),

                const SizedBox(height: 16),

                // Stats row
                _buildStatsRow(a, tierColor),

                const SizedBox(height: 20),

                // Join button
                if (a.canJoin)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _joining ? null : _join,
                      icon: _joining
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.group_add_rounded),
                      label: Text(_joining ? 'جارٍ الإرسال...' : 'طلب الانضمام'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tierColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  )
                else if (a.isMember)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('أنت عضو في هذه الوكالة', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    ]),
                  ),

                const SizedBox(height: 24),

                // Members section
                Text('أعضاء الوكالة', style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16, fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 12),

                ..._members.take(10).map((m) => _MemberRow(data: m)),

                if (_members.length > 10)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: Text('+${_members.length - 10} عضو آخر',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13))),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AgencyCard a, Color tierColor) {
    return Row(
      children: [
        Expanded(child: _StatBlock(
          icon: '👥',
          value: a.memberCount.toString(),
          label: 'عضو',
          color: tierColor,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatBlock(
          icon: '♦',
          value: _fmtK(a.totalDiamondsMonthly),
          label: 'ألماس الشهر',
          color: const Color(0xFFB39DDB),
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatBlock(
          icon: '💎',
          value: _fmtK(a.totalDiamondsCumulative),
          label: 'تراكمي',
          color: const Color(0xFF6ADBF5),
        )),
      ],
    );
  }

  static const _tierColors = {
    AgencyTier.bronze:   Color(0xFFCD7F32),
    AgencyTier.silver:   Color(0xFFC0C0C0),
    AgencyTier.gold:     Color(0xFFD4AF37),
    AgencyTier.platinum: Color(0xFF6ADBF5),
    AgencyTier.diamond:  Color(0xFFB39DDB),
  };

  static String _fmtK(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

// ─── Widgets ────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  const _StatBlock({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MemberRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final name    = profile['display_name'] as String? ?? '—';
    final avatar  = profile['avatar_url'] as String?;
    final level   = (profile['level'] as num?)?.toInt() ?? 1;
    final role    = data['role'] as String? ?? 'host';
    final diamonds = (data['diamonds_earned_monthly'] as num?)?.toInt() ?? 0;

    final roleColors = {
      'owner':      const Color(0xFFD4AF37),
      'supervisor': const Color(0xFF6ADBF5),
      'host':       Colors.white54,
    };
    final roleLabels = {
      'owner':      'مالك',
      'supervisor': 'مشرف',
      'host':       'مضيف',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
            backgroundImage: avatar != null ? EncryptedImageProvider(avatar) : null,
            child: avatar == null ? Text(name.characters.first, style: const TextStyle(color: Color(0xFFD4AF37))) : null,
          ),
          const SizedBox(width: 10),
          // Name + level
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('Lv.$level · ${roleLabels[role] ?? role}',
                style: TextStyle(color: roleColors[role] ?? Colors.white54, fontSize: 11)),
            ]),
          ),
          // Diamonds
          Text('${_fmtK(diamonds)} ♦',
            style: const TextStyle(color: Color(0xFFB39DDB), fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  static String _fmtK(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
