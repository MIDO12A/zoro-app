import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/r.dart';
import '../../../config/app_colors.dart';
import '../../../services/level_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dynamic_config_service.dart';
import '../../../core/supabase_compat.dart';
import 'svga_frame.dart';
import 'svga_player.dart';
import 'vap_player.dart';
import 'vip_cover_animator.dart';

class UserProfile extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool showMicControls;
  final bool isCurrentUser;
  final bool isFollowed;
  final bool isModerator;
  final bool isBlocked;
  final String? currentUserId;
  final VoidCallback? onClose;
  final VoidCallback? onViewProfile;
  final VoidCallback? onFollow;
  final VoidCallback? onChat;
  final VoidCallback? onMention;
  final VoidCallback? onGift;
  final VoidCallback? onMicDown;
  final VoidCallback? onMicMute;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;
  final VoidCallback? onKick;
  final VoidCallback? onMute;

  const UserProfile({
    super.key,
    required this.user,
    this.showMicControls = false,
    this.isCurrentUser = false,
    this.isFollowed = false,
    this.isModerator = false,
    this.isBlocked = false,
    this.currentUserId,
    this.onClose,
    this.onViewProfile,
    this.onFollow,
    this.onChat,
    this.onMention,
    this.onGift,
    this.onMicDown,
    this.onMicMute,
    this.onReport,
    this.onBlock,
    this.onUnblock,
    this.onKick,
    this.onMute,
  });

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  List<Map<String, dynamic>> _badgesCatalog = [];
  List<String> _ownedBadgeIds = [];
  List<String> _ownedLevelBadgeUrls = [];
  List<Map<String, String?>> _necklaces = [];
  List<Map<String, dynamic>> _rechargeNecklaces = [];
  List<Map<String, dynamic>> _allOwnedNecklaces = [];
  Map<String, dynamic> _extraUserData = {};
  bool _dataLoaded = false;
  final Map<String, String> _storeSvgaMap = {}; // itemId -> svgaAsset URL
  List<Map<String, String?>> _showcaseItems = [];
  List<String> _showcaseCategories = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final uid = widget.user['id']?.toString();
    if (uid == null) return;
    try {
      final svc = SupabaseService();
      final userData = await Supabase.instance.client
          .from('users')
          .select('custom_id, active_frame, active_cover, owned_badges, owned_level_badges, wealth_level, recharge_level, gems_level, owned_level_frames, owned_level_badges, owned_items, owned_necklaces')
          .eq('uid', uid)
          .maybeSingle();
      if (userData != null) {
        _extraUserData = userData;
        _ownedBadgeIds = (userData['owned_badges'] as List?)?.cast<String>() ?? [];
        _ownedLevelBadgeUrls = (userData['owned_level_badges'] as List?)?.cast<String>() ?? [];
      }
      // Auto-award recharge necklaces
      try {
        final rl = (userData?['recharge_level'] ?? 1).toInt();
        await svc.awardRechargeNecklaces(uid, rl);
      } catch (_) {}
      // Load badges catalog
      try {
        final badges = await svc.getBadgesCatalog();
        _badgesCatalog = badges;
      } catch (_) {}
      // Load necklaces catalog and build owned lists
      try {
        final nCat = await svc.getNecklacesCatalog();
        final ownedN = (userData?['owned_necklaces'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final allOwned = <Map<String, dynamic>>[];
        final rn = <Map<String, dynamic>>[];
        for (final n in nCat) {
          final nid = n['id']?.toString() ?? '';
          if (ownedN.contains(nid)) {
            allOwned.add(n);
            if (n['type']?.toString() == 'recharge') {
              final req = (n['required_recharge_level'] ?? 0).toInt();
              if (req > 0) {
                rn.add(n);
              }
            }
          }
        }
        _allOwnedNecklaces = allOwned;
        _rechargeNecklaces = rn;
      } catch (_) {}
      // Load store items to resolve itemId -> svgaAsset URL
      try {
        final storeItems = await Supabase.instance.client
            .from('store_items')
            .select('item_id, svga_asset');
        if (storeItems != null) {
          for (final item in (storeItems as List)) {
            final id = item['item_id']?.toString();
            final svga = item['svga_asset']?.toString();
            if (id != null && svga != null && svga.isNotEmpty) {
              _storeSvgaMap[id] = svga;
            }
          }
        }
      } catch (_) {}
      try {
        final gifts = await svc.getGiftedItems(uid);
        _necklaces = gifts
            .where((g) => g.itemCategory == 'necklace')
            .map((g) => {'icon': g.itemIcon, 'svga': g.svgaAsset, 'name': g.itemName})
            .toList();
        _showcaseItems = gifts.map((g) => {
          'name': g.itemName,
          'icon': g.itemIcon,
          'svga': g.svgaAsset,
          'category': g.itemCategory,
        }).toList();
        final cats = gifts.map((g) => g.itemCategory).toSet().where((c) => c.isNotEmpty && c != 'necklace').toList()..sort();
        _showcaseCategories = cats;
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _dataLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: SizedBox(
              width: double.infinity,
              child: _buildSheet(),
            ),
          ),
        ),
    );
  }

  Widget _buildSheet() {
    final avatar = widget.user['avatar']?.toString() ?? R.avaBoy;
    final name = widget.user['name']?.toString() ?? 'User';
    final vipLevel = widget.user['vipLevel']?.toString();
    final config = DynamicConfigService();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: const Color(0xFF16151A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        image: config.miniprofileBgImage.isNotEmpty
            ? DecorationImage(image: R.cachedImage(config.miniprofileBgImage), fit: BoxFit.cover)
            : null,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Stack(
          children: [
            // Scrollable Content
            ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _buildNewHeader(config, avatar, name, vipLevel),
                const SizedBox(height: 24),
                _buildStatsRow(),
                const SizedBox(height: 24),
                _buildCardsRow(config),
                const SizedBox(height: 16),
                _buildSupportersRow(config),
                const SizedBox(height: 24),
                _buildIdentitySection(config),
                const SizedBox(height: 24),
                _buildBadgesSectionNew(config),
                const SizedBox(height: 24),
                _buildAchievementsSection(config),
              ],
            ),
            // Top Nav Icons (Back / Report)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (!widget.isCurrentUser) {
                        _showReportDialog();
                      }
                    },
                    child: Icon(widget.isCurrentUser ? Icons.edit_square : Icons.report_problem_outlined, color: Colors.white, size: 24),
                  ),
                  GestureDetector(
                    onTap: widget.onViewProfile,
                    child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            // Bottom Action Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black, Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showMicControls) _buildMicOperate(),
                    if (widget.showMicControls) const SizedBox(height: 12),
                    _buildOperateRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewHeader(DynamicConfigService config, String avatar, String name, String? vipLevel) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Image Area
        SizedBox(
          height: 160,
          width: double.infinity,
          child: (_extraUserData['active_cover']?.toString() != null && _extraUserData['active_cover'].toString().isNotEmpty)
              ? (isVideoType(_resolveSvga(_extraUserData['active_cover'].toString()))
                  ? VapPlayer(url: _resolveSvga(_extraUserData['active_cover'].toString()), fit: BoxFit.cover)
                  : SvgaPlayer(assetPath: _resolveSvga(_extraUserData['active_cover'].toString()), fit: BoxFit.cover))
              : const SizedBox(),
        ),
        // Content
        Container(
          margin: const EdgeInsets.only(top: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // User Info (Left side in RTL, Right side in UI but we use spaceBetween so avatar is right, info is left)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    // ID & Gender row
                    Row(
                      children: [
                        Builder(builder: (context) {
                          final fbUid = widget.user['id']?.toString() ?? widget.user['uid']?.toString() ?? '';
                          final generatedId = fbUid.isNotEmpty ? (1000000 + (fbUid.hashCode.abs() % 9000000)).toString() : '';
                          final idText = _extraUserData['custom_id']?.toString() ?? widget.user['custom_id']?.toString() ?? widget.user['customId']?.toString() ?? (generatedId.isNotEmpty ? generatedId : fbUid);
                          return GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: idText));
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('تم نسخ الـ ID'), duration: Duration(seconds: 1)));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                              child: Text('ID: $idText', style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Icon(widget.user['gender'] == 'female' ? Icons.female : Icons.male, size: 12, color: Colors.white),
                              const SizedBox(width: 2),
                              Text('${widget.user['age'] ?? 18}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.network('https://flagcdn.com/w40/${(widget.user['country_code'] ?? 'EG').toString().toLowerCase()}.png', width: 20, height: 14, errorBuilder: (_,__,___) => const Icon(Icons.flag, size: 14, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Levels
                    Row(
                      children: [
                        _levelChip(widget.user['wealth_level'] ?? 1, 'wealth'),
                        const SizedBox(width: 4),
                        _levelChip(widget.user['recharge_level'] ?? 1, 'recharge'),
                        const SizedBox(width: 4),
                        _levelChip(widget.user['gems_level'] ?? 1, 'gems'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Signature / Quote
                    Row(
                      children: [
                        const Icon(Icons.edit, size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.user['bio']?.toString() ?? 'أقول شيئاً لجعل الآخرين يعرفون لك.',
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Avatar
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: VipCoverAnimator(
                  vipLevel: vipLevel,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: ClipOval(child: R.loadImage(avatar, width: 90, height: 90, fit: BoxFit.cover)),
                      ),
                      if (_extraUserData['active_frame'] != null || (_extraUserData['owned_level_frames'] as List?)?.isNotEmpty == true)
                        SvgaFrame(
                          svgaPath: _resolveSvga(_extraUserData['active_frame']?.toString() ?? (_extraUserData['owned_level_frames'] as List).last.toString()),
                          size: 110,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _countItem(widget.user['visitors']?.toString() ?? '0', 'الزائرين'),
        _countItem(widget.user['following']?.toString() ?? '0', 'تمت متابعة'),
        _countItem(widget.user['fans']?.toString() ?? '0', 'أتابعه'),
      ],
    );
  }

  Widget _buildCardsRow(DynamicConfigService config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('قريباً...'), duration: Duration(seconds: 1)));
              },
              child: Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pinkAccent.withOpacity(0.5), width: 1),
                  gradient: const LinearGradient(colors: [Color(0xFF5A1A4A), Color(0xFF2A0D2A)]),
                  image: config.miniprofileIntimateCardBg.isNotEmpty
                      ? DecorationImage(image: R.cachedImage(config.miniprofileIntimateCardBg), fit: BoxFit.cover)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.arrow_back_ios, size: 12, color: Colors.white54),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Text('علاقة حميمة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Icon(Icons.favorite, color: Colors.pink[200], size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('اربط علاقة حميمة الآن!', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('قريباً...'), duration: Duration(seconds: 1)));
              },
              child: Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
                  gradient: const LinearGradient(colors: [Color(0xFF4A4A1A), Color(0xFF1A1A0D)]),
                  image: config.miniprofileFamilyCardBg.isNotEmpty
                      ? DecorationImage(image: R.cachedImage(config.miniprofileFamilyCardBg), fit: BoxFit.cover)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.arrow_back_ios, size: 12, color: Colors.white54),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Text('العائلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            const CircleAvatar(radius: 10, backgroundImage: NetworkImage('https://i.pravatar.cc/100')), // Placeholder
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('ID:15652', style: TextStyle(color: Colors.amber, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportersRow(DynamicConfigService config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            // Custom Banner if exists
            if (config.miniprofileSupportersBanner.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: R.loadImage(config.miniprofileSupportersBanner, fit: BoxFit.cover),
                ),
              ),
            // Default SUPPORTERS text if no banner
            if (config.miniprofileSupportersBanner.isEmpty)
              const Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text('SUPPORTERS', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                ),
              ),
            Positioned(
              left: 16, top: 0, bottom: 0,
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios, size: 12, color: Colors.white54),
                  const SizedBox(width: 12),
                  _buildSupporterSlot(config, config.miniprofileGoldCrown, Colors.amber),
                  const SizedBox(width: 8),
                  _buildSupporterSlot(config, config.miniprofileSilverCrown, Colors.grey[300]!),
                  const SizedBox(width: 8),
                  _buildSupporterSlot(config, config.miniprofileBronzeCrown, Colors.orange[300]!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupporterSlot(DynamicConfigService config, String crownImg, Color defaultColor) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: defaultColor, width: 2),
            image: config.miniprofileSupporterSlot.isNotEmpty
                ? DecorationImage(image: R.cachedImage(config.miniprofileSupporterSlot), fit: BoxFit.cover)
                : null,
          ),
          child: config.miniprofileSupporterSlot.isEmpty
              ? const Icon(Icons.person, color: Colors.white24, size: 20)
              : null,
        ),
        Positioned(
          top: -12,
          child: crownImg.isNotEmpty
              ? R.loadImage(crownImg, width: 20, height: 20)
              : Icon(Icons.workspace_premium, color: defaultColor, size: 20),
        ),
      ],
    );
  }

  Widget _buildIdentitySection(DynamicConfigService config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildSectionTitle(config.miniprofileIdentityTitleImg, 'وسم الهوية'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Dummy Identity Badges
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.purpleAccent]),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Voice Host', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Agency Lead', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String imgUrl, String fallbackText) {
    if (imgUrl.isNotEmpty) {
      return R.loadImage(imgUrl, height: 24, fit: BoxFit.contain);
    }
    return Text(
      fallbackText,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _badgeItem({String? svga, String? img}) {
    if (svga != null && svga.isNotEmpty) {
      final url = _resolveSvga(svga);
      return Container(
        margin: const EdgeInsets.only(left: 8),
        width: 40, height: 40,
        child: isVideoType(url)
            ? VapPlayer(url: url)
            : SvgaPlayer(assetPath: url),
      );
    }
    if (img != null && img.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        width: 40, height: 40,
        child: R.loadImage(img, fit: BoxFit.contain),
      );
    }
    return const SizedBox();
  }

  Widget _buildBadgesSectionNew(DynamicConfigService config) {
    final badgeWidgets = <Widget>[];
    for (final id in _ownedBadgeIds) {
      final match = _badgesCatalog.where((b) => b['id']?.toString() == id).toList();
      if (match.isNotEmpty) {
        final b = match.first;
        badgeWidgets.add(_badgeItem(svga: b['svga_url']?.toString(), img: b['image_url']?.toString()));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildSectionTitle(config.miniprofileBadgesTitleImg, 'شارات'),
          const SizedBox(height: 12),
          badgeWidgets.isEmpty
              ? const Center(child: Text('إذهب لإضاءة أول شارة لك!', style: TextStyle(color: Colors.white54, fontSize: 12)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: badgeWidgets,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(DynamicConfigService config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildSectionTitle(config.miniprofileAchievementsTitleImg, 'إنجازات'),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAchievementCard('إطار', Icons.crop_square),
              const SizedBox(width: 12),
              _buildAchievementCard('مركبة', Icons.directions_car),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF22202A), borderRadius: BorderRadius.circular(12)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.arrow_back_ios, size: 12, color: Colors.white54),
                          Text('جدار الهدايا', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Spacer(),
                      Center(child: Icon(Icons.card_giftcard, size: 40, color: Colors.pinkAccent)),
                      Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(String title, IconData defaultIcon) {
    return Expanded(
      flex: 1,
      child: Container(
        height: 140,
        decoration: BoxDecoration(color: const Color(0xFF22202A), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.arrow_back_ios, size: 12, color: Colors.white54),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Spacer(),
            Icon(defaultIcon, size: 40, color: Colors.white24),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _countItem(String count, String label) => Column(
    children: [
      Text(
        count,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF16151A),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0x8016151A)),
      ),
    ],
  );

  Widget _buildOperateRow() {
    if (widget.isCurrentUser) {
      return const SizedBox();
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onFollow,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              height: 36,
              decoration: BoxDecoration(
                color: widget.isFollowed ? Colors.red.shade50 : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isFollowed ? Icons.favorite : Icons.favorite_border,
                    color: widget.isFollowed ? Colors.red : const Color(0xFF16151A),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isFollowed ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isFollowed ? Colors.red : const Color(0xFF16151A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: widget.onChat,
            child: _opBtn(
              icon: R.roomUserChatIc,
              label: 'Chat',
              marginStart: 4,
              marginEnd: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _opBtn({
    required String icon,
    required String label,
    double marginStart = 0,
    double marginEnd = 0,
  }) => Container(
    margin: EdgeInsets.only(left: marginStart, right: marginEnd),
    height: 36,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          icon,
          width: 16,
          height: 16,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF16151A)),
        ),
      ],
    ),
  );

  Widget _buildMicOperate() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: widget.onMicDown,
          child: R.image(
            R.roomMicDown,
            width: 40,
            height: 40,
          ),
        ),
        GestureDetector(
          onTap: widget.onMicMute,
          child: R.image(
            R.roomMicOff,
            width: 40,
            height: 40,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBadge(Map<String, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _levelChip(user['wealth_level'] ?? 1, 'wealth'),
              const SizedBox(width: 4),
              _levelChip(user['recharge_level'] ?? 1, 'recharge'),
              const SizedBox(width: 4),
              _levelChip(user['gems_level'] ?? 1, 'gems'),
            ],
          ),
        ],
      ),
    );
  }

  String _resolveSvga(String itemId) {
    if (itemId.startsWith('http://') || itemId.startsWith('https://')) return itemId;
    return _storeSvgaMap[itemId] ?? itemId;
  }

  Widget _levelChip(int level, String type) {
    final config = LevelService().getLevelConfig(type, level);
    final url = config?.imageUrl;
    if (url != null) {
      return Container(
        width: 32,
        height: 32,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: R.loadAsset(url),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: AppColors.giftBtnGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Lv.$level',
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
    );
  }

  void _showReportDialog() {
    final descCtrl = TextEditingController();
    String? selectedReason;
    final reasons = ['Spam', 'Harassment', 'Inappropriate content', 'Fake account', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report User', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reason', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedReason,
                hint: const Text('Select a reason', style: TextStyle(fontSize: 13)),
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => selectedReason = v,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Description (optional)', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Provide additional details...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (selectedReason == null) return;
              SupabaseService().reportUser(
                reporterUid: widget.currentUserId ?? '',
                reportedUid: widget.user['id']?.toString() ?? '',
                reason: selectedReason!,
                description: descCtrl.text,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Report submitted'), duration: Duration(seconds: 2)),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
