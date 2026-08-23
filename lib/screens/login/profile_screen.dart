import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/r.dart';
import '../../providers/user_provider.dart';
import '../../services/dynamic_config_service.dart';
import '../../services/level_service.dart';
import '../../services/supabase_service.dart';
import '../../core/supabase_compat.dart';
import '../../screens/room/widgets/svga_player.dart';
import '../../screens/room/widgets/vap_player.dart';
import '../follow/follow_recent_screen.dart';
import '../profile/account_management_screen.dart';
import '../wallet/wallet_main_screen.dart';
import '../mall/mall_screen.dart';
import '../user_profile/user_profile_screen.dart';
import '../level/level_screen.dart';
import '../badges/badges_screen.dart';
import '../backpack/backpack_screen.dart';
import 'edit_profile_screen.dart';
import '../setting/feedback_screen.dart';
import '../vip/vip_center_screen.dart';
import '../vip/vip_intro_screen.dart';
import '../../features/cp/cp_detail_full_screen.dart';
import '../../features/cp/cp_service.dart';
import '../../features/host_agency/host_agency_screen.dart';
import '../../features/financial/agent_recharge_portal_screen.dart';
import '../../features/signin/weekly_signin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              _buildInfoSection(context, user),
              _buildCpRelationshipCard(context),
              _buildDataSection(context),
              _buildWalletSection(context, user),
              _buildVipSection(context),
              _buildSettingsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrameWidget(String activeFrame) {
    if (activeFrame.startsWith('http')) {
      final type = detectAssetType(activeFrame);
      if (type == AssetType.svga) {
        return SvgaPlayer(
          assetPath: activeFrame,
          fit: BoxFit.contain,
          loops: true,
        );
      }
      if (type == AssetType.vap || type == AssetType.mp4) {
        return VapPlayer(
          url: activeFrame,
          fit: BoxFit.contain,
          loops: true,
        );
      }
      return Image(
        image: R.cachedImage(activeFrame),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(),
      );
    }
    final storeItem = SupabaseService().getStoreItemSync(activeFrame);
    final frameAsset = storeItem?.svgaAsset;
    if (frameAsset != null) {
      return SvgaPlayer(
        assetPath: frameAsset,
        fit: BoxFit.contain,
        loops: true,
      );
    }
    return Image.asset(
      activeFrame,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(),
    );
  }

  Widget _buildInfoSection(BuildContext context, dynamic user) {
    return Stack(
      children: [
        R.image(R.mineTopBg,
          width: double.infinity,
          fit: BoxFit.fitWidth,
        ),
        Column(
          children: [
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                    child: R.image(R.mineBtnEditIc,
                      width: 24,
                      height: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              },
              child: SizedBox(
                width: 122,
                height: 122,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    R.image(R.mineAvatarIc,
                      width: 122,
                      height: 122,
                    ),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide.none),
                      ),
                      child: ClipOval(
                        child: (user?.photoUrl != null && user?.photoUrl != '')
                            ? Image(
                                image: R.cachedImage(user.photoUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    R.avaBoy,
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            : Image.asset(
                                R.avaBoy,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    if (user?.activeFrame != null && user!.activeFrame!.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _buildFrameWidget(user.activeFrame!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user?.name ?? 'اسم المستخدم',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16151A),
                  ),
                ),
                const SizedBox(width: 2),
                R.image(
                  (user?.gender == 'female')
                      ? R.icSexGirl
                      : R.icSexBoy,
                  width: 18,
                  height: 16,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              R.image(R.commonUserIdIc,
                width: 20,
                height: 20,
              ),
                const SizedBox(width: 2),
                Text(
                  'ID: ${user?.customId?.isNotEmpty == true ? user!.customId : ((1000000 + (user?.uid.hashCode.abs() ?? 0) % 9000000).toString())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9BA1B6),
                  ),
                ),
                const SizedBox(width: 2),
              R.image(R.commonIdCopyIc,
                width: 20,
                height: 20,
              ),
              ],
            ),
            const SizedBox(height: 8),
            _buildLevelDisplay(user),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelDisplay(dynamic user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _levelIcon(user?.wealthLevel ?? 1, 'wealth'),
          const SizedBox(width: 8),
          _levelIcon(user?.rechargeLevel ?? 1, 'recharge'),
        ],
      ),
    );
  }

  Widget _levelIcon(int level, String type) {
    final config = LevelService().getLevelConfig(type, level);
    final url = config?.imageUrl;
    if (url != null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: R.loadAsset(url),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: Text(
        'Lv.$level',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16151A)),
      ),
    );
  }

  Widget _buildCpRelationshipCard(BuildContext context) {
    final cfg = DynamicConfigService();
    return FutureBuilder<Map<String, dynamic>>(
      future: CpService.getMyData(),
      builder: (context, snapshot) {
        final couple = snapshot.data?['couple'] as Map<String, dynamic>?;
        final partner = couple?['partner'] as Map<String, dynamic>?;
        final hasCp = couple != null && snapshot.connectionState == ConnectionState.done && !snapshot.hasError;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final user = userProvider.currentUser;
        final totalScore = (couple?['total_score'] as num?)?.toInt() ?? 0;
        final daysTogether = (couple?['days_together'] as num?)?.toInt() ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CPDetailFullScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              color: cfg.cpCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cfg.cpCardBorder.withValues(alpha: 0.3), width: 1),
              boxShadow: [
                BoxShadow(color: cfg.cpPrimaryColor.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: cfg.cpPrimaryColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'العلاقات',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cfg.cpTextColor),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_back_ios, size: 14, color: cfg.cpSubText),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (hasCp && partner != null)
                  _buildCpPartnerRow(cfg, user, partner, daysTogether, totalScore)
                else
                  _buildCpEmptyState(cfg),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCpPartnerRow(DynamicConfigService cfg, dynamic user, Map<String, dynamic> partner, int days, int score) {
    final partnerName = partner['name'] as String? ?? partner['nickname'] as String? ?? '';
    final partnerAvatar = partner['avatar'] as String? ?? partner['photoUrl'] as String? ?? '';
    final userName = user?.name ?? '';
    final userPhoto = user?.photoUrl ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  child: _cpAvatarFrame(userPhoto.isNotEmpty ? R.cachedImage(userPhoto) : null, userName, cfg),
                ),
                Positioned(
                  left: 76,
                  top: 4,
                  child: Icon(Icons.favorite, color: cfg.cpPrimaryColor, size: 28),
                ),
                Positioned(
                  right: 0,
                  child: _cpAvatarFrame(partnerAvatar.isNotEmpty ? R.cachedImage(partnerAvatar) : null, partnerName, cfg),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(userName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cfg.cpTextColor)),
              const SizedBox(width: 20),
              Text(partnerName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cfg.cpTextColor)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: cfg.cpPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'معاً منذ $days يوم',
              style: TextStyle(fontSize: 11, color: cfg.cpAccent, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cpAvatarFrame(ImageProvider? avatar, String name, DynamicConfigService cfg) {
    return SizedBox(
      width: 80, height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cfg.cpAvatarBorderColor, width: 2),
            ),
          ),
          CircleAvatar(
            radius: 33,
            backgroundImage: avatar,
            child: avatar == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 18))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCpEmptyState(DynamicConfigService cfg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, color: cfg.cpSubText, size: 16),
          const SizedBox(width: 6),
          Text(
            'ليس لديك علاقة بعد',
            style: TextStyle(fontSize: 13, color: cfg.cpSubText),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cfg.cpGradientStart, cfg.cpGradientEnd],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ابحث عن شريك',
              style: TextStyle(fontSize: 12, color: cfg.cpButtonTextColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildDataItem('${user?.followers ?? 0}', 'متابع', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowRecentScreen(),
                ),
              );
            }),
          ),
          Expanded(
            child: _buildDataItem('${user?.following ?? 0}', 'المتابعين', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowRecentScreen(),
                ),
              );
            }),
          ),
          Expanded(
            child: _buildDataItem('${user?.visitors ?? 0}', 'الزائرين', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowRecentScreen(),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String count, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16151A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9BA1B6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletSection(BuildContext context, dynamic user) {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            R.mineWalletIc,
            'الحقيبة',
            'اشحن الآن',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalletMainScreen(),
                ),
              );
            },
          ),
          Container(
            height: 1,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
              R.image(R.commonGoldIc3,
                width: 24,
                height: 24,
              ),
                const SizedBox(width: 8),
                Text(
                  user?.coins?.toString() ?? '1,234,567',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16151A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipSection(BuildContext context) {
    return GestureDetector(
      onTap: () => _openVip(context),
      child: Container(
        margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
        width: double.infinity,
        height: 64,
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: R.image(R.mineVipCenterBg,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  R.image(R.mineMallTabVipIc,
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'VIP Center',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFAE9B5),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  R.image(R.mineVipLabelIc,
                    width: 56,
                    height: 56,
                  ),
                  const SizedBox(width: 4),
                  R.image(R.mineVipGo,
                    width: 16,
                    height: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVip(BuildContext context) async {
    try {
      final res = await Supabase.instance.client
          .from('vip_config')
          .select('intro_video_url')
          .order('tier')
          .limit(1)
          .maybeSingle();
      final introUrl = res?['intro_video_url']?.toString();
      if (introUrl != null && introUrl.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => VipIntroScreen(videoUrl: introUrl),
        ));
        return;
      }
    } catch (_) {}
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const VipCenterScreen(),
    ));
  }

  Widget _buildSettingsSection(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            R.mineCpIc,
            'CP',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CPDetailFullScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.mineUnionIc,
            'وكالة المضيفين',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HostAgencyScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.mineUnionIc,
            'وكيل الشحن',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AgentRechargePortalScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.mineLevelIc,
            'المستوى',
            'Lv.${user?.level ?? 1}',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LevelScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.mineLevelIc,
            'الشارات',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BadgesScreen()),
              );
            },
          ),
          _buildMenuItem(
            R.mineMallIc,
            'المتجر',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MallScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.icSigningOk,
            'المكافآت اليومية',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WeeklySigninScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.mineBackpackIc,
            'الحقيبة',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackpackScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.mineFeedbackIc,
            'الشكوى والاقتراحات',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeedbackScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            R.mineSettingIc,
            'الإعدادات',
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountManagementScreen(),
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String iconPath,
    String title,
    String? subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            R.image(iconPath, width: 44, height: 44),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF16151A),
              ),
            ),
            const Spacer(),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9BA1B6),
                  ),
                ),
              ),
            R.image(R.commonNext4Ic, width: 16, height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.grey[200],
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
