import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/firebase_service.dart';

/// CP (Relationships) service backed by Firestore.
///
/// Collections mirror the original Postgres tables:
///   cp_couples, cp_requests, cp_themes, cp_settings,
///   cp_gifts, cp_cars, cp_gift_logs, cp_rank_rewards
///
/// Response shapes match the original RPC output so screens are unchanged.
class CpService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ═══════════════════════════════════════════════════════
  // My Data
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getMyData() async {
    final uid = _uid;
    if (uid == null) return <String, dynamic>{'error': 'Not authenticated'};

    final couple = await _findActiveCoupleFor(uid);

    Map<String, dynamic>? activeTheme;
    if (couple != null) {
      final themeId = couple['active_theme_id'] as String?;
      if (themeId != null && themeId.isNotEmpty) {
        activeTheme = await _getTheme(themeId);
      }
    }

    final pending = await _findRequestsFor(uid, status: 'pending');
    final rejected = await _findRequestsFor(uid, status: 'rejected');
    final history = await _findHistoryFor(uid);

    final result = <String, dynamic>{
      'has_cp': couple != null,
      'active_theme': activeTheme,
      'pending_requests': pending,
      'rejected_requests': rejected,
      'history': history,
    };

    if (couple != null) {
      final partnerUid = couple['user1_uid'] == uid
          ? couple['user2_uid'] as String
          : couple['user1_uid'] as String;
      final partner = await FirebaseService().getUser(partnerUid);

      final startedRaw = couple['started_at'];
      final startedAt = _parseDate(startedRaw);
      final daysTogether = startedAt != null
          ? DateTime.now().difference(startedAt).inDays
          : 0;

      result['couple'] = <String, dynamic>{
        'id': couple['id'],
        'partner': <String, dynamic>{
          'uid': partnerUid,
          'name': partner?.name ?? '',
          'avatar': partner?.photoUrl ?? '',
        },
        'started_at': couple['started_at'],
        'countdown_end': couple['countdown_end'],
        'days_together': daysTogether,
        'total_score': (couple['total_score'] as num?)?.toInt() ?? 0,
        'week_score': (couple['week_score'] as num?)?.toInt() ?? 0,
        'month_score': (couple['month_score'] as num?)?.toInt() ?? 0,
        'theme': activeTheme,
      };
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════
  // Ranking
  // ═══════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getRanking({
    String period = 'week',
    int limit = 50,
  }) async {
    final scoreField = switch (period) {
      'week' => 'week_score',
      'month' => 'month_score',
      _ => 'total_score',
    };

    final snap = await _db.collection('cp_couples').orderBy(scoreField, descending: true).get();
    final rows = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      if (rows.length >= limit) break;
      final d = doc.data();
      if (d['ended_at'] != null) continue;

      final u1 = await FirebaseService().getUser(d['user1_uid'] as String? ?? '');
      final u2 = await FirebaseService().getUser(d['user2_uid'] as String? ?? '');

      rows.add(<String, dynamic>{
        'rank': rows.length + 1,
        'user1': <String, dynamic>{'name': u1?.name ?? '', 'avatar': u1?.photoUrl ?? ''},
        'user2': <String, dynamic>{'name': u2?.name ?? '', 'avatar': u2?.photoUrl ?? ''},
        'score': (d[scoreField] as num?)?.toInt() ?? 0,
      });
    }

    return rows;
  }

  // ═══════════════════════════════════════════════════════
  // Themes & Settings
  // ═══════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getThemes() async {
    final snap = await _db.collection('cp_themes').orderBy('sort_order').get();
    final list = snap.docs
        .where((e) => e.data()['is_active'] != false)
        .map((e) {
          final d = e.data();
          d['id'] = e.id;
          return d;
        })
        .toList();
    return list;
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final snap = await _db.collection('cp_settings').get();
    final map = <String, dynamic>{};
    for (final doc in snap.docs) {
      map[doc.id] = doc.data()['value'];
    }
    return map;
  }

  // ═══════════════════════════════════════════════════════
  // Requests
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> sendRequest(
    String receiverId, {
    String? message,
  }) async {
    final sender = _uid;
    if (sender == null) return <String, dynamic>{'error': 'Not authenticated'};
    if (sender == receiverId) {
      return <String, dynamic>{'error': 'Cannot send request to yourself'};
    }

    if (await _findActiveCoupleFor(sender) != null) {
      return <String, dynamic>{'error': 'You already have an active CP'};
    }
    if (await _findActiveCoupleFor(receiverId) != null) {
      return <String, dynamic>{'error': 'Receiver already has an active CP'};
    }

    final pending = await _findRequestsFor(sender, status: 'pending');
    for (final r in pending) {
      if (r['receiver_uid'] == receiverId) {
        return <String, dynamic>{'error': 'Request already sent'};
      }
    }

    final doc = await _db.collection('cp_requests').add(<String, dynamic>{
      'sender_uid': sender,
      'receiver_uid': receiverId,
      'message': message,
      'status': 'pending',
      'created_at': _now(),
    });

    return <String, dynamic>{'success': true, 'id': doc.id};
  }

  static Future<Map<String, dynamic>> respondRequest(
    String requestId,
    bool accept,
  ) async {
    final receiver = _uid;
    if (receiver == null) return <String, dynamic>{'error': 'Not authenticated'};

    final reqDoc = await _db.collection('cp_requests').doc(requestId).get();
    if (!reqDoc.exists) return <String, dynamic>{'error': 'Request not found'};
    final req = reqDoc.data()!;
    if (req['receiver_uid'] != receiver) {
      return <String, dynamic>{'error': 'Not your request'};
    }

    await reqDoc.reference.update(<String, dynamic>{
      'status': accept ? 'accepted' : 'rejected',
      'responded_at': _now(),
    });

    if (accept) {
      final senderUid = req['sender_uid'] as String;
      await _endActiveCouplesFor(senderUid);
      await _endActiveCouplesFor(receiver);

      await _db.collection('cp_couples').add(<String, dynamic>{
        'user1_uid': senderUid,
        'user2_uid': receiver,
        'started_at': _now(),
        'countdown_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'total_score': 0,
        'week_score': 0,
        'month_score': 0,
        'created_at': _now(),
        'updated_at': _now(),
      });
    }

    return <String, dynamic>{'success': true};
  }

  static Future<bool> setTheme(String themeId) async {
    final uid = _uid;
    if (uid == null) return false;
    final couple = await _findActiveCoupleFor(uid);
    if (couple == null) return false;
    await _db.collection('cp_couples').doc(couple['id']).update(<String, dynamic>{
      'active_theme_id': themeId,
      'updated_at': _now(),
    });
    return true;
  }

  static Future<bool> endCp() async {
    final uid = _uid;
    if (uid == null) return false;
    final couple = await _findActiveCoupleFor(uid);
    if (couple == null) return false;
    await _db.collection('cp_couples').doc(couple['id']).update(<String, dynamic>{
      'ended_at': _now(),
      'updated_at': _now(),
    });
    return true;
  }

  // ═══════════════════════════════════════════════════════
  // Gifts & Cars
  // ═══════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getCpGifts() async {
    final snap = await _db.collection('cp_gifts').orderBy('sort_order').get();
    final list = snap.docs
        .where((e) => e.data()['is_active'] != false)
        .map((e) {
          final d = e.data();
          d['id'] = e.id;
          return d;
        })
        .toList();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getCpCars() async {
    final snap = await _db.collection('cp_cars').orderBy('sort_order').get();
    final list = snap.docs
        .where((e) => e.data()['is_active'] != false)
        .map((e) {
          final d = e.data();
          d['id'] = e.id;
          return d;
        })
        .toList();
    return list;
  }

  static Future<Map<String, dynamic>> sendCpGift({
    required String giftId,
    required String receiverId,
  }) async {
    final sender = _uid;
    if (sender == null) return <String, dynamic>{'error': 'Not authenticated'};

    final giftSnap = await _db.collection('cp_gifts').doc(giftId).get();
    if (!giftSnap.exists || giftSnap.data()?['is_active'] == false) {
      return <String, dynamic>{'error': 'Gift not found'};
    }
    final gift = giftSnap.data()!;
    final giftValue = (gift['value'] as num?)?.toInt() ?? 0;
    final giftName = gift['name_ar']?.toString() ?? gift['name']?.toString() ?? '';

    final couple = await _findActiveCoupleFor(sender);
    if (couple == null) return <String, dynamic>{'error': 'No active CP'};

    final partnerUid = couple['user1_uid'] == sender
        ? couple['user2_uid'] as String
        : couple['user1_uid'] as String;
    if (partnerUid != receiverId) {
      return <String, dynamic>{'error': 'Receiver is not your CP partner'};
    }

    final senderDoc = await _db.collection('users').doc(sender).get();
    final balance = (senderDoc.data()?['coins'] as num?)?.toInt() ?? 0;
    if (balance < giftValue) {
      return <String, dynamic>{
        'error': 'Insufficient coins',
        'need': giftValue,
        'balance': balance,
      };
    }

    final batch = _db.batch();
    batch.update(_db.collection('users').doc(sender), <String, dynamic>{
      'coins': FieldValue.increment(-giftValue),
    });
    batch.update(_db.collection('cp_couples').doc(couple['id']), <String, dynamic>{
      'total_score': FieldValue.increment(giftValue),
      'week_score': FieldValue.increment(giftValue),
      'month_score': FieldValue.increment(giftValue),
      'updated_at': _now(),
    });
    await batch.commit();

    await _db.collection('cp_gift_logs').add(<String, dynamic>{
      'couple_id': couple['id'],
      'sender_uid': sender,
      'receiver_uid': receiverId,
      'gift_id': giftId,
      'gift_name': giftName,
      'gift_value': giftValue,
      'created_at': _now(),
    });

    await FirebaseService().sendNotification(
      uid: receiverId,
      type: 'cp_gift',
      actorUid: sender,
      title: '🎁 هدية CP',
      body: 'أرسل لك شريكك هدية 🎁',
      data: <String, dynamic>{
        'gift_name': giftName,
        'gift_value': giftValue,
        'couple_id': couple['id'],
      },
    );

    return <String, dynamic>{
      'success': true,
      'gift_value': giftValue,
      'new_score': ((couple['total_score'] as num?)?.toInt() ?? 0) + giftValue,
    };
  }

  /// Send a CP gift to create or strengthen a CP relationship.
  /// If user has no CP, sends a request + notification with gift info.
  /// Returns: {success: bool, message: String, couple_id?: String}
  static Future<Map<String, dynamic>> sendGiftAndLink({
    required String giftId,
    required String senderId,
    required String senderName,
    required String receiverId,
    String? receiverName,
    String? giftName,
    int? giftValue,
    int durationHours = 24,
  }) async {
    try {
      final myData = await getMyData();
      final couple = myData['couple'] as Map<String, dynamic>?;

      if (couple != null) {
        final partnerId = couple['partner']?['uid'] as String?;
        if (partnerId == receiverId) {
          try {
            return await sendCpGift(giftId: giftId, receiverId: receiverId);
          } catch (_) {
            // If the gift is not a CP gift, just send a notification
            await sendCpGiftNotification(
              senderId: senderId,
              senderName: senderName,
              receiverId: receiverId,
              receiverName: receiverName ?? '',
              giftName: giftName,
              giftValue: giftValue,
            );
            return <String, dynamic>{
              'success': true,
              'message': 'تم إرسال الهدية لشريكك بنجاح',
            };
          }
        }
        return <String, dynamic>{'error': 'لديك علاقة CP بالفعل مع شخص آخر'};
      }

      final reqResult = await sendRequest(
        receiverId,
        message: 'أرسل لك هدية CP 🎁',
      );
      final success = reqResult['success'] == true || reqResult['id'] != null;
      if (!success) {
        return <String, dynamic>{'error': reqResult['error'] ?? 'فشل إرسال الطلب'};
      }

      final requestId = reqResult['id']?.toString();
      await sendCpGiftNotification(
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        receiverName: receiverName ?? '',
        giftName: giftName,
        giftValue: giftValue,
        requestId: requestId,
      );

      return <String, dynamic>{
        'success': true,
        'message': 'تم إرسال هدية CP وطلب الارتباط بنجاح',
        'request_id': requestId,
      };
    } catch (e) {
      return <String, dynamic>{'error': e.toString()};
    }
  }

  /// Send CP gift notification to partner (not linked yet) with accept/decline action.
  static Future<void> sendCpGiftNotification({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    String? giftName,
    int? giftValue,
    String? requestId,
  }) async {
    await FirebaseService().sendNotification(
      uid: receiverId,
      type: 'cp_gift',
      actorUid: senderId,
      title: '💝 هدية CP من $senderName',
      body: 'أرسل $senderName هدية CP لك. هل توافق على ربط علاقة CP?',
      data: <String, dynamic>{
        'sender_id': senderId,
        'sender_name': senderName,
        'gift_name': giftName ?? '',
        'gift_value': giftValue ?? 0,
        if (requestId != null) 'request_id': requestId,
        'action': 'cp_relationship_request',
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // History & Achievements
  // ═══════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getCpHistory({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return <Map<String, dynamic>>[];

    final couple = await _findLatestCoupleFor(uid);
    if (couple == null) return <Map<String, dynamic>>[];

    final snap = await _db
        .collection('cp_gift_logs')
        .where('couple_id', isEqualTo: couple['id'])
        .get();

    final logs = snap.docs.map((e) => e.data()).toList();
    logs.sort((a, b) =>
        (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));

    final result = <Map<String, dynamic>>[];
    for (final log in logs.take(limit)) {
      final sender = await FirebaseService().getUser(log['sender_uid'] as String? ?? '');
      result.add(<String, dynamic>{
        'id': log['id'],
        'action': 'gift',
        'user_name': sender?.name ?? '',
        'gift_name': log['gift_name'] ?? '',
        'gift_value': (log['gift_value'] as num?)?.toInt() ?? 0,
        'timestamp': log['created_at'],
      });
    }
    return result;
  }

  static Future<List<Map<String, dynamic>>> getCpAchievements({String? coupleId}) async {
    final uid = _uid;
    if (uid == null) return <Map<String, dynamic>>[];

    Map<String, dynamic>? couple;
    if (coupleId != null && coupleId.isNotEmpty) {
      final doc = await _db.collection('cp_couples').doc(coupleId).get();
      if (doc.exists) couple = doc.data()!;
    } else {
      couple = await _findActiveCoupleFor(uid);
    }
    if (couple == null) return <Map<String, dynamic>>[];

    final logs = await _db
        .collection('cp_gift_logs')
        .where('couple_id', isEqualTo: couple['id'])
        .get();

    final giftCount = logs.docs.length;
    var totalGiftValue = 0;
    for (final log in logs.docs) {
      totalGiftValue += (log.data()['gift_value'] as num?)?.toInt() ?? 0;
    }

    final startedRaw = couple['started_at'];
    final endedRaw = couple['ended_at'];
    final startedAt = _parseDate(startedRaw);
    final endedAt = _parseDate(endedRaw) ?? DateTime.now();
    final daysTogether = startedAt != null
        ? endedAt.difference(startedAt).inDays
        : 0;

    return <Map<String, dynamic>>[
      <String, dynamic>{'icon': 'favorite', 'title': '$daysTogether يوم', 'subtitle': 'معاً'},
      <String, dynamic>{'icon': 'favorite', 'title': '${couple['total_score'] ?? 0}', 'subtitle': 'القربى'},
      <String, dynamic>{'icon': 'card_giftcard', 'title': '$giftCount', 'subtitle': 'الهدايا'},
      <String, dynamic>{'icon': 'stars', 'title': '$totalGiftValue', 'subtitle': 'قيمة الهدايا'},
    ];
  }

  /// Get the total CP gift value sent by a specific user (individual, not couple).
  static Future<int> getUserCpGiftTotal(String uid) async {
    try {
      final snap = await _db
          .collection('cp_gift_logs')
          .where('sender_uid', isEqualTo: uid)
          .get();
      var total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['gift_value'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('[CpService] getUserCpGiftTotal error: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════
  // Rank Rewards
  // ═══════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getRankRewards({String period = 'weekly'}) async {
    try {
      final snap = await _db
          .collection('cp_rank_rewards')
          .where('period', isEqualTo: period)
          .get();
      final list = snap.docs.map((e) {
        final d = e.data();
        d['id'] = e.id;
        return d;
      }).toList();
      list.sort((a, b) {
        final rankCmp = ((a['rank_position'] as num?)?.toInt() ?? 0)
            .compareTo((b['rank_position'] as num?)?.toInt() ?? 0);
        if (rankCmp != 0) return rankCmp;
        return ((a['slot_index'] as num?)?.toInt() ?? 0)
            .compareTo((b['slot_index'] as num?)?.toInt() ?? 0);
      });
      return list;
    } catch (e) {
      debugPrint('[CpService] getRankRewards error: $e');
      try {
        final settings = await getSettings();
        final raw = settings['cp_rank_rewards_data']?.toString();
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          final all = List<Map<String, dynamic>>.from(decoded as List);
          final filtered = all.where((r) => r['period'] == period).toList();
          filtered.sort((a, b) {
            final rankCmp = ((a['rank_position'] as int?) ?? 0).compareTo((b['rank_position'] as int?) ?? 0);
            if (rankCmp != 0) return rankCmp;
            return ((a['slot_index'] as int?) ?? 0).compareTo((b['slot_index'] as int?) ?? 0);
          });
          return filtered;
        }
      } catch (_) {}
    }
    return <Map<String, dynamic>>[];
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════

  static String _now() => DateTime.now().toIso8601String();

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  /// Active couple (ended_at is null) where [uid] is a member.
  static Future<Map<String, dynamic>?> _findActiveCoupleFor(String uid) async {
    final results = await Future.wait([
      _db.collection('cp_couples').where('user1_uid', isEqualTo: uid).limit(10).get(),
      _db.collection('cp_couples').where('user2_uid', isEqualTo: uid).limit(10).get(),
    ]);
    for (final snap in results) {
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['ended_at'] == null) {
          d['id'] = doc.id;
          return d;
        }
      }
    }
    return null;
  }

  /// Most recent couple (active or ended) for [uid].
  static Future<Map<String, dynamic>?> _findLatestCoupleFor(String uid) async {
    final results = await Future.wait([
      _db.collection('cp_couples').where('user1_uid', isEqualTo: uid).limit(50).get(),
      _db.collection('cp_couples').where('user2_uid', isEqualTo: uid).limit(50).get(),
    ]);
    Map<String, dynamic>? latest;
    String? latestDocId;
    String? latestKey;
    for (final snap in results) {
      for (final doc in snap.docs) {
        final d = doc.data();
        final key = d['ended_at']?.toString() ?? d['created_at']?.toString() ?? '';
        if (latest == null || key.compareTo(latestKey ?? '') > 0) {
          latest = d;
          latestDocId = doc.id;
          latestKey = key;
        }
      }
    }
    if (latest != null) latest['id'] = latestDocId;
    return latest;
  }

  static Future<void> _endActiveCouplesFor(String uid) async {
    final couple = await _findActiveCoupleFor(uid);
    if (couple == null) return;
    await _db.collection('cp_couples').doc(couple['id']).update(<String, dynamic>{
      'ended_at': _now(),
      'updated_at': _now(),
    });
  }

  static Future<Map<String, dynamic>?> _getTheme(String themeId) async {
    final doc = await _db.collection('cp_themes').doc(themeId).get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    d['id'] = doc.id;
    return d;
  }

  static Future<List<Map<String, dynamic>>> _findRequestsFor(String uid,
      {String? status}) async {
    final snap = await _db
        .collection('cp_requests')
        .where('receiver_uid', isEqualTo: uid)
        .get();
    final list = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      if (status != null && d['status'] != status) continue;
      final sender = await FirebaseService().getUser(d['sender_uid'] as String? ?? '');
      list.add(<String, dynamic>{
        'id': doc.id,
        'sender_uid': d['sender_uid'],
        'receiver_uid': d['receiver_uid'],
        'status': d['status'],
        'message': d['message'],
        'sender_name': sender?.name ?? '',
        'sender_avatar': sender?.photoUrl ?? '',
      });
    }
    return list;
  }

  static Future<List<Map<String, dynamic>>> _findHistoryFor(String uid) async {
    final results = await Future.wait([
      _db.collection('cp_couples').where('user1_uid', isEqualTo: uid).get(),
      _db.collection('cp_couples').where('user2_uid', isEqualTo: uid).get(),
    ]);
    final ended = <Map<String, dynamic>>[];
    for (final snap in results) {
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['ended_at'] == null) continue;
        final isUser1 = d['user1_uid'] == uid;
        final partnerUid = isUser1 ? d['user2_uid'] as String : d['user1_uid'] as String;
        final partner = await FirebaseService().getUser(partnerUid);
        ended.add(<String, dynamic>{
          'partner_name': partner?.name ?? '',
          'partner_avatar': partner?.photoUrl ?? '',
          'total_score': (d['total_score'] as num?)?.toInt() ?? 0,
          'started_at': d['started_at'],
          'ended_at': d['ended_at'],
        });
      }
    }
    ended.sort((a, b) =>
        (b['ended_at']?.toString() ?? '').compareTo(a['ended_at']?.toString() ?? ''));
    return ended;
  }
}
