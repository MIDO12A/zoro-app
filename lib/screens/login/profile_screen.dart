import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../config/r.dart';
import '../../providers/user_provider.dart';
import '../../services/level_service.dart';
import '../../services/supabase_service.dart';
import '../../services/update_service.dart';
import '../../widgets/app_update_dialog.dart';
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
          _buildDivider(),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => _buildMenuItem(
              R.mineFeedbackIc,
              'فحص التحديثات',
              snap.hasData ? 'v${snap.data!.version}+${snap.data!.buildNumber}' : null,
              () => _checkUpdatesManually(context),
            ),
          ),

        ],
      ),
    );
  }

  Future<void> _checkUpdatesManually(BuildContext context) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري فحص التحديثات...'), duration: Duration(seconds: 2)),
    );
    try {
      final update = await UpdateService.instance.checkForUpdate(throwOnError: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (update != null) {
        await AppUpdateDialog.show(context, update);
        return;
      }
      final info = await PackageInfo.fromPlatform();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('أنت على أحدث نسخة (بناء ${info.buildNumber})')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فحص التحديث — تحقق من الاتصال: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
