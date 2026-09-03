import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/nine_patch_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/r.dart';
import '../../config/app_colors.dart';
import '../../models/room_model.dart';
import '../../models/message_model.dart';
import '../message/message_screen.dart';
import '../../models/user_model.dart' as app;
import '../../models/gift_model.dart' as gm;
import '../../models/gift_banner_config_model.dart';
import '../../models/store_item_model.dart';
import '../../services/supabase_service.dart';
import '../../services/media_prefetch_service.dart';
import '../../services/dynamic_config_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/room_audio_service.dart';
import '../../services/room_state_service.dart';
import 'package:uuid/uuid.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../core/supabase_compat.dart';
import '../../providers/user_provider.dart';
import 'models/seat_model.dart' hide SeatStyle;
import 'models/seat_model.dart' as seat_model;
import 'room_settings_screen.dart';
import 'widgets/room_header.dart';
import 'widgets/seat_area.dart';
import 'widgets/room_rank_bottom_sheet.dart';

import 'widgets/room_background_bottom_sheet.dart';
import 'widgets/seat_dialogs.dart';
import 'widgets/seat_style_panel.dart';
import 'widgets/volume_panel.dart';
import 'widgets/mixer_panel.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/gift_panel.dart';
import 'widgets/user_profile.dart';
import 'widgets/function_panel.dart';
import 'widgets/svga_frame.dart';
import '../rank/rank_screen.dart';
import '../game/game_teaming_screen.dart';
import '../music/music_screen.dart';
import '../notifications/notifications_screen.dart';
import '../user_profile/user_profile_screen.dart';
import '../report/report_room_screen.dart';
import '../report/report_user_screen.dart';

/// Helper to navigate to a room, exiting any minimized room first
Future<void> navigateToRoom(
  BuildContext context, {
  required String roomName,
  required String hostName,
  required String roomId,
  String? hostUid,
  String roomPassword = '',
  String hotValue = '0',
  String gameDesc = '',
  bool replace = false,
}) async {
  // Double-tap guard: pushing two RoomScreens concurrently initializes the
  // audio engine twice and crashes natively (SIGSEGV in Zego engineInitJni).
  if (!RoomScreen.pushGuard(roomId)) return;
  final svc = MinimizedRoomService();
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  final uid = userProvider.currentUser?.uid;
  bool isReentry = false;
  if (svc.isActive) {
    if (svc.roomId == roomId) {
      // Same room – don't exit, mark as re-entry
      isReentry = true;
      svc.deactivate();
    } else {
      // Different room – exit the old one
      if (uid != null) svc.exitRoom(uid);
    }
  }

  if (roomPassword.isNotEmpty && hostUid != uid) {
    String inputPassword = '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF211211),
          title: const Text('كلمة المرور مطلوبة', style: TextStyle(color: Colors.white)),
          content: TextField(
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'أدخل كلمة مرور الغرفة',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD3A350))),
            ),
            onChanged: (v) => inputPassword = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                if (inputPassword == roomPassword) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور غير صحيحة')));
                }
              },
              child: const Text('دخول', style: TextStyle(color: Color(0xFFD3A350))),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
  }

  if (!context.mounted) return;
  final route = MaterialPageRoute(
    builder: (_) => RoomScreen(
      roomName: roomName,
      hostName: hostName,
      roomId: roomId,
      roomPassword: roomPassword,
      hotValue: hotValue,
      gameDesc: gameDesc,
      isReentry: isReentry,
    ),
  );
  if (replace) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}

