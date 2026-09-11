import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/r.dart';
import '../../../../providers/user_provider.dart';
import '../../../../services/supabase_service.dart';
import '../data/anchor_agent_model.dart';
import 'query_anchor_agent_screen.dart';
import 'agent_transfer_screen.dart';

/// شاشة وكيل المضيفين وإدارة الوكالة (AnchorAgentActivity)
class AnchorAgentScreen extends StatefulWidget {
  final String? agencyId;

  const AnchorAgentScreen({super.key, this.agencyId});

  @override
  State<AnchorAgentScreen> createState() => _AnchorAgentScreenState();
}

class _AnchorAgentScreenState extends State<AnchorAgentScreen> {
  AgentInfoModel? _agentInfo;
  List<AnchorAgentUserInfoDataModel> _anchors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgencyData();
  }

  Future<void> _loadAgencyData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      final uid = user?.uid ?? '';

      // جلب بيانات الوكالة والمضيفين
      final fb = SupabaseService();
      final data = await fb.getAnchorAgencyData(agencyId: widget.agencyId, agentUid: uid);

      if (mounted) {
        setState(() {
          _agentInfo = data['info'] as AgentInfoModel? ??
              AgentInfoModel(
                userId: int.tryParse(user?.customId ?? '0') ?? 0,
                agencyName: user?.name ?? 'وكالة النجوم',
                avatarUrl: user?.photoUrl ?? '',
                agentBean: user?.coins ?? 0,
                transferMoney: user?.diamonds ?? 0,
                transferDollar: ((user?.diamonds ?? 0) / 1000).toInt(),
              );
          _anchors = (data['anchors'] as List<dynamic>?)
                  ?.map((e) => AnchorAgentUserInfoDataModel.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ في تحميل بيانات الوكالة';
          _loading = false;
        });
      }
    }
  }

  @override
  int _currentTab = 0; // 0: Members, 1: Income, 2: Sub-agents
  String _noticeText = 'أهلاً بكم في الوكالة الرسمية! يرجى الالتزام بساعات البث المحددة وتحقيق التارجت الشهري للحصول على المكافآت.';

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final info = _agentInfo;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
            : RefreshIndicator(
                color: const Color(0xFFFFD700),
                onRefresh: _loadAgencyData,
                child: CustomScrollView(
                  slivers: [
                    // ── CollapsingToolbar / App Bar matching union_activity_my_agency.xml ──
                    SliverToBoxAdapter(
                      child: _buildCollapsingHeader(info, isAr),
                    ),

                    // ── Tab Bar with union_tab_bg ──
                    SliverToBoxAdapter(
                      child: _buildTabBar(isAr),
                    ),

                    // ── Tab Content ──
                    if (_currentTab == 0)
                      _buildMembersList(isAr)
                    else if (_currentTab == 1)
                      _buildIncomeTab(info, isAr)
                    else
                      _buildSubAgentsTab(isAr),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 60),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Collapsing Header matching union_activity_my_agency.xml
  Widget _buildCollapsingHeader(AgentInfoModel? info, bool isAr) {
    final agencyName = info?.agencyName.isNotEmpty == true ? info!.agencyName : (isAr ? 'وكالتي الرسمية' : 'My Agency');
    final agencyId = info?.userId.toString() ?? '10001';
    final memberCount = _anchors.length;

    return Stack(
      children: [
        // Background: union_my_agency_bg
        Positioned.fill(
          child: Image.asset(
            R.unionMyAgencyBg,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF221A1A)),
          ),
        ),

        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: Image.asset(
                        'assets/mipmap-xxhdpi/back_white_2.webp',
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      isAr ? 'وكالتي' : 'My Agency',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Rules icon: union_rule_ic
                    IconButton(
                      icon: Image.asset(
                        R.unionRuleIc,
                        width: 26,
                        height: 26,
                        errorBuilder: (_, __, ___) => const Icon(Icons.help_outline, color: Colors.white),
                      ),
                      tooltip: isAr ? 'قوانين الوكالة' : 'Rules',
                      onPressed: () => _showRulesDialog(isAr),
                    ),
                    // Transfer icon
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Color(0xFFFFD700), size: 26),
                      tooltip: isAr ? 'تحويل الرصيد' : 'Transfer',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AgentTransferScreen(agentInfo: _agentInfo),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Agency Avatar Stack: union_my_agency_avatar_bg + crown + avatar + border
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Avatar base frame: union_my_agency_avatar_bg
                    Image.asset(
                      R.unionMyAgencyAvatarBg,
                      width: 130,
                      height: 130,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 130, height: 130),
                    ),

                    // Crown: union_agency_avatar_heder_ic
                    Positioned(
                      top: -10,
                      child: Image.asset(
                        R.unionAgencyAvatarHeaderIc,
                        width: 44,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),

                    // Agency Avatar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 84,
                        height: 84,
                        color: Colors.white12,
                        child: (info?.avatarUrl.isNotEmpty == true)
                            ? Image(
                                image: R.cachedImage(info!.avatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white54, size: 40),
                              )
                            : const Icon(Icons.shield, color: Colors.white54, size: 40),
                      ),
                    ),

                    // Border: union_avatar_border_ic
                    Image.asset(
                      R.unionAvatarBorderIc,
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),

                    // Invite Sub-Agent Badge: union_sub_agent_invite_bg
                    Positioned(
                      bottom: -10,
                      child: GestureDetector(
                        onTap: () => _showInviteDialog(isAr),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage(R.unionSubAgentInviteBg),
                              fit: BoxFit.fill,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(R.unionSubAgentInviteIc, width: 16, height: 16, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                              const SizedBox(width: 4),
                              Text(
                                isAr ? 'دعوة وكيل فرعي' : 'Invite Agent',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Agency Name + Country
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (info?.countryFlagUrl.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Image.network(info!.countryFlagUrl, width: 22, height: 14),
                    ),
                  Text(
                    agencyName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Agency ID with union_id_ic
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(R.unionIdIc, width: 14, height: 14, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  const SizedBox(width: 4),
                  Text(
                    'ID: $agencyId',
                    style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Stats Bar: cl_rank_detail (union_agency_info_bg) ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: Row(
                  children: [
                    // Rank
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(R.unionAgencyRank1Ic, width: 16, height: 16, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                              const SizedBox(width: 4),
                              Text(
                                isAr ? 'الترتيب' : 'Rank',
                                style: const TextStyle(color: Color(0xFFFFFFAD), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'No.1',
                            style: TextStyle(color: Color(0xFFFFFFAD), fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 0.5, height: 28, color: Colors.white24),
                    // Members
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(R.unionAgencyMemberIc, width: 16, height: 16, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                              const SizedBox(width: 4),
                              Text(
                                isAr ? 'الأعضاء' : 'Members',
                                style: const TextStyle(color: Color(0xFFFFFFAD), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            memberCount.toString(),
                            style: const TextStyle(color: Color(0xFFFFFFAD), fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 0.5, height: 28, color: Colors.white24),
                    // Sub Agents
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(R.unionSubAgentIc, width: 16, height: 16, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                              const SizedBox(width: 4),
                              Text(
                                isAr ? 'الوكلاء الفرعيين' : 'Sub-agents',
                                style: const TextStyle(color: Color(0xFFFFFFAD), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '0',
                            style: TextStyle(color: Color(0xFFFFFFAD), fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Announcement / Notice Bar: cl_notice (union_dialog_agency_notice.xml) ──
              GestureDetector(
                onTap: () => _showNoticeDialog(isAr),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(R.unionNoticeIc, width: 16, height: 16, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          const SizedBox(width: 6),
                          Text(
                            isAr ? 'إعلان الوكالة' : 'Agency Notice',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white54),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _noticeText,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  /// Tab bar matching union_layout_agency_tab_custom_view.xml & union_tab_bg
  Widget _buildTabBar(bool isAr) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _buildTabButton(0, isAr ? 'أعضاء الوكالة' : 'Members'),
          _buildTabButton(1, isAr ? 'دخل الوكالة' : 'Income'),
          _buildTabButton(2, isAr ? 'الوكلاء الفرعيون' : 'Sub-agents'),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF1A1A1A) : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// Tab 1: Members List matching union_adapter_agency_item.xml
  Widget _buildMembersList(bool isAr) {
    if (_anchors.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              isAr ? 'لا يوجد أعضاء في الوكالة حالياً' : 'No members yet',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, index) {
          final anchor = _anchors[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white12,
                  backgroundImage: anchor.avatarUrl.isNotEmpty ? R.cachedImage(anchor.avatarUrl) : null,
                  child: anchor.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anchor.nickname.isNotEmpty ? anchor.nickname : (isAr ? 'مضيف' : 'Host'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${anchor.userId}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Image.asset(R.commonDiamondIc, width: 14, height: 14, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        const SizedBox(width: 4),
                        Text(
                          anchor.totalDiamond.toString(),
                          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAr ? 'نشط اليوم' : 'Active',
                      style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        childCount: _anchors.length,
      ),
    );
  }

  /// Tab 2: Income & Targets matching union_adapter_agency_detail_item.xml
  Widget _buildIncomeTab(AgentInfoModel? info, bool isAr) {
    final transferMoney = info?.transferMoney ?? 0;
    final dollar = info?.transferDollar ?? 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C2415), Color(0xFF1E1A16)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33FFD700)),
              ),
              child: Column(
                children: [
                  Text(
                    isAr ? 'إجمالي أرباح الوكالة' : 'Total Agency Commission',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$$dollar USD',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$transferMoney ماسة مؤهلة للتحويل',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Target Progress
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAr ? 'الهدف الشهري للوكالة' : 'Monthly Target',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Text('Level 1', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: const LinearProgressIndicator(
                      value: 0.65,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr ? 'تم إنجاز 65% من التارجت الشهري' : '65% completed',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 3: Sub Agents matching union_adapter_agency_sub_agent_detail_item.xml
  Widget _buildSubAgentsTab(bool isAr) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Image.asset(R.unionSubAgentIc, width: 56, height: 56, errorBuilder: (_, __, ___) => const Icon(Icons.group, size: 56, color: Colors.white24)),
            const SizedBox(height: 14),
            Text(
              isAr ? 'ليس لديك وكلاء فرعيين حالياً' : 'No Sub-agents yet',
              style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isAr ? 'قم بدعوة وكلاء فرعيين للحصول على عمولات إضافية على نشاطهم' : 'Invite sub-agents to earn bonus commission',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showInviteDialog(isAr),
              icon: const Icon(Icons.person_add, color: Color(0xFF1A1A1A)),
              label: Text(isAr ? 'دعوة وكيل فرعي' : 'Invite Sub-agent', style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Announcement Dialog matching union_dialog_agency_notice.xml
  void _showNoticeDialog(bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF24242A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'إعلان الوكالة' : 'Agency Notice',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                _noticeText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD4D6E5), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF454658), height: 1),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    isAr ? 'تأكيد' : 'OK',
                    style: const TextStyle(color: Color(0xFFFFD98B), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rules Dialog matching union_activity_rule.xml
  void _showRulesDialog(bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF24242A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'قواعد وإرشادات الوكالة' : 'Agency Rules',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const Text(
                '1. يجب على المضيفين البث لمدة لا تقل عن 20 ساعة أسبوعياً.\n2. تحسب العمولات نهاية كل شهر ميلادي.\n3. يمنع منعاً باتاً نقل المضيفين بين الوكالات دون موافقة الإدارة.\n4. التحويلات تتم بالماس المعتمد فقط.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(isAr ? 'فهمت ذلك' : 'Understood', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Invite dialog
  void _showInviteDialog(bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF24242A),
        title: Text(isAr ? 'دعوة وكيل فرعي' : 'Invite Sub-agent', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          isAr ? 'شارك كود الوكالة الخاص بك مع الوكيل الجديد للانضمام تحت إدارتك.' : 'Share your agency code to invite sub-agents.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(color: Color(0xFFFFD700))),
          ),
        ],
      ),
    );
  }

  /// 1. بطاقة معلومات الوكالة العلوية (Header Card)
  Widget _buildAgencyHeaderCard() {
    final info = _agentInfo;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: AssetImage('assets/images/bg_anchor_agent_info.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          // شارة عنوان بطاقة الوكالة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB74D), Color(0xFFFFA726)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'معلومات الوكالة',
              style: TextStyle(
                color: Color(0xFF211211),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // صورة الوكيل
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 2),
                  image: (info?.avatarUrl.isNotEmpty ?? false)
                      ? DecorationImage(
                          image: R.cachedImage(info!.avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (info?.avatarUrl.isEmpty ?? true)
                    ? const Icon(Icons.person, color: Colors.white70, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              // اسم الوكالة ومعرف الوكيل
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (info?.countryFlagUrl.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Image.network(info!.countryFlagUrl, width: 18, height: 12),
                          ),
                        Expanded(
                          child: Text(
                            info?.agencyName.isNotEmpty ?? false
                                ? info!.agencyName
                                : 'وكالة النجوم المعتمدة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID الوكيل: ${info?.userId ?? 0}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'إجمالي المضيفين: ${_anchors.length} مضيف',
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          // إحصائيات الأرباح والتحويلات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('الماسات المكتسبة', R.formatCoins(info?.transferMoney ?? 0)),
              Container(width: 1, height: 24, color: Colors.white12),
              _buildStatItem('قيمة الأرباح', '\$${info?.transferDollar ?? 0}'),
              Container(width: 1, height: 24, color: Colors.white12),
              _buildStatItem('رصيد الكوينز', R.formatCoins(info?.agentBean ?? 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFFBD98C),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  /// 2. قسم جدول المضيفين (3 أعمدة متناسقة)
  Widget _buildAnchorsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // عنوان القسم
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/icon_title_bg.png'),
                  fit: BoxFit.fill,
                ),
              ),
              child: const Text(
                'جميع المضيفين',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // شريط عناوين الأعمدة الثلاثة
          Row(
            children: [
              Expanded(child: _buildColumnTabHeader('assets/images/icon_tab_one.png', 'بيانات المضيف')),
              Expanded(child: _buildColumnTabHeader('assets/images/icon_tab_two.png', 'وقت المايك')),
              Expanded(child: _buildColumnTabHeader('assets/images/icon_tab_three.png', 'تارجت الذهب')),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // قائمة المضيفين
          if (_anchors.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: const [
                  Icon(Icons.people_outline, size: 48, color: Colors.black26),
                  SizedBox(height: 8),
                  Text('لا يوجد مضيفين منضمين للوكالة بعد', style: TextStyle(color: Colors.black45, fontSize: 13)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _anchors.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF2F2F2)),
              itemBuilder: (context, index) => _buildAnchorItemRow(_anchors[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildColumnTabHeader(String bgAsset, String title) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(bgAsset),
          fit: BoxFit.fill,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// سطر بيانات المضيف المطابق لـ `item_anchor_info_data.xml`
  Widget _buildAnchorItemRow(AnchorAgentUserInfoDataModel anchor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          // العمود 1: بيانات المضيف (الصورة + الاسم + المعرف)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: anchor.headImage.isNotEmpty
                      ? R.cachedImage(anchor.headImage)
                      : null,
                  child: anchor.headImage.isEmpty
                      ? const Icon(Icons.person, size: 20, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              anchor.nickname,
                              style: const TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (anchor.vip > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFF9900)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'VIP${anchor.vip}',
                                style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${anchor.userNo > 0 ? anchor.userNo : anchor.userId}',
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // العمود 2: وقت التواجد على المايك
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  anchor.formattedTime,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // العمود 3: تارجت الذهب والماسات
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${R.formatCoins(int.tryParse(anchor.diamonds) ?? 0)} 💎',
                  style: const TextStyle(
                    color: Color(0xFFDE880F),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: anchor.targetProgress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFDE880F)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
