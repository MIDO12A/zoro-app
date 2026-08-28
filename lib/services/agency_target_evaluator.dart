import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyTargetEvaluator {
  static final _db = FirebaseFirestore.instance;

  static Future<void> evaluateHostTargets(String hostUserId) async {
    try {
      // 1. Get host's agency_member doc
      final memberQs = await _db.collection('host_agency_members')
          .where('user_id', isEqualTo: hostUserId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (memberQs.docs.isEmpty) return;
      
      final memberDoc = memberQs.docs.first;
      final md = memberDoc.data();
      final agencyId = md['agency_id']?.toString() ?? '';
      final diamondsMonthly = (md['diamonds_earned_monthly'] as num?)?.toInt() ?? 0;
      
      // 2. Get global targets config (agency_targets_config)
      final targetsSnap = await _db.collection('agency_targets_config')
          .orderBy('target_diamonds', descending: false)
          .get();
          
      if (targetsSnap.docs.isEmpty) return;
      
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // 3. For each target, check if achieved
      for (final targetDoc in targetsSnap.docs) {
        final td = targetDoc.data();
        final targetDiamonds = (td['target_diamonds'] as num?)?.toInt() ?? 0;
        
        if (targetDiamonds > 0 && diamondsMonthly >= targetDiamonds) {
          // Did they already achieve this target this month?
          final achievedId = '${hostUserId}_${targetDoc.id}_$currentMonth';
          final achievedRef = _db.collection('agency_achieved_targets').doc(achievedId);
          
          final achievedSnap = await achievedRef.get();
          if (!achievedSnap.exists) {
            // HIT TARGET!
            await _awardTarget(
              hostUserId: hostUserId,
              agencyId: agencyId,
              targetId: targetDoc.id,
              targetData: td,
              achievedRef: achievedRef,
              currentMonth: currentMonth,
            );
          }
        }
      }
    } catch (e) {
      print('Error evaluating host targets: $e');
    }
  }
  
  static Future<void> _awardTarget({
    required String hostUserId,
    required String agencyId,
    required String targetId,
    required Map<String, dynamic> targetData,
    required DocumentReference achievedRef,
    required String currentMonth,
  }) async {
    final targetDiamonds = (targetData['target_diamonds'] as num?)?.toInt() ?? 0;
    final agencyProfitPercent = (targetData['agency_profit_percent'] as num?)?.toDouble() ?? 0.0;
    final rewardFrameId = targetData['reward_frame_id']?.toString();
    final rewardBadgeId = targetData['reward_badge_id']?.toString();
    final rewardDurationDays = (targetData['reward_duration_days'] as num?)?.toInt() ?? 7;
    
    // 1. Mark as achieved
    await achievedRef.set({
      'user_id': hostUserId,
      'agency_id': agencyId,
      'target_id': targetId,
      'month': currentMonth,
      'achieved_at': DateTime.now().toIso8601String(),
    });
    
    // 2. Give agency profit to Agency Owner
    if (agencyProfitPercent > 0 && agencyId.isNotEmpty) {
      final agencySnap = await _db.collection('host_agencies').doc(agencyId).get();
      if (agencySnap.exists) {
        final ownerId = agencySnap.data()?['owner_id']?.toString() ?? '';
        if (ownerId.isNotEmpty) {
          final profit = (targetDiamonds * (agencyProfitPercent / 100.0)).toInt();
          
          final agencyWalletRef = _db.collection('agency_wallets').doc(agencyId);
          final awSnap = await agencyWalletRef.get();
          if (awSnap.exists) {
            await agencyWalletRef.update({
              'diamond_balance': FieldValue.increment(profit),
            });
          } else {
            await agencyWalletRef.set({
              'agency_id': agencyId,
              'diamond_balance': profit,
              'gold_balance': 0,
            });
          }
          // Notify owner
          await _sendSystemMessage(ownerId, 'مبروك! تمت إضافة أرباح بقيمة $profit ماسة (بنسبة $agencyProfitPercent%) إلى محفظة الوكالة، لنجاح أحد مضيفيك في تقفيل تارجت $targetDiamonds.');
        }
      }
    }
    
    // 3. Give rewards to Host (Frame / Badge) in backpack
    final expiresAt = DateTime.now().add(Duration(days: rewardDurationDays)).toIso8601String();
    
    if (rewardFrameId != null && rewardFrameId.isNotEmpty) {
       await _db.collection('user_backpack').doc().set({
         'user_id': hostUserId,
         'item_type': 'frame',
         'item_id': rewardFrameId,
         'expires_at': expiresAt,
         'created_at': DateTime.now().toIso8601String(),
       });
       
       // Equip automatically
       await _db.collection('users').doc(hostUserId).update({
         'active_frame': rewardFrameId,
       });
    }
    
    if (rewardBadgeId != null && rewardBadgeId.isNotEmpty) {
       await _db.collection('user_backpack').doc().set({
         'user_id': hostUserId,
         'item_type': 'badge',
         'item_id': rewardBadgeId,
         'expires_at': expiresAt,
         'created_at': DateTime.now().toIso8601String(),
       });
    }
    
    // 4. Send System Message to Host
    String msg = 'تهانينا! لقد حققت هدف $targetDiamonds وحصلت على مكافأة صالحة لمدة $rewardDurationDays يوم.';
    await _sendSystemMessage(hostUserId, msg, imageUrl: targetData['reward_image_url']?.toString());
  }
  
  static Future<void> _sendSystemMessage(String userId, String text, {String? imageUrl}) async {
     await _db.collection('private_messages').doc().set({
        'sender_id': 'system',
        'receiver_id': userId,
        'text': text,
        'image_url': imageUrl ?? '',
        'type': 'system',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'conversationId': 'system_$userId',
     });
     
     // Update conversation
     await _db.collection('conversations').doc('system_$userId').set({
        'id': 'system_$userId',
        'user1Id': 'system',
        'user2Id': userId,
        'lastMessage': text,
        'lastMessageTime': DateTime.now().toIso8601String(),
        'unreadCount1': 0,
        'unreadCount2': FieldValue.increment(1),
     }, SetOptions(merge: true));
  }
}
