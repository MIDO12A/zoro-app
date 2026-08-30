import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../config/r.dart';
import '../../../config/app_colors.dart';
import '../../../services/level_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dynamic_config_service.dart';
import '../../../core/supabase_compat.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../models/gift_model.dart' as gm;
import '../../user_profile/user_profile_screen.dart';
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
  final bool isRoomOwner;
  final bool isTargetModerator;
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
  final VoidCallback? onToggleAdmin;

  const UserProfile({
    super.key,
    required this.user,
    this.showMicControls = false,
    this.isCurrentUser = false,
    this.isFollowed = false,
    this.isModerator = false,
    this.isRoomOwner = false,
    this.isTargetModerator = false,
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
    this.onToggleAdmin,
  });

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  Map<String, dynamic> _extraUserData = {};
  bool _dataLoaded = false;
  final Map<String, String> _storeSvgaMap = {}; // itemId -> svgaAsset URL
  
  List<gm.SentGiftModel> _receivedGifts = [];
  Map<String, gm.GiftModel> _giftsCatalog = {};
  int _totalReceivedGiftCount = 0;

  int _followersCount = 0;
  int _fansCount = 0;
  int _visitorsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final uid = widget.user['id']?.toString() ?? widget.user['uid']?.toString();
    if (uid == null || uid.isEmpty) return;
    try {
      final svc = SupabaseService();
      // 1. Fetch user model directly from service
      final userObj = await svc.getUser(uid);
      if (userObj != null) {
        _extraUserData.addAll(userObj.toMap());
      }
      try {
        final userData = await Supabase.instance.client
            .from('users')
            .select('custom_id, active_frame, active_cover, profile_bg_url, owned_badges, owned_level_badges, wealth_level, recharge_level, gems_level, owned_level_frames, owned_level_badges, owned_items, owned_necklaces, country, country_code')
            .eq('uid', uid)
            .maybeSingle();
        if (userData != null) {
          _extraUserData.addAll(userData);
        }
      } catch (_) {}

      // Load received gifts
      try {
        final gifts = await svc.getReceivedGifts(uid);
        final giftsCat = await svc.getGiftsCatalog();
        int total = 0;
        for (final g in gifts) {
          total += g.count;
        }
        _receivedGifts = gifts;
        _giftsCatalog = giftsCat;
        _totalReceivedGiftCount = total;
      } catch (_) {}

      // Load stats counts
      try {
        final followingList = await svc.getFollowing(uid);
        final fansList = await svc.getFans(uid);
        final visitorsList = await svc.getVisitors(uid);
        _followersCount = followingList.length;
        _fansCount = fansList.length;
        _visitorsCount = visitorsList.length;
      } catch (_) {}

      // Load store items to resolve itemId -> svgaAsset / videoAsset URL
      try {
        final storeList = await svc.getStoreItems();
        for (final item in storeList) {
          final anim = (item.videoAsset != null && item.videoAsset!.isNotEmpty)
              ? item.videoAsset!
              : (item.svgaAsset != null && item.svgaAsset!.isNotEmpty)
                  ? item.svgaAsset!
                  : item.iconAsset;
          if (anim.isNotEmpty) {
            _storeSvgaMap[item.itemId] = anim;
          }
        }
      } catch (_) {}
      try {
        final storeItems = await Supabase.instance.client
            .from('store_items')
            .select('item_id, id, svga_asset, video_asset, icon_asset');
        if (storeItems != null) {
          for (final item in (storeItems as List)) {
            final id = item['item_id']?.toString() ?? item['id']?.toString();
            final docId = item['id']?.toString();
            final asset = (item['video_asset']?.toString().isNotEmpty == true)
                ? item['video_asset'].toString()
                : (item['svga_asset']?.toString().isNotEmpty == true)
                    ? item['svga_asset'].toString()
                    : item['icon_asset']?.toString();
            if (asset != null && asset.isNotEmpty) {
              if (id != null) _storeSvgaMap[id] = asset;
              if (docId != null) _storeSvgaMap[docId] = asset;
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[UserProfile Mini] Error loading data: $e');
    }
    if (mounted) setState(() => _dataLoaded = true);
  }

  String _resolveSvga(String itemId) {
    if (itemId.isEmpty) return '';
    if (itemId.startsWith('http://') || itemId.startsWith('https://') || itemId.startsWith('assets/')) {
      return itemId;
    }
    if (_storeSvgaMap.containsKey(itemId)) {
      return _storeSvgaMap[itemId]!;
    }
    final storeItem = SupabaseService().getStoreItemSync(itemId);
    if (storeItem != null) {
      final anim = (storeItem.videoAsset != null && storeItem.videoAsset!.isNotEmpty)
          ? storeItem.videoAsset!
          : (storeItem.svgaAsset != null && storeItem.svgaAsset!.isNotEmpty)
              ? storeItem.svgaAsset!
              : storeItem.iconAsset;
      if (anim.isNotEmpty) {
        _storeSvgaMap[itemId] = anim;
        return anim;
      }
    }
    return itemId;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
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
          child: _buildCompactSheet(),
        ),
      ),
    );
  }

  Widget _buildCompactSheet() {
    final config = DynamicConfigService();
    final avatar = widget.user['avatar']?.toString() ?? widget.user['photo_url']?.toString() ?? widget.user['photoUrl']?.toString() ?? R.avaBoy;
    final name = widget.user['name']?.toString() ?? 'User';
    final gender = widget.user['gender']?.toString() ?? 'male';
    final country = _extraUserData['country_code']?.toString() ?? _extraUserData['country']?.toString() ?? widget.user['country']?.toString() ?? 'EG';
    final activeFrame = _extraUserData['active_frame']?.toString() ?? widget.user['active_frame']?.toString() ?? '';
    final isHost = widget.user['is_host'] == true || widget.user['role'] == 'host' || widget.user['role'] == 'owner' || widget.isModerator;

    final fbUid = widget.user['id']?.toString() ?? widget.user['uid']?.toString() ?? '';
    final generatedId = fbUid.isNotEmpty ? (1000000 + (fbUid.hashCode.abs() % 9000000)).toString() : '9000000';
    final idText = _extraUserData['custom_id']?.toString() ?? widget.user['custom_id']?.toString() ?? widget.user['customId']?.toString() ?? generatedId;

    final cardBgColor = config.miniprofileBgColor;
    final cardBorderColor = config.miniprofileBorderColor;
    final textColor = config.miniprofileTextColor;
    final subTextColor = config.miniprofileSubTextColor;
    final btnColor = config.miniprofileButtonColor;
    final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
    final isMe = widget.isCurrentUser || (currentUser != null && (widget.user['uid'] == currentUser.uid || widget.user['id'] == currentUser.uid));

    final rawUserCover = (isMe && currentUser?.activeCover != null && currentUser!.activeCover!.isNotEmpty)
        ? currentUser.activeCover!
        : _extraUserData['active_cover']?.toString() ??
            widget.user['active_cover']?.toString() ??
            '';
    final userCover = _resolveSvga(rawUserCover);
    final hasUserCover = userCover.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Full Background User Cover (extends above the avatar and spans whole height)
        if (hasUserCover)
          Positioned(
            top: -45,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (detectAssetType(userCover) == AssetType.svga)
                    SvgaPlayer(assetPath: userCover, fit: BoxFit.fill, loops: true)
                  else if (detectAssetType(userCover) == AssetType.vap || detectAssetType(userCover) == AssetType.mp4)
                    VapPlayer(url: userCover, fit: BoxFit.fill, loops: true)
                  else
                    Image(
                      image: R.cachedImage(userCover),
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.20),
                          Colors.black.withOpacity(0.60),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Main bottom card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 36),
          decoration: BoxDecoration(
            color: hasUserCover ? Colors.transparent : cardBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: hasUserCover ? null : Border.all(color: cardBorderColor, width: 1),
            boxShadow: hasUserCover
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                if (!hasUserCover && config.miniprofileBgImage.isNotEmpty)
                  Positioned.fill(
                    child: Image(
                      image: R.cachedImage(config.miniprofileBgImage),
                      fit: BoxFit.cover,
                    ),
                  ),

                // Card Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 44, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. User Name & Gender & VIP Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: gender == 'female' ? const Color(0xFFE91E63) : const Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      gender == 'female' ? Icons.female : Icons.male,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42351A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 0.8),
                    ),
                    child: const Icon(Icons.person, color: Colors.amber, size: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 2. ID & Copy & Flag
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: idText));
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('تم نسخ المعرف بنجاح'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, color: Colors.white54, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          idText,
                          style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(
                      'https://flagcdn.com/w40/${country.toLowerCase()}.png',
                      width: 18,
                      height: 12,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Text('🇪🇬', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),

              // 3. Host / Role Badge (مضيف)
              if (isHost) ...[
                const SizedBox(height: 8),
                if (config.miniprofileHostBadgeImg.isNotEmpty)
                  SizedBox(
                    height: 24,
                    child: Image(
                      image: R.cachedImage(config.miniprofileHostBadgeImg),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: BoxDecoration(
                          color: config.miniprofileHostBadgeBg,
                          gradient: config.miniprofileHostBadgeBg == const Color(0xFF1E5BB5)
                              ? const LinearGradient(colors: [Color(0xFF1E5BB5), Color(0xFF0F3675)])
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF5C9DFF), width: 0.8),
                        ),
                        child: const Text(
                          'مضيف',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                    decoration: BoxDecoration(
                      color: config.miniprofileHostBadgeBg,
                      gradient: config.miniprofileHostBadgeBg == const Color(0xFF1E5BB5)
                          ? const LinearGradient(colors: [Color(0xFF1E5BB5), Color(0xFF0F3675)])
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF5C9DFF), width: 0.8),
                    ),
                    child: const Text(
                      'مضيف',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),

              // 4. Received Gifts Gallery Bar (شريط استلام الهدايا)
              GestureDetector(
                onTap: () {
                  if (widget.onViewProfile != null) {
                    widget.onViewProfile!();
                  } else {
                    final targetId = widget.user['id']?.toString() ?? widget.user['uid']?.toString();
                    if (targetId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserProfileScreen(targetUid: targetId)),
                      );
                    }
                  }
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF221A11),
                    image: config.miniprofileGiftBarBg.isNotEmpty
                        ? DecorationImage(image: R.cachedImage(config.miniprofileGiftBarBg), fit: BoxFit.cover)
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: config.miniprofileGiftBarBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
                      const SizedBox(width: 4),
                      // Top received gifts list
                      Expanded(
                        child: _receivedGifts.isEmpty
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'لا توجد هدايا بعد',
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _receivedGifts.length.clamp(0, 6),
                                itemBuilder: (ctx, i) {
                                  final g = _receivedGifts[i];
                                  final giftDef = _giftsCatalog[g.giftId];
                                  final icon = giftDef?.iconAsset ?? '';
                                  final isSvga = icon.isNotEmpty && detectAssetType(icon) == AssetType.svga;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: icon.isNotEmpty
                                              ? (isSvga
                                                  ? SvgaPlayer(assetPath: icon, width: 36, height: 36)
                                                  : CachedImg(icon, width: 36, height: 36, fit: BoxFit.contain))
                                              : const Icon(Icons.card_giftcard, color: Colors.amber, size: 24),
                                        ),
                                        Positioned(
                                          bottom: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4A3419),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.amber.withOpacity(0.5), width: 0.5),
                                            ),
                                            child: Text(
                                              'x${g.count}',
                                              style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      // "استلام" label & count
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('استلام', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              SizedBox(width: 3),
                              Text('🎁', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(
                            _formatCount(_totalReceivedGiftCount),
                            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Stats Row: الزائر | المحبون | متابعون
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('$_visitorsCount', 'الزائر', textColor, subTextColor),
                  _buildStatDivider(),
                  _buildStatColumn('$_fansCount', 'المحبون', textColor, subTextColor),
                  _buildStatDivider(),
                  _buildStatColumn('$_followersCount', 'متابعون', textColor, subTextColor),
                ],
              ),
              const SizedBox(height: 16),

              // 6. Mic Controls (if active on seat)
              if (widget.showMicControls) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: widget.onMicDown,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic_off, color: Colors.white70, size: 22),
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: widget.onMicMute,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volume_off, color: Colors.white70, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // 7. Bottom Action Buttons Bar
              if (!widget.isCurrentUser) ...[
                Row(
                  children: [
                    // Main Golden Gift Button
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () {
                          widget.onClose?.call();
                          widget.onGift?.call();
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: btnColor,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE8BD56), Color(0xFFC99427)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: btnColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (config.miniprofileGiftIcon.isNotEmpty)
                                Image(image: R.cachedImage(config.miniprofileGiftIcon), width: 18, height: 18, errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 14)))
                              else
                                const Text('🎁', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              const Text(
                                'هدية',
                                style: TextStyle(
                                  color: Color(0xFF1A1408),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // @ Mention Button
                    _buildRoundActionBtn(
                      icon: config.miniprofileMentionIcon.isNotEmpty
                          ? Image(image: R.cachedImage(config.miniprofileMentionIcon), width: 20, height: 20, errorBuilder: (_, __, ___) => const Text('@', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))
                          : const Text('@', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      onTap: () {
                        widget.onClose?.call();
                        widget.onMention?.call();
                      },
                    ),
                    const SizedBox(width: 10),

                    // Chat/Message Button - Opens direct 1-on-1 private chat
                    _buildRoundActionBtn(
                      icon: config.miniprofileChatIcon.isNotEmpty
                          ? Image(image: R.cachedImage(config.miniprofileChatIcon), width: 20, height: 20, errorBuilder: (_, __, ___) => const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18))
                          : const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                      onTap: () {
                        widget.onClose?.call();
                        if (widget.onChat != null) {
                          widget.onChat!();
                        } else {
                          final targetUid = widget.user['id']?.toString() ?? widget.user['uid']?.toString();
                          final targetName = widget.user['name']?.toString() ?? 'User';
                          final targetPhoto = widget.user['avatar']?.toString() ?? widget.user['photo_url']?.toString() ?? widget.user['photoUrl']?.toString();
                          if (targetUid != null && targetUid.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  targetUid: targetUid,
                                  targetName: targetName,
                                  targetPhotoUrl: targetPhoto,
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 10),

                    // Follow Button
                    _buildRoundActionBtn(
                      icon: config.miniprofileFollowIcon.isNotEmpty && !widget.isFollowed
                          ? Image(image: R.cachedImage(config.miniprofileFollowIcon), width: 20, height: 20, errorBuilder: (_, __, ___) => Icon(widget.isFollowed ? Icons.favorite : Icons.favorite_border_rounded, color: widget.isFollowed ? Colors.pinkAccent : Colors.white, size: 18))
                          : Icon(
                              widget.isFollowed ? Icons.favorite : Icons.favorite_border_rounded,
                              color: widget.isFollowed ? Colors.pinkAccent : Colors.white,
                              size: 18,
                            ),
                      onTap: widget.onFollow,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ),
),

        // Centered Avatar
        Positioned(
          top: 0,
          child: GestureDetector(
            onTap: () {
              if (widget.onViewProfile != null) {
                widget.onViewProfile!();
              } else {
                final targetId = widget.user['id']?.toString() ?? widget.user['uid']?.toString();
                if (targetId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UserProfileScreen(targetUid: targetId)),
                  );
                }
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cardBorderColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: R.loadImage(avatar, width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
                if (activeFrame.isNotEmpty)
                  SvgaFrame(
                    svgaPath: _resolveSvga(activeFrame),
                    size: 92,
                  ),
              ],
            ),
          ),
        ),

        // Top-Right Three-Dot Options Button (...)
        Positioned(
          top: 46,
          right: 20,
          child: GestureDetector(
            onTap: () => _showOptionsMenu(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: config.miniprofileMoreIcon.isNotEmpty
                  ? Image(image: R.cachedImage(config.miniprofileMoreIcon), width: 18, height: 18, errorBuilder: (_, __, ___) => const Icon(Icons.more_horiz, color: Colors.white70, size: 20))
                  : const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
            ),
          ),
        ),
        // Decorative Card Frame Image Overlay
        if (config.miniprofileCardFrameImg.isNotEmpty)
          Positioned(
            top: 36,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image(
                  image: R.cachedImage(config.miniprofileCardFrameImg),
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatColumn(String count, String label, Color textColor, Color subTextColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: subTextColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 20,
      color: Colors.white10,
    );
  }

  Widget _buildRoundActionBtn({required Widget icon, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF24202B),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12, width: 1),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1B26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isCurrentUser) ...[
              // 1. Assign / Remove Admin/Moderator (تعيين كأدمن / مشرف)
              if (widget.isRoomOwner || widget.isModerator)
                ListTile(
                  leading: Icon(
                    widget.isTargetModerator ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
                    color: Colors.amber,
                  ),
                  title: Text(
                    widget.isTargetModerator ? 'إلغاء الإشراف في الغرفة' : 'تعيين كأدمن / مشرف في الغرفة',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onToggleAdmin?.call();
                  },
                ),

              // 2. Mute in Room (كتم في الغرفة)
              if (widget.isModerator)
                ListTile(
                  leading: const Icon(Icons.volume_off_outlined, color: Colors.amberAccent),
                  title: const Text('كتم في الغرفة', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onMute?.call();
                  },
                ),

              // 3. Kick from Room (طرد من الغرفة)
              if (widget.isModerator)
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: const Text('طرد من الغرفة', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onKick?.call();
                  },
                ),

              // 4. Block / Unblock User (حظر / إلغاء حظر)
              ListTile(
                leading: Icon(
                  widget.isBlocked ? Icons.lock_open : Icons.block,
                  color: Colors.redAccent,
                ),
                title: Text(
                  widget.isBlocked ? 'إلغاء حظر المستخدم' : 'حظر المستخدم',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (widget.isBlocked) {
                    widget.onUnblock?.call();
                  } else {
                    widget.onBlock?.call();
                  }
                },
              ),

              // 5. Report User (إبلاغ عن المستخدم)
              ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
                title: const Text('إبلاغ عن المستخدم', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog();
                },
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('خيارات المستخدم', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ],
          ],
        ),
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
        backgroundColor: const Color(0xFF1E1B26),
        title: const Text('إبلاغ عن المستخدم', style: TextStyle(fontSize: 16, color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('سبب الإبلاغ', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedReason,
                dropdownColor: const Color(0xFF2A2634),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                hint: const Text('اختر السبب', style: TextStyle(fontSize: 13, color: Colors.white38)),
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13, color: Colors.white)))).toList(),
                onChanged: (v) => selectedReason = v,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('تفاصيل إضافية (اختياري)', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 4),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                maxLength: 500,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'اكتب التفاصيل هنا...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
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
                const SnackBar(content: Text('تم إرسال البلاغ بنجاح'), duration: Duration(seconds: 2)),
              );
            },
            child: const Text('إرسال', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

