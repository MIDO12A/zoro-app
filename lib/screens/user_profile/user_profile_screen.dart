import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../models/message_model.dart';
import '../../config/r.dart';
import '../../config/app_colors.dart';
import '../../services/dynamic_config_service.dart';
import '../../services/level_service.dart';
import '../../services/supabase_service.dart';
import '../../services/cloudinary_service.dart';
import '../../core/supabase_compat.dart';
import '../../core/widgets/cached_image.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../models/gift_model.dart' as gm;
import '../../models/gifted_item_model.dart';
import '../room/widgets/svga_player.dart';
import '../room/widgets/svga_frame.dart';
import '../room/widgets/vap_player.dart';
import '../room/room_screen.dart';
import '../../features/cp/cp_service.dart';
import '../../features/cp/cp_detail_full_screen.dart';
import '../login/edit_profile_screen.dart';
import '../follow/follow_recent_screen.dart';
import '../../features/host_agency/host_agency_screen.dart';
import '../../features/host_agency/screens/agency_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? targetUid;

  const UserProfileScreen({super.key, this.targetUid});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = SupabaseService();
  UserModel? _user;
  bool _loading = true;
  bool _isFollowing = false;
  List<gm.SentGiftModel> _receivedGifts = [];
  List<Map<String, dynamic>> _badgesCatalog = [];
  List<Map<String, dynamic>> _allOwnedNecklaces = [];
  List<Map<String, dynamic>> _allOwnedEntrances = [];
  List<Map<String, dynamic>> _topMonthlyFans = [];
  List<Map<String, dynamic>> _allOwnedFrames = [];
  String? _currentRoomId;
  gm.SentGiftModel? _selectedGift;
  GiftedItemModel? _selectedItem;
  Map<String, gm.GiftModel> _giftsCatalog = {};
  String? _profileBgUrl;
  String? _activeFrame;
  List<dynamic> _ownedLevelFrames = [];

  final Map<String, String> _storeSvgaMap = {};

  // Stats counts (fetched from relational tables for accuracy)
  int _followingCount = 0;
  int _fansCount = 0;
  int _visitorsCount = 0;
  int _sentGiftsCount = 0;

  // CP data
  Map<String, dynamic>? _cpCouple;
  Map<String, dynamic>? _cpPartner;
  int _cpGiftTotal = 0;

  // Agency / Family data
  Map<String, dynamic>? _userAgency;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final uid = widget.targetUid;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      UserModel? targetUser;
      if (uid != null) {
        targetUser = await supabase.getUser(uid);
        if (currentUser != null) {
          final following = await supabase.isFollowing(currentUser.uid, uid);
          if (mounted) setState(() => _isFollowing = following);
          if (currentUser.uid != uid && targetUser != null) {
            supabase.recordProfileVisit(
              visitedUid: uid,
              visitorUid: currentUser.uid,
              visitorName: currentUser.name,
              visitorPhoto: currentUser.photoUrl,
            );
          }
        }
      } else {
        targetUser = currentUser;
      }

      if (targetUser != null) {
        final uidVal = targetUser.uid;
        final added = await supabase.awardRechargeNecklaces(uidVal, targetUser.rechargeLevel);
        if (added.isNotEmpty) {
          targetUser = await supabase.getUser(uidVal);
        }
        final gifts = await supabase.getReceivedGifts(uidVal);
        final badgesCat = await supabase.getBadgesCatalog();
        final nCat = await supabase.getNecklacesCatalog();
        if (badgesCat.isEmpty) debugPrint('[UserProfile] badgesCatalog is empty');
        if (nCat.isEmpty) debugPrint('[UserProfile] necklacesCatalog is empty');
        final roomId = await supabase.getUserCurrentRoomId(uidVal);
        final giftsCat = await supabase.getGiftsCatalog();
        final ownedGifted = await supabase.getGiftedItems(uidVal);
        final necklaces = ownedGifted.where((i) => i.itemCategory == 'necklace').toList();
        final allOwnedNList = <Map<String, dynamic>>[];
        final ownedNIds = targetUser?.ownedNecklaces ?? [];
        final List<Map<String, dynamic>> allOwnedEList = [];
        final List<Map<String, dynamic>> allOwnedFList = [];
        for (final n in nCat) {
          final nid = n['id']?.toString();
          if (ownedNIds.contains(nid)) {
            allOwnedNList.add(n);
          }
        }
        for (final n in necklaces) {
          if (!allOwnedNList.any((x) => x['id']?.toString() == n.itemId)) {
            allOwnedNList.add({'id': n.itemId, 'svga_url': n.svgaAsset, 'image_url': n.itemIcon, 'name': n.itemName});
          }
        }
        final entrances = ownedGifted.where((i) => i.itemCategory == 'entrance' || i.itemCategory == 'car' || i.itemCategory == 'vehicle').toList();
        final frames = ownedGifted.where((i) => i.itemCategory == 'frame' || i.itemCategory == 'avatar_frame').toList();
        for (final e in entrances) {
          allOwnedEList.add({'id': e.itemId, 'svga_url': e.svgaAsset, 'image_url': e.itemIcon, 'name': e.itemName});
        }
        for (final f in frames) {
          allOwnedFList.add({'id': f.itemId, 'svga_url': f.svgaAsset, 'image_url': f.itemIcon, 'name': f.itemName});
        }

        Map<String, dynamic>? extraUserData;
        try {
          extraUserData = await Supabase.instance.client
              .from('users')
              .select('profile_bg_url, active_frame, owned_level_frames')
              .eq('uid', uidVal)
              .maybeSingle();
        } catch (e) {
          debugPrint('[UserProfile] extraUserData query error: $e');
        }
        // Load store items to resolve itemId -> svga asset URL
        try {
          final storeItems = await Supabase.instance.client
              .from('store_items')
              .select('item_id, svga_asset');
          for (final item in (storeItems as List)) {
            final id = item['item_id']?.toString();
            final svga = item['svga_asset']?.toString();
            if (id != null && svga != null && svga.isNotEmpty) {
              _storeSvgaMap[id] = svga;
            }
          }
        } catch (e) {
          debugPrint('[UserProfile] store_items query error: $e');
        }
        // Resolve frame IDs to actual SVGA asset paths
        final rawFrame = extraUserData?['active_frame']?.toString() ?? targetUser?.activeFrame ?? '';
        final rawFrames = (extraUserData?['owned_level_frames'] as List?) ?? targetUser?.ownedLevelFrames ?? [];
        final resolvedFrame = rawFrame.isNotEmpty ? _resolveSvga(rawFrame) : null;
        final resolvedFrames = rawFrames.map((e) => _resolveSvga(e.toString())).toList();

        // Load Agency / Family info
        Map<String, dynamic>? userAgency;
        try {
          final memberRes = await Supabase.instance.client
              .from('host_agency_members')
              .select('agency_id, role, status')
              .eq('user_id', uidVal)
              .eq('status', 'active')
              .maybeSingle();
          if (memberRes != null && memberRes['agency_id'] != null) {
            final agencyId = memberRes['agency_id'].toString();
            final agencyRes = await Supabase.instance.client
                .from('host_agencies')
                .select('id, name, photo_url, kayan_id, country')
                .eq('id', agencyId)
                .maybeSingle();
            if (agencyRes != null) {
              userAgency = agencyRes;
            }
          }
        } catch (e) {
          debugPrint('[UserProfile] agency query error: $e');
        }

        // Load CP data
        Map<String, dynamic>? cpMyData;
        try {
          cpMyData = await CpService.getMyData();
        } catch (_) {}

        // Load individual CP gift total (for level determination)
        int cpGiftTotal = 0;
        try {
          cpGiftTotal = await CpService.getUserCpGiftTotal(uidVal);
        } catch (e) {
          debugPrint('[UserProfile] cp gift total error: $e');
        }

        // Fetch actual stats counts from relational tables
        int followingCount = 0, fansCount = 0, visitorsCount = 0, sentGiftsCount = 0;
        try {
          final followingList = await supabase.getFollowing(uidVal);
          followingCount = followingList.length;
        } catch (_) {}
        try {
          final fansList = await supabase.getFans(uidVal);
          fansCount = fansList.length;
        } catch (_) {}
        try {
          final visitorsList = await supabase.getVisitors(uidVal);
          visitorsCount = visitorsList.length;
        } catch (_) {}
        try {
          final sentRes = await Supabase.instance.client
              .from('sent_gifts')
              .select('id')
              .eq('sender_id', uidVal);
          sentGiftsCount = (sentRes as List?)?.length ?? 0;
        } catch (_) {}

        List<Map<String, dynamic>> topFans = [];
        try {
          topFans = await supabase.getTopMonthlyFans(uidVal);
        } catch (_) {}

        if (mounted) {
          setState(() {
            _user = targetUser;
            _receivedGifts = gifts;
            _badgesCatalog = badgesCat;
            _allOwnedNecklaces = allOwnedNList;
            _allOwnedEntrances = allOwnedEList;
            _allOwnedFrames = allOwnedFList;
            _currentRoomId = roomId;
            _giftsCatalog = giftsCat;
            _profileBgUrl = extraUserData?['profile_bg_url']?.toString() ?? targetUser?.profileBgUrl;
            _activeFrame = resolvedFrame;
            _ownedLevelFrames = resolvedFrames;
            _userAgency = userAgency;
            _cpCouple = cpMyData?['couple'] as Map<String, dynamic>?;
            _cpPartner = _cpCouple?['partner'] as Map<String, dynamic>?;
            _cpGiftTotal = cpGiftTotal;
            _followingCount = followingCount;
            _fansCount = fansCount;
            _visitorsCount = visitorsCount;
            _sentGiftsCount = sentGiftsCount;
            _topMonthlyFans = topFans;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('_loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null || _user == null) return;
    if (_isFollowing) {
      await supabase.unfollowUser(currentUser.uid, _user!.uid);
    } else {
      await supabase.followUser(currentUser.uid, _user!.uid);
    }
    if (mounted) setState(() => _isFollowing = !_isFollowing);
  }

  Future<void> _navigateToRoom() async {
    final roomId = _currentRoomId ?? _user?.hostedRoomId;
    if (roomId == null || roomId.isEmpty) return;
    final room = await supabase.getRoom(roomId);
    if (room == null || !mounted) return;
    navigateToRoom(context,
        roomName: room.name,
        hostName: room.hostName,
        roomId: room.roomId,
        roomPassword: room.password,
        hotValue: room.totalGifts.toString(),
        gameDesc: room.description);
  }

  Future<void> _navigateToChat() async {
    if (_user == null || widget.targetUid == null) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          targetUid: _user!.uid,
          targetName: _user!.name,
          targetPhotoUrl: _user!.photoUrl,
        ),
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null || !mounted) return;
    setState(() => _loading = true);
    try {
      debugPrint('[CoverImage] picked: ${image.path}');
      CroppedFile? cropped;
      try {
        cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'قص صورة الغلاف',
              toolbarColor: const Color(0xFF171A24),
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: const Color(0xFF4CC790),
              lockAspectRatio: false,
              statusBarColor: const Color(0xFF171A24),
            ),
            IOSUiSettings(
              title: 'قص صورة الغلاف',
              aspectRatioPickerButtonHidden: false,
              resetButtonHidden: true,
            ),
          ],
        );
      } catch (e) {
        debugPrint('[CoverImage] crop error: $e');
        cropped = null;
      }
      
      final File fileToUpload = cropped != null ? File(cropped.path) : File(image.path);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      if (currentUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      String url = '';
      try {
        url = await CloudinaryService().uploadImage(
          fileToUpload,
          publicId: 'cover_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        debugPrint('[CoverImage] Cloudinary upload error: $e, attempting Supabase fallback...');
        try {
          final fileName = 'covers/${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final bytes = await fileToUpload.readAsBytes();
          await Supabase.instance.client.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
          url = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
        } catch (se) {
          debugPrint('[CoverImage] Supabase upload error: $se');
        }
      }

      if (!mounted || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل رفع الصورة، يرجى المحاولة مرة أخرى')),
          );
          setState(() => _loading = false);
        }
        return;
      }

      try {
        await Supabase.instance.client.from('users').update({'profile_bg_url': url}).eq('uid', currentUser.uid);
      } catch (e) {
        debugPrint('[CoverImage] db update error: $e');
      }

      if (mounted) {
        setState(() {
          _profileBgUrl = url;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث صورة الغلاف بنجاح')),
        );
      }
    } catch (e) {
      debugPrint('[CoverImage] unexpected error: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحديث الغلاف')),
        );
      }
    }
  }

  String _resolveSvga(String itemId) {
    if (itemId.isEmpty) return '';
    if (itemId.startsWith('http://') || itemId.startsWith('https://') || itemId.startsWith('assets/')) return itemId;
    if (_storeSvgaMap.containsKey(itemId)) return _storeSvgaMap[itemId]!;
    final storeItem = supabase.getStoreItemSync(itemId);
    if (storeItem != null) {
      final anim = (storeItem.videoAsset != null && storeItem.videoAsset!.isNotEmpty)
          ? storeItem.videoAsset!
          : (storeItem.svgaAsset != null && storeItem.svgaAsset!.isNotEmpty)
              ? storeItem.svgaAsset!
              : (storeItem.iconAsset.isNotEmpty ? storeItem.iconAsset : '');
      if (anim.isNotEmpty) {
        _storeSvgaMap[itemId] = anim;
        return anim;
      }
    }
    return itemId;
  }

  void _showImageFullScreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF171A24),
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(
                child: CachedImg(url, fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                  error: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCoverMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF888888)),
                title: const Text('تغيير صورة الغلاف', style: TextStyle(color: Color(0xFF333333))),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickCoverImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Color(0xFF888888)),
                title: const Text('إزالة صورة الغلاف', style: TextStyle(color: Color(0xFF333333))),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (!mounted) return;
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  final currentUser = userProvider.currentUser;
                  if (currentUser == null) return;
                  await Supabase.instance.client.from('users').update({'profile_bg_url': null}).eq('uid', currentUser.uid);
                  if (mounted) setState(() => _profileBgUrl = null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCpLevelFromGifts(int totalGifts) {
    if (totalGifts >= 1000000) return 'cp3';
    if (totalGifts >= 500000) return 'cp2';
    if (totalGifts >= 1) return 'cp1';
    if (_cpCouple != null) return 'cp1';
    return 'cp1';
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = _user ?? userProvider.currentUser;

    return ListenableBuilder(
      listenable: DynamicConfigService(),
      builder: (context, _) {
        final config = DynamicConfigService();
        return Scaffold(
          backgroundColor: config.fullProfileBgColor,
          body: SafeArea(
            child: Stack(
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        decoration: BoxDecoration(
                          color: config.fullProfileBgColor,
                          image: config.fullProfileBgImage.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(config.fullProfileBgImage),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _buildNewProfileHeader(config, user),
                              const SizedBox(height: 12),
                              _buildActionButtons(config, user),
                              const SizedBox(height: 12),
                              _buildNewStatsRow(config),
                              const SizedBox(height: 24),
                              _buildNewCardsRow(config),
                              const SizedBox(height: 16),
                              _buildNewSupportersRow(config),
                              const SizedBox(height: 24),
                              _buildNewIdentitySection(config, user),
                              const SizedBox(height: 24),
                              _buildNewBadgesSection(config),
                              const SizedBox(height: 24),
                              _buildNewAchievementsSection(config, user),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                if (_selectedGift != null) _buildGiftOverlay(config),
                if (_selectedItem != null) _buildItemOverlay(config),
                _buildNewTitleBar(context, user, config),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── NEW DARK DESIGN METHODS ────────────────────────────────────────────────

  Widget _buildNewTitleBar(BuildContext ctx, UserModel? user, DynamicConfigService config) {
    final currentUser = Provider.of<UserProvider>(ctx, listen: false).currentUser;
    final isOwnProfile = widget.targetUid == null ||
        (currentUser != null && widget.targetUid == currentUser.uid);
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            ),
            if (isOwnProfile)
              GestureDetector(
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
                child: config.fullProfileEditIcon.isNotEmpty
                    ? Image.network(config.fullProfileEditIcon, width: 22, height: 22, color: Colors.white, errorBuilder: (_, __, ___) => const Icon(Icons.edit_square, color: Colors.white, size: 22))
                    : const Icon(Icons.edit_square, color: Colors.white, size: 22),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewProfileHeader(DynamicConfigService config, UserModel? user) {
    final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
    final isOwnProfile = widget.targetUid == null || (currentUser != null && widget.targetUid == currentUser.uid);
    final coverUrl = (_profileBgUrl != null && _profileBgUrl!.isNotEmpty)
        ? _profileBgUrl!
        : (user?.profileBgUrl != null && user!.profileBgUrl!.isNotEmpty)
            ? user!.profileBgUrl!
            : '';
    final hasCover = coverUrl.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover background
        GestureDetector(
          onTap: () {
            if (hasCover) {
              _showImageFullScreen(coverUrl);
            } else if (isOwnProfile) {
              _pickCoverImage();
            }
          },
          child: Stack(
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: hasCover
                    ? Image(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF22202A)),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2A1A3A), Color(0xFF16151A)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
              ),
              if (isOwnProfile)
                Positioned(
                  top: 50,
                  left: 16,
                  child: GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'تغيير الغلاف',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Smooth gradient overlay at bottom of cover blending into page
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  config.fullProfileBgColor.withOpacity(0.6),
                  config.fullProfileBgColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        // Content row: info LEFT, avatar RIGHT
        Container(
          margin: const EdgeInsets.only(top: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // User info (left)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Name
                    Text(
                      user?.name ?? 'اسم المستخدم',
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ID + Gender + Flag
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'ID: ${(user?.customId.isNotEmpty == true) ? user!.customId : ((1000000 + ((user?.uid ?? '').hashCode.abs() % 9000000)).toString())}',
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: user?.gender == 'female'
                                ? Colors.pinkAccent.withOpacity(0.5)
                                : Colors.blueAccent.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                user?.gender == 'female' ? Icons.female : Icons.male,
                                size: 12, color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text('${user?.age ?? 18}',
                                  style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.network(
                            'https://flagcdn.com/w40/${(user?.country ?? 'eg').toLowerCase()}.png',
                            width: 20, height: 14,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.flag, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Level chips
                    Row(
                      children: [
                        _newLevelChip(user?.wealthLevel ?? 1, 'wealth'),
                        const SizedBox(width: 4),
                        _newLevelChip(user?.rechargeLevel ?? 1, 'recharge'),
                        const SizedBox(width: 4),
                        _newLevelChip(user?.gemsLevel ?? 1, 'gems'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Bio
                    Row(
                      children: [
                        const Icon(Icons.edit, size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (user?.signature.isNotEmpty == true)
                                ? user!.signature
                                : 'أقول شيئاً لجعل الآخرين يعرفون لك.',
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
              const SizedBox(width: 12),
              // Avatar (right)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: (user?.photoUrl != null && user!.photoUrl.isNotEmpty)
                            ? Image(
                                image: NetworkImage(user.photoUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Image.asset(R.avaBoy, fit: BoxFit.cover),
                              )
                            : Image.asset(R.avaBoy, fit: BoxFit.cover),
                      ),
                    ),
                    if (_activeFrame != null && _activeFrame!.isNotEmpty)
                      SvgaFrame(svgaPath: _activeFrame!, size: 110),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _newLevelChip(int level, String type) {
    final lvlConfig = LevelService().getLevelConfig(type, level);
    final url = lvlConfig?.badgeUrl ?? lvlConfig?.imageUrl;
    if (url != null && url.isNotEmpty) {
      return SizedBox(
        height: 22,
        child: R.loadAsset(url, height: 22, fit: BoxFit.contain),
      );
    }
    return _buildLevelBadgeSmall(level, type);
  }

  Widget _newLevelChipFallback(int level) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('Lv.$level',
        style: const TextStyle(fontSize: 10, color: Colors.white)),
  );

  Widget _buildNewStatsRow(DynamicConfigService config) {
    final uid = _user?.uid;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FollowRecentScreen(initialTab: 2, targetUid: uid),
              ),
            );
          },
          child: _newCountItem('$_visitorsCount', 'الزائرين', config),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FollowRecentScreen(initialTab: 1, targetUid: uid),
              ),
            );
          },
          child: _newCountItem('$_fansCount', 'أتابعه', config),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FollowRecentScreen(initialTab: 0, targetUid: uid),
              ),
            );
          },
          child: _newCountItem('$_followingCount', 'تمت متابعة', config),
        ),
      ],
    );
  }

  Widget _newCountItem(String count, String label, DynamicConfigService config) => Column(
    children: [
      Text(count,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: config.fullProfileTextColor)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(fontSize: 10, color: config.fullProfileSubTextColor)),
    ],
  );

  Widget _buildNewCardsRow(DynamicConfigService config) {
    final hasAgency = _userAgency != null;
    final agencyName = _userAgency?['name']?.toString() ?? 'العائلة';
    final agencyAvatar = _userAgency?['photo_url']?.toString() ?? '';
    final rawAgencyId = _userAgency?['custom_id'] ?? _userAgency?['numeric_id'] ?? _userAgency?['kayan_id'] ?? _userAgency?['agency_id'] ?? _userAgency?['id'];
    final agencyId = (rawAgencyId != null && int.tryParse(rawAgencyId.toString()) != null)
        ? rawAgencyId.toString()
        : (rawAgencyId != null ? (100000 + (rawAgencyId.toString().hashCode.abs() % 900000)).toString() : '');

    final hasCp = _cpCouple != null;
    final partnerName = _cpPartner?['name']?.toString() ?? '';
    final partnerAvatar = _cpPartner?['avatar']?.toString() ?? '';
    final daysTogether = (_cpCouple?['days_together'] as num?)?.toInt() ?? 0;
    final cpLevel = _getCpLevelFromGifts(_cpGiftTotal);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 1. Family card (golden) — يمين في RTL
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (hasAgency) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AgencyProfileScreen(agencyId: _userAgency!['id'].toString()),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HostAgencyScreen(),
                    ),
                  );
                }
              },
              child: Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF4A4A1A), Color(0xFF1A1A0D)]),
                  image: config.fullProfileFamilyCardBg.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(config.fullProfileFamilyCardBg),
                          fit: BoxFit.cover)
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
                        Row(children: [
                          Text(
                            hasAgency ? agencyName : 'العائلة',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: (agencyAvatar.isNotEmpty)
                                ? NetworkImage(agencyAvatar)
                                : const NetworkImage('https://i.pravatar.cc/100'),
                            backgroundColor: Colors.amber.withOpacity(0.3),
                            child: agencyAvatar.isEmpty
                                ? const Icon(Icons.groups, size: 12, color: Colors.amber)
                                : null,
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          hasAgency ? 'ID:$agencyId' : 'أنت لست منضم إلى عائلة',
                          style: TextStyle(
                            color: hasAgency ? Colors.amber : Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 2. Intimate/CP card (pink) — يسار في RTL
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CPDetailFullScreen()),
                );
              },
              child: Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.pinkAccent.withOpacity(0.5), width: 1),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF5A1A4A), Color(0xFF2A0D2A)]),
                  image: config.fullProfileIntimateCardBg.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(config.fullProfileIntimateCardBg),
                          fit: BoxFit.cover)
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
                        Row(children: [
                          Text(
                            hasCp ? partnerName : 'علاقة حميمة',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          if (hasCp && cpLevel != 'none')
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: SvgaPlayer(
                                assetPath: 'assets/svga/$cpLevel.svga',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                              ),
                            )
                          else if (hasCp && partnerAvatar.isNotEmpty)
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: NetworkImage(partnerAvatar),
                            )
                          else
                            Icon(Icons.favorite, color: Colors.pink[200], size: 16),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          hasCp ? 'معاً منذ $daysTogether يوم' : 'اربط علاقة حميمة الآن!',
                          style: TextStyle(
                            color: hasCp ? Colors.pinkAccent[100] : Colors.white54,
                            fontSize: 10,
                          ),
                        ),
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

  Widget _buildNewSupportersRow(DynamicConfigService config) {
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
            if (config.fullProfileSupportersBanner.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(config.fullProfileSupportersBanner,
                      fit: BoxFit.cover),
                ),
              ),
            if (config.fullProfileSupportersBanner.isEmpty)
              const Positioned(
                right: 16, top: 0, bottom: 0,
                child: Center(
                  child: Text('SUPPORTERS',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic)),
                ),
              ),
            Positioned(
              left: 16, top: 0, bottom: 0,
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios, size: 12, color: Colors.white54),
                  const SizedBox(width: 12),
                  _newSupporterSlot(config, config.fullProfileGoldCrown, Colors.amber),
                  const SizedBox(width: 8),
                  _newSupporterSlot(
                      config, config.fullProfileSilverCrown, Colors.grey[300]!),
                  const SizedBox(width: 8),
                  _newSupporterSlot(
                      config, config.fullProfileBronzeCrown, Colors.orange[300]!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newSupporterSlot(
      DynamicConfigService config, String crownImg, Color defaultColor) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: defaultColor, width: 2),
            image: config.fullProfileSupporterSlot.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(config.fullProfileSupporterSlot),
                    fit: BoxFit.cover)
                : null,
          ),
          child: config.fullProfileSupporterSlot.isEmpty
              ? const Icon(Icons.person, color: Colors.white24, size: 20)
              : null,
        ),
        Positioned(
          top: -12,
          child: crownImg.isNotEmpty
              ? Image.network(crownImg, width: 20, height: 20)
              : Icon(Icons.workspace_premium, color: defaultColor, size: 20),
        ),
      ],
    );
  }

  Widget _buildNewIdentitySection(DynamicConfigService config, UserModel? user) {
    final List<Map<String, dynamic>> necklaces = List.from(_allOwnedNecklaces);

    // Auto-inject Agency Leader / Owner SVGA Necklace
    final isAgencyLeader = (_userAgency != null && _userAgency!['owner_id']?.toString() == _user?.uid) ||
        (_user != null && _user!.ownedNecklaces.contains('agency_leader_necklace'));
    if (isAgencyLeader && config.agencyLeaderNecklaceSvga.isNotEmpty) {
      if (!necklaces.any((n) => n['type'] == 'agency_leader' || n['id'] == 'agency_leader_necklace')) {
        necklaces.insert(0, {
          'id': 'agency_leader_necklace',
          'name': config.agencyLeaderNecklaceName,
          'name_ar': config.agencyLeaderNecklaceName,
          'type': 'agency_leader',
          'svga_url': config.agencyLeaderNecklaceSvga,
          'image_url': config.agencyLeaderNecklaceImg,
          'description_ar': 'قلادة الوكيل الحصرية لرؤساء الوكالات',
        });
      }
    } else {
      final isAgencyHost = (_userAgency != null) ||
          (_user != null && _user!.ownedNecklaces.contains('agency_host_necklace'));
      if (isAgencyHost && config.agencyHostNecklaceSvga.isNotEmpty) {
        // Auto-inject Agency Host Member SVGA Necklace
        if (!necklaces.any((n) => n['type'] == 'agency_host' || n['id'] == 'agency_host_necklace')) {
          necklaces.insert(0, {
            'id': 'agency_host_necklace',
            'name': config.agencyHostNecklaceName,
            'name_ar': config.agencyHostNecklaceName,
            'type': 'agency_host',
            'svga_url': config.agencyHostNecklaceSvga,
            'image_url': config.agencyHostNecklaceImg,
            'description_ar': 'قلادة وشارة المضيف الحصرية لأعضاء الوكالة',
          });
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _newSectionTitle(config.fullProfileIdentityTitleImg, 'وسم الهوية'),
          const SizedBox(height: 12),
          if (necklaces.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'لا توجد قلادات بعد',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              // Bigger necklaces: exactly 3 fit side by side across the section width
              final double tile = ((constraints.maxWidth - 16) / 3).clamp(72.0, 130.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: necklaces.map((n) {
                    final svga = n['svga_url']?.toString();
                    final img = n['image_url']?.toString();
                    return GestureDetector(
                      onTap: () => _showNecklaceDetail(n),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: tile,
                        height: tile,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: (svga != null && svga.isNotEmpty)
                            ? SvgaPlayer(assetPath: svga, width: tile, height: tile)
                            : (img != null && img.isNotEmpty)
                                ? CachedImg(img, fit: BoxFit.contain)
                                : Icon(Icons.workspace_premium, color: Colors.amber, size: tile * 0.45),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNewBadgesSection(DynamicConfigService config) {
    final ownedBadgeIds = _user?.ownedBadges ?? [];
    final levelBadgeUrls = _user?.ownedLevelBadges ?? [];
    final badgeWidgets = <Widget>[];

    for (final id in ownedBadgeIds) {
      if (id.isEmpty) continue;
      if (id.startsWith('http://') || id.startsWith('https://') || id.startsWith('assets/')) {
        if (id.endsWith('.svga') || id.contains('.svga')) {
          badgeWidgets.add(
            Container(
              margin: const EdgeInsets.only(left: 8),
              width: 44, height: 44,
              child: SvgaPlayer(assetPath: id, width: 44, height: 44),
            ),
          );
        } else {
          badgeWidgets.add(
            Container(
              margin: const EdgeInsets.only(left: 8),
              width: 44, height: 44,
              child: CachedImg(id, width: 44, height: 44, fit: BoxFit.contain),
            ),
          );
        }
        continue;
      }
      final match = _badgesCatalog.where((b) => b['id']?.toString() == id).toList();
      if (match.isNotEmpty) {
        final b = match.first;
        final svgaUrl = b['svga_url']?.toString();
        final imgUrl = b['image_url']?.toString();
        if (svgaUrl != null && svgaUrl.isNotEmpty) {
          badgeWidgets.add(
            GestureDetector(
              onTap: () => _showBadgeDetail(b),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                width: 44, height: 44,
                child: SvgaPlayer(assetPath: svgaUrl, width: 44, height: 44),
              ),
            ),
          );
        } else if (imgUrl != null && imgUrl.isNotEmpty) {
          badgeWidgets.add(
            GestureDetector(
              onTap: () => _showBadgeDetail(b),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                width: 44, height: 44,
                child: CachedImg(imgUrl, width: 44, height: 44, fit: BoxFit.contain),
              ),
            ),
          );
        }
      }
    }

    for (final url in levelBadgeUrls) {
      if (url.endsWith('.svga') || url.contains('.svga') || detectAssetType(url) == AssetType.svga) {
        badgeWidgets.add(
          Container(
            margin: const EdgeInsets.only(left: 8),
            width: 44, height: 44,
            child: SvgaPlayer(assetPath: url, width: 44, height: 44),
          ),
        );
      } else {
        badgeWidgets.add(
          Container(
            margin: const EdgeInsets.only(left: 8),
            width: 44, height: 44,
            child: CachedImg(url, width: 44, height: 44, fit: BoxFit.contain),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _newSectionTitle(config.fullProfileBadgesTitleImg, 'شارات'),
          const SizedBox(height: 12),
          badgeWidgets.isEmpty
              ? const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'إذهب لإضاءة أول شارة لك!',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: badgeWidgets,
                  ),
                ),
        ],
      ),
    );
  }

  // تجميع الهدايا المستلمة حسب معرف الهدية: صورة واحدة لكل هدية + العدد الإجمالي
  // (بدل تكرار نفس الهدية في كل مرة أُرسلت فيها).
  List<Map<String, dynamic>> _getAggregatedReceivedGifts() {
    final Map<String, Map<String, dynamic>> map = {};
    for (final g in _receivedGifts) {
      final key = g.giftId.isNotEmpty ? g.giftId : (g.giftName.isNotEmpty ? g.giftName : 'gift');
      if (map.containsKey(key)) {
        map[key]!['count'] = (map[key]!['count'] as int) + g.count;
      } else {
        map[key] = {
          'giftId': g.giftId,
          'giftName': g.giftName,
          'count': g.count,
        };
      }
    }
    return map.values.toList();
  }

  /// Converts an aggregated gift map back into a SentGiftModel for display.
  gm.SentGiftModel _giftMapToModel(Map<String, dynamic> m) => gm.SentGiftModel(
        id: m['giftId']?.toString() ?? '',
        giftId: m['giftId']?.toString() ?? '',
        giftName: m['giftName']?.toString() ?? '',
        senderId: '',
        senderName: '',
        receiverId: '',
        receiverName: '',
        roomId: '',
        value: 0,
        count: (m['count'] as num?)?.toInt() ?? 1,
        timestamp: DateTime.now(),
      );

  Widget _buildNewAchievementsSection(
      DynamicConfigService config, UserModel? user) {
    // 1. Vehicle / Entrance
    final hasEntrance = _allOwnedEntrances.isNotEmpty;
    final topEntrance = hasEntrance ? _allOwnedEntrances.first : null;
    final entranceSvga = topEntrance?['svga_url']?.toString();
    final entranceImg = topEntrance?['image_url']?.toString();

    // 2. Frame
    final hasFrame = (_activeFrame != null && _activeFrame!.isNotEmpty) || _allOwnedFrames.isNotEmpty;
    final topFrame = _allOwnedFrames.isNotEmpty ? _allOwnedFrames.first : null;
    final frameSvga = _activeFrame ?? topFrame?['svga_url']?.toString();
    final frameImg = topFrame?['image_url']?.toString();

    // 3. Top Received Gift for preview
    final aggGifts = _getAggregatedReceivedGifts();
    final topGift = aggGifts.isNotEmpty ? aggGifts.first : null;
    final topGiftDef = topGift != null
        ? _giftsCatalog[topGift['giftId'] as String?]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _newSectionTitle(config.fullProfileAchievementsTitleImg, 'إنجازات'),
          const SizedBox(height: 12),
          Row(
            children: [
              // Left column: مركبة + إطار (stacked vertically)
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (hasEntrance && topEntrance != null) {
                          _showItemDetailMap(topEntrance, 'مركبة');
                        }
                      },
                      child: _newAchievementCardSmall(
                        'مركبة',
                        Icons.directions_car,
                        svgaUrl: entranceSvga,
                        assetUrl: entranceImg,
                        hasItem: hasEntrance,
                        cardBg: config.fullProfileVehicleCardBg,
                        cardBorder: config.fullProfileVehicleCardBorder,
                        customIcon: config.fullProfileVehicleIcon,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        if (hasFrame) {
                          _showItemDetailMap(topFrame ?? {'name': 'إطار', 'svga_url': _activeFrame}, 'إطار');
                        }
                      },
                      child: _newAchievementCardSmall(
                        'اطار',
                        Icons.crop_square,
                        svgaUrl: frameSvga,
                        assetUrl: frameImg,
                        hasItem: hasFrame,
                        cardBg: config.fullProfileFrameCardBg,
                        cardBorder: config.fullProfileFrameCardBorder,
                        customIcon: config.fullProfileFrameIcon,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: جدار الهدايا (Gift Wall)
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => _showFrostedGiftWall(context),
                  child: Container(
                    height: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22202A),
                      image: config.fullProfileGiftWallCardBg.isNotEmpty
                          ? DecorationImage(
                              image: R.cachedImage(config.fullProfileGiftWallCardBg),
                              fit: BoxFit.cover,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: config.fullProfileGiftWallCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.arrow_back_ios,
                                size: 12, color: Colors.white54),
                            Row(
                              children: [
                                if (_receivedGifts.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.pinkAccent.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${aggGifts.length}',
                                      style: const TextStyle(
                                          color: Colors.pinkAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                const Text('جدار الهدايا',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: _receivedGifts.isNotEmpty && topGiftDef?.iconAsset != null
                              ? SizedBox(
                                  width: 54,
                                  height: 54,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      detectAssetType(topGiftDef!.iconAsset) == AssetType.svga
                                          ? SvgaPlayer(assetPath: topGiftDef.iconAsset, width: 54, height: 54)
                                          : CachedImg(topGiftDef.iconAsset, width: 54, height: 54, fit: BoxFit.contain),
                                      Positioned(
                                        bottom: -2, right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.amber, width: 0.5),
                                          ),
                                          child: Text(
                                            'x${topGift!['count']}',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : (config.fullProfileGiftWallIcon.isNotEmpty
                                  ? CachedImg(config.fullProfileGiftWallIcon, width: 48, height: 48, fit: BoxFit.contain, error: (_, __, ___) => const Icon(Icons.card_giftcard, size: 48, color: Colors.pinkAccent))
                                  : const Icon(Icons.card_giftcard, size: 48, color: Colors.pinkAccent)),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _newAchievementCardSmall(String title, IconData defaultIcon,
      {String? svgaUrl, String? assetUrl, bool hasItem = false, String cardBg = '', Color? cardBorder, String customIcon = ''}) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF22202A),
        image: cardBg.isNotEmpty
            ? DecorationImage(
                image: R.cachedImage(cardBg),
                fit: BoxFit.cover,
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder ?? Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.arrow_back_ios, size: 12, color: Colors.white54),
          if (svgaUrl != null && svgaUrl.isNotEmpty)
            SizedBox(
              width: 40, height: 40,
              child: SvgaPlayer(assetPath: svgaUrl, width: 40, height: 40),
            )
          else if (assetUrl != null && assetUrl.isNotEmpty)
            SizedBox(
              width: 40, height: 40,
              child: CachedImg(assetUrl, width: 40, height: 40, fit: BoxFit.contain,
                  error: (_, __, ___) => Icon(defaultIcon, size: 28, color: Colors.white24)),
            )
          else if (customIcon.isNotEmpty)
            SizedBox(
              width: 40, height: 40,
              child: CachedImg(customIcon, width: 40, height: 40, fit: BoxFit.contain,
                  error: (_, __, ___) => Icon(defaultIcon, size: 28, color: hasItem ? Colors.amber : Colors.white24)),
            )
          else
            Icon(defaultIcon, size: 28, color: hasItem ? Colors.amber : Colors.white24),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showItemDetailMap(Map<String, dynamic> item, String categoryTitle) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1C24).withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  categoryTitle,
                  style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 80, height: 80,
                  child: (item['svga_url'] != null && item['svga_url'].toString().isNotEmpty)
                      ? SvgaPlayer(assetPath: item['svga_url'].toString(), width: 80, height: 80)
                      : (item['image_url'] != null && item['image_url'].toString().isNotEmpty)
                          ? CachedImg(item['image_url'].toString(), width: 80, height: 80, fit: BoxFit.contain)
                          : const Icon(Icons.stars, color: Colors.amber, size: 50),
                ),
                const SizedBox(height: 12),
                Text(
                  (item['name_ar']?.toString()?.isNotEmpty ?? false)
                      ? item['name_ar'].toString()
                      : (item['name']?.toString()?.isNotEmpty ?? false ? item['name'].toString() : categoryTitle),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBadgeDetail(Map<String, dynamic> b) {
    _showItemDetailMap(b, 'شارة');
  }

  void _showNecklaceDetail(Map<String, dynamic> n) {
    _showItemDetailMap(n, 'قلادة');
  }

  void _showFrostedGiftWall(BuildContext context) {
    final aggGifts = _getAggregatedReceivedGifts();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(
              color: const Color(0xFF16151A).withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      Text(
                        'جدار الهدايا (${aggGifts.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),
                Expanded(
                  child: _receivedGifts.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد هدايا مستلمة بعد',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: aggGifts.length,
                          itemBuilder: (context, index) {
                            final g = aggGifts[index];
                            final giftDef = _giftsCatalog[g['giftId'] as String?];
                            final isSvga = giftDef?.iconAsset != null &&
                                detectAssetType(giftDef!.iconAsset) == AssetType.svga;

                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _selectedGift = _giftMapToModel(g));
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          if (giftDef?.iconAsset != null)
                                            isSvga
                                                ? SvgaPlayer(
                                                    assetPath: giftDef!.iconAsset,
                                                    width: 48,
                                                    height: 48,
                                                  )
                                                : CachedImg(
                                                    giftDef!.iconAsset,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.contain,
                                                    error: (_, __, ___) => const Icon(
                                                        Icons.card_giftcard,
                                                        color: Colors.white38,
                                                        size: 32),
                                                  )
                                          else
                                            const Icon(Icons.card_giftcard,
                                                color: Colors.pinkAccent, size: 36),
                                          // Badge count xN
                                          Positioned(
                                            bottom: -2,
                                            right: -2,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                    colors: [Colors.pinkAccent, Colors.purpleAccent]),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.pink.withOpacity(0.4),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                'x${g['count']}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      g['giftName'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _newSectionTitle(String? imgUrl, String fallbackText) {
    if (imgUrl != null && imgUrl.isNotEmpty) {
      return Image.network(imgUrl, height: 24, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _newSectionTitleFallback(fallbackText));
    }
    return _newSectionTitleFallback(fallbackText);
  }

  Widget _newSectionTitleFallback(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTopIcon(String url, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsetsDirectional.only(end: 12),
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: CachedImg(
            url,
            fit: BoxFit.cover,
            error: (_, __, ___) => const Icon(Icons.broken_image, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(DynamicConfigService config, UserModel? user) {
    final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
    final isOwnProfile = widget.targetUid == null || (currentUser != null && widget.targetUid == currentUser.uid);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsetsDirectional.only(start: 10),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
            const Spacer(),
            if (isOwnProfile && config.profileEditIcon.isNotEmpty)
              _buildTopIcon(config.profileEditIcon, () {
                // TODO: Edit Profile
              }),
            if (isOwnProfile && config.profileSettingsIcon.isNotEmpty)
              _buildTopIcon(config.profileSettingsIcon, () {
                // TODO: Settings
              }),
            if (config.profileShareIcon.isNotEmpty)
              _buildTopIcon(config.profileShareIcon, () {
                // TODO: Share Profile
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(DynamicConfigService config, UserModel? user) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    final isOwnProfile = widget.targetUid == null || (currentUser != null && widget.targetUid == currentUser.uid);
    final hasCp = _cpCouple != null;
    final svgaBg = config.profileBgSvga;
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          // Banner image - matching XML aspect ratio 1.11
          GestureDetector(
            onTap: isOwnProfile ? _pickCoverImage : null,
            child: AspectRatio(
              aspectRatio: 1.11,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // SVGA animated background (replaces blurry image)
                    if (svgaBg.isNotEmpty)
                      Positioned.fill(
                        child: SvgaPlayer(
                          assetPath: svgaBg,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: (_profileBgUrl == null || _profileBgUrl!.isEmpty) && config.profileBgType == 'solid'
                              ? config.profileSolidColor
                              : null,
                          gradient: (_profileBgUrl == null || _profileBgUrl!.isEmpty) && config.profileBgType == 'gradient'
                              ? LinearGradient(
                                  colors: config.profileGradientColors,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                          image: (_profileBgUrl != null && _profileBgUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: cachedImgProvider(_profileBgUrl!),
                                  fit: BoxFit.cover,
                                )
                              : ((config.profileBgType == 'image' && config.customProfileBgImage.isNotEmpty)
                                  ? DecorationImage(
                                      image: cachedImgProvider(config.customProfileBgImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                        ),
                      ),
                    if (isOwnProfile) ...[
                      // Camera badge
                      Positioned(
                        bottom: 12, right: 12,
                        child: GestureDetector(
                          onTap: _pickCoverImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      // Cover menu
                      Positioned(
                        top: 12, left: 12,
                        child: GestureDetector(
                          onTap: () => _showCoverMenu(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Gradient overlay matching XML gradientView + bv
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Container(
                  height: 42,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
          // Avatar section - matching XML ConstraintLayout with avatars
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 104,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main avatar
                  Positioned(
                    left: 12,
                    child: GestureDetector(
                      onTap: () {
                        if (user?.photoUrl != null && user!.photoUrl.isNotEmpty) {
                          _showImageFullScreen(user.photoUrl);
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: (user?.photoUrl != null && user!.photoUrl.isNotEmpty)
                                      ? cachedImgProvider(user.photoUrl)
                                      : null,
                                  child: (user?.photoUrl == null || user!.photoUrl.isEmpty)
                                      ? Image.asset(R.avaBoy, fit: BoxFit.cover)
                                      : null,
                                ),
                              ),
                              if (_activeFrame != null || _ownedLevelFrames.isNotEmpty)
                                SvgaFrame(
                                  svgaPath: _activeFrame ?? (_ownedLevelFrames.isNotEmpty ? _ownedLevelFrames.last.toString() : ''),
                                  size: 100,
                                ),
                            ],
                          ),
                          // Online indicator - matching XML imgOnline position
                          Positioned(
                          bottom: 18,
                          right: 28,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                  // CP avatar - positioned overlapping main avatar (marginStart=-12dp)
                  if (hasCp)
                    Positioned(
                      left: 104 - 12,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: (_cpPartner?['avatar'] as String?) != null
                                    ? cachedImgProvider(_cpPartner!['avatar'] as String)
                                    : null,
                                child: const Icon(Icons.person, size: 40, color: Colors.white70),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // CP heart icon between avatars
                  if (hasCp)
                    Positioned(
                      left: 104 - 12,
                      top: 32,
                      child: Image.asset(
                        config.cpProfileHeartIcon,
                        width: 32,
                        height: 32,
                      ),
                    ),
                                    // Join Room Animated Button
                  if (_currentRoomId != null)
                    Positioned(
                      right: 70,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _navigateToRoom,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black26,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ''.isEmpty
                                ? const Icon(Icons.meeting_room, color: Colors.white)
                                : (''.toLowerCase().endsWith('.svga')
                                    ? SvgaPlayer(assetPath: '')
                                    : CachedNetworkImage(
                                        imageUrl: '',
                                        fit: BoxFit.contain,
                                      )),
                            ),
                          ],
                        ),
                      ),
                    ),
// Like button - only for other users' profiles
                  if (!isOwnProfile)
                    Positioned(
                      right: 20,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0x99000000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_border,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoPanel(DynamicConfigService config, UserModel? user) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name row - matching XML: userNameTv1 + userCountryFlag + unionBadge
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 3, start: 12),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    user?.name ?? 'اسم المستخدم',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Country flag placeholder
                Container(
                  width: 24,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white70.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 1),
                // Union badge placeholder
                if (user?.hostedRoomId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: config.buttonColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Room',
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
          // Sex/Age view + Level badges row
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 10, start: 12),
            child: Row(
              children: [
                // Sex/Age pill - matching layout_sex_age_v2.xml
                Container(
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: user?.gender == 'female'
                        ? const Color(0xFFf3517c)
                        : const Color(0xFF4690f2),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user?.gender == 'female' ? Icons.female : Icons.male,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${user?.age ?? 18}',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                if (config.profileShowLevel) ...[
                  // Level badges
                  _buildLevelBadgeSmall(user?.wealthLevel ?? 1, 'wealth'),
                  const SizedBox(width: 3),
                  _buildLevelBadgeSmall(user?.rechargeLevel ?? 1, 'recharge'),
                  const SizedBox(width: 3),
                  _buildLevelBadgeSmall(user?.gemsLevel ?? 1, 'gems'),
                ],
              ],
            ),
          ),
          if (config.profileShowId)
            // ID row - matching XML llID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'ID: ${(user?.customId ?? '').isNotEmpty ? user!.customId : ((1000000 + (user?.uid.hashCode.abs() ?? 0) % 9000000).toString())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                  const SizedBox(width: 5),
                  const Text('|', style: TextStyle(color: Color(0xFFbbbbbb), fontSize: 12)),
                  const SizedBox(width: 5),
                  const Icon(Icons.location_on, size: 12, color: Color(0xFF666666)),
                  const SizedBox(width: 3),
                  Text(
                    (user?.country != null && user!.country.isNotEmpty) ? user.country : 'مصر',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                  const SizedBox(width: 5),
                  const Text('|', style: TextStyle(color: Color(0xFFbbbbbb), fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    'منذ 5 ساعات',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          // Bio/Signature
          if (config.profileShowSignature)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                (user?.signature != null && user!.signature.isNotEmpty) ? user.signature : 'لم يضف توقيعاً بعد',
                style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(DynamicConfigService config, UserModel? user) {
    final stats = <_StatItemData>[
      _StatItemData('$_followingCount', 'Following'),
      _StatItemData('$_fansCount', 'Fans'),
      _StatItemData('$_visitorsCount', 'Visitors'),
      _StatItemData('${_receivedGifts.length}', 'Gifts'),
      _StatItemData('$_sentGiftsCount', 'Sent'),
    ];
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFDE880F).withValues(alpha: 0.1),
              const Color(0xFFF5F5F5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: AspectRatio(
          aspectRatio: 351 / 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: () {
              final items = <Widget>[];
              for (int i = 0; i < stats.length; i++) {
                items.add(_statItem(stats[i].count, stats[i].label));
                if (i < stats.length - 1) {
                  items.add(_dividerVertical());
                }
              }
              return items;
            }(),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String count, String label) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 15,
            fontWeight: FontWeight.bold,
               color: Colors.white,
             ),
           ),
           const SizedBox(height: 4),
           Text(
             label,
             style: TextStyle(
               fontSize: 11,
               color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerVertical() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildRoomCard(DynamicConfigService config, UserModel? user) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.meeting_room, color: Colors.white54, size: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _currentRoomId ?? 'الغرفة',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _navigateToRoom,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6de5ff)),
                ),
                child: const Text(
                  'دخول',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6de5ff)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFansPodium(DynamicConfigService config, UserModel? user) {
    if (_topMonthlyFans.isEmpty) return const SizedBox.shrink();

    // Pad with empty entries if less than 3
    final fans = List<Map<String, dynamic>>.from(_topMonthlyFans);
    while (fans.length < 3) {
      fans.add({});
    }

    final top1 = fans[0];
    final top2 = fans[1];
    final top3 = fans[2];

    Widget buildAvatar(Map<String, dynamic> fan, double size, double bottomPad) {
      final url = fan['user_photo_url']?.toString() ?? '';
      final name = fan['user_name']?.toString() ?? '';
      final isEmpty = url.isEmpty && name.isEmpty;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2),
                color: Colors.grey[300],
              ),
              child: isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : ClipOval(child: CachedImg(url, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 4),
            if (!isEmpty)
              SizedBox(
                width: size * 1.5,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Top Fans (This Month)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            height: 150,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Podium image
                Positioned(
                  bottom: 0,
                  child: Image.asset('assets/images/podium.png', width: 280, fit: BoxFit.contain),
                ),
                // Top 2 (Left)
                Positioned(
                  left: 30,
                  bottom: 50,
                  child: buildAvatar(top2, 45, 10),
                ),
                // Top 1 (Center)
                Positioned(
                  left: 0, right: 0,
                  bottom: 75,
                  child: buildAvatar(top1, 55, 15),
                ),
                // Top 3 (Right)
                Positioned(
                  right: 30,
                  bottom: 40,
                  child: buildAvatar(top3, 45, 5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String getCpLevelFromGifts(int totalGifts) {
    if (totalGifts >= 1000000) return 'cp3';
    if (totalGifts >= 500000) return 'cp2';
    if (totalGifts >= 1) return 'cp1';
    if (_cpCouple != null) return 'cp1';
    return 'cp1'; // Always show cp1 even without CP data
  }

  Widget _buildCpPanelSection(DynamicConfigService cfg, UserModel? user) {
    final userName = user?.name ?? '';
    final userPhoto = user?.photoUrl ?? '';
    final partnerName = _cpPartner?['name'] as String? ?? '';
    final partnerAvatar = _cpPartner?['avatar'] as String? ?? '';
    final daysTogether = (_cpCouple?['days_together'] as num?)?.toInt() ?? 0;
    final hasCp = _cpCouple != null;
    final cpLevel = _getCpLevelFromGifts(_cpGiftTotal);
    final hasLevel = cpLevel != 'none';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 310,
            child: Column(
              children: [
                if (hasCp && hasLevel) ...[
                  Image.asset(cfg.cpProfileLevelBg,
                      width: 123, height: 19),
                  const SizedBox(height: 4),
                  Text('Lv.$cpLevel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: [cfg.cpProfileLevelGradientStart, cfg.cpProfileLevelGradientEnd],
                          ).createShader(Rect.fromLTWH(0, 0, 60, 16)),
                      )),
                  const SizedBox(height: 8),
                ],
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CPDetailFullScreen()),
                    );
                  },
                  child: SizedBox(
                    height: 170,
                    child: hasLevel
                        ? SvgaPlayer(
                            assetPath: 'assets/svga/$cpLevel.svga',
                            width: 360,
                            height: 170,
                            fit: BoxFit.contain,
                            imageReplacement: {
                              'avatar1': userPhoto.isNotEmpty ? userPhoto : '',
                              if (partnerAvatar.isNotEmpty) 'avatar2': partnerAvatar,
                            },
                            defaultImageUrl: hasCp ? '' : null,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _cpNameBadge(cfg, userName),
                  const SizedBox(width: 20),
                  _cpNameBadge(cfg, hasCp ? partnerName : '....'),
                ],
              ),
              if (hasCp)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: cfg.cpProfileDaysBadgeBg,
                      borderRadius: BorderRadius.circular(55),
                      border: Border.all(
                          color: cfg.cpProfileDaysBadgeBorder, width: 0.5),
                    ),
                    child: Text(
                      'معاً منذ $daysTogether يوم',
                      style: TextStyle(
                          color: cfg.cpProfileDaysTogetherText, fontSize: 10),
                    ),
                  ),
                ),
              if (hasCp)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: cfg.cpProfileDaysBadgeBg2,
                      borderRadius: BorderRadius.circular(29),
                      border: Border.all(
                          color: cfg.cpProfileDaysBadgeBorder2, width: 0.5),
                    ),
                    child: Text(
                      '$daysTogether يوم',
                      style: TextStyle(
                          color: cfg.cpProfileDaysText, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cpNameBadge(DynamicConfigService cfg, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(cfg.cpProfileNameFrame),
          fit: BoxFit.fill,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(color: cfg.cpHeaderText, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMomentsSection(DynamicConfigService config, UserModel? user) {
    final momentsList = _allOwnedNecklaces.take(4).toList();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'اللحظات',
                   style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Color(0xFF555555), size: 20),
              ],
            ),
            if (momentsList.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: momentsList.map((m) {
                    final svga = m['svga_url']?.toString();
                    final img = m['image_url']?.toString();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: svga != null && svga.isNotEmpty
                            ? SvgaPlayer(assetPath: svga, width: 50, height: 50)
                            : (img != null && img.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                  child: CachedImg(img, fit: BoxFit.contain),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8E8E8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.music_note, color: Colors.white70),
                                )),
                        ),
                      );
                    }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGiftWallSection(DynamicConfigService config, UserModel? user) {

    return Container(
      width: double.infinity,
      color: const Color(0xffffffff),
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text(
                  'جدار الهدايا',
                   style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Color(0xFF555555), size: 20),
              ],
            ),
          ),
          if (_receivedGifts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا توجد هدايا بعد',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
            )
          else
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _receivedGifts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final g = _receivedGifts[index];
                  final giftDef = _giftsCatalog[g.giftId];
                  final isCpGift = giftDef?.isCpGift ?? false;
                  final cpDays = isCpGift ? (giftDef?.cpGiftDurationHours ?? 0) ~/ 24 : 0;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGift = g),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.transparent, // Removed background square
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: giftDef?.iconAsset != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: detectAssetType(giftDef!.iconAsset) == AssetType.svga
                                          ? SvgaPlayer(
                                              assetPath: giftDef!.iconAsset,
                                              width: 54,
                                              height: 54,
                                            )
                                          : CachedImg(
                                              giftDef!.iconAsset,
                                              fit: BoxFit.contain,
                                              error: (_, __, ___) =>
                                                  const Icon(Icons.card_giftcard, size: 24, color: Colors.white70),
                                            ),
                                    )
                                  : const Icon(Icons.card_giftcard, size: 24, color: Colors.white70),
                            ),
                            // Gift count badge
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('x${g.count}',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            if (isCpGift && cpDays > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: config.cpGold,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.music_note, size: 8, color: Colors.white),
                                      const SizedBox(width: 1),
                                      Text('$cpDays',
                                          style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 54,
                          child: Text(
                            g.giftName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedalWallSection(DynamicConfigService config, UserModel? user) {
    final necklaces = _allOwnedNecklaces.take(8).toList();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text(
                  'المدليات',
                   style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                const Spacer(),
              ],
            ),
          ),
          necklaces.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Image.asset('assets/cp/ic_add_cp.webp', width: 52, height: 52,
                        errorBuilder: (_, __, ___) => Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E8E8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.card_giftcard, color: Colors.white70, size: 24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'لا توجد مدليات',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    children: necklaces.map((n) {
                      final svga = n['svga_url']?.toString();
                      final img = n['image_url']?.toString();
                      final name = n['name']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _showNecklaceDetail(n),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: svga != null && svga.isNotEmpty
                                    ? SvgaPlayer(assetPath: svga, width: 52, height: 52)
                                    : (img != null && img.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: CachedImg(img, fit: BoxFit.contain,
                                              error: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.white70)),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8E8E8),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(Icons.card_giftcard, color: Colors.white70, size: 24),
                                          )),
                              ),
                              if (name.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: SizedBox(
                                    width: 52,
                                    child: Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 8, color: Colors.white70),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEntrancesSection(DynamicConfigService config, UserModel? user) {
    final entrances = _allOwnedEntrances.take(8).toList();
    if (entrances.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('الدخوليات', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: entrances.map((n) {
                final svga = n['svga_url']?.toString();
                final img = n['image_url']?.toString();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: svga != null && svga.isNotEmpty
                        ? SvgaPlayer(assetPath: svga, width: 52, height: 52)
                        : (img != null && img.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedImg(img, fit: BoxFit.contain),
                              )
                            : Container(
                                decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(6)),
                                child: Icon(Icons.card_giftcard, color: Colors.white70, size: 24),
                              )),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFramesSection(DynamicConfigService config, UserModel? user) {
    final frames = _allOwnedFrames.take(8).toList();
    if (frames.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('الإطارات', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: frames.map((n) {
                final svga = n['svga_url']?.toString();
                final img = n['image_url']?.toString();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: svga != null && svga.isNotEmpty
                        ? SvgaPlayer(assetPath: svga, width: 52, height: 52)
                        : (img != null && img.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedImg(img, fit: BoxFit.contain),
                              )
                            : Container(
                                decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(6)),
                                child: Icon(Icons.card_giftcard, color: Colors.white70, size: 24),
                              )),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(DynamicConfigService config, UserModel? user) {
    final ownedBadgeIds = user?.ownedBadges ?? [];
    final levelBadgeUrls = user?.ownedLevelBadges ?? [];
    if (ownedBadgeIds.isEmpty && levelBadgeUrls.isEmpty) {
      return const SizedBox();
    }
    final badgeWidgets = <Widget>[];
    for (final id in ownedBadgeIds) {
      if (id.isEmpty) continue;
      if (id.startsWith('http://') || id.startsWith('https://') || id.startsWith('assets/')) {
        badgeWidgets.add(SvgaPlayer(assetPath: id, width: 40, height: 40));
        continue;
      }
      final match = _badgesCatalog.where((b) => b['id']?.toString() == id).toList();
      if (match.isNotEmpty) {
        final b = match.first;
        final svgaUrl = b['svga_url']?.toString();
        final imgUrl = b['image_url']?.toString();
        if (svgaUrl != null && svgaUrl.isNotEmpty) {
          badgeWidgets.add(SvgaPlayer(assetPath: svgaUrl, width: 40, height: 40));
        } else if (imgUrl != null && imgUrl.isNotEmpty) {
          badgeWidgets.add(CachedImg(imgUrl, width: 40, height: 40, fit: BoxFit.contain));
        }
      }
    }
    for (final url in levelBadgeUrls) {
      if (detectAssetType(url) == AssetType.svga) {
        badgeWidgets.add(SvgaPlayer(assetPath: url, width: 40, height: 40));
      } else {
        badgeWidgets.add(
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedImg(url, width: 40, height: 40, fit: BoxFit.contain,
                error: (_, __, ___) => const SizedBox()),
          ),
        );
      }
    }
    if (badgeWidgets.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text(
                  'الشارات',
                   style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                const Spacer(),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: badgeWidgets.map((w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: w,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DynamicConfigService config, UserModel? user) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    // Own profile -> show Edit button
    if (widget.targetUid == null || (currentUser != null && widget.targetUid == currentUser.uid)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditProfileScreenPlaceholder(),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFF6de5ff)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit, size: 20, color: Color(0xFF6de5ff)),
                const SizedBox(width: 10),
                const Text(
                  'تعديل الملف الشخصي',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6de5ff)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Other user -> Show Follow + Message buttons
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Follow button
          Expanded(
            child: GestureDetector(
              onTap: _toggleFollow,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isFollowing ? const Color(0xFFE53935).withOpacity(0.15) : const Color(0xFF6de5ff).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _isFollowing ? const Color(0xFFE53935) : const Color(0xFF6de5ff),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isFollowing ? Icons.favorite : Icons.favorite_border,
                      size: 22,
                      color: _isFollowing ? const Color(0xFFE53935) : const Color(0xFF6de5ff),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isFollowing ? 'متابع' : 'متابعة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _isFollowing ? const Color(0xFFE53935) : const Color(0xFF6de5ff),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Message button
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isFollowing) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب متابعة المستخدم أولاً لإرسال رسالة'),
                      backgroundColor: Color(0xFFE53935),
                    ),
                  );
                  return;
                }
                _navigateToChat();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isFollowing ? const Color(0xFF6de5ff).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _isFollowing ? const Color(0xFF6de5ff) : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: _isFollowing ? const Color(0xFF6de5ff) : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'رسالة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _isFollowing ? const Color(0xFF6de5ff) : Colors.white38,
                      ),
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

  Widget _buildLevelBadgeSmall(int level, String type) {
    final lvlConfig = LevelService().getLevelConfig(type, level);
    final url = lvlConfig?.imageUrl;
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: R.loadAsset(url, width: 20, height: 20),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        gradient: AppColors.giftBtnGradient,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Lv.$level',
        style: const TextStyle(fontSize: 8, color: Colors.white),
      ),
    );
  }

  Widget _buildGiftOverlay(DynamicConfigService config) {
    final g = _selectedGift!;
    final giftDef = _giftsCatalog[g.giftId];
    final isCpGift = giftDef?.isCpGift ?? false;
    final cpDays = isCpGift ? (giftDef?.cpGiftDurationHours ?? 0) ~/ 24 : 0;
    return GestureDetector(
      onTap: () => setState(() => _selectedGift = null),
      child: Container(
        color: Colors.white.withValues(alpha: 0.7),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (g.giftName.isNotEmpty)
                    Text(g.giftName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (isCpGift && cpDays > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: config.cpGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.music_note, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('هدية CP - $cpDays يوم',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white70.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _giftsCatalog[g.giftId]?.iconAsset != null
                          ? CachedImg(_giftsCatalog[g.giftId]!.iconAsset,
                              fit: BoxFit.contain,
                              error: (_, __, ___) =>
                                  Icon(Icons.card_giftcard, size: 40, color: config.goldColor))
                          : Icon(Icons.card_giftcard, size: 40, color: config.goldColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Value: ${g.value} x ${g.count}',
                      style: TextStyle(fontSize: 12, color: config.textSecondary)),
                  const SizedBox(height: 4),
                  Text('From: ${g.senderName}',
                      style: TextStyle(fontSize: 12, color: config.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemOverlay(DynamicConfigService config) {
    final item = _selectedItem!;
    final isSvga = item.svgaAsset != null;
    final assetUrl = item.svgaAsset ?? item.itemIcon;
    return GestureDetector(
      onTap: () => setState(() => _selectedItem = null),
      child: Container(
        color: Colors.white.withValues(alpha: 0.7),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.itemName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: isSvga
                        ? SvgaPlayer(assetPath: assetUrl, width: 100, height: 100, loops: true)
                        : (assetUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedImg(assetUrl, fit: BoxFit.contain),
                              )
                            : Icon(Icons.card_giftcard, size: 50, color: config.goldColor)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItemData {
  final String count;
  final String label;
  const _StatItemData(this.count, this.label);
}

class EditProfileScreenPlaceholder extends StatelessWidget {
  const EditProfileScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
      body: const Center(child: Text('شاشة تعديل الملف الشخصي')),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String targetUid;
  final String targetName;
  final String? targetPhotoUrl;

  const ChatScreen({
    super.key,
    required this.targetUid,
    required this.targetName,
    this.targetPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseService _firebaseService = SupabaseService();
  List<MessageModel> _messages = [];
  bool _sendingImage = false;
  StreamSubscription? _messagesSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConversation());
  }

  Future<void> _initConversation() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null) return;
    final sorted = [user.uid, widget.targetUid]..sort();
    final convId = '${sorted[0]}_${sorted[1]}';
    _messagesSub = _firebaseService.privateMessagesStream(convId).listen((msgs) {
      if (mounted) {
        setState(() => _messages = msgs);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });
    _firebaseService.markConversationRead(user.uid, convId);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null) return;

    try {
      await _firebaseService.sendPrivateMessage(
        senderId: user.uid,
        senderName: user.name,
        senderPhotoUrl: user.photoUrl,
        receiverId: widget.targetUid,
        receiverName: widget.targetName,
        receiverPhotoUrl: widget.targetPhotoUrl ?? '',
        text: text,
      );
    } catch (e) {
      debugPrint('sendPrivateMessage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _sendingImage = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      if (user == null) return;

      final imageUrl = await CloudinaryService().uploadImage(
        File(image.path),
        publicId: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      );

      await _firebaseService.sendPrivateMessage(
        senderId: user.uid,
        senderName: user.name,
        senderPhotoUrl: user.photoUrl,
        receiverId: widget.targetUid,
        receiverName: widget.targetName,
        receiverPhotoUrl: widget.targetPhotoUrl ?? '',
        text: '',
        imageUrl: imageUrl,
        type: 'image',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgImg = DynamicConfigService().chatBackgroundImage;
    return Container(
      decoration: BoxDecoration(
        color: DynamicConfigService().chatBackgroundColor,
        image: bgImg.isNotEmpty
            ? DecorationImage(
                image: R.cachedImage(bgImg),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: R.image(R.backIc, width: 24, height: 24),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.targetPhotoUrl != null && widget.targetPhotoUrl!.isNotEmpty
                  ? cachedImgProvider(widget.targetPhotoUrl!)
                  : null,
              child: widget.targetPhotoUrl == null || widget.targetPhotoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.targetName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16151A),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Color(0xFF9BA1B6)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      final isMe = msg.senderUid == userProvider.currentUser?.uid;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),
          if (_sendingImage)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          _buildInputBar(),
        ],
      ),
    ),
  );
}

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  msg.senderName,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9BA1B6)),
                ),
              ),
            if (msg.type == 'image' && msg.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => _showImagePreview(msg.imageUrl!),
                    child: CachedImg(
                      msg.imageUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      error: (_, __, ___) => Container(
                        width: 200,
                        height: 200,
                        color: Colors.white54,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe
                      ? DynamicConfigService().chatBubbleSelfBg
                      : DynamicConfigService().chatBubbleOtherBg,
                  borderRadius: BorderRadius.circular(12).copyWith(
                    bottomRight: isMe ? const Radius.circular(0) : null,
                    bottomLeft: !isMe ? const Radius.circular(0) : null,
                  ),
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe
                        ? Colors.white
                        : DynamicConfigService().chatTextColor,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatTime(msg.timestamp),
                style: const TextStyle(fontSize: 10, color: Color(0xFF9BA1B6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5FC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.image, size: 20, color: Color(0xFF9BA1B6)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5FC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _msgController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E90FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.send, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: CachedImg(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}








