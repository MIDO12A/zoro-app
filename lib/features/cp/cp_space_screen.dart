import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/r.dart';
import '../../providers/user_provider.dart';
import '../../services/dynamic_config_service.dart';
import 'cp_service.dart';
import 'cp_record_screen.dart';

/// Relationship Space screen — matches act_relationship_space.xml
/// Shows: RS panel (avatars + heartbeat + token), progress bar, daily tasks.
class CpSpaceScreen extends StatefulWidget {
  const CpSpaceScreen({super.key});
  @override
  State<CpSpaceScreen> createState() => _CpSpaceScreenState();
}

class _CpSpaceScreenState extends State<CpSpaceScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await CpService.getMyData();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = DynamicConfigService();
    final couple = _data['couple'] as Map<String, dynamic>?;
    final hasCp = _data['has_cp'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF2e0d15),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasCp
              ? _buildNoCpState()
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxScrolled) {
                    return [
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: const Text('مساحة العلاقة',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                        centerTitle: true,
                      ),
                    ];
                  },
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTopSection(cfg, couple),
                        const SizedBox(height: 10),
                        _buildProgressBar(cfg, couple),
                        const SizedBox(height: 16),
                        _buildBorderSection(cfg),
                        const SizedBox(height: 12),
                        _buildTasksSection(cfg),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoCpState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          R.image('assets/cp/frame_no_cp.png', width: 120, height: 120,
              fit: BoxFit.contain),
          const SizedBox(height: 20),
          const Text('ليس لديك علاقة CP حالياً',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFd32a43),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('اكتشف العلاقات'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection(DynamicConfigService cfg, Map<String, dynamic>? couple) {
    final partner = couple?['partner'] as Map<String, dynamic>?;
    final user = context.read<UserProvider>().currentUser;
    final myAvatar = user?.photoUrl ?? '';
    final myName = user?.name ?? 'أنا';
    final partnerAvatar = partner?['avatar']?.toString() ?? '';
    final partnerName = partner?['name']?.toString() ?? '';
    final daysTogether = couple?['days_together']?.toString() ?? '0';
    final totalScore = couple?['total_score']?.toString() ?? '0';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4a1020), Color(0xFF2e0d15)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFfff19f), Color(0xFFffb565)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Lv.${_calcLevel(int.tryParse(totalScore) ?? 0)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4a1020),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // RS Panel: avatars + heartbeat + token
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatarFrame(myAvatar, myName, isMe: true),
              // Heartbeat line + token (overlapping avatars)
              Transform.translate(
                offset: const Offset(-12, 0),
                child: SizedBox(
                width: 106,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.pink.withValues(alpha: 0.3),
                            Colors.pink,
                            Colors.pink.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                    // Token icon
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFff6b9d), Color(0xFFd32a43)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
              ),
              Transform.translate(
                offset: const Offset(-12, 0),
                child: _buildAvatarFrame(partnerAvatar, partnerName, isMe: false),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Days together badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFd32a43).withValues(alpha: 0.3),
                  const Color(0xFF7d102b).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFa31b44), width: 1),
            ),
            child: Text(
              '$daysTogether يوم معاً',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAvatarFrame(String? avatarUrl, String name, {bool isMe = true}) {
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Frame (102x102)
          SizedBox(
            width: 102,
            height: 102,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Border frame
                Container(
                  width: 102,
                  height: 102,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isMe ? const Color(0xFFffb565) : const Color(0xFFff6b9d),
                      width: 3,
                    ),
                  ),
                ),
                // Avatar
                ClipOval(
                  child: R.loadImage(
                    avatarUrl ?? (isMe ? R.avaBoy : R.avaGirl),
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          // Name
          Text(
            name.isNotEmpty ? name : (isMe ? 'أنا' : 'شريكي'),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(DynamicConfigService cfg, Map<String, dynamic>? couple) {
    final totalScore = (couple?['total_score'] as num?)?.toInt() ?? 0;
    final currentLv = _calcLevel(totalScore);
    final nextLv = currentLv + 1;
    final currentLvMin = _lvMinScore(currentLv);
    final nextLvMin = _lvMinScore(nextLv);
    final progress = nextLvMin > currentLvMin
        ? ((totalScore - currentLvMin) / (nextLvMin - currentLvMin)).clamp(0.0, 1.0)
        : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          // Next level tip
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_nextLvTip',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.help_outline, color: Colors.white54, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                // Background
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4a1020),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFF770d1e), width: 1),
                  ),
                ),
                // Fill
                Container(
                  height: 10,
                  width: constraints.maxWidth * progress,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFd32a43), Color(0xFFff6b9d)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 4),
          // Level labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lv.$currentLv',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Text('Lv.$nextLv',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBorderSection(DynamicConfigService cfg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF770d1e), width: 1.5),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4a1020).withValues(alpha: 0.5),
            const Color(0xFF2e0d15).withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('القربى', '${(_data['couple'] as Map?)?['total_score'] ?? 0}', Icons.favorite),
          _buildStatItem('هذا الأسبوع', '${(_data['couple'] as Map?)?['week_score'] ?? 0}', Icons.star),
          _buildStatItem('هذا الشهر', '${(_data['couple'] as Map?)?['month_score'] ?? 0}', Icons.emoji_events),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFffb565), size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildTasksSection(DynamicConfigService cfg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Header with navigation to record
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المهام اليومية',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CpRecordScreen()),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('السجل', style: TextStyle(color: Color(0xFFffb565), fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, color: Color(0xFFffb565), size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'أكمل المهام لزيادة القربى',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildTaskItem('إرسال هدية CP', '+10 قربى', Icons.card_giftcard, const Color(0xFFff6b9d)),
          _buildTaskItem('الدخول معاً إلى غرفة', '+5 قربى', Icons.meeting_room, const Color(0xFFffb565)),
          _buildTaskItem('إرسال رسالة', '+2 قربى', Icons.chat_bubble, const Color(0xFF64b5f6)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String title, String reward, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4a1020).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF770d1e), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(reward, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int _calcLevel(int score) {
    if (score >= 1000) return 6;
    if (score >= 500) return 5;
    if (score >= 200) return 4;
    if (score >= 100) return 3;
    if (score >= 30) return 2;
    return 1;
  }

  int _lvMinScore(int lv) {
    return switch (lv) {
      1 => 0,
      2 => 30,
      3 => 100,
      4 => 200,
      5 => 500,
      6 => 1000,
      _ => 0,
    };
  }

  String get _nextLvTip => 'أكمل المهام للوصول للمستوى التالي';
}
