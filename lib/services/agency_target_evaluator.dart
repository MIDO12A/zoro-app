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
      
      // 2. Get global targets config from host_milestones and agency_targets_config
      final milestonesSnap = await _db.collection('host_milestones')
          .where('is_active', isEqualTo: true)
          .get();
      final targetsSnap = await _db.collection('agency_targets_config')
          .orderBy('target_diamonds', descending: false)
          .get();
          
      final List<Map<String, dynamic>> allTargets = [];
      for (final doc in milestonesSnap.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        allTargets.add(d);
      }
      for (final doc in targetsSnap.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        allTargets.add(d);
      }
      if (allTargets.isEmpty) return;
      
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // 3. For each target, check if achieved
      for (final td in allTargets) {
        final targetDiamonds = (td['target_diamonds'] as num?)?.toInt() ?? 0;
        final targetId = td['id']?.toString() ?? '';
        
        if (targetDiamonds > 0 && diamondsMonthly >= targetDiamonds) {
          // Did they already achieve this target this month?
          final achievedId = '${hostUserId}_${targetId}_$currentMonth';
          final achievedRef = _db.collection('agency_achieved_targets').doc(achievedId);
          
          final achievedSnap = await achievedRef.get();
          if (!achievedSnap.exists) {
            // HIT TARGET!
            await _awardTarget(
              hostUserId: hostUserId,
              agencyId: agencyId,
              targetId: targetId,
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
    final rewardType = targetData['reward_type']?.toString() ?? 'salary_usd';
    final rewardValue = (targetData['reward_value'] as num?)?.toDouble() ?? 0.0;
    final rewardItemId = targetData['reward_item_id']?.toString() ?? '';
    final agentCommissionRate = (targetData['agent_commission_rate'] as num?)?.toDouble() ?? 
        ((targetData['agency_profit_percent'] as num?)?.toDouble() != null ? ((targetData['agency_profit_percent'] as num!).toDouble() / 100.0) : 0.1);
    final rewardFrameId = targetData['reward_frame_id']?.toString() ?? (rewardType == 'frame' ? rewardItemId : null);
    final rewardBadgeId = targetData['reward_badge_id']?.toString() ?? (rewardType == 'badge' ? rewardItemId : null);
    final rewardDurationDays = (targetData['reward_duration_days'] as num?)?.toInt() ?? 30;
    
    // 1. Mark as achieved
    await achievedRef.set({
      'user_id': hostUserId,
      'agency_id': agencyId,
      'target_id': targetId,
      'month': currentMonth,
      'reward_type': rewardType,
      'reward_value': rewardValue,
      'reward_item_id': rewardItemId,
      'achieved_at': DateTime.now().toIso8601String(),
    });
    
    // 2. Give agent commission to Agency Owner
    if (agentCommissionRate > 0 && agencyId.isNotEmpty) {
      final agencySnap = await _db.collection('host_agencies').doc(agencyId).get();
      if (agencySnap.exists) {
        final ownerId = agencySnap.data()?['owner_id']?.toString() ?? '';
        if (ownerId.isNotEmpty) {
          final profit = (targetDiamonds * agentCommissionRate).toInt();
          
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
          await _sendSystemMessage(ownerId, 'مبروك! تمت إضافة عمولة بقيمة $profit ماسة (بنسبة ${(agentCommissionRate * 100).toStringAsFixed(1)}%) إلى محفظة وكالتك، لنجاح مضيفك في تحقيق تارجت $targetDiamonds 💎.');
        }
      }
    }
    
    // 3. Give rewards to Host automatically
    final expiresAt = DateTime.now().add(Duration(days: rewardDurationDays)).toIso8601String();
    
    if (rewardType == 'gold' && rewardValue > 0) {
      await _db.collection('users').doc(hostUserId).update({
        'coins': FieldValue.increment(rewardValue.toInt()),
      });
    } else if (rewardType == 'diamonds' && rewardValue > 0) {
      await _db.collection('users').doc(hostUserId).update({
        'diamonds': FieldValue.increment(rewardValue.toInt()),
      });
    } else if (rewardType == 'salary_usd' && rewardValue > 0) {
      await _db.collection('host_salaries').doc().set({
        'user_id': hostUserId,
        'agency_id': agencyId,
        'target_id': targetId,
        'amount_usd': rewardValue,
        'target_diamonds': targetDiamonds,
        'month': currentMonth,
        'status': 'pending_payout',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    // Backpack rewards (frames, badges, store items)
    if (rewardFrameId != null && rewardFrameId.isNotEmpty) {
       await _db.collection('user_backpack').doc().set({
         'user_id': hostUserId,
         'item_type': 'frame',
         'item_id': rewardFrameId,
         'expires_at': expiresAt,
         'created_at': DateTime.now().toIso8601String(),
       });
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

    if (rewardItemId.isNotEmpty && rewardType == 'gift_item') {
      await _db.collection('user_backpack').doc().set({
        'user_id': hostUserId,
        'item_type': 'gift',
        'item_id': rewardItemId,
        'count': (rewardValue > 0 ? rewardValue.toInt() : 1),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    // 4. Send System Message to Host with celebration
    String rewardDesc = rewardType == 'salary_usd' ? '$rewardValue\$' :
                        rewardType == 'gold' ? '${rewardValue.toInt()} عملة ذهبية' :
                        rewardType == 'diamonds' ? '${rewardValue.toInt()} ماسة' : 'مكافأة مميزة';
    String msg = '🎉 تهانينا! لقد حققت هدف $targetDiamonds 💎 وحصلت على $rewardDesc وجوائزك التلقائية.';
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
