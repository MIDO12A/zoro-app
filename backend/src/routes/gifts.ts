import { Router, Request, Response } from 'express';
import { db } from '../config/database';
import { authenticate } from '../middleware/auth';
import { evaluateHostTargets } from './hostTargets';

const router = Router();

function asInt(v: unknown): number {
  if (typeof v === 'number') return Math.trunc(v);
  const n = parseInt(String(v ?? ''), 10);
  return Number.isFinite(n) ? n : 0;
}

/**
 * POST /api/v1/gifts/send
 * Server-authoritative gift send (V1.8: price fetched server-side by gift ID —
 * the client can no longer trade a cheap price for an expensive gift):
 *  - loads gifts/{giftId} as the single source of truth for value/is_active
 *  - deducts sender coins + credits receiver diamonds in ONE transaction
 *  - writes sent_gifts + room_messages + agency member credits atomically
 *  - optional lucky:draw follow-up is handled separately by /lucky/draw
 */
router.post('/send', authenticate, async (req: Request, res: Response) => {
  const senderId = req.user?.uid;
  if (!senderId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { giftId, receiverId, roomId, count: rawCount } = req.body ?? {};
  const count = Math.max(1, Math.min(100, Number(rawCount) || 1));
  const giftIdStr = String(giftId ?? '');
  const receiverIdStr = String(receiverId ?? '');
  const roomIdStr = String(roomId ?? '');
  if (!giftIdStr || !receiverIdStr || !roomIdStr) {
    res.status(400).json({ error: 'Missing giftId/receiverId/roomId' });
    return;
  }

  try {
    const giftRef = db.collection('gifts').doc(giftIdStr);
    const senderRef = db.collection('users').doc(senderId);

    const result = await db.runTransaction(async (txn) => {
      const [giftSnap, senderSnap] = await Promise.all([
        txn.get(giftRef),
        txn.get(senderRef),
      ]);

      if (!giftSnap.exists) throw new Error('gift_not_found');
      const gift = giftSnap.data() ?? {};
      if (gift.is_active === false) throw new Error('gift_inactive');

      // Server-side authoritative price — NEVER trust client-supplied value.
      const value = asInt(gift.value);
      if (value <= 0) throw new Error('invalid_gift_value');
      const totalCost = value * count;

      if (!senderSnap.exists) throw new Error('sender_not_found');
      const senderData = senderSnap.data() ?? {};
      const coins = asInt(senderData.coins);
      if (coins < totalCost) throw new Error('insufficient_coins');

      const id = `${Date.now()}_${senderId}_${giftIdStr}`;
      const giftName = String(gift.name ?? '');
      const giftNameAr = String(gift.name_ar ?? gift.name ?? '');
      const iconUrl = String(gift.icon_url ?? gift.animation_asset ?? '');

      txn.set(db.collection('sent_gifts').doc(id), {
        id,
        gift_id: giftIdStr,
        gift_name: giftName,
        animation_asset: iconUrl,
        sender_id: senderId,
        sender_name: String(senderData.name ?? ''),
        sender_photo_url: String(senderData.photo_url ?? senderData.photoUrl ?? ''),
        receiver_id: receiverIdStr,
        receiver_name: '',
        room_id: roomIdStr,
        value,
        count,
        created_at: new Date().toISOString(),
      });

      txn.set(db.collection('room_messages').doc(), {
        msg_id: id,
        room_id: roomIdStr,
        sender_uid: senderId,
        sender_name: String(senderData.name ?? ''),
        type: 'gift',
        text: `🎁 ${giftNameAr} x${count} → ${receiverIdStr}`,
        image_url: iconUrl,
        created_at: new Date().toISOString(),
      });

      txn.update(senderRef, {
        coins: coins - totalCost,
        total_gifts_sent: asInt(senderData.total_gifts_sent) + totalCost,
      });

      const receiverRef = db.collection('users').doc(receiverIdStr);
      const receiverSnap = await txn.get(receiverRef);
      if (receiverSnap.exists) {
        const rd = receiverSnap.data() ?? {};
        txn.update(receiverRef, {
          diamonds: asInt(rd.diamonds) + totalCost,
          total_gifts_received: asInt(rd.total_gifts_received) + totalCost,
        });
      }

      const roomRef = db.collection('rooms').doc(roomIdStr);
      const roomSnap = await txn.get(roomRef);
      if (roomSnap.exists) {
        const rm = roomSnap.data() ?? {};
        txn.update(roomRef, {
          total_gifts: asInt(rm.total_gifts) + totalCost,
          hot_value: asInt(rm.hot_value) + totalCost,
        });
      }

      const walletRef = db.collection('user_wallets').doc(receiverIdStr);
      const wSnap = await txn.get(walletRef);
      if (wSnap.exists) {
        const wd = wSnap.data() ?? {};
        txn.update(walletRef, { diamond_balance: asInt(wd.diamond_balance) + totalCost });
      } else {
        txn.set(walletRef, { user_id: receiverIdStr, diamond_balance: totalCost, gold_balance: 0 });
      }

      // Host agency member credit (mirrors legacy client behaviour).
      const memberQs = await db.collection('host_agency_members')
        .where('user_id', '==', receiverIdStr)
        .where('status', '==', 'active')
        .limit(1)
        .get();
      if (!memberQs.empty) {
        const mRef = memberQs.docs[0].ref;
        const md = memberQs.docs[0].data() ?? {};
        txn.update(mRef, {
          diamonds_available: asInt(md.diamonds_available) + totalCost,
          diamonds_earned_monthly: asInt(md.diamonds_earned_monthly) + totalCost,
          diamonds_earned_cumulative: asInt(md.diamonds_earned_cumulative) + totalCost,
        });
      }

      return { id, cost: totalCost, giftName: giftNameAr };
    });

    // Fire-and-forget host target evaluation (V2.7): rewards are computed and
    // written ONLY on the backend. Never notify-first-then-fail — the present
    // outcome is already committed; a failed evaluation only logs.
    if (result.giftName) {
      evaluateHostTargets(receiverIdStr).catch((err) => {
        console.error('[gifts] host target evaluation failed:', err);
      });
    }
    res.json({ success: true, ...result });
  } catch (err: any) {
    res.status(400).json({ error: String(err?.message ?? 'server_error') });
  }
});

export default router;