// fragment_chat_room.xml
class RoomScreen extends StatefulWidget {
  static DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);
  static String? _lastPushRoomId;

  /// Returns true if this push is allowed (debounces double-taps on the same
  /// room within 800ms, which would stack two RoomScreens and double-init Zego).
  static bool pushGuard(String roomId) {
    final now = DateTime.now();
    final dup = identical(_lastPushRoomId, roomId) &&
        now.difference(_lastPushAt).inMilliseconds < 800;
    if (dup) return false;
    _lastPushAt = now;
    _lastPushRoomId = roomId;
    return true;
  }

  final String roomName;
  final String hostName;
  final String roomId;
  final String roomPassword;
  final String hotValue;
  final String gameDesc;
  final bool isReentry;

  const RoomScreen({
    super.key,
    required this.roomName,
    required this.hostName,
    required this.roomId,
    this.roomPassword = '',
    this.hotValue = '0',
    this.gameDesc = '',
    this.isReentry = false,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  // ── UI state ──────────────────────────────────────────────────
  bool _isMicOn = true;
  bool _showGift = false;
  bool _showGiftAnim = false;
  String? _giftAnimAsset;
  bool _showEntranceAnim = false;
  String? _entranceAnimAsset;

  // Dynamic SVGA data for entrance/car
  Map<String, String>? _entranceTextReplacement;
  Map<String, String>? _entranceImageReplacement;
  String? _entranceDefaultImage;

  // Dynamic SVGA data for entrance item (category 'entrance' above car)
  bool _showEntranceItemAnim = false;
  String? _entranceItemAnimAsset;
  Map<String, String>? _entranceItemTextReplacement;
  Map<String, String>? _entranceItemImageReplacement;
  String? _entranceItemDefaultImage;

  // Dynamic SVGA data for gift
  Map<String, String>? _giftTextReplacement;
  Map<String, String>? _giftImageReplacement;
  String? _giftDefaultImage;

  // Gift banner overlay state
  bool _showGiftBanner = false;
  String? _giftBannerAsset;
  String? _giftBannerSenderPhoto;
  String? _giftBannerReceiverPhoto;
  String? _giftBannerGiftImage;
  int _giftBannerCount = 1;
  String _giftBannerUserRKey = 'user_r';
  String _giftBannerUserLKey = 'user_l';
  String _giftBannerNumberKey = 'number';
  String _giftBannerGiftKey = 'gift';
  List<GiftBannerConfig> _bannerConfigs = [];

  // Cached gift definitions for looking up dynamic keys
  final Map<String, gm.GiftModel> _cachedGiftItems = {};
  bool _hasPlayedEntryAnimations = false;
  bool _showFunction = false;
  bool _showEmoj = false;
  bool _showChatInput = false;
  bool _showProfile = false;
  bool _showRoomInfo = false;
  bool _showExit = false;
  bool _showNotifications = false;
  bool _showShare = false;
  bool _isMinimized = false;
  bool _isFollowed = false;
  int _msgCount = 0;
  final List<MessageModel> _chatMessages = [];
  int _giftCount = 1;
  int _onlineCount = 0;

  final SupabaseService _firebaseService = SupabaseService();

  // Store items index for resolving frame/bubble/car assets
  Map<String, StoreItemModel> _storeItemsIndex = {};
  StreamSubscription? _storeSub;

  // Cache of user data for frame asset resolution
  final Map<String, app.UserModel> _cachedUsers = {};

  // currently selected seat index for profile/actions
  int? _selectedSeatIdx;
  UserModel? _selectedUser;

  final Map<int, String> _seatEmojis = {};
  bool _showCharmValues = true;
  // Track followed users
  final Set<String> _followedUsers = {};
  // Track blocked users
  final Set<String> _blockedUsers = {};

  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  DateTime? _joinedAt;

  // ── 20 seats: index 0 = owner, 1-19 = regular ─────────────────
  late List<SeatModel> _seats;

  // Current user is owner
  bool _isOwner = false;
  final Set<String> _moderators = {};
  String? _currentUserId;
  String? _currentUserName;
  bool get _isOwnerOrModerator => _isOwner || _moderators.contains(_currentUserId);
  seat_model.SeatStyle _roomSeatStyle = seat_model.SeatStyle.circle;

  // Current room data
  RoomModel? _currentRoom;

  // Track seen entrance message IDs to avoid replaying
  final Set<String> _seenEntranceIds = {};

  // Track total gifts received per seat user ID
  final Map<String?, int> _giftReceiverTotals = {};
  StreamSubscription? _giftSub;
  StreamSubscription? _seatsSub;
  StreamSubscription? _roomSub;
  StreamSubscription? _giftCacheSub;
  StreamSubscription? _bannerConfigSub;
  StreamSubscription? _msgSub;
  StreamSubscription? _entranceSub;
  Timer? _seatsRefreshTimer;
  final RoomAudioService _roomAudio = RoomAudioService();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _seats = _buildInitialSeats();
    _loadRoomData();
  }

  void _loadRoomData() {
    _joinedAt = DateTime.now();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      _currentUserName = currentUser.name;
      _isOwner = false;
      _isFollowed = currentUser.followedRooms.contains(widget.roomId);
      _checkRoomBan(currentUser.uid);
      // Clear any stale seats for this user before registering (await to avoid race)
      // Only on fresh joins – on minimized-room re-entry the current seat must survive.
      if (!widget.isReentry) {
        Future(() async {
          await Supabase.instance.client
              .from('room_seats')
              .delete()
              .eq('room_id', widget.roomId)
              .eq('uid', currentUser.uid);
        });
      }
      // Register in Firebase so others see this user
      _firebaseService.joinRoom(widget.roomId, currentUser);
      if (!widget.isReentry) {
        try {
          // Log entrance effect for other users to see
          _firebaseService.logEntrance(
            widget.roomId,
            currentUser.uid,
            currentUser.name,
            currentUser.photoUrl,
            currentUser.activeEntrance,
            carItem: currentUser.activeCar,
          );
        } catch (e) {
          debugPrint('logEntrance error: $e');
        }
      } else {
        _hasPlayedEntryAnimations = true;
      }
      // Load blocked users list
      _firebaseService.getBlockedUids(currentUser.uid).then((list) {
        if (mounted) setState(() { _blockedUsers.clear(); _blockedUsers.addAll(list); });
      });
    }
    // Initialize audio service (use customId for Zego, not real uid)
    final audioUid = (Provider.of<UserProvider>(context, listen: false).currentUser?.customId)
        ?? _currentUserId?.replaceAll('-', '').substring(0, 7) ?? '0';
    _roomAudio.initialize().then((ok) {
      if (ok) _roomAudio.joinChannel(widget.roomId, audioUid);
    });
    // Cache gift definitions for dynamic SVGA key lookup
    _giftCacheSub = _firebaseService.giftsStream().listen((gifts) {
      if (!mounted) return;
      for (final g in gifts) {
        _cachedGiftItems[g.id] = g;
      }
      MediaPrefetchService().prefetchGifts(gifts);
    });

    // Load gift banner configs
    _bannerConfigSub = _firebaseService.giftBannerConfigsStream().listen((configs) {
      if (mounted) {
        setState(() => _bannerConfigs = configs.where((c) => c.isActive).toList());
      }
      // Pre-cache the banner SVGA/VAP files so the first play is instant
      MediaPrefetchService()
          .prefetchUrls(configs.where((c) => c.isActive).map((c) => c.svgaUrl));
    });

    _roomSub = _firebaseService.roomStream(widget.roomId).listen((room) {
      if (room != null && mounted) {
        setState(() {
          _currentRoom = room;
          _isOwner = _currentUserId == room.hostUid;
          _onlineCount = room.memberCount;
          _moderators
            ..clear()
            ..addAll(room.moderators);
          if (room.seatCount != _seats.length) {
            _seats = List.generate(room.seatCount, (i) => SeatModel(index: i));
          }
          _roomSeatStyle = room.seatStyle;
        });
      }
    });
    final joinedMs = _joinedAt?.millisecondsSinceEpoch ?? 0;
    _msgSub = _firebaseService.messagesStream(widget.roomId).listen((msgs) {
      if (mounted) {
        final clearedAt = _currentRoom?.chatClearedAt ?? 0;
        final filterTime = max(joinedMs, clearedAt);
        setState(() {
          _chatMessages
            ..clear()
            ..addAll(msgs.where((m) => m.timestamp >= filterTime));
          _msgCount = _chatMessages.length;
        });
        if (_chatScroll.hasClients) {
          _chatScroll.animateTo(
            _chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      }
    });
    // Track gifts to update seat charm values
    final seenGiftIds = <String>{};
    bool _giftStreamInitial = true;
    _giftSub = _firebaseService.sentGiftsStream(widget.roomId).listen((gifts) {
      final totals = <String?, int>{};
      gm.SentGiftModel? latestNewGift;
      for (final g in gifts) {
        totals[g.receiverId] = (totals[g.receiverId] ?? 0) + g.totalValue.toInt();
        if (!seenGiftIds.contains(g.id)) {
          seenGiftIds.add(g.id);
          if (!_giftStreamInitial) latestNewGift = g;
        }
      }
      _giftStreamInitial = false;
      // Show gift animation for the newest unseen gift
      if (latestNewGift != null && latestNewGift.animationAsset != null && latestNewGift.animationAsset!.isNotEmpty) {
        final latest = latestNewGift;
        final giftDef = _cachedGiftItems[latest.giftId];
        final nameKey = giftDef?.nameKey;
        final photoKey = giftDef?.photoKey;
        final defaultImage = giftDef?.defaultImage;
        final textReplacement = nameKey != null && nameKey.isNotEmpty && latest.senderName.isNotEmpty
            ? <String, String>{nameKey: latest.senderName}
            : null;
        final imageReplacement = photoKey != null && photoKey.isNotEmpty && latest.senderPhotoUrl != null && latest.senderPhotoUrl!.isNotEmpty
            ? <String, String>{photoKey: latest.senderPhotoUrl!}
            : null;
        if (mounted) setState(() {
          _giftAnimAsset = latest.animationAsset;
          _showGiftAnim = true;
          _giftTextReplacement = textReplacement;
          _giftImageReplacement = imageReplacement;
          _giftDefaultImage = defaultImage;
        });
      }
      // Show gift banner strip for ALL users (not just sender), regardless of animation
      if (latestNewGift != null && mounted) {
        final giftDef = _cachedGiftItems[latestNewGift.giftId];
        _checkGiftBanner({
          'giftValue': latestNewGift.value,
          'giftCount': latestNewGift.count,
          'categoryId': giftDef?.categoryId,
          'senderPhotoUrl': latestNewGift.senderPhotoUrl,
          'defaultImage': giftDef?.defaultImage,
          'receiverId': latestNewGift.receiverId,
        });
      }
      // Update charm totals for all seats
      if (mounted) {
        setState(() {
          _giftReceiverTotals.clear();
          _giftReceiverTotals.addAll(totals);
          // Update seat charm values
          for (final seat in _seats) {
            if (seat.user != null && _giftReceiverTotals.containsKey(seat.user!.id)) {
              seat.user = seat.user!.copyWith(
                giftCount: _giftReceiverTotals[seat.user!.id]!,
                totalGiftsReceived: _giftReceiverTotals[seat.user!.id]!,
                charm: _giftReceiverTotals[seat.user!.id].toString(),
              );
            }
          }
        });
      }
    });
    // Sync seats from Firebase in real time
    _seatsSub = _firebaseService.seatsStream(widget.roomId).listen((seatMap) {
      _processSeatMap(seatMap);
    });

    // Periodic refresh as fallback in case Realtime misses updates
    _seatsRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      try {
        final list = await Supabase.instance.client
            .from('room_seats')
            .select()
            .eq('room_id', widget.roomId);
        final seatMap = <int, Map<String, dynamic>>{};
        for (final e in list) {
          seatMap[(e['seat_index'] as int?) ?? 0] = Map<String, dynamic>.from(e);
        }
        if (!mounted) return;
        _processSeatMap(seatMap);
      } catch (_) {}
    });

    // Buffer for entrance animations that arrive before store items are loaded
    final _pendingEntrances = <Map<String, dynamic>>[];

    // Index store items for resolving frame/bubble/entrance assets
    _storeSub = _firebaseService.storeItemsStream().listen((items) {
      final index = <String, StoreItemModel>{};
      for (final item in items) {
        index[item.itemId] = item;
      }
      _storeItemsIndex = index;
      // Re-derive assets for all occupied seats (live updates from dashboard)
      for (int i = 0; i < _seats.length; i++) {
        final seat = _seats[i];
        if (seat.state == SeatState.occupied && seat.user?.id != null) {
          final cachedUser = _cachedUsers[seat.user!.id!];
          if (cachedUser != null) {
            final af = cachedUser.activeFrame;
            final isFrameUrl = af != null && af.startsWith('http');
            final frameAsset = isFrameUrl ? af : index[af]?.svgaAsset;
            final carVal = cachedUser.activeCar;
            final carStoreItem = carVal != null && !carVal.startsWith('http')
                ? index[carVal]
                : null;
            final carAsset = carVal != null && carVal.startsWith('http')
                ? carVal
                : carStoreItem?.svgaAsset;
            _seats[i] = seat.copyWith(
              frameAsset: frameAsset,
              carAsset: carAsset,
            );
          }
        }
      }
      // Resolve & play entry animations (car + entrance item)
      if (!_hasPlayedEntryAnimations && _currentUserId != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final u = userProvider.currentUser;
        if (u != null) {
          bool playedAny = false;
          // Car SVGA
          if (u.activeCar != null) {
            final carValue = u.activeCar!;
            final carItem = carValue.startsWith('http') ? null : index[carValue];
            // Support raw URL fallback for VIP-purchased car assets
            final carAssetUrl = carItem != null && carItem.animationUrl != null
                ? carItem.animationUrl
                : (carValue.startsWith('http') ? carValue : null);
            if (carAssetUrl != null) {
              playedAny = true;
              final nameKey = carItem?.nameKey;
              final photoKey = carItem?.photoKey;
              final textReplacement = nameKey != null && nameKey.isNotEmpty
                  ? <String, String>{nameKey: u.name}
                  : null;
              final imageReplacement = photoKey != null && photoKey.isNotEmpty && u.photoUrl.isNotEmpty
                  ? <String, String>{photoKey: u.photoUrl}
                  : null;
              setState(() {
                _entranceAnimAsset = carAssetUrl;
                _showEntranceAnim = true;
                _entranceTextReplacement = textReplacement;
                _entranceImageReplacement = imageReplacement;
                _entranceDefaultImage = carItem?.defaultImage;
              });
            }
          }
          // Entrance item (category 'entrance') – plays above the car
          if (u.activeEntrance != null) {
            final entValue = u.activeEntrance!;
            final entranceItem = entValue.startsWith('http') ? null : index[entValue];
            final entranceAssetUrl = entranceItem != null && entranceItem.animationUrl != null
                ? entranceItem.animationUrl
                : (entValue.startsWith('http') ? entValue : null);
            if (entranceAssetUrl != null) {
              playedAny = true;
              final nameKey = entranceItem?.nameKey;
              final photoKey = entranceItem?.photoKey;
              final textReplacement = nameKey != null && nameKey.isNotEmpty
                  ? <String, String>{nameKey: u.name}
                  : null;
              final imageReplacement = photoKey != null && photoKey.isNotEmpty && u.photoUrl.isNotEmpty
                  ? <String, String>{photoKey: u.photoUrl}
                  : null;
              setState(() {
                _entranceItemAnimAsset = entranceAssetUrl;
                _showEntranceItemAnim = true;
                _entranceItemTextReplacement = textReplacement;
                _entranceItemImageReplacement = imageReplacement;
                _entranceItemDefaultImage = entranceItem?.defaultImage;
              });
            }
          }
          if (playedAny) _hasPlayedEntryAnimations = true;
        }
      }
      // Process any entrance animations that were buffered while store items were loading
      if (_pendingEntrances.isNotEmpty) {
        for (final entry in _pendingEntrances) {
          final uid = entry['uid']?.toString();
          final entranceItemId = entry['entranceItem']?.toString();
          if (entranceItemId != null) {
            final storeItem = index[entranceItemId];
            if (storeItem?.animationUrl != null) {
              _playEntranceEffect(entry, storeItem!, uid);
            }
          }
        }
        _pendingEntrances.clear();
      }
      if (mounted) setState(() {});
    });

    // Listen for other users' entrance/car effects
    _entranceSub = _firebaseService.entrancesStream(widget.roomId).listen((entrances) {
      if (!mounted || entrances.isEmpty) return;
      final joinedMs = _joinedAt?.millisecondsSinceEpoch ?? 0;
      for (final entry in entrances) {
        final uid = entry['uid']?.toString();
        if (uid == null || uid == _currentUserId) continue;
        final entranceItemId = entry['entranceItem']?.toString() ?? '';
        if (entranceItemId.isEmpty) continue;
        final entryTs = entry['timestamp']?.toString() ?? '';
        final entryMs = DateTime.tryParse(entryTs)?.millisecondsSinceEpoch ?? 0;
        if (entryMs < joinedMs) continue;
        final entranceKey = '${uid}_$entranceItemId';
        if (_seenEntranceIds.contains(entranceKey)) continue;
        _seenEntranceIds.add(entranceKey);
        final storeItem = _storeItemsIndex[entranceItemId];
        if (storeItem == null || storeItem.animationUrl == null) {
          if (_storeItemsIndex.isEmpty) {
            _pendingEntrances.add(entry);
            continue;
          }
          // Fallback: raw URL entrance (VIP-purchased) -> play directly
          final rawUrl = entranceItemId.startsWith('http') ? entranceItemId : null;
          if (rawUrl == null) continue;
          _playEntranceEffectRaw(entry, rawUrl);
          continue;
        }
        _playEntranceEffect(entry, storeItem, uid);
      }
    });
  }

  void _clearMessages() {
    // Persist a chat_cleared_at stamp so every user's stream filter hides old messages
    final now = DateTime.now().millisecondsSinceEpoch;
    _firebaseService.updateRoom(widget.roomId, {'chat_cleared_at': now});
    setState(() {
      _chatMessages.clear();
    });
  }

  seat_model.SeatModel? get _currentUserSeat {
    if (_currentUserId == null) return null;
    for (final seat in _seats) {
      if (seat.user?.id == _currentUserId) return seat;
    }
    return null;
  }

  void _processSeatMap(Map<int, Map<String, dynamic>> seatMap) {
    if (!mounted) return;
    // Preserve locked state before reset
    final lockedIndices = <int>{};
    for (int i = 0; i < _seats.length; i++) {
      if (_seats[i].isLocked) lockedIndices.add(i);
    }
    // Reset ALL seats to empty first to clear vacated seats
    for (int i = 0; i < _seats.length; i++) {
      _seats[i] = SeatModel(index: i);
    }
    // Restore locked seats
    for (final i in lockedIndices) {
      _seats[i] = SeatModel(index: i, state: SeatState.locked, isLocked: true);
    }
    // Apply seatMap data from Firebase
    bool isCurrentUserOnSeatNow = false;
    bool currentUserMuted = false;
    for (final entry in seatMap.entries) {
      final idx = entry.key;
      if (idx < 0 || idx >= _seats.length) continue;
      final data = entry.value;
      final uid = data['uid']?.toString();
      if (uid != null) {
        if (uid == _currentUserId) {
          isCurrentUserOnSeatNow = true;
          currentUserMuted = data['is_muted'] == true;
        }
        // Fetch full user data for frame asset resolution
        if (!_cachedUsers.containsKey(uid)) {
          _firebaseService.getUser(uid).then((user) {
            if (user != null && mounted) {
              setState(() {
                _cachedUsers[uid] = user;
                _processSeatMap(seatMap);
              });
            }
          });
        }
        final cachedUser = _cachedUsers[uid];
        final activeFrame = data['active_frame']?.toString() ?? cachedUser?.activeFrame;
        final isFrameUrl = activeFrame != null && activeFrame.startsWith('http');
        final frameAsset = isFrameUrl ? activeFrame! : _storeItemsIndex[activeFrame]?.svgaAsset;
        final activeCar = data['active_car']?.toString() ?? cachedUser?.activeCar;
        final carStoreItem = activeCar != null && !activeCar.startsWith('http')
            ? _storeItemsIndex[activeCar]
            : null;
        final carAsset = activeCar != null && activeCar.startsWith('http')
            ? activeCar
            : carStoreItem?.svgaAsset;

        final giftTotal = _giftReceiverTotals[uid] ?? 0;
        final isMuted = data['is_muted'] == true;
        _seats[idx] = SeatModel(
          index: idx,
          state: SeatState.occupied,
          user: UserModel(
            name: data['name']?.toString() ?? '',
            avatar: data['photo_url']?.toString(),
            id: uid,
            customId: cachedUser?.customId ?? data['custom_id']?.toString(),
            giftCount: giftTotal,
            totalGiftsReceived: giftTotal,
            charm: giftTotal.toString(),
          ),
          isMuted: isMuted,
          hasFrame: activeFrame != null && activeFrame.isNotEmpty,
          frameAsset: frameAsset,
          carAsset: carAsset,
        );
      } else {
        _seats[idx] = SeatModel(index: idx);
      }
    }
    // Only allow publishing when the current user is actually on a seat
    if (isCurrentUserOnSeatNow) {
      _roomAudio.startPublishing();
      _roomAudio.toggleMic(!currentUserMuted);
    } else {
      final engine = ZegoExpressEngine.instance;
      if (engine != null) {
        engine.stopPublishingStream();
      }
      _roomAudio.resetPublishingState();
    }
    if (mounted) setState(() {});
  }

  void _playEntranceEffectRaw(Map<String, dynamic> data, String url) {
    if (!mounted) return;
    setState(() {
      _entranceItemAnimAsset = url;
      _showEntranceItemAnim = true;
      _entranceItemTextReplacement = null;
      _entranceItemImageReplacement = null;
      _entranceItemDefaultImage = null;
    });
  }

  void _playEntranceEffect(Map<String, dynamic> data, StoreItemModel storeItem, String? uid) {
    if (!mounted) return;
    final nameKey = storeItem.nameKey;
    final photoKey = storeItem.photoKey;
    final enteringUser = uid != null ? _cachedUsers[uid] : null;
    Map<String, String>? textReplacement;
    Map<String, String>? imageReplacement;
    if (nameKey != null && nameKey.isNotEmpty && enteringUser != null) {
      textReplacement = <String, String>{nameKey: enteringUser.name};
    }
    if (photoKey != null && photoKey.isNotEmpty && enteringUser != null && enteringUser.photoUrl.isNotEmpty) {
      imageReplacement = <String, String>{photoKey: enteringUser.photoUrl};
    }
    final isCar = storeItem.category == 'car';
    setState(() {
      if (isCar) {
        _entranceAnimAsset = storeItem.animationUrl;
        _showEntranceAnim = true;
        _entranceTextReplacement = textReplacement;
        _entranceImageReplacement = imageReplacement;
        _entranceDefaultImage = storeItem.defaultImage;
      } else {
        _entranceItemAnimAsset = storeItem.animationUrl;
        _showEntranceItemAnim = true;
        _entranceItemTextReplacement = textReplacement;
        _entranceItemImageReplacement = imageReplacement;
        _entranceItemDefaultImage = storeItem.defaultImage;
      }
    });
  }

  // Future<void> _initAgora() async {
  //   // Request microphone permission
  //   await [Permission.microphone].request();

  //   // Create the engine
  //   _engine = createAgoraRtcEngine();

  //   // Initialize the engine
  //   await _engine!.initialize(RtcEngineContext(appId: AgoraConfig.appId));

  //   // Register event handlers
  //   _engine!.registerEventHandler(RtcEngineEventHandler(
  //     onJoinChannelSuccess: (connection, elapsed) {
  //       print('onJoinChannelSuccess: ${connection.channelId}, uid: ${connection.localUid}');
  //       setState(() {
  //         _localUid = connection.localUid;
  //       });
  //     },
  //     onUserJoined: (connection, remoteUid, elapsed) {
  //       print('onUserJoined: $remoteUid');
  //     },
  //     onUserOffline: (connection, remoteUid, reason) {
  //       print('onUserOffline: $remoteUid, reason: $reason');
  //     },
  //   ));

  //   // Join channel with token (or empty string if no token)
  //   await _engine!.joinChannel(
  //     token: AgoraConfig.token,
  //     channelId: widget.roomId,
  //     uid: 0,
  //     options: const ChannelMediaOptions(
  //       channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
  //       clientRoleType: ClientRoleType.clientRoleAudience,
  //     ),
  //   );
  // }

  List<SeatModel> _buildInitialSeats() {
    final seats = <SeatModel>[];
    for (int i = 0; i < 20; i++) {
      seats.add(SeatModel(index: i));
    }
    return seats;
  }

  @override
  void dispose() {
    // Minimized rooms keep their seat, membership and audio session alive –
    // the user is still "in" the room via the floating bubble.
    if (!_isMinimized) {
      _cleanupUserSession();
      _roomAudio.dispose();
    }
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _giftSub?.cancel();
    _seatsSub?.cancel();
    _seatsRefreshTimer?.cancel();
    _roomSub?.cancel();
    _storeSub?.cancel();
    _giftCacheSub?.cancel();
    _bannerConfigSub?.cancel();
    _msgSub?.cancel();
    _entranceSub?.cancel();
    super.dispose();
  }

  void _closeAllPanels() => setState(() {
        _showGift = false;
        _showFunction = false;
        _showEmoj = false;
        _showChatInput = false;
        _showNotifications = false;
        _showProfile = false;
      });

  void _openMessageSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF211211),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final isLocked = _currentRoom?.isChatLocked ?? false;
            final isAr = Localizations.localeOf(context).languageCode == 'ar';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAr ? 'إعدادات الرسائل' : 'Message Settings',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAr ? 'قفل الدردشة' : 'Lock Chat',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Switch(
                        value: isLocked,
                        activeColor: const Color(0xFFD3A350),
                        onChanged: (val) {
                          setModalState(() {});
                          _firebaseService.updateRoom(widget.roomId, {
                            'is_chat_locked': val,
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openGiftPanel() {
    final hasSeatedUsers = _seats.any((s) => s.isOccupied && s.user != null);
    if (!hasSeatedUsers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مستخدم على المقعد لإرسال الهدية')),
      );
      return;
    }
    _closeAllPanels();
    setState(() => _showGift = true);
  }

  void _checkGiftBanner(Map<String, dynamic> data) {
    final giftValue = data['giftValue'] as int? ?? 0;
    final giftCount = data['giftCount'] as int? ?? 1;
    final categoryId = data['categoryId'] as String?;
    final totalCost = giftValue * giftCount;

    // Get receiver photo from data, seat, or cached users
    String? receiverPhoto = data['receiverPhotoUrl']?.toString();
    final receiverId = data['receiverId']?.toString();
    if (receiverPhoto == null || receiverPhoto.isEmpty) {
      if (_selectedSeatIdx != null &&
          _selectedSeatIdx! < _seats.length &&
          _seats[_selectedSeatIdx!].isOccupied &&
          _seats[_selectedSeatIdx!].user != null) {
        receiverPhoto = _seats[_selectedSeatIdx!].user!.avatar;
      } else if (receiverId != null) {
        final seat = _seats.where((s) => s.user?.id == receiverId).firstOrNull;
        receiverPhoto = seat?.user?.avatar ?? _cachedUsers[receiverId]?.photoUrl;
      }
    }

    // Find matching banner config by category, or fallback to any active
    GiftBannerConfig? config;
    if (categoryId != null) {
      config = _bannerConfigs.where((c) => c.categoryId == categoryId).firstOrNull;
    }
    config ??= _bannerConfigs.isNotEmpty ? _bannerConfigs.first : null;

    if (config != null && totalCost >= config.thresholdCoins) {
      final cfg = config;
      setState(() {
        _giftBannerAsset = cfg.svgaUrl;
        _giftBannerSenderPhoto = data['senderPhotoUrl']?.toString();
        _giftBannerReceiverPhoto = receiverPhoto;
        _giftBannerGiftImage = data['defaultImage']?.toString();
        _giftBannerCount = giftCount;
        _giftBannerUserRKey = cfg.userRKey;
        _giftBannerUserLKey = cfg.userLKey;
        _giftBannerNumberKey = cfg.numberKey;
        _giftBannerGiftKey = cfg.giftKey;
        _showGiftBanner = true;
      });
      return;
    }

    // Default fallback: show strip for any gift (no threshold check)
    setState(() {
      _giftBannerAsset = 'assets/svga/gift_banner_strip.svga';
      _giftBannerSenderPhoto = data['senderPhotoUrl']?.toString();
      _giftBannerReceiverPhoto = receiverPhoto;
      _giftBannerGiftImage = data['defaultImage']?.toString();
      _giftBannerCount = giftCount;
      _giftBannerUserRKey = 'user_r';
      _giftBannerUserLKey = 'user_l';
      _giftBannerNumberKey = 'number';
      _giftBannerGiftKey = 'gift';
      _showGiftBanner = true;
    });
  }

  void _sendMessage() {
    final t = _chatCtrl.text.trim();
    if (t.isEmpty) return;
    if (_currentRoom?.isChatLocked == true && !_isOwnerOrModerator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قفل الدردشة من قبل الإدارة')),
      );
      setState(() => _showChatInput = false);
      return;
    }
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user != null) {
      _firebaseService.sendMessage(
        widget.roomId,
        t,
        user.uid,
        user.name,
        user.photoUrl,
        activeBubble: user.activeBubble,
      );
    }
    _chatCtrl.clear();
    setState(() => _showChatInput = false);
  }

  Future<void> _pickRoomImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      if (user == null) return;
      final imageUrl = await CloudinaryService().uploadImage(
        File(image.path),
        publicId: 'room_${widget.roomId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _firebaseService.sendImageMessage(
        widget.roomId, imageUrl, user.uid, user.name, user.photoUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── Seat tap handler ──────────────────────────────────────────
  void _onSeatTap(int idx) {
    final seat = _seats[idx];
    if (seat.isOccupied && seat.user != null) {
      final user = seat.user!;
      if (_isOwnerOrModerator || user.isAdmin) {
        // Owner/moderator/admin: show action sheet directly
        _showOccupiedDialog(idx, user);
      } else {
        // Regular user: show profile first
        setState(() {
          _selectedSeatIdx = idx;
          _selectedUser = user;
          _showProfile = true;
        });
      }
    } else {
      // Empty or locked seat
      _showEmptyDialog(idx);
    }
  }

  void _showEmptyDialog(int idx) {
    final seat = _seats[idx];
    SeatDialogs.showEmptySeatDialog(
      context,
      seatIndex: idx,
      isOwnerOrModerator: _isOwnerOrModerator,
      isLocked: seat.isLocked,
      isMuted: seat.isMuted,
      onTakeMic: () => _takeMic(idx),
      onInviteToMic: () => _inviteToMic(idx),
      onToggleLock: (locked) => _toggleSeatLock(idx, locked),
      onToggleMic: (muted) => _toggleSeatMute(idx, muted),
    );
  }

  void _showOccupiedDialog(int idx, UserModel user) {
    final seat = _seats[idx];
    SeatDialogs.showOccupiedSeatDialog(
      context,
      user: user,
      isOwner: _isOwner,
      isOwnerOrModerator: _isOwnerOrModerator,
      isMuted: seat.isMuted,
      isAdmin: user.isAdmin,
      isBlacked: user.isBlacked,
      onUserDetail: () => _openProfile(idx, user),
      onKickOffMic: () => _kickOffMic(idx),
      onToggleMicLock: (muted) => _toggleSeatMute(idx, muted),
      onSetAdmin: (admin) => _setAdmin(idx, admin),
      onToggleComments: (enabled) {},
      onToggleBlack: (blacked) => _toggleBlack(idx, blacked),
      onKickOutFromRoom: () => _kickOutFromRoom(idx),
      onPrivateMessage: () => setState(() {
        _closeAllPanels();
        _showChatInput = true;
      }),
      onGift: _openGiftPanel,
    );
  }

  // ── Seat actions ──────────────────────────────────────────────

  bool _takingSeat = false;
  void _takeMic(int idx) {
    if (_takingSeat) return;
    if (_currentUserId == null) return;
    // If already on this seat, skip
    if (idx < _seats.length && _seats[idx].user?.id == _currentUserId) return;
    _takingSeat = true;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    final name = currentUser?.name ?? 'Me';
    // Remember the previous seat before overwriting local state
    int? previousIdx;
    for (int i = 0; i < _seats.length; i++) {
      if (i != idx && _seats[i].user?.id == _currentUserId) {
        previousIdx = i;
        break;
      }
    }
    // Optimistic UI: place the user on the target seat immediately so the
    // move feels instant; the seats stream reconciles with the server state.
    setState(() {
      _seats[idx] = SeatModel(
        index: idx,
        state: SeatState.occupied,
        user: UserModel(
          name: name,
          avatar: currentUser?.photoUrl ?? '',
          id: _currentUserId!,
          customId: currentUser?.customId,
        ),
      );
      if (previousIdx != null) {
        _seats[previousIdx] = SeatModel(index: previousIdx);
      }
    });
    Future<void> doTake() async {
      await _firebaseService.takeSeat(widget.roomId, idx, app.UserModel(
        uid: _currentUserId!,
        customId: currentUser?.customId ?? '',
        name: name,
        photoUrl: currentUser?.photoUrl ?? '',
        activeFrame: currentUser?.activeFrame,
        activeCar: currentUser?.activeCar,
      ));
      _takingSeat = false;
    }
    if (previousIdx != null) {
      _firebaseService.leaveSeat(widget.roomId, previousIdx).then((_) => doTake());
    } else {
      doTake();
    }
  }

  void _kickOffMic(int idx) {
    final kickedUid = _seats[idx].user?.id;

    setState(() {
      _seats[idx].state = SeatState.empty;
      _seats[idx].user = null;
      _seats[idx].isMuted = false;
    });

    _firebaseService.leaveSeat(widget.roomId, idx);

    if (kickedUid != null) {
      _roomAudio.muteRemoteAudio(kickedUid, widget.roomId, true);
      _roomAudio.stopRemoteStream(kickedUid, widget.roomId);
    }
  }

  void _inviteToMic(int idx) {
    // Open invite UI — stub
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Invited to seat $idx')));
  }

  void _toggleSeatLock(int idx, bool locked) {
    setState(() {
      _seats[idx].isLocked = locked;
      _seats[idx].state = locked ? SeatState.locked : SeatState.empty;
    });
  }

  void _toggleSeatMute(int idx, bool muted) {
    setState(() {
      _seats[idx].isMuted = muted;
      if (_seats[idx].isOccupied) {
        _seats[idx].state = muted ? SeatState.muted : SeatState.occupied;
      }
    });
    _firebaseService.toggleMute(widget.roomId, idx, muted);
  }

  void _kickOutFromRoom(int idx) {
    final user = _seats[idx].user;
    if (user == null) return;
    final uid = user.id;
    final name = user.name;
    setState(() {
      _seats[idx].state = SeatState.empty;
      _seats[idx].user = null;
      _seats[idx].isMuted = false;
    });
    _firebaseService.leaveSeat(widget.roomId, idx);
    if (uid != null && _currentUserId != null) {
      _firebaseService.blockUserFromRoom(widget.roomId, _currentUserId!, uid, reason: 'Kicked by room owner');
      _firebaseService.leaveRoom(widget.roomId, uid);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name has been banned from the room')));
  }

  void _setAdmin(int idx, bool isAdmin) {
    final user = _seats[idx].user;
    if (user == null) return;
    setState(() {
      _seats[idx].user = user.copyWith(isAdmin: isAdmin);
    });
  }

  void _toggleBlack(int idx, bool blacked) {
    final user = _seats[idx].user;
    if (user == null || user.id == null) return;
    setState(() {
      _seats[idx].user = user.copyWith(isBlacked: blacked);
    });
    if (blacked) {
      _kickOffMic(idx);
      if (_currentUserId != null) {
        _firebaseService.blockUserFromRoom(widget.roomId, _currentUserId!, user.id!);
        _firebaseService.leaveRoom(widget.roomId, user.id!);
      }
    } else {
      if (_currentUserId != null) {
        _firebaseService.unblockUserFromRoom(widget.roomId, user.id!);
      }
    }
  }

  void _openProfile(int idx, UserModel user) {
    setState(() {
      _selectedSeatIdx = idx;
      _selectedUser = user;
      _showProfile = true;
    });
  }

  void _openChatUserProfile(String uid, String name, String photoUrl) {
    setState(() {
      _selectedSeatIdx = null;
      _selectedUser = UserModel(
        id: uid,
        name: name,
        avatar: photoUrl.isNotEmpty ? photoUrl : null,
      );
      _showProfile = true;
    });
  }

  // ── Function panel actions ────────────────────────────────────

  void _openVolume() {
    _closeAllPanels();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VolumePanel(initialVolume: 20, onVolumeChanged: (_) {}),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomSettingsScreen(
          roomId: widget.roomId,
          initialName: widget.roomName,
          initialPassword: widget.roomPassword,
          roomAvatarPath: _seats[0].user?.avatar,
          isModerator: !_isOwner && _moderators.contains(_currentUserId),
          onConfirm: (name, pwd, photoUrl) async {
            final updates = <String, dynamic>{
              'name': name,
              'password': pwd,
            };
            if (photoUrl != null) updates['room_photo_url'] = photoUrl;
            await _firebaseService.updateRoom(widget.roomId, updates);
            if (_currentUserId != null) {
              await _firebaseService.updateUser(_currentUserId!, {'name': name});
            }
          },
        ),
      ),
    );
  }

  void _openSeatStyle() {
    _closeAllPanels();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SeatStylePanel(
        initialStyle: SeatStyle.values[_roomSeatStyle.index.clamp(0, 2)],
        initialSeatCount: _seats.length,
        onConfirm: (style, count) {
          seat_model.SeatStyle newSeatStyle;
          switch (style) {
            case SeatStyle.game:
              newSeatStyle = seat_model.SeatStyle.circle;
              break;
            case SeatStyle.classic:
              newSeatStyle = seat_model.SeatStyle.classic;
              break;
            case SeatStyle.vip:
              newSeatStyle = seat_model.SeatStyle.heart;
              break;
          }
          _firebaseService.updateRoomSeatStyle(widget.roomId, newSeatStyle.index);
          _firebaseService.updateRoomSeatCount(widget.roomId, count);
          // Clean up removed seats in Firebase
          if (count < _seats.length) {
            for (int i = count; i < _seats.length; i++) {
              _firebaseService.leaveSeat(widget.roomId, i);
            }
          }
          setState(() {
            _roomSeatStyle = newSeatStyle;
            if (count != _seats.length) {
              _seats = List.generate(count, (i) => seat_model.SeatModel(index: i));
            }
          });
        },
      ),
    );
  }

  void _openRoomBackground() {
    _closeAllPanels();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RoomBackgroundBottomSheet(
        roomId: widget.roomId,
        currentBackground: _currentRoom?.bgImage ?? '',
      ),
    );
  }

  void _openMixer() {
    _closeAllPanels();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MixerPanel(onMixerToggle: (_) {}),
    );
  }

  void _openReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportRoomScreen(
          roomName: widget.roomName,
          roomAvatar: _currentRoom?.roomPhotoUrl ?? _seats[0].user?.avatar,
        ),
      ),
    );
  }

  void _openPrivateChat(UserModel? user) {
    if (user?.id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          targetUid: user!.id!,
          targetName: user.name,
          targetPhotoUrl: user.avatar,
        ),
      ),
    );
  }

  void _openEffect() {
    setState(() {
      _showCharmValues = !_showCharmValues;
    });
  }

  void _openMusic() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF211211),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MusicListSheet(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final navH = MediaQuery.of(context).padding.bottom;
    final sizeH = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_isMinimized) {
            Navigator.of(context).pop();
            return;
          }
          bool isOnSeat = false;
          for (int i = 0; i < _seats.length; i++) {
            if (_seats[i].user?.id == _currentUserId) {
              isOnSeat = true;
              break;
            }
          }
          if (isOnSeat) {
            _minimizeRoom();
          } else {
            _showExit ? setState(() => _showExit = false) : _exitRoom();
          }
        }
      },
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.roomBg,
      body: GestureDetector(
        onTap: _closeAllPanels,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
          // ── Background ───────────────────────────────────────
          Positioned.fill(
            child: Builder(
              builder: (ctx) {
                final customBg = _currentRoom?.bgImage;
                if (customBg != null && customBg.isNotEmpty) {
                  return Image.network(customBg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.black));
                }

                final theme = _currentRoom?.category ?? 'themeFriend';
                final bgImageUrl = DynamicConfigService().getRoomBgImage(theme);
                if (bgImageUrl != null && bgImageUrl.isNotEmpty) {
                  return Image(image: R.cachedImage(bgImageUrl), fit: BoxFit.cover);
                }
                
                final gradient = AppColors.themeFriend; // default
                final colors = DynamicConfigService().getRoomGradient(theme);
                final LinearGradient activeGradient = (colors != null && colors.length >= 2) 
                    ? LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter)
                    : (theme == 'themeChat' ? AppColors.themeChat : 
                       theme == 'themeMusic' ? AppColors.themeMusic :
                       theme == 'themeGame' ? AppColors.themeGame :
                       theme == 'themeParty' ? AppColors.themeParty :
                       theme == 'themeHobby' ? AppColors.themeHobby : AppColors.themeFriend);
                
                return Container(
                  decoration: BoxDecoration(gradient: activeGradient),
                );
              },
            ),
          ),

          // ── Main column ──────────────────────────────────────
          Column(
            children: [
              // Header
               RoomHeader(
                roomName: widget.roomName,
                roomId: widget.roomId,
                hostAvatar: _currentRoom?.roomPhotoUrl ?? _seats[0].user?.avatar,
                isLocked: widget.roomPassword.isNotEmpty,
                hotValue: widget.hotValue,
                gameDesc: widget.gameDesc,
                onlineCount: '$_onlineCount',
                isFollowed: _isFollowed,
                onExit: () => setState(() => _showExit = true),
                onMinimize: _minimizeRoom,
                onRank: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => RoomRankBottomSheet(roomId: widget.roomId),
                  );
                },
                onInfoTap: () => setState(() => _showRoomInfo = true),
                onOnlineTap: _showMembersSheet,
                onGameTap: () {},
                onFollow: _toggleFollow,
              ),

              // SeatArea — 21 seats
              SeatArea(
                seats: _seats,
                onSeatTap: _onSeatTap,
                seatEmojis: _seatEmojis,
                moderators: _moderators,
                hostUid: _currentRoom?.hostUid,
                seatStyle: _roomSeatStyle,
                showCharmValues: _showCharmValues,
                onCharmTap: () => setState(() => _showCharmValues = !_showCharmValues),
              ),

              // Chat area fills remaining
              Expanded(child: _buildChatArea()),

              // Bottom bar
              BottomBar(
                isMicOn: _isMicOn,
                showMic: _currentUserSeat != null,
                msgCount: _msgCount,
                onChat: () {
                  if (_currentRoom?.isChatLocked == true && !_isOwnerOrModerator) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قفل الدردشة من قبل الإدارة')));
                    return;
                  }
                  _closeAllPanels();
                  setState(() => _showChatInput = !_showChatInput);
                },
                onEmoj: () {
                  _closeAllPanels();
                  setState(() => _showEmoj = !_showEmoj);
                },
                onMic: () async {
                  if (_currentUserSeat == null) return;
                  final newVal = !_isMicOn;
                  setState(() => _isMicOn = newVal);
                  await _roomAudio.toggleMic(newVal);
                  _toggleSeatMute(_currentUserSeat!.index, !newVal);
                },
                onGift: () {
                  if (_showGift) {
                    setState(() => _showGift = false);
                  } else {
                    _openGiftPanel();
                  }
                },
                onMusic: _openMusic,
                onMsg: () {
                  _closeAllPanels();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessageScreen()),
                  );
                },
                onFunction: () {
                  _closeAllPanels();
                  setState(() => _showFunction = !_showFunction);
                },
              ),

              SizedBox(height: navH),
            ],
          ),

          // ── Game button ───────────────────────────────────────
          Positioned(
            bottom: navH + 63 + 17,
            right: 14,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameTeamingScreen()),
                );
              },
              child: R.image(
                R.roomGameIc,
                width: 44,
                height: 44,
              ),
            ),
          ),

          // ── Bottom sheet panels ───────────────────────────────
          if (_showGift)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showGift = false),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: GiftPanel(
                        selectedCount: _giftCount,
                        coins: Provider.of<UserProvider>(context).currentUser?.coins ?? 0,
                        roomId: widget.roomId,
                        targetUsers: _seats
                            .where((s) => s.isOccupied && s.user != null)
                            .map((s) => {
                                  'id': s.user!.id ?? '',
                                  'name': s.user!.name,
                                  'photoUrl': s.user!.avatar,
                                })
                            .toList(),
                        receiverId: _selectedSeatIdx != null &&
                                _seats[_selectedSeatIdx!].isOccupied &&
                                _seats[_selectedSeatIdx!].user != null
                            ? _seats[_selectedSeatIdx!].user!.id
                            : null,
                        receiverName: _selectedSeatIdx != null &&
                                _seats[_selectedSeatIdx!].isOccupied &&
                                _seats[_selectedSeatIdx!].user != null
                            ? _seats[_selectedSeatIdx!].user!.name
                            : null,
                        onSend: () {
                          setState(() {
                            _showGift = false;
                            _showGiftAnim = true;
                          });
                        },
                        onSendGift: (asset) {
                          setState(() => _giftAnimAsset = asset);
                        },
                        onSendGiftExtended: (data) {
                          if (data != null) {
                            setState(() {
                              _giftTextReplacement = data['nameKey'] != null && data['nameKey'].toString().isNotEmpty && data['senderName'].toString().isNotEmpty
                                  ? <String, String>{data['nameKey'].toString(): data['senderName'].toString()}
                                  : null;
                              _giftImageReplacement = data['photoKey'] != null && data['photoKey'].toString().isNotEmpty && data['senderPhotoUrl'].toString().isNotEmpty
                                  ? <String, String>{data['photoKey'].toString(): data['senderPhotoUrl'].toString()}
                                  : null;
                              _giftDefaultImage = data['defaultImage']?.toString();
                            });
                            _checkGiftBanner(data);
                          }
                        },
                        onCountTap: _showGiftCountMenu,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_showFunction)
            _sheet(
              GestureDetector(
                onTap: () {},
                child: FunctionPanel(
                  isOwner: _isOwner,
                  isModerator: _moderators.contains(_currentUserId),
                  onClose: () => setState(() => _showFunction = false),
                  onItemTap: _onFunctionTap,
                ),
              ),
            ),

          if (_showEmoj) _buildEmojPanel(),
          if (_showChatInput) _buildChatInputBar(),

          // ── Full-screen overlays ──────────────────────────────
          if (_showProfile && _selectedUser != null)
            Positioned.fill(
              child: UserProfile(
                user: _selectedUser!.toMap(),
                showMicControls:
                    _selectedSeatIdx != null &&
                    _seats[_selectedSeatIdx!].isOccupied &&
                    (_isOwnerOrModerator || _selectedUser?.id == _currentUserId),
                isCurrentUser: _selectedUser?.id == _currentUserId,
                isFollowed: _selectedUser?.id != null && _followedUsers.contains(_selectedUser!.id!),
                isModerator: _isOwnerOrModerator,
                isRoomOwner: _isOwner,
                isTargetModerator: _selectedUser?.id != null && _moderators.contains(_selectedUser!.id!),
                isBlocked: _selectedUser?.id != null && _blockedUsers.contains(_selectedUser!.id!),
                currentUserId: _currentUserId,
                onClose: () => setState(() {
                  _showProfile = false;
                  _selectedUser = null;
                  _selectedSeatIdx = null;
                }),
                onViewProfile: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(targetUid: _selectedUser!.id),
                  ));
                },
                onToggleAdmin: () async {
                  final targetUid = _selectedUser?.id;
                  if (targetUid == null) return;
                  final isMod = _moderators.contains(targetUid);
                  try {
                    if (isMod) {
                      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
                        'moderators': FieldValue.arrayRemove([targetUid]),
                      });
                      setState(() => _moderators.remove(targetUid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم إلغاء إشراف ${_selectedUser?.name}')),
                      );
                    } else {
                      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
                        'moderators': FieldValue.arrayUnion([targetUid]),
                      });
                      setState(() => _moderators.add(targetUid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم تعيين ${_selectedUser?.name} كمشرف في الغرفة 👑')),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error toggling moderator: $e');
                  }
                  setState(() => _showProfile = false);
                },
                onFollow: () {
                  final userId = _selectedUser?.id;
                  if (userId == null) return;
                  if (_blockedUsers.contains(userId)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot follow this user'), duration: Duration(seconds: 2)),
                    );
                    return;
                  }
                  setState(() {
                    if (_followedUsers.contains(userId)) {
                      _followedUsers.remove(userId);
                      _firebaseService.unfollowUser(_currentUserId!, userId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unfollowed ${_selectedUser?.name}')),
                      );
                    } else {
                      _followedUsers.add(userId);
                      _firebaseService.followUser(_currentUserId!, userId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Followed ${_selectedUser?.name}')),
                      );
                    }
                  });
                },
                onChat: () {
                  final userId = _selectedUser?.id;
                  if (userId != null && _blockedUsers.contains(userId)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot message this user'), duration: Duration(seconds: 2)),
                    );
                    return;
                  }
                  setState(() {
                    _showProfile = false;
                  });
                  // Navigate to private message screen
                  _openPrivateChat(_selectedUser);
                },
                onMention: () {
                  final userId = _selectedUser?.id;
                  if (userId != null && _blockedUsers.contains(userId)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot mention this user'), duration: Duration(seconds: 2)),
                    );
                    return;
                  }
                  setState(() {
                    _showProfile = false;
                    _showChatInput = true;
                    _chatCtrl.text = '@${_selectedUser?.name} ';
                  });
                },
                onGift: _openGiftPanel,
                onMicDown: () {
                  if (_selectedSeatIdx != null) {
                    _kickOffMic(_selectedSeatIdx!);
                  }
                  setState(() => _showProfile = false);
                },
                onMicMute: () {
                  if (_selectedSeatIdx != null) {
                    final idx = _selectedSeatIdx!;
                    _toggleSeatMute(idx, !_seats[idx].isMuted);
                  }
                  setState(() => _showProfile = false);
                },
                onReport: () {
                  final u = _selectedUser;
                  if (u == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportUserScreen(
                        nickname: u.name,
                        avatar: u.avatar,
                        reportedUid: u.id ?? '',
                      ),
                    ),
                  );
                },
                onBlock: () {
                  final userId = _selectedUser?.id;
                  if (userId == null || _currentUserId == null) return;
                  _firebaseService.blockUser(_currentUserId!, userId);
                  setState(() => _blockedUsers.add(userId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_selectedUser?.name} has been blocked'), duration: Duration(seconds: 2)),
                  );
                },
                onUnblock: () {
                  final userId = _selectedUser?.id;
                  if (userId == null || _currentUserId == null) return;
                  _firebaseService.unblockUser(_currentUserId!, userId);
                  setState(() => _blockedUsers.remove(userId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_selectedUser?.name} has been unblocked'), duration: Duration(seconds: 2)),
                  );
                },
                onKick: () {
                  if (_selectedSeatIdx != null) {
                    _kickOutFromRoom(_selectedSeatIdx!);
                  }
                  setState(() => _showProfile = false);
                },
                onMute: () {
                  if (_selectedSeatIdx != null) {
                    final idx = _selectedSeatIdx!;
                    _toggleSeatMute(idx, !_seats[idx].isMuted);
                  }
                  setState(() => _showProfile = false);
                },
              ),
            ),

          if (_showRoomInfo) _buildRoomInfoSheet(sizeH),
          if (_showNotifications) _buildNotificationsSheet(),
          if (_showExit) _buildExitDialog(),
          if (_showShare) _buildShare(),
          // ── أنيميشن gift.svga يملأ الشاشة عند الإرسال ──
          if (_showGiftAnim)
            GiftSvgaOverlay(
              animationAsset: _giftAnimAsset,
              textReplacement: _giftTextReplacement,
              imageReplacement: _giftImageReplacement,
              defaultImageUrl: _giftDefaultImage,
              onFinished: () => setState(() {
                _showGiftAnim = false;
                _giftAnimAsset = null;
                _giftTextReplacement = null;
                _giftImageReplacement = null;
                _giftDefaultImage = null;
              }),
            ),
          // ── Gift banner strip (high-value gifts) ──
          if (_showGiftBanner && _giftBannerAsset != null)
            GiftBannerOverlay(
              animationAsset: _giftBannerAsset,
              senderPhotoUrl: _giftBannerSenderPhoto,
              receiverPhotoUrl: _giftBannerReceiverPhoto,
              giftImageUrl: _giftBannerGiftImage,
              giftCount: _giftBannerCount,
              userRKey: _giftBannerUserRKey,
              userLKey: _giftBannerUserLKey,
              numberKey: _giftBannerNumberKey,
              giftKey: _giftBannerGiftKey,
              onFinished: () => setState(() {
                _showGiftBanner = false;
                _giftBannerAsset = null;
                _giftBannerSenderPhoto = null;
                _giftBannerReceiverPhoto = null;
                _giftBannerGiftImage = null;
                _giftBannerCount = 1;
              }),
            ),
          // ── أنيميشن دخول الغرفة (car effect) ──
          if (_showEntranceAnim && _entranceAnimAsset != null)
            GiftSvgaOverlay(
              animationAsset: _entranceAnimAsset,
              textReplacement: _entranceTextReplacement,
              imageReplacement: _entranceImageReplacement,
              defaultImageUrl: _entranceDefaultImage,
              onFinished: () => setState(() {
                _showEntranceAnim = false;
                _entranceAnimAsset = null;
                _entranceTextReplacement = null;
                _entranceImageReplacement = null;
                _entranceDefaultImage = null;
              }),
            ),
          // ── أنيميشن دخول (entrance item) يعمل فوق السيارة ──
          if (_showEntranceItemAnim && _entranceItemAnimAsset != null)
            GiftSvgaOverlay(
              animationAsset: _entranceItemAnimAsset,
              textReplacement: _entranceItemTextReplacement,
              imageReplacement: _entranceItemImageReplacement,
              defaultImageUrl: _entranceItemDefaultImage,
              showBackground: false,
              onFinished: () => setState(() {
                _showEntranceItemAnim = false;
                _entranceItemAnimAsset = null;
                _entranceItemTextReplacement = null;
                _entranceItemImageReplacement = null;
                _entranceItemDefaultImage = null;
              }),
            ),
          // ── Minimized room bubble (room stays functional underneath) ──
          if (_isMinimized)
            Positioned(
              top: navH + 60,
              right: 12,
              child: GestureDetector(
                onTap: () => setState(() => _isMinimized = false),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.cardBg,
                      child: ClipOval(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: R.loadImage(
                            _currentRoom?.roomPhotoUrl ?? R.avaBoy,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: _exitRoom,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ── Function panel item tap ───────────────────────────────────
  void _onFunctionTap(String label) {
    setState(() => _showFunction = false);
    switch (label) {
      case 'Volume':
        _openVolume();
        break;
      case 'Settings':
        if (_isOwnerOrModerator) _openSettings();
        break;
      case 'Seat Style':
        if (_isOwnerOrModerator) _openSeatStyle();
        break;
      case 'Room Background':
        if (_isOwner) _openRoomBackground();
        break;
      case 'Mixer':
        _openMixer();
        break;
      case 'Report':
        _openReport();
        break;
      case 'Effect':
        _openEffect();
        break;
      case 'Clear Messages':
        if (_isOwnerOrModerator) _clearMessages();
        break;
      case 'Message Settings':
        if (_isOwnerOrModerator) _openMessageSettings();
        break;
      case 'Music':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MusicScreen()),
        );
        break;
      case 'Notifications':
        setState(() => _showFunction = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
      case 'Rankings':
        Navigator.push(
          context,
              MaterialPageRoute(builder: (context) => const RankScreen()),
        );
        break;
      case 'Share':
        setState(() => _showShare = true);
        break;
      default:
        break;
    }
  }

  // ── Chat area (uses Firebase messages) ──────────────────────
  Widget _buildChatArea() {
    return Padding(
      padding: const EdgeInsets.only(right: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _chatMessages.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    controller: _chatScroll,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: _chatMessages.length,
                    itemBuilder: (_, i) {
                      final m = _chatMessages[i];
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      final isMe = m.senderUid == userProvider.currentUser?.uid;
                      return _buildChatMsg(m, isMe);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMsg(MessageModel m, bool isMe) {
    if (m.type == 'gift') {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              m.text,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFFD856)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (m.type == 'entrance') {
      final isExit = m.text.contains('left');
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              m.text,
              style: TextStyle(fontSize: 12, color: isExit ? const Color(0xFFFF6B6B) : const Color(0xFF41FE88)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (m.type == 'system') {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              m.text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF41FE88)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openChatUserProfile(m.senderUid, m.senderName, m.senderPhotoUrl),
            child: ClipOval(
              child: m.senderPhotoUrl.isNotEmpty
                  ? Image(
                      image: R.cachedImage(m.senderPhotoUrl),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.senderName.length > 15
                      ? m.senderName.substring(0, 15)
                      : m.senderName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isMe ? AppColors.goldLight : const Color(0xFF24D5C3),
                  ),
                ),
                const SizedBox(height: 9),
                if (m.type == 'image' && m.imageUrl != null)
                  GestureDetector(
                    onTap: () => _showImagePreview(m.imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: R.cachedImage(m.imageUrl!),
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 180,
                          height: 180,
                          color: const Color(0x33000000),
                          child: const Icon(Icons.broken_image, color: Colors.white54),
                        ),
                      ),
                    ),
                  )
                else
                  _buildChatBubble(
                    text: m.text,
                    isMe: isMe,
                    activeBubble: m.activeBubble,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 18, color: Colors.white54),
    );
  }

  Widget _buildChatBubble({
    required String text,
    required bool isMe,
    String? activeBubble,
  }) {
    final bubbleColor = isMe ? AppColors.chatBubbleSelf : AppColors.chatBubbleOther;
    final textColor = isMe ? AppColors.chatBubbleSelfText : AppColors.chatBubbleOtherText;
    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(10.96),
            topRight: Radius.circular(2.19),
            bottomLeft: Radius.circular(10.96),
            bottomRight: Radius.circular(10.96),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(2.19),
            topRight: Radius.circular(10.96),
            bottomLeft: Radius.circular(10.96),
            bottomRight: Radius.circular(10.96),
          );

    Widget bubbleContent = Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: textColor),
      ),
    );

    String? bubbleUrl;
    if (activeBubble != null && activeBubble.isNotEmpty) {
      if (activeBubble.startsWith('http://') || activeBubble.startsWith('https://')) {
        bubbleUrl = activeBubble;
      } else {
        final storeItem = SupabaseService().getStoreItemSync(activeBubble);
        bubbleUrl = storeItem?.svgaAsset ?? storeItem?.iconAsset;
      }
    }

    if (bubbleUrl != null && bubbleUrl.isNotEmpty) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 240),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: NinePatchImage(
                imageUrl: bubbleUrl,
                fit: BoxFit.fill,
                errorWidget: (_, url) => Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
            bubbleContent,
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
      ),
      child: bubbleContent,
    );
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image(image: R.cachedImage(url), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _sheet(Widget child) =>
      Positioned(bottom: 0, left: 0, right: 0, child: child);

  // ── Emoji panel ───────────────────────────────────────────────
  Widget _buildEmojPanel() {
    final navH = MediaQuery.of(context).padding.bottom;
    final staticEmojis = ['😀', '😂', '🥰', '😎', '🤔', '😅', '😊', '🙂',
                   '❤️', '🔥', '💯', '✨', '🎉', '🎁', '👍', '👏',
                   '😢', '😡', '😱', '🤩', '😴', '🤗', '😇', '🤫'];
    
    final config = context.read<DynamicConfigService>();
    final dynamicEmojis = config.appAssets.values
        .where((a) => a.category == 'emoji' && a.isActive && (a.remoteUrl?.isNotEmpty ?? false))
        .map((a) => a.remoteUrl!)
        .toList();
        
    final emojis = [...dynamicEmojis, ...staticEmojis];
    
    // Find current user's seat
    int? currentUserSeat;
    for (int i = 0; i < _seats.length; i++) {
      if (_seats[i].user?.id == _currentUserId) {
        currentUserSeat = i;
        break;
      }
    }
    
    return Positioned(
      bottom: navH + 63,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          height: 220,
          decoration: const BoxDecoration(
            color: Color(0xF51D1111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: const [
                    _EmojiTab(label: '😀', selected: true),
                    _EmojiTab(label: '❤️'),
                    _EmojiTab(label: '🎁'),
                    _EmojiTab(label: '🎵'),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 15),
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (_, idx) => GestureDetector(
                      onTap: () {
                        // Show emoji on current user's seat
                        if (currentUserSeat != null) {
                          final seat = currentUserSeat;
                          setState(() {
                            _seatEmojis[seat] = emojis[idx];
                          });
                          // Clear emoji after some time
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                if (_seatEmojis[seat] == emojis[idx]) {
                                  _seatEmojis.remove(seat);
                                }
                              });
                            }
                          });
                        }
                        
                        // Send emoji directly to chat
                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                        final user = userProvider.currentUser;
                        if (user != null) {
                          if (emojis[idx].startsWith('http')) {
                            _firebaseService.sendImageMessage(
                              widget.roomId, emojis[idx], user.uid, user.name, user.photoUrl,
                            );
                          } else {
                            _firebaseService.sendMessage(
                              widget.roomId, emojis[idx], user.uid, user.name, user.photoUrl,
                              activeBubble: user.activeBubble,
                            );
                          }
                        }
                        
                        setState(() => _showEmoj = false);
                      },
                      child: Center(
                        child: emojis[idx].startsWith('http')
                            ? Image.network(emojis[idx], width: 40, height: 40, fit: BoxFit.contain)
                            : Text(emojis[idx], style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat input bar ────────────────────────────────────────────
  Widget _buildChatInputBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF51D1111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 15),
              GestureDetector(
                onTap: _pickRoomImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, size: 20, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _chatCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Say something...',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: Colors.black38,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    maxLines: 1,
                    maxLength: 100,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendMessage,
                child: Builder(
                  builder: (context) {
                    final sendImage = DynamicConfigService().roomSendMessageImage;
                    if (sendImage != null && sendImage.isNotEmpty) {
                      return Image.network(
                        sendImage,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('Send', style: TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold)),
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'إرسال',
                        style: TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Room info sheet ───────────────────────────────────────────
  Widget _buildRoomInfoSheet(double sizeH) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          height: sizeH * 0.72,
          decoration: const BoxDecoration(
            color: Color(0xFF211211),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Text(
                      'Room Information',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _showRoomInfo = false),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: const Color(0x1AFFFFFF)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: R.loadImage(
                                _currentRoom?.roomPhotoUrl ?? R.avaBoy,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.roomName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${widget.roomId}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xB2FFFFFF),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: AppColors.headerBadge,
                                  child: const Text(
                                    'Social',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Room Owner',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              R.avaBoy,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 72,
                                height: 72,
                                color: AppColors.cardBg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.hostName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                'ID: ${widget.roomId}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xB2FFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Room Notice',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 105),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Welcome to our room!\nPlease respect each other and have fun 🎉',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: AppColors.giftBtnGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              R.image(
                                R.roomFollowPre,
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Follow',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Member list ───────────────────────────────────────────────
  void _showMembersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF1B1414), // Dark background matching image
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'متصل',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'الاستخدام:$_onlineCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _seats.where((s) => s.isOccupied && s.user != null).length,
                  itemBuilder: (context, index) {
                    final occupiedSeats = _seats.where((s) => s.isOccupied && s.user != null).toList();
                    final u = occupiedSeats[index].user!;
                    final isMuted = occupiedSeats[index].isMuted;
                    
                    final bool isMale = true; // Defaulting to true as UserModel has no gender
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipOval(child: _memberAvatar(u.avatar, 46)),
                          const SizedBox(width: 12),
                          Text(
                            u.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          // Wealth / Level badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B2A15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 10, color: Color(0xFFFFD700)),
                                const SizedBox(width: 2),
                                Text(
                                  u.level.toString(),
                                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Mic icon
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD3A350), // orange-ish bg
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMuted ? Icons.mic_off : Icons.mic,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Gender icon
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isMale ? const Color(0xFF4A90E2) : const Color(0xFFE91E63),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMale ? Icons.male : Icons.female,
                              size: 14,
                              color: Colors.white,
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
      },
    );
  }


  // ── Notifications sheet ───────────────────────────────────────
  Widget _buildNotificationsSheet() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showNotifications = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: double.infinity,
              color: const Color(0xFF211211),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _showNotifications = false),
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 0.5, color: const Color(0x1AFFFFFF)),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: const Icon(Icons.favorite, color: Colors.red),
                            title: const Text(
                              'New like',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Someone liked your post',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            trailing: const Text(
                              '2m ago',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: const Icon(Icons.person_add, color: Colors.blue),
                            title: const Text(
                              'New follower',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'User123 started following you',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            trailing: const Text(
                              '5m ago',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: const Icon(Icons.card_giftcard, color: Colors.orange),
                            title: const Text(
                              'Gift received',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'You received a Crown gift',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            trailing: const Text(
                              '10m ago',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Minimize / Exit ─────────────────────────────────────────
  void _minimizeRoom() {
    setState(() => _showExit = false);
    _isMinimized = true;
    MinimizedRoomService().activate(
      roomId: widget.roomId,
      roomName: widget.roomName,
      hostName: widget.hostName,
      roomPassword: widget.roomPassword.isNotEmpty ? widget.roomPassword : null,
      hotValue: widget.hotValue,
      gameDesc: widget.gameDesc,
      roomPhoto: _currentRoom?.roomPhotoUrl ?? _seats[0].user?.avatar,
    );
    Navigator.of(context).pop();
  }

  void _cleanupUserSession() {
    if (_currentUserId == null) return;
    final name = _currentUserName;
    // Fire-and-forget: async cleanup that survives even if widget disposes
    Future(() async {
      try {
        // Remove any seat for this user in this room
        await Supabase.instance.client
            .from('room_seats')
            .delete()
            .eq('room_id', widget.roomId)
            .eq('uid', _currentUserId!);
        // Log exit message on Firestore so ALL users in the room see it
        if (name != null && name.isNotEmpty) {
          await _firebaseService.logExit(widget.roomId, name);
        }
        // Remove from room members (Firestore — same DB the stream listens to)
        await _firebaseService.leaveRoom(widget.roomId, _currentUserId!);
        await Supabase.instance.client
            .from('room_members')
            .delete()
            .eq('room_id', widget.roomId)
            .eq('uid', _currentUserId!);
      } catch (_) {}
    });
  }

  void _exitRoom() {
    setState(() => _showExit = false);
    _cleanupUserSession();
    _roomAudio.dispose();
    Navigator.of(context).pop();
  }

  void _checkRoomBan(String uid) {
    _firebaseService.isUserBlockedFromRoom(widget.roomId, uid).then((isBlocked) {
      if (isBlocked && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are banned from this room'), duration: Duration(seconds: 3)),
        );
        Navigator.of(context).pop();
      }
    });
  }

  void _toggleFollow() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null) return;
    if (_isFollowed) {
      _firebaseService.unfollowRoom(user.uid, widget.roomId);
    } else {
      _firebaseService.followRoom(user.uid, widget.roomId);
    }
    setState(() => _isFollowed = !_isFollowed);
  }

  Widget _memberAvatar(String? avatar, double size) {
    if (avatar == null || avatar.isEmpty) {
      return R.image(R.avaBoy, width: size, height: size, fit: BoxFit.cover);
    }
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return Image(
        image: R.cachedImage(avatar),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => R.image(
          R.avaBoy, width: size, height: size, fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      avatar,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        R.avaBoy, width: size, height: size, fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildExitDialog() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showExit = false),
        child: Container(
          color: DynamicConfigService().roomExitSheetBgColor.withOpacity(0.9),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minimize Room Button
                    GestureDetector(
                      onTap: _minimizeRoom,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD54F),
                                  Color(0xFFFFB300),
                                  Color(0xFFE65100),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_fullscreen,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isAr ? 'تصغير' : 'Minimize',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Exit Room Button
                    GestureDetector(
                      onTap: _exitRoom,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD54F),
                                  Color(0xFFFFB300),
                                  Color(0xFFE65100),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.power_settings_new,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isAr ? 'خروج' : 'Exit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Fullscreen back button in bottom-left corner
              Positioned(
                bottom: 48,
                left: 32,
                child: GestureDetector(
                  onTap: () => setState(() => _showExit = false),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.4),
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Share dialog ───────────────────────────────────────────────
  Widget _buildShare() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showShare = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF211211),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Share Room',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildShareItem('WhatsApp', Icons.chat, Colors.green),
                        _buildShareItem('Facebook', Icons.facebook, Colors.blue),
                        _buildShareItem('Twitter', Icons.flutter_dash, Colors.lightBlue),
                        _buildShareItem('Copy Link', Icons.link, Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => setState(() => _showShare = false),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareItem(String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── Gift count popup ──────────────────────────────────────────
  void _showGiftCountMenu() {
    const counts = [1, 9, 99, 999];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF372928),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: counts
              .map(
                (c) => GestureDetector(
                  onTap: () {
                    setState(() => _giftCount = c);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: Text(
                      '$c',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ── Emoji tab ────────────────────────────────────────────────────
class _EmojiTab extends StatelessWidget {
  final String label;
  final bool selected;
  const _EmojiTab({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 22,
          color: selected ? Colors.white : Colors.white54,
        ),
      ),
    );
  }
}

// ── Music list sheet ─────────────────────────────────────────────
class _MusicListSheet extends StatelessWidget {
  static const _songs = [
    {'title': 'Chill Vibes', 'artist': 'Lo-Fi Beats', 'duration': '3:24'},
    {'title': 'Summer Wind', 'artist': 'DJ Wave', 'duration': '4:12'},
    {'title': 'Night Drive', 'artist': 'Synthwave', 'duration': '5:08'},
    {'title': 'Morning Coffee', 'artist': 'Acoustic', 'duration': '2:55'},
    {'title': 'Deep Ocean', 'artist': 'Ambient', 'duration': '6:30'},
  ];

  const _MusicListSheet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Music',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: const Color(0x1AFFFFFF)),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _songs.length,
              separatorBuilder: (_, __) =>
                  Container(height: 0.5, color: const Color(0x1AFFFFFF)),
              itemBuilder: (_, i) {
                final s = _songs[i];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: AppColors.goldLight,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    s['title']!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    s['artist']!,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  trailing: Text(
                    s['duration']!,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  onTap: () => Navigator.pop(context),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

