import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:zero/services/agency_target_evaluator.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';
import '../models/gift_model.dart' as gm;
import '../models/user_model.dart';
import '../models/store_item_model.dart';
import '../models/banner_config.dart';
import '../models/gifted_item_model.dart';
import '../models/notification_model.dart';
import '../models/ranking_frame_config.dart';
import '../models/gift_category_model.dart';
import '../models/gift_banner_config_model.dart';
import 'level_service.dart';
import 'cloudinary_service.dart';

/// Firebase (Firestore) implementation of the app's data layer.
///
/// Collections are named exactly like the original Supabase tables so the
/// whole schema maps 1:1 (see supabase/migrations/*.sql):
///   users, rooms, room_members, room_seats, room_messages, sent_gifts,
///   private_messages, conversations, follows, blocks, room_blocks,
///   notifications, reports, profile_visits, gifted_items, store_items,
///   banners, app_config, gifts, gift_categories, gift_banner_configs,
///   ranking_frames, badges, necklaces, user_wallets, level_config, vip_config
///
/// Auth is handled with Firebase Auth (anonymous + email/password + OAuth).
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._();
  factory FirebaseService() => _instance;
  FirebaseService._();

  late final FirebaseApp _app;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void init() {}

  Future<void> initializeApp() async {
    if (Firebase.apps.isNotEmpty) {
      _app = Firebase.app();
      return;
    }
    _app = await Firebase.initializeApp();
  }

  // ═══════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentAuthUser => _auth.currentUser;

  String get currentUid => _auth.currentUser?.uid ?? '';

  Future<String?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user?.uid;
  }

  Future<String?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return cred.user?.uid;
  }

  Future<String?> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return cred.user?.uid;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAuthAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }

  Future<String> getIdToken() async => await _auth.currentUser?.getIdToken() ?? '';

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════

  static String _now() => DateTime.now().toIso8601String();

  static Map<String, dynamic> _data(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return {};
    final m = Map<String, dynamic>.from(d);
    m['id'] = doc.id;
    return m;
  }

  static Map<String, dynamic> _stripNulls(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    map.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

  // ═══════════════════════════════════════════════════════
  // ROOMS
  // ═══════════════════════════════════════════════════════

  Future<String> createRoom({
    required String name,
    String description = '',
    String roomPhotoUrl = '',
    required String hostUid,
    required String hostCustomId,
    required String hostName,
    String hostPhotoUrl = '',
    bool isLocked = false,
    String password = '',
    String category = '',
    String country = '',
  }) async {
    final roomId = hostCustomId;
    final room = RoomModel(
      roomId: roomId,
      name: name,
      description: description,
      roomPhotoUrl: roomPhotoUrl,
      hostUid: hostUid,
      hostName: hostName,
      hostPhotoUrl: hostPhotoUrl,
      memberCount: 1,
      maxMembers: 10,
      isLocked: isLocked,
      category: category,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      password: password,
      country: country,
    );
    await _db.collection('rooms').doc(roomId).set(room.toMap(), SetOptions(merge: true));
    try {
      await _db.collection('users').doc(hostUid).set({'hosted_room_id': roomId}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('createRoom: users.update failed: $e');
      rethrow;
    }
    return roomId;
  }

  Future<void> followRoom(String uid, String roomId) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final d = doc.data() ?? {};
    final followed = List<String>.from(d['followed_rooms'] ?? []);
    if (!followed.contains(roomId)) {
      followed.add(roomId);
      await _db.collection('users').doc(uid).update({'followed_rooms': followed});
    }
  }

  Future<void> unfollowRoom(String uid, String roomId) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final d = doc.data() ?? {};
    final followed = List<String>.from(d['followed_rooms'] ?? []);
    if (followed.contains(roomId)) {
      followed.remove(roomId);
      await _db.collection('users').doc(uid).update({'followed_rooms': followed});
    }
  }

  Stream<RoomModel?> roomStream(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return RoomModel.fromMap(_data(snap));
    });
  }

  Future<List<RoomModel>> getAllRooms() async {
    final snap = await _db.collection('rooms').get();
    final rooms = snap.docs.map((e) => RoomModel.fromMap(_data(e))).toList();
    rooms.sort((a, b) => b.totalGifts.compareTo(a.totalGifts));
    return rooms;
  }

  Stream<List<RoomModel>> allRoomsStream() {
    return _db.collection('rooms').snapshots().map((snap) {
      final rooms = snap.docs.map((e) => RoomModel.fromMap(_data(e))).toList();
      rooms.sort((a, b) => b.totalGifts.compareTo(a.totalGifts));
      return rooms;
    });
  }

  Future<void> updateRoomMemberCount(String roomId, int count) async {
    await _db.collection('rooms').doc(roomId).update({'member_count': count});
  }

  Future<void> updateRoomName(String roomId, String name) async {
    await _db.collection('rooms').doc(roomId).update({'name': name});
  }

  Future<void> updateRoomSeatStyle(String roomId, int seatStyleIndex) async {
    await _db.collection('rooms').doc(roomId).update({'seat_style': seatStyleIndex});
  }

  Future<void> updateRoomSeatCount(String roomId, int count) async {
    await _db.collection('rooms').doc(roomId).update({'seat_count': count});
  }

  Future<void> updateRoomSeatColor(String roomId, int seatColorIndex) async {
    await _db.collection('rooms').doc(roomId).update({'seat_color': seatColorIndex});
  }

  Future<void> updateRoomBackground(String roomId, String bgUrl) async {
    await _db.collection('rooms').doc(roomId).update({'bgImage': bgUrl});
  }

  Future<RoomModel?> getRoom(String roomId) async {
    final doc = await _db.collection('rooms').doc(roomId).get();
    if (!doc.exists) return null;
    return RoomModel.fromMap(_data(doc));
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) async {
    await _db.collection('rooms').doc(roomId).update(updates);
  }

  Future<void> addModerator(String roomId, String uid) async {
    final doc = await _db.collection('rooms').doc(roomId).get();
    if (!doc.exists) return;
    final d = doc.data() ?? {};
    final mods = List<String>.from(d['moderators'] ?? d['moderator_uids'] ?? []);
    if (!mods.contains(uid)) {
      mods.add(uid);
      await _db.collection('rooms').doc(roomId).update({
        'moderators': mods,
        'moderator_uids': mods,
      });
    }
  }

  Future<void> removeModerator(String roomId, String uid) async {
    final doc = await _db.collection('rooms').doc(roomId).get();
    if (!doc.exists) return;
    final d = doc.data() ?? {};
    final mods = List<String>.from(d['moderators'] ?? d['moderator_uids'] ?? []);
    mods.remove(uid);
    await _db.collection('rooms').doc(roomId).update({
      'moderators': mods,
      'moderator_uids': mods,
    });
  }

  // ═══════════════════════════════════════════════════════
  // MEMBERS
  // ═══════════════════════════════════════════════════════

  Future<void> joinRoom(String roomId, UserModel user) async {
    await _db.collection('room_members').doc('${roomId}_${user.uid}').set({
      'room_id': roomId,
      'uid': user.uid,
      'name': user.name,
      'photo_url': user.photoUrl,
      'role': 'member',
      'joined_at': _now(),
    });
  }

  Future<void> leaveRoom(String roomId, String uid) async {
    await _db.collection('room_members').doc('${roomId}_$uid').delete();
  }

  Stream<List<UserModel>> roomMembersStream(String roomId) {
    return _db
        .collection('room_members')
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .map((snap) => snap.docs.map((e) => UserModel.fromMap(_data(e))).toList());
  }

  // ═══════════════════════════════════════════════════════
  // SEATS
  // ═══════════════════════════════════════════════════════

  Future<bool> takeSeat(String roomId, int seatIndex, UserModel user) async {
    try {
      final ref = _db.collection('room_seats').doc('${roomId}_$seatIndex');
      await _db.runTransaction((txn) async {
        final existing = await txn.get(ref);
        if (existing.exists) {
          throw Exception('seat taken');
        }
        txn.set(ref, {
          'room_id': roomId,
          'seat_index': seatIndex,
          'uid': user.uid,
          'custom_id': user.customId,
          'name': user.name,
          'photo_url': user.photoUrl,
          'active_frame': user.activeFrame,
          'active_car': user.activeCar,
          'is_muted': false,
          'taken_at': _now(),
        });
      });
      return true;
    } catch (e) {
      debugPrint('takeSeat error (possible race): $e');
      return false;
    }
  }

  Future<void> leaveSeat(String roomId, int seatIndex) async {
    await _db.collection('room_seats').doc('${roomId}_$seatIndex').delete();
  }

  Future<void> toggleMute(String roomId, int seatIndex, bool muted) async {
    await _db.collection('room_seats').doc('${roomId}_$seatIndex').update({'is_muted': muted});
  }

  Stream<Map<int, Map<String, dynamic>>> seatsStream(String roomId) {
    return _db
        .collection('room_seats')
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .map((snap) {
      final map = <int, Map<String, dynamic>>{};
      for (final e in snap.docs) {
        final d = Map<String, dynamic>.from(e.data());
        map[(d['seat_index'] as int?) ?? 0] = d;
      }
      return map;
    });
  }

  // ═══════════════════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════════════════

  Future<void> sendMessage(String roomId, String text, String senderUid,
      String senderName, String senderPhotoUrl, {String? activeBubble}) async {
    final msgId = const Uuid().v4();
    final msg = MessageModel(
      msgId: msgId,
      roomId: roomId,
      senderUid: senderUid,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: text,
      type: 'text',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      activeBubble: activeBubble,
    );
    await _db.collection('room_messages').doc(msgId).set(msg.toMap());
  }

  Stream<List<MessageModel>> messagesStream(String roomId, {String? since}) {
    return _db
        .collection('room_messages')
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .map((snap) {
      var msgs = snap.docs.map((e) => MessageModel.fromMap(_data(e))).toList();
      if (since != null) {
        final sinceMs = DateTime.tryParse(since)?.millisecondsSinceEpoch ?? 0;
        msgs = msgs.where((m) => m.timestamp >= sinceMs).toList();
      }
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return msgs;
    });
  }

  // ═══════════════════════════════════════════════════════
  // GIFTS
  // ═══════════════════════════════════════════════════════

  /// Safe int conversion – fields may be stored as int, double or string by
  /// different writers (admin dashboard, REST backend, manual console edits).
  /// A strict `as int` cast throws inside the transaction and silently rolls
  /// back the whole gift (no coin deduction).
  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<bool> sendGift({
    required String roomId,
    required String giftId,
    String giftName = '',
    String? animationAsset,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    required int value,
    int count = 1,
  }) async {
    final id = const Uuid().v4();
    final totalCost = value * count;
    final senderRef = _db.collection('users').doc(senderId);

    try {
      await _db.runTransaction((txn) async {
        // ── ALL READS FIRST ──
        // Firestore transactions forbid any read after the first write;
        // interleaving them made every gift transaction throw and roll back
        // silently (coins were never deducted).
        final senderSnap = await txn.get(senderRef);
        if (!senderSnap.exists) throw Exception('sender missing');
        final senderCoins = _asInt(senderSnap.data()?['coins']);
        if (senderCoins < totalCost) throw Exception('insufficient coins');

        final receiverRef = _db.collection('users').doc(receiverId);
        final recvSnap = await txn.get(receiverRef);

        final roomRef = _db.collection('rooms').doc(roomId);
        final roomSnap = await txn.get(roomRef);

        final walletRef = _db.collection('user_wallets').doc(receiverId);
        final wSnap = await txn.get(walletRef);

        final memberQs = await _db.collection('host_agency_members')
            .where('user_id', isEqualTo: receiverId)
            .limit(1)
            .get();
        DocumentSnapshot? agencyMemberSnap;
        if (memberQs.docs.isNotEmpty) {
           agencyMemberSnap = await txn.get(memberQs.docs.first.reference);
        }

        // ── THEN ALL WRITES ──
        txn.set(_db.collection('sent_gifts').doc(id), {
          'id': id,
          'gift_id': giftId,
          'gift_name': giftName,
          'animation_asset': animationAsset,
          'sender_id': senderId,
          'sender_name': senderName,
          'sender_photo_url': senderPhotoUrl,
          'receiver_id': receiverId,
          'receiver_name': receiverName,
          'room_id': roomId,
          'value': value,
          'count': count,
          'created_at': DateTime.now().toIso8601String(),
        });

        txn.set(_db.collection('room_messages').doc(const Uuid().v4()), {
          'msg_id': const Uuid().v4(),
          'room_id': roomId,
          'sender_uid': senderId,
          'sender_name': senderName,
          'type': 'gift',
          'text': '$senderName 🎁 $giftName x$count → $receiverName',
          'image_url': animationAsset ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });

        final sd = senderSnap.data() ?? {};
        final sentTotal = _asInt(sd['total_gifts_sent']);
        txn.update(senderRef, {
          'coins': senderCoins - totalCost,
          'total_gifts_sent': sentTotal + totalCost,
        });

        if (recvSnap.exists) {
          final rd = recvSnap.data() ?? {};
          txn.update(receiverRef, {
            'diamonds': _asInt(rd['diamonds']) + totalCost,
            'total_gifts_received': _asInt(rd['total_gifts_received']) + totalCost,
          });
        }

        if (roomSnap.exists) {
          final rm = roomSnap.data() ?? {};
          txn.update(roomRef, {
            'total_gifts': _asInt(rm['total_gifts']) + totalCost,
            'hot_value': _asInt(rm['hot_value']) + totalCost,
          });
        }

        if (wSnap.exists) {
          final wd = wSnap.data() ?? {};
          txn.update(walletRef, {'diamond_balance': _asInt(wd['diamond_balance']) + totalCost});
        } else {
          txn.set(walletRef, {'user_id': receiverId, 'diamond_balance': totalCost, 'gold_balance': 0});
        }

        if (agencyMemberSnap != null && agencyMemberSnap.exists) {
          final md = agencyMemberSnap.data() as Map<String, dynamic>? ?? {};
          txn.update(agencyMemberSnap.reference, {
            'diamonds_available': _asInt(md['diamonds_available']) + totalCost,
            'diamonds_earned_monthly': _asInt(md['diamonds_earned_monthly']) + totalCost,
            'diamonds_earned_cumulative': _asInt(md['diamonds_earned_cumulative']) + totalCost,
          });
        }
      });
    } catch (e) {
      debugPrint('sendGift: transaction failed (insufficient coins?): $e');
      return false;
    }

    // Evaluate targets asynchronously (do not await)
    AgencyTargetEvaluator.evaluateHostTargets(receiverId);

    // Real-time notification for the receiver (non-fatal)
    try {
      await sendNotification(
        uid: receiverId,
        type: 'gift',
        actorUid: senderId,
        title: '🎁 هدية من $senderName',
        body: '$senderName أرسل لك "$giftName" x$count ($totalCost)',
        data: <String, dynamic>{
          'sender_name': senderName,
          'sender_photo': senderPhotoUrl,
          'gift_id': giftId,
          'gift_name': giftName,
          'gift_image': animationAsset ?? '',
          'value': value,
          'count': count,
          'room_id': roomId,
        },
      );
    } catch (e) {
      debugPrint('sendGift: notification error: $e');
    }

    // XP side-effects (non-fatal)
    try {
      final levelService = LevelService();
      await levelService.loadAllLevels();
      await levelService.addExp(uid: senderId, type: 'wealth', amount: totalCost);
      await levelService.addExp(uid: receiverId, type: 'gems', amount: totalCost);
    } catch (e) {
      debugPrint('sendGift: XP award error: $e');
    }

    return true;
  }

  /// ═══════════════════════════════════════════════════════
  /// LUCKY GIFTS & BURST SYSTEM (FIREBASE FIRESTORE)
  /// ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> sendLuckyGift({
    required String roomId,
    required String giftId,
    required String giftName,
    required String giftNameAr,
    required String giftIconUrl,
    required String giftCoverUrl,
    required String giftBgUrl,
    String? svgaAnimUrl,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    required int value,
    int count = 1,
    String? comboId,
    int comboCount = 1,
  }) async {
    final multipliers = _drawLuckyMultipliers(count);
    int totalWonCoins = 0;
    for (final m in multipliers) {
      totalWonCoins += (value * m);
    }
    final totalCost = value * count;
    final isBigWin = multipliers.any((m) => m >= 50);
    final maxMultiplier = multipliers.isEmpty ? 0 : multipliers.reduce((curr, next) => curr > next ? curr : next);

    final id = const Uuid().v4();
    final senderRef = _db.collection('users').doc(senderId);

    try {
      await _db.runTransaction((txn) async {
        final senderSnap = await txn.get(senderRef);
        if (!senderSnap.exists) throw Exception('sender missing');
        final senderCoins = _asInt(senderSnap.data()?['coins']);
        if (senderCoins < totalCost) throw Exception('insufficient coins');

        final receiverRef = _db.collection('users').doc(receiverId);
        final recvSnap = await txn.get(receiverRef);

        final roomRef = _db.collection('rooms').doc(roomId);
        final roomSnap = await txn.get(roomRef);

        final walletRef = _db.collection('user_wallets').doc(receiverId);
        final wSnap = await txn.get(walletRef);

        // تسجيل العملية في sent_lucky_gifts
        txn.set(_db.collection('sent_lucky_gifts').doc(id), {
          'id': id,
          'gift_id': giftId,
          'gift_name': giftName,
          'gift_name_ar': giftNameAr,
          'gift_icon_url': giftIconUrl,
          'sender_id': senderId,
          'sender_name': senderName,
          'sender_photo_url': senderPhotoUrl,
          'receiver_id': receiverId,
          'receiver_name': receiverName,
          'room_id': roomId,
          'value': value,
          'count': count,
          'combo_id': comboId ?? id,
          'combo_count': comboCount,
          'won_coins': totalWonCoins,
          'multipliers': multipliers,
          'is_big_win': isBigWin,
          'created_at': DateTime.now().toIso8601String(),
        });

        // بث الحدث اللحظي للغرفة عبر room_messages
        txn.set(_db.collection('room_messages').doc(const Uuid().v4()), {
          'msg_id': const Uuid().v4(),
          'room_id': roomId,
          'sender_uid': senderId,
          'sender_name': senderName,
          'type': 'lucky_gift',
          'text': '$senderName 🍀 $giftNameAr x$count (فاز بـ $totalWonCoins 🪙)',
          'gift_payload': {
            'roomId': roomId,
            'sender': {
              'id': senderId,
              'nickname': senderName,
              'avatar': senderPhotoUrl,
            },
            'receiver': {
              'id': receiverId,
              'nickname': receiverName,
            },
            'gift': {
              'id': giftId,
              'giftName': giftName,
              'giftNameAr': giftNameAr,
              'coinPrice': value,
              'giftIconUrl': giftIconUrl,
              'giftCoverUrl': giftCoverUrl,
              'giftBgUrl': giftBgUrl,
              'svgaAnimUrl': svgaAnimUrl,
            },
            'combo': {
              'comboId': comboId ?? id,
              'comboCount': comboCount,
              'times': count,
            },
            'results': {
              'multipliers': multipliers,
              'cards': List.generate(multipliers.length, (i) => {
                'index': i,
                'multiplier': multipliers[i],
                'wonCoins': value * multipliers[i],
                'giftName': giftNameAr,
                'giftIcon': giftIconUrl,
              }),
              'totalWonCoins': totalWonCoins,
              'maxMultiplier': maxMultiplier,
              'isBigWin': isBigWin,
            },
          },
          'created_at': DateTime.now().toIso8601String(),
        });

        // خصم التكلفة وإيداع أرباح الحظ في محفظة المرسل ذرّياً
        final sd = senderSnap.data() ?? {};
        final sentTotal = _asInt(sd['total_gifts_sent']);
        txn.update(senderRef, {
          'coins': senderCoins - totalCost + totalWonCoins,
          'total_gifts_sent': sentTotal + totalCost,
        });

        if (recvSnap.exists) {
          final rd = recvSnap.data() ?? {};
          txn.update(receiverRef, {
            'diamonds': _asInt(rd['diamonds']) + totalCost,
            'total_gifts_received': _asInt(rd['total_gifts_received']) + totalCost,
          });
        }

        if (roomSnap.exists) {
          final rm = roomSnap.data() ?? {};
          txn.update(roomRef, {
            'total_gifts': _asInt(rm['total_gifts']) + totalCost,
            'hot_value': _asInt(rm['hot_value']) + totalCost,
          });
        }

        if (wSnap.exists) {
          final wd = wSnap.data() ?? {};
          txn.update(walletRef, {'diamond_balance': _asInt(wd['diamond_balance']) + totalCost});
        } else {
          txn.set(walletRef, {'user_id': receiverId, 'diamond_balance': totalCost, 'gold_balance': 0});
        }
      });

      // بث الفوز الكبير عبر جميع الغرف في التطبيق (Global Big Win Broadcast)
      if (isBigWin) {
        _db.collection('global_announcements').add({
          'type': 'lucky_big_win',
          'sender_name': senderName,
          'gift_name': giftNameAr,
          'room_id': roomId,
          'multiplier': maxMultiplier,
          'total_won': totalWonCoins,
          'created_at': DateTime.now().toIso8601String(),
        }).catchError((err) {
          debugPrint('global_announcements error: $err');
        });
      }

      return {
        'success': true,
        'wonCoins': totalWonCoins,
        'multipliers': multipliers,
        'maxMultiplier': maxMultiplier,
        'isBigWin': isBigWin,
      };
    } catch (e) {
      debugPrint('sendLuckyGift error: $e');
      return null;
    }
  }

  /// استماع للبث العام للفوز الكبير عبر كافة الغرف
  Stream<Map<String, dynamic>> globalBigWinStream() {
    return _db
        .collection('global_announcements')
        .where('type', isEqualTo: 'lucky_big_win')
        .limit(5)
        .snapshots()
        .where((snap) => snap.docs.isNotEmpty)
        .map((snap) => snap.docs.first.data());
  }

  List<int> _drawLuckyMultipliers(int count) {
    final odds = [
      {'multiplier': 0, 'weight': 650},
      {'multiplier': 1, 'weight': 200},
      {'multiplier': 2, 'weight': 90},
      {'multiplier': 5, 'weight': 40},
      {'multiplier': 10, 'weight': 15},
      {'multiplier': 50, 'weight': 4},
      {'multiplier': 100, 'weight': 1},
      {'multiplier': 500, 'weight': 1},
    ];

    final totalWeight = odds.fold<int>(0, (sum, item) => sum + (item['weight'] as int));
    final random = Random.secure();
    final results = <int>[];

    for (int c = 0; c < count; c++) {
      final roll = random.nextInt(totalWeight);
      int current = 0;
      int selected = 0;
      for (final item in odds) {
        current += (item['weight'] as int);
        if (roll < current) {
          selected = item['multiplier'] as int;
          break;
        }
      }
      results.add(selected);
    }
    return results;
  }

  Stream<List<gm.SentGiftModel>> sentGiftsStream(String roomId) {
    return _db
        .collection('sent_gifts')
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .map((snap) => snap.docs.map((e) => gm.SentGiftModel.fromMap(_data(e))).toList());
  }

  Stream<List<gm.SentGiftModel>> userReceivedGiftsStream(String uid) {
    return _db
        .collection('sent_gifts')
        .where('receiver_id', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((e) => gm.SentGiftModel.fromMap(_data(e))).toList());
  }

  Future<List<gm.SentGiftModel>> getReceivedGifts(String uid) async {
    try {
      final snap = await _db
          .collection('sent_gifts')
          .where('receiver_id', isEqualTo: uid)
          .limit(50)
          .get();
      final list = snap.docs.map((e) => gm.SentGiftModel.fromMap(_data(e))).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (e) {
      debugPrint('getReceivedGifts error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════════════════════

  Future<void> saveUser(UserModel user) async {
    final data = user.toMap();
    data['uid'] = user.uid;
    await _db.collection('users').doc(user.uid).set(_stripNulls(data), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final m = doc.data() ?? {};
    return UserModel.fromMap({...m, 'uid': uid});
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final m = snap.data() ?? {};
      return UserModel.fromMap({...m, 'uid': uid});
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(_stripNulls(data));
  }

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _db.collection('users').get();
    return snap.docs.map((e) => UserModel.fromMap(_data(e))).toList();
  }

  Stream<List<UserModel>> allUsersStream() {
    return _db
        .collection('users')
        .snapshots()
        .map((snap) => snap.docs.map((e) => UserModel.fromMap(_data(e))).toList());
  }

  /// ترتيب المستخدمين حسب حقل عدّاد (total_gifts_sent / total_gifts_received).
  Future<List<Map<String, dynamic>>> getUserRanking({
    required String orderByField,
    int limit = 50,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .orderBy(orderByField, descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((e) {
        final d = e.data();
        return <String, dynamic>{
          'uid': e.id,
          'id': (d['customId'] ?? d['id'] ?? '').toString(),
          'name': (d['name'] ?? '').toString(),
          'photo_url': (d['photo_url'] ?? d['photoUrl'] ?? '').toString(),
          'level': d['level'] ?? 1,
          'total_gifts_sent': _asInt(d['total_gifts_sent']),
          'total_gifts_received': _asInt(d['total_gifts_received']),
        };
      }).toList();
    } catch (e) {
      debugPrint('getUserRanking($orderByField) failed: $e');
      return const [];
    }
  }

  /// ترتيب الغرف حسب إجمالي الهدايا.
  Future<List<Map<String, dynamic>>> getRoomRanking({int limit = 50}) async {
    try {
      final snap = await _db
          .collection('rooms')
          .orderBy('total_gifts', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((e) {
        final d = e.data();
        return <String, dynamic>{
          'uid': e.id,
          'name': (d['name'] ?? '').toString(),
          'hostName': (d['host_name'] ?? '').toString(),
          'photo_url': (d['cover_image'] ?? d['room_photo_url'] ?? '').toString(),
          'points': _asInt(d['total_gifts']),
        };
      }).toList();
    } catch (e) {
      debugPrint('getRoomRanking failed: $e');
      return const [];
    }
  }

  Future<void> saveAppConfig(String key, dynamic value) async {
    await _db.collection('app_config').doc(key).set({'key': key, 'value': value});
  }

  Future<dynamic> getAppConfig(String key) async {
    final doc = await _db.collection('app_config').doc(key).get();
    return doc.data()?['value'];
  }

  Stream<Map<String, dynamic>> appConfigStream() {
    return _db.collection('app_config').snapshots().map((snap) {
      return {for (final e in snap.docs) e.id: e.data()['value']};
    });
  }

  // ═══════════════════════════════════════════════════════
  // GIFT CATALOG + CATEGORIES + BANNERS
  // ═══════════════════════════════════════════════════════

  Stream<List<gm.GiftModel>> giftsStream() {
    return _db.collection('gifts').snapshots().map((snap) {
      final gifts = snap.docs.map((e) => gm.GiftModel.fromMap(_data(e))).toList();
      gifts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return gifts;
    });
  }

  Future<Map<String, gm.GiftModel>> getGiftsCatalog() async {
    try {
      final snap = await _db.collection('gifts').get();
      return {for (final e in snap.docs) e.id: gm.GiftModel.fromMap(_data(e))};
    } catch (e) {
      debugPrint('getGiftsCatalog error: $e');
      return {};
    }
  }

  Future<List<gm.GiftModel>> getCpGiftsFromCatalog() async {
    try {
      final snap = await _db
          .collection('gifts')
          .where('is_cp_gift', isEqualTo: true)
          .get();
      final list = snap.docs.map((e) => gm.GiftModel.fromMap(_data(e))).toList();
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    } catch (e) {
      debugPrint('getCpGiftsFromCatalog error: $e');
      return [];
    }
  }

  Stream<List<GiftCategory>> giftCategoriesStream() {
    return _db.collection('gift_categories').snapshots().map((snap) {
      final cats = snap.docs.map((e) => GiftCategory.fromMap(_data(e))).toList();
      cats.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return cats;
    });
  }

  Future<List<GiftCategory>> getGiftCategories() async {
    try {
      final snap = await _db.collection('gift_categories').get();
      final list = snap.docs.map((e) => GiftCategory.fromMap(_data(e))).toList();
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    } catch (e) {
      debugPrint('getGiftCategories error: $e');
      return [];
    }
  }

  Future<void> saveGiftCategory(GiftCategory category) async {
    await _db.collection('gift_categories').doc(category.id).set(category.toMap());
  }

  Future<void> deleteGiftCategory(String id) async {
    await _db.collection('gift_categories').doc(id).delete();
  }

  Future<void> saveGift(gm.GiftModel gift) async {
    await _db.collection('gifts').doc(gift.id).set(gift.toMap());
  }

  Future<void> deleteGift(String id) async {
    await _db.collection('gifts').doc(id).delete();
  }

  Stream<List<GiftBannerConfig>> giftBannerConfigsStream() {
    return _db
        .collection('gift_banner_configs')
        .snapshots()
        .map((snap) => snap.docs.map((e) => GiftBannerConfig.fromMap(_data(e))).toList());
  }

  Future<List<GiftBannerConfig>> getGiftBannerConfigs() async {
    try {
      final snap = await _db.collection('gift_banner_configs').get();
      return snap.docs.map((e) => GiftBannerConfig.fromMap(_data(e))).toList();
    } catch (e) {
      debugPrint('getGiftBannerConfigs error: $e');
      return [];
    }
  }

  Future<void> saveGiftBannerConfig(GiftBannerConfig config) async {
    await _db.collection('gift_banner_configs').doc(config.id).set(config.toMap());
  }

  Future<void> deleteGiftBannerConfig(String id) async {
    await _db.collection('gift_banner_configs').doc(id).delete();
  }

  Future<String> uploadGiftBannerSvga(String filePath, String fileName) async {
    try {
      final path = filePath.startsWith('file://') ? Uri.parse(filePath).toFilePath() : filePath;
      final url = await CloudinaryService().upload(
        File(path),
        publicId: 'admin-uploads/$fileName',
        type: CloudinaryResourceType.raw,
      );
      return url;
    } catch (e) {
      debugPrint('uploadGiftBannerSvga error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // RANKING FRAMES
  // ═══════════════════════════════════════════════════════

  Future<List<RankingFrameConfig>> getRankingFrames() async {
    try {
      final snap = await _db.collection('ranking_frames').get();
      return snap.docs.map((e) => RankingFrameConfig.fromMap(_data(e))).toList();
    } catch (e) {
      debugPrint('getRankingFrames error: $e');
      return [];
    }
  }

  Future<void> saveRankingFrame(RankingFrameConfig config) async {
    final map = config.toMap();
    final id = map['id']?.toString() ?? '${map['category']}_${map['rank']}';
    await _db.collection('ranking_frames').doc(id).set(map);
  }

  Future<void> deleteRankingFrame(String id) async {
    await _db.collection('ranking_frames').doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════
  // STORE
  // ═══════════════════════════════════════════════════════

  Map<String, StoreItemModel> _storeItems = {};

  Stream<List<StoreItemModel>> storeItemsStream() {
    return _db.collection('store_items').snapshots().map((snap) {
      final items = snap.docs.map((e) => StoreItemModel.fromMap(_data(e))).toList();
      _storeItems = {for (final item in items) item.itemId: item};
      return items;
    });
  }

  Future<List<StoreItemModel>> getStoreItems() async {
    final snap = await _db.collection('store_items').get();
    final items = snap.docs.map((e) => StoreItemModel.fromMap(_data(e))).toList();
    _storeItems = {for (final item in items) item.itemId: item};
    return items;
  }

  StoreItemModel? getStoreItemSync(String itemId) => _storeItems[itemId];

  Stream<List<BannerConfig>> bannersStream() {
    return _db.collection('banners').snapshots().map((snap) {
      final banners = snap.docs
          .map((e) => BannerConfig.fromMap(_data(e)))
          .where((b) => b.active && b.imageUrl.isNotEmpty)
          .toList();
      banners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return banners;
    });
  }

  Future<void> addStoreItem(StoreItemModel item) async {
    await _db.collection('store_items').doc(item.itemId).set(item.toMap());
  }

  Future<StoreItemModel?> getStoreItem(String itemId) async {
    final doc = await _db.collection('store_items').doc(itemId).get();
    if (!doc.exists) return null;
    return StoreItemModel.fromMap(_data(doc));
  }

  // ═══════════════════════════════════════════════════════
  // BACKPACK & PURCHASES
  // ═══════════════════════════════════════════════════════

  Future<bool> purchaseItem(String uid, StoreItemModel item) async {
    final userRef = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((txn) async {
        final snap = await txn.get(userRef);
        if (!snap.exists) throw Exception('user missing');
        final d = snap.data() ?? {};
        final coins = (d['coins'] ?? 0) as int;
        final owned = List<String>.from(d['owned_items'] ?? []);
        if (coins < item.price) throw Exception('insufficient coins');
        if (!owned.contains(item.itemId)) owned.add(item.itemId);
        txn.update(userRef, {'coins': coins - item.price, 'owned_items': owned});
      });
      return true;
    } catch (e) {
      debugPrint('purchaseItem error: $e');
      return false;
    }
  }

  Future<void> equipItem(String uid, String itemId, String category) async {
    final updateMap = <String, dynamic>{};
    switch (category) {
      case 'frame':
        updateMap['active_frame'] = itemId;
        break;
      case 'headwear':
        updateMap['active_headwear'] = itemId;
        break;
      case 'bubble':
        final storeItem = getStoreItemSync(itemId);
        updateMap['active_bubble'] = storeItem?.svgaAsset ?? storeItem?.iconAsset ?? '';
        break;
      case 'entrance':
        updateMap['active_entrance'] = itemId;
        break;
      case 'car':
        updateMap['active_car'] = itemId;
        break;
      case 'cover':
        updateMap['active_cover'] = itemId;
        break;
    }
    await _db.collection('users').doc(uid).update(updateMap);
  }

  Future<void> unequipItem(String uid, String category) async {
    final updateMap = <String, dynamic>{};
    switch (category) {
      case 'frame':
        updateMap['active_frame'] = null;
        break;
      case 'headwear':
        updateMap['active_headwear'] = null;
        break;
      case 'bubble':
        updateMap['active_bubble'] = null;
        break;
      case 'entrance':
        updateMap['active_entrance'] = null;
        break;
      case 'car':
        updateMap['active_car'] = null;
        break;
      case 'cover':
        updateMap['active_cover'] = null;
        break;
    }
    await _db.collection('users').doc(uid).set(_stripNulls(updateMap), SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════
  // GIFTED ITEMS
  // ═══════════════════════════════════════════════════════

  Stream<List<GiftedItemModel>> userGiftedItemsStream(String uid) {
    return _db
        .collection('gifted_items')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((e) => GiftedItemModel.fromMap(_data(e), e.id)).toList());
  }

  Future<List<GiftedItemModel>> getGiftedItems(String uid) async {
    final snap = await _db.collection('gifted_items').where('uid', isEqualTo: uid).get();
    return snap.docs.map((e) => GiftedItemModel.fromMap(_data(e), e.id)).toList();
  }

  Future<List<GiftedItemModel>> getGiftedItemsByCategory(String uid, String category) async {
    try {
      final snap = await _db
          .collection('gifted_items')
          .where('uid', isEqualTo: uid)
          .where('item_category', isEqualTo: category)
          .get();
      return snap.docs.map((e) => GiftedItemModel.fromMap(_data(e), e.id)).toList();
    } catch (e) {
      debugPrint('getGiftedItemsByCategory error: $e');
      return [];
    }
  }

  Future<void> removeGiftedItem(String id) async {
    await _db.collection('gifted_items').doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════
  // IMAGE MESSAGES
  // ═══════════════════════════════════════════════════════

  Future<void> sendImageMessage(String roomId, String imageUrl, String senderUid,
      String senderName, String senderPhotoUrl) async {
    final msgId = const Uuid().v4();
    final msg = MessageModel(
      msgId: msgId,
      senderUid: senderUid,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: '',
      imageUrl: imageUrl,
      type: 'image',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final map = msg.toMap();
    map['room_id'] = roomId;
    await _db.collection('room_messages').doc(msgId).set(map);
  }

  // ═══════════════════════════════════════════════════════
  // PRIVATE MESSAGING
  // ═══════════════════════════════════════════════════════

  Future<String> _getOrCreateConversationId(String uid1, String uid2) async {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendPrivateMessage({
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required String text,
    String? imageUrl,
    String type = 'text',
  }) async {
    // التحقق من الحظر
    final blockDoc = await _db.collection('blocks').doc('${receiverId}_$senderId').get();
    if (blockDoc.exists) {
      throw Exception('لا يمكنك إرسال رسالة لأن هذا المستخدم قام بحظرك.');
    }
    final myBlockDoc = await _db.collection('blocks').doc('${senderId}_$receiverId').get();
    if (myBlockDoc.exists) {
      throw Exception('لقد قمت بحظر هذا المستخدم. يجب إزالة الحظر أولاً.');
    }

    final convId = await _getOrCreateConversationId(senderId, receiverId);
    final msgId = const Uuid().v4();
    final msg = MessageModel(
      msgId: msgId,
      senderUid: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: text,
      imageUrl: imageUrl,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final data = msg.toMap();
    data['conv_id'] = convId;
    data['id'] = msgId;
    await _db.collection('private_messages').doc(msgId).set(data);

    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    for (final uid in [senderId, receiverId]) {
      final isSender = uid == senderId;
      await _db.collection('conversations').doc('${uid}_$convId').set({
        'uid': uid,
        'conversationId': convId,
        'otherUid': isSender ? receiverId : senderId,
        'otherName': isSender ? receiverName : senderName,
        'otherPhotoUrl': isSender ? receiverPhotoUrl : senderPhotoUrl,
        'lastMessage': type == 'image' ? '[صورة]' : text,
        'lastMessageTime': nowMillis,
        'unreadCount': isSender ? 0 : FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
  }

  Stream<List<Map<String, dynamic>>> conversationsStream(String uid) {
    return _db
        .collection('conversations')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final convs = snap.docs.map((e) => Map<String, dynamic>.from(e.data())).toList();
      convs.sort((a, b) {
        final at = a['lastMessageTime'] as int? ?? 0;
        final bt = b['lastMessageTime'] as int? ?? 0;
        return bt.compareTo(at);
      });
      return convs;
    });
  }

  Stream<List<MessageModel>> privateMessagesStream(String conversationId) {
    return _db
        .collection('private_messages')
        .where('conv_id', isEqualTo: conversationId)
        .snapshots()
        .map((snap) {
      final msgs = snap.docs.map((e) => MessageModel.fromMap(_data(e))).toList();
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return msgs;
    });
  }

  Future<void> markConversationRead(String uid, String conversationId) async {
    await _db.collection('conversations').doc('${uid}_$conversationId').update({'unreadCount': 0});
  }

  // ═══════════════════════════════════════════════════════
  // DIAMOND ↔ COIN EXCHANGE
  // ═══════════════════════════════════════════════════════

  Future<({bool success, int coinsReceived, String? error})> exchangeDiamondsToCoins({
    required String uid,
    required int diamonds,
    required int rate,
  }) async {
    if (diamonds < rate) {
      return (success: false, coinsReceived: 0, error: 'الحد الأدنى $rate ألماس');
    }
    final userRef = _db.collection('users').doc(uid);
    try {
      final result = await _db.runTransaction((txn) async {
        final snap = await txn.get(userRef);
        if (!snap.exists) throw Exception('المستخدم غير موجود');
        final d = snap.data() ?? {};
        final bal = (d['diamonds'] ?? 0) as int;
        if (bal < diamonds) throw Exception('رصيد ألماس غير كافٍ');
        final curCoins = (d['coins'] ?? 0) as int;
        final coinsReceived = diamonds ~/ rate;
        txn.update(userRef, {'diamonds': bal - diamonds, 'coins': curCoins + coinsReceived});

        final walletRef = _db.collection('user_wallets').doc(uid);
        final wSnap = await txn.get(walletRef);
        if (wSnap.exists) {
          final wd = wSnap.data() ?? {};
          txn.update(walletRef, {
            'diamond_balance': ((wd['diamond_balance'] ?? 0) as int) - diamonds,
            'gold_balance': ((wd['gold_balance'] ?? 0) as int) + coinsReceived,
          });
        }
        return coinsReceived;
      });
      return (success: true, coinsReceived: result, error: null);
    } catch (e) {
      return (success: false, coinsReceived: 0, error: 'فشل التبادل: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // RECHARGE
  // ═══════════════════════════════════════════════════════

  Future<void> addCoins(String uid, int amount) async {
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) throw Exception('user missing');
        final d = snap.data() ?? {};
        txn.update(ref, {'coins': ((d['coins'] ?? 0) as int) + amount});
      });
    } catch (e) {
      debugPrint('addCoins error: $e');
    }
    try {
      final levelService = LevelService();
      await levelService.loadAllLevels();
      await levelService.addExp(uid: uid, type: 'recharge', amount: amount);
    } catch (e) {
      debugPrint('addCoins: recharge XP error: $e');
    }
  }

  Future<bool> deductCoins(String uid, int amount, String reason) async {
    if (amount <= 0) return true;
    try {
      final ref = _db.collection('users').doc(uid);
      return await _db.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return false;
        final d = snap.data()!;
        final curCoins = (d['coins'] ?? 0) as int;
        if (curCoins < amount) return false;
        txn.update(ref, {'coins': curCoins - amount});
        return true;
      });
    } catch (e) {
      debugPrint('deductCoins error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // USER FOLLOW
  // ═══════════════════════════════════════════════════════

  Future<void> followUser(String uid, String targetUid) async {
    if (uid == targetUid) return;
    try {
      await _db.collection('follows').doc('${uid}_$targetUid').set({
        'follower_uid': uid,
        'following_uid': targetUid,
        'created_at': _now(),
      });
      await _incrementCounter('users', uid, 'following', 1);
      await _incrementCounter('users', targetUid, 'followers', 1);
      await _db.collection('notifications').add({
        'id': const Uuid().v4(),
        'uid': targetUid,
        'type': 'follow',
        'actor_uid': uid,
        'title': 'New Follower',
        'body': 'started following you',
        'created_at': _now(),
      });
    } catch (e) {
      debugPrint('followUser error: $e');
    }
  }

  Future<void> unfollowUser(String uid, String targetUid) async {
    if (uid == targetUid) return;
    try {
      await _db.collection('follows').doc('${uid}_$targetUid').delete();
      await _incrementCounter('users', uid, 'following', -1);
      await _incrementCounter('users', targetUid, 'followers', -1);
    } catch (e) {
      debugPrint('unfollowUser error: $e');
    }
  }

  Future<bool> isFollowing(String uid, String targetUid) async {
    if (uid.isEmpty || targetUid.isEmpty) return false;
    try {
      final doc = await _db.collection('follows').doc('${uid}_$targetUid').get();
      return doc.exists;
    } catch (e) {
      debugPrint('isFollowing error: $e');
      return false;
    }
  }

  Future<void> recordProfileVisit({
    required String visitedUid,
    required String visitorUid,
    String? visitorName,
    String? visitorPhoto,
  }) async {
    if (visitedUid.isEmpty || visitorUid.isEmpty || visitedUid == visitorUid) {
      return;
    }
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final visitDocId = '${visitedUid}_$visitorUid';
      await _db.collection('profile_visits').doc(visitDocId).set({
        'visited_uid': visitedUid,
        'visitor_uid': visitorUid,
        'visitor_name': visitorName ?? '',
        'visitor_photo': visitorPhoto ?? '',
        'visited_at': now,
      }, SetOptions(merge: true));

      final countSnap = await _db
          .collection('profile_visits')
          .where('visited_uid', isEqualTo: visitedUid)
          .count()
          .get();
      final int count = countSnap.count ?? 0;
      await _db.collection('users').doc(visitedUid).update({
        'visitors': count,
      });
    } catch (e) {
      debugPrint('recordProfileVisit error: $e');
    }
  }

  Future<int> incrementVisitors(String uid) async {
    try {
      final countSnap = await _db
          .collection('profile_visits')
          .where('visited_uid', isEqualTo: uid)
          .count()
          .get();
      final int count = countSnap.count ?? 0;
      await _db.collection('users').doc(uid).update({'visitors': count});
      return count;
    } catch (e) {
      debugPrint('incrementVisitors error: $e');
      return 0;
    }
  }

  Future<void> _incrementCounter(String coll, String docId, String field, int delta) async {
    try {
      final ref = _db.collection(coll).doc(docId);
      final snap = await ref.get();
      if (!snap.exists) return;
      await ref.update({field: ((snap.data()?[field] ?? 0) as int) + delta});
    } catch (e) {
      debugPrint('_incrementCounter error: $e');
    }
  }

  Future<String?> getUserCurrentRoomId(String uid) async {
    try {
      final snap = await _db.collection('room_members').where('uid', isEqualTo: uid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['room_id']?.toString();
    } catch (e) {
      debugPrint('getUserCurrentRoomId error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getFollowing(String uid) async {
    try {
      final snap = await _db.collection('follows').where('follower_uid', isEqualTo: uid).get();
      final uids = snap.docs
          .map((e) => e.data()['following_uid']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      return await _batchFetchUsers(uids);
    } catch (e) {
      debugPrint('getFollowing error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFans(String uid) async {
    try {
      final snap = await _db.collection('follows').where('following_uid', isEqualTo: uid).get();
      final uids = snap.docs
          .map((e) => e.data()['follower_uid']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      return await _batchFetchUsers(uids);
    } catch (e) {
      debugPrint('getFans error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _batchFetchUsers(List<String> uids) async {
    final users = <Map<String, dynamic>>[];
    for (final uid in uids) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (!doc.exists) continue;
        final d = doc.data() ?? {};
        final photo = d['photoUrl']?.toString() ?? d['photo_url']?.toString() ?? d['avatar']?.toString() ?? '';
        final name = d['name']?.toString() ?? 'User';
        users.add({
          'uid': uid,
          'id': uid,
          'name': name,
          'photo_url': photo,
          'avatar': photo,
          'gender': d['gender']?.toString() ?? 'male',
          'level': (d['level'] as num?)?.toInt() ?? 1,
          'country_idx': (d['country_idx'] as num?)?.toInt() ?? 0,
          'custom_id': d['custom_id']?.toString() ?? d['customId']?.toString() ?? '',
        });
      } catch (_) {}
    }
    return users;
  }

  Future<List<Map<String, dynamic>>> getVisitors(String uid) async {
    if (uid.isEmpty) return [];
    try {
      final snap = await _db
          .collection('profile_visits')
          .where('visited_uid', isEqualTo: uid)
          .limit(50)
          .get();
      final items = snap.docs.map((e) => e.data()).toList();
      items.sort((a, b) => (b['visited_at'] ?? '').toString().compareTo((a['visited_at'] ?? '').toString()));
      
      final uids = items
          .map((e) => e['visitor_uid']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != uid)
          .toSet()
          .toList();

      final userMap = <String, Map<String, dynamic>>{};
      for (final u in await _batchFetchUsers(uids)) {
        userMap[u['uid'].toString()] = u;
      }
      final result = <Map<String, dynamic>>[];
      for (final item in items) {
        final visitorUid = item['visitor_uid']?.toString() ?? '';
        if (visitorUid.isEmpty || visitorUid == uid) continue;
        final user = userMap[visitorUid];
        if (user != null) {
          result.add({...user, 'time': item['visited_at']?.toString() ?? ''});
        } else {
          result.add({
            'uid': visitorUid,
            'id': visitorUid,
            'name': item['visitor_name']?.toString() ?? 'User',
            'photo_url': item['visitor_photo']?.toString() ?? '',
            'avatar': item['visitor_photo']?.toString() ?? '',
            'time': item['visited_at']?.toString() ?? '',
          });
        }
      }
      return result;
    } catch (e) {
      debugPrint('getVisitors error: $e');
      return [];
    }
  }

  Future<Map<String, int>> getVisitorHistoryDays(String uid) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final snap = await _db
          .collection('profile_visits')
          .where('visited_uid', isEqualTo: uid)
          .get();
      final dayCounts = <String, int>{};
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        dayCounts[key] = 0;
      }
      for (final e in snap.docs) {
        final ts = e.data()['visited_at']?.toString() ?? '';
        final dt = DateTime.tryParse(ts);
        if (dt != null && !dt.isBefore(sevenDaysAgo)) {
          final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          if (dayCounts.containsKey(key)) {
            dayCounts[key] = (dayCounts[key] ?? 0) + 1;
          }
        }
      }
      return dayCounts;
    } catch (e) {
      debugPrint('getVisitorHistoryDays error: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════
  // BADGES & NECKLACES
  // ═══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getBadgesCatalog() async {
    try {
      final snap = await _db.collection('badges').get();
      return snap.docs.map((e) => Map<String, dynamic>.from(e.data())).toList();
    } catch (e) {
      debugPrint('getBadgesCatalog error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNecklacesCatalog() async {
    try {
      final snap = await _db.collection('necklaces').get();
      final list = snap.docs.map((e) => Map<String, dynamic>.from(e.data())).toList();
      list.sort((a, b) => ((a['sort_order'] ?? 0) as int).compareTo((b['sort_order'] ?? 0) as int));
      return list;
    } catch (e) {
      debugPrint('getNecklacesCatalog error: $e');
      return [];
    }
  }

  Future<List<String>> awardRechargeNecklaces(String uid, int rechargeLevel) async {
    try {
      final cat = await getNecklacesCatalog();
      final eligible = <Map<String, dynamic>>[];
      for (final n in cat) {
        if (n['type']?.toString() == 'recharge') {
          final req = (n['required_recharge_level'] ?? 0).toInt();
          if (req > 0 && req <= rechargeLevel) {
            eligible.add(n);
          }
        }
      }
      if (eligible.isEmpty) return [];

      final userDoc = await _db.collection('users').doc(uid).get();
      final current = List<String>.from(userDoc.data()?['owned_necklaces'] ?? []);
      final toAdd = eligible
          .map((n) => n['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && !current.contains(id))
          .toList();
      if (toAdd.isEmpty) return [];

      final updated = [...current, ...toAdd];
      await updateUser(uid, {'owned_necklaces': updated});
      return toAdd;
    } catch (e) {
      debugPrint('awardRechargeNecklaces error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // ENTRANCE EFFECTS
  // ═══════════════════════════════════════════════════════

  Future<void> logEntrance(String roomId, String uid, String name, String photoUrl,
      String? entranceItem, {String? carItem}) async {
    final now = _now();
    if (entranceItem != null && entranceItem.isNotEmpty) {
      await _db.collection('room_messages').doc(const Uuid().v4()).set({
        'msg_id': const Uuid().v4(),
        'room_id': roomId,
        'sender_uid': uid,
        'sender_name': name,
        'sender_photo_url': photoUrl,
        'text': '$name entered the room',
        'type': 'entrance',
        'image_url': entranceItem,
        'created_at': now,
      });
    }
    if (carItem != null && carItem.isNotEmpty && carItem != entranceItem) {
      await _db.collection('room_messages').doc(const Uuid().v4()).set({
        'msg_id': const Uuid().v4(),
        'room_id': roomId,
        'sender_uid': uid,
        'sender_name': name,
        'sender_photo_url': photoUrl,
        'text': '$name entered with car',
        'type': 'entrance',
        'image_url': carItem,
        'created_at': now,
      });
    }
  }

  Future<void> logExit(String roomId, String name) async {
    await _db.collection('room_messages').doc(const Uuid().v4()).set({
      'msg_id': const Uuid().v4(),
      'room_id': roomId,
      'sender_uid': '',
      'sender_name': '',
      'sender_photo_url': '',
      'text': '$name left the room',
      'type': 'entrance',
      'created_at': _now(),
    });
  }

  Stream<List<Map<String, dynamic>>> entrancesStream(String roomId) {
    return _db
        .collection('room_messages')
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((e) => Map<String, dynamic>.from(e.data())).toList();
      list.sort((a, b) {
        final at = a['created_at']?.toString() ?? '';
        final bt = b['created_at']?.toString() ?? '';
        return bt.compareTo(at);
      });
      return list.where((e) => e['type'] == 'entrance').map((e) {
        return {
          'uid': e['sender_uid'],
          'name': e['sender_name'],
          'photoUrl': e['sender_photo_url'],
          'entranceItem': e['image_url']?.toString() ?? '',
          'timestamp': e['created_at'],
        };
      }).toList();
    });
  }

  // ═══════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════

  Stream<List<NotificationModel>> notificationsStream({String? uid}) {
    Query<Map<String, dynamic>> query = _db.collection('notifications');
    if (uid != null && uid.isNotEmpty) {
      query = query.where('uid', isEqualTo: uid);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map((e) => NotificationModel.fromMap(_data(e))).toList();
      list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return list;
    });
  }

  Future<void> sendNotification({
    required String uid,
    required String type,
    String actorUid = '',
    String title = '',
    String body = '',
    Map<String, dynamic>? data,
  }) async {
    await _db.collection('notifications').add({
      'id': const Uuid().v4(),
      'uid': uid,
      'type': type,
      'actor_uid': actorUid,
      'title': title,
      'body': body,
      'data': data,
      'created_at': _now(),
    });
  }

  Future<void> markNotificationRead(String id) async {
    await _db.collection('notifications').doc(id).update({'read': true});
  }

  Future<void> deleteNotification(String id) async {
    await _db.collection('notifications').doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════
  // REPORTS
  // ═══════════════════════════════════════════════════════

  Future<void> reportUser({
    required String reporterUid,
    required String reportedUid,
    required String reason,
    String? description,
  }) async {
    try {
      await _db.collection('reports').add({
        'id': const Uuid().v4(),
        'reporter_uid': reporterUid,
        'reported_uid': reportedUid,
        'reason': reason,
        'description': description ?? '',
        'status': 'pending',
        'created_at': _now(),
      });
    } catch (e) {
      debugPrint('reportUser error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getReports() async {
    try {
      final snap = await _db.collection('reports').get();
      final list = snap.docs.map((e) {
        final d = Map<String, dynamic>.from(e.data());
        d['id'] = e.id;
        return d;
      }).toList();
      list.sort((a, b) {
        final at = a['created_at']?.toString() ?? '';
        final bt = b['created_at']?.toString() ?? '';
        return bt.compareTo(at);
      });
      return list;
    } catch (e) {
      debugPrint('getReports error: $e');
      return [];
    }
  }

  Future<void> resolveReport(String reportId) async {
    try {
      await _db.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'resolved_at': _now(),
      });
    } catch (e) {
      debugPrint('resolveReport error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ROOM BLOCKS (BAN FROM ROOM)
  // ═══════════════════════════════════════════════════════

  Future<void> blockUserFromRoom(String roomId, String blockerUid, String blockedUid,
      {String reason = ''}) async {
    if (blockerUid == blockedUid) return;
    try {
      await _db.collection('room_blocks').doc('${roomId}_$blockedUid').set({
        'room_id': roomId,
        'blocker_uid': blockerUid,
        'blocked_uid': blockedUid,
        'reason': reason,
        'created_at': _now(),
      });
    } catch (e) {
      debugPrint('blockUserFromRoom error: $e');
    }
  }

  Future<void> unblockUserFromRoom(String roomId, String blockedUid) async {
    try {
      await _db.collection('room_blocks').doc('${roomId}_$blockedUid').delete();
    } catch (e) {
      debugPrint('unblockUserFromRoom error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRoomBlockedUsers(String roomId) async {
    try {
      final snap = await _db.collection('room_blocks').where('room_id', isEqualTo: roomId).get();
      return snap.docs.map((e) => Map<String, dynamic>.from(e.data())).toList();
    } catch (e) {
      debugPrint('getRoomBlockedUsers error: $e');
      return [];
    }
  }

  Future<List<String>> getRoomBlockedUids(String roomId) async {
    try {
      final snap = await _db.collection('room_blocks').where('room_id', isEqualTo: roomId).get();
      return snap.docs
          .map((e) => e.data()['blocked_uid']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('getRoomBlockedUids error: $e');
      return [];
    }
  }

  Future<bool> isUserBlockedFromRoom(String roomId, String uid) async {
    if (roomId.isEmpty || uid.isEmpty) return false;
    try {
      final doc = await _db.collection('room_blocks').doc('${roomId}_$uid').get();
      return doc.exists;
    } catch (e) {
      debugPrint('isUserBlockedFromRoom error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // BLOCKS
  // ═══════════════════════════════════════════════════════

  Future<void> blockUser(String blockerUid, String blockedUid) async {
    if (blockerUid == blockedUid) return;
    try {
      await _db.collection('blocks').doc('${blockerUid}_$blockedUid').set({
        'blocker_uid': blockerUid,
        'blocked_uid': blockedUid,
        'created_at': _now(),
      });
    } catch (e) {
      debugPrint('blockUser error: $e');
    }
  }

  Future<void> unblockUser(String blockerUid, String blockedUid) async {
    try {
      await _db.collection('blocks').doc('${blockerUid}_$blockedUid').delete();
    } catch (e) {
      debugPrint('unblockUser error: $e');
    }
  }

  Future<List<String>> getBlockedUids(String uid) async {
    try {
      final snap = await _db.collection('blocks').where('blocker_uid', isEqualTo: uid).get();
      return snap.docs
          .map((e) => e.data()['blocked_uid']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('getBlockedUids error: $e');
      return [];
    }
  }

  Future<bool> isBlocked(String uid, String targetUid) async {
    if (uid.isEmpty || targetUid.isEmpty) return false;
    try {
      final d1 = await _db.collection('blocks').doc('${uid}_$targetUid').get();
      if (d1.exists) return true;
      final d2 = await _db.collection('blocks').doc('${targetUid}_$uid').get();
      return d2.exists;
    } catch (e) {
      debugPrint('isBlocked error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // GENERIC (for admin / other modules)
  // ═══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAllDocs(String collection) async {
    final snap = await _db.collection(collection).get();
    return snap.docs.map((e) {
      final d = Map<String, dynamic>.from(e.data());
      d['id'] = e.id;
      return d;
    }).toList();
  }

  Future<void> setDoc(String collection, String docId, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(docId).set(data, SetOptions(merge: true));
  }

  Future<void> deleteDoc(String collection, String docId) async {
    await _db.collection(collection).doc(docId).delete();
  }

  /// Fetch Top 10 rankings for a room (Wealth = senders, Magic = receivers)
  Future<List<Map<String, dynamic>>> getRoomRankings({
    required String roomId,
    required bool isWealth,
    required String timeframe,
  }) async {
    // احسب منتصف الليل بتوقيت السعودية/مصر (UTC+3)
    final nowUtc = DateTime.now().toUtc();
    final ksaTime = nowUtc.add(const Duration(hours: 3));
    
    DateTime startDateUtc;
    if (timeframe == 'daily') {
      startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, ksaTime.day).subtract(const Duration(hours: 3));
    } else if (timeframe == 'weekly') {
      final daysToSubtract = ksaTime.weekday - 1;
      startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, ksaTime.day).subtract(Duration(days: daysToSubtract, hours: 3));
    } else { // monthly
      startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, 1).subtract(const Duration(hours: 3));
    }
    
    String startStr = startDateUtc.toIso8601String();

    try {
      final snap = await _db.collection('sent_gifts')
          .where('room_id', isEqualTo: roomId)
          .where('created_at', isGreaterThanOrEqualTo: startStr)
          .get();
      return _processRankings(snap.docs, isWealth);
    } catch (e) {
      // Fallback if composite index is missing
      final snap = await _db.collection('sent_gifts')
          .where('room_id', isEqualTo: roomId)
          .get();
      final filteredDocs = snap.docs.where((doc) {
        final d = doc.data();
        final created = d['created_at'] as String? ?? '';
        return created.compareTo(startStr) >= 0;
      }).toList();
      return _processRankings(filteredDocs, isWealth);
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalRankings({
    required bool isWealth,
    required String timeframe,
  }) async {
    if (timeframe == 'all') {
      return getUserRanking(
        orderByField: isWealth ? 'total_gifts_sent' : 'total_gifts_received',
      );
    }
    final nowUtc = DateTime.now().toUtc();
    final ksaTime = nowUtc.add(const Duration(hours: 3));
    
    DateTime startDateUtc;
    if (timeframe == 'daily') {
      startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, ksaTime.day).subtract(const Duration(hours: 3));
    } else if (timeframe == 'weekly') {
      final daysToSubtract = ksaTime.weekday - 1;
      startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, ksaTime.day).subtract(Duration(days: daysToSubtract, hours: 3));
    } else { // monthly
      startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, 1).subtract(const Duration(hours: 3));
    }
    
    String startStr = startDateUtc.toIso8601String();

    try {
      final snap = await _db.collection('sent_gifts')
          .where('created_at', isGreaterThanOrEqualTo: startStr)
          .get();
      return _processGlobalRankings(snap.docs, isWealth);
    } catch (e) {
      final snap = await _db.collection('sent_gifts').get();
      final filteredDocs = snap.docs.where((doc) {
        final d = doc.data();
        final created = d['created_at'] as String? ?? '';
        return created.compareTo(startStr) >= 0;
      }).toList();
      return _processGlobalRankings(filteredDocs, isWealth);
    }
  }

  Future<List<Map<String, dynamic>>> _processGlobalRankings(List<dynamic> docs, bool isWealth) async {
    final Map<String, int> totals = {};
    for (var doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final userId = isWealth ? d['sender_id'] : d['receiver_id'];
      final value = _asInt(d['value']) * _asInt(d['count']);
      if (userId == null) continue;
      totals[userId] = (totals[userId] ?? 0) + value;
    }

    final entries = totals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    final top50 = entries.take(50).toList();

    final List<Map<String, dynamic>> results = [];
    for (var entry in top50) {
      final userSnap = await _db.collection('users').doc(entry.key).get();
      final ud = userSnap.data() ?? {};
      results.add({
        'uid': entry.key,
        'id': (ud['customId'] ?? ud['id'] ?? '').toString(),
        'name': (ud['name'] ?? 'Unknown').toString(),
        'photo_url': (ud['photo_url'] ?? ud['photoUrl'] ?? '').toString(),
        'level': ud['level'] ?? 1,
        'total_gifts_sent': isWealth ? entry.value : _asInt(ud['total_gifts_sent']),
        'total_gifts_received': !isWealth ? entry.value : _asInt(ud['total_gifts_received']),
        'user_id': entry.key,
      });
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _processRankings(List<dynamic> docs, bool isWealth) async {
    final Map<String, int> totals = {};
    for (var doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final userId = isWealth ? d['sender_id'] : d['receiver_id'];
      final value = _asInt(d['value']) * _asInt(d['count']);
      if (userId == null) continue;
      totals[userId] = (totals[userId] ?? 0) + value;
    }

    final entries = totals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    final top10 = entries.take(10).toList();

    final List<Map<String, dynamic>> results = [];
    for (var entry in top10) {
      final userSnap = await _db.collection('users').doc(entry.key).get();
      final ud = userSnap.data() ?? {};
      results.add({
        'user_id': entry.key,
        'user_name': ud['name'] ?? 'Unknown',
        'user_photo_url': ud['photo_url'] ?? '',
        'total_value': entry.value,
      });
    }
    return results;
  }
  Future<List<Map<String, dynamic>>> getRoomGlobalRanking({
    int limit = 50,
  }) async {
    try {
      final snap = await _db
          .collection('rooms')
          .orderBy('total_gifts', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['title'] ?? 'Room',
          'photoUrl': data['image'] ?? '',
          'user_id': data['room_id'] ?? doc.id,
          'points': (data['total_gifts'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('getRoomGlobalRanking error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopMonthlyFans(String uid) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final ksaTime = nowUtc.add(const Duration(hours: 3));
      final startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, 1).subtract(const Duration(hours: 3));
      final startStr = startDateUtc.toIso8601String();

      final snap = await _db.collection('sent_gifts')
          .where('receiver_id', isEqualTo: uid)
          .where('created_at', isGreaterThanOrEqualTo: startStr)
          .get();

      return _processRankings(snap.docs, false);
    } catch (e) {
      debugPrint('getTopMonthlyFans error: ');
      // Fallback
      try {
        final snap = await _db.collection('sent_gifts')
            .where('receiver_id', isEqualTo: uid)
            .get();
        final nowUtc = DateTime.now().toUtc();
        final ksaTime = nowUtc.add(const Duration(hours: 3));
        final startDateUtc = DateTime.utc(ksaTime.year, ksaTime.month, 1).subtract(const Duration(hours: 3));
        final startStr = startDateUtc.toIso8601String();
        
        final filteredDocs = snap.docs.where((doc) {
          final d = doc.data();
          final created = d['created_at'] as String? ?? '';
          return created.compareTo(startStr) >= 0;
        }).toList();
        return _processRankings(filteredDocs, false);
      } catch (innerE) {
        debugPrint('getTopMonthlyFans fallback error: ');
        return [];
      }
    }
  }
}


