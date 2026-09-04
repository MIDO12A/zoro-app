import { Router, Request, Response } from 'express';
import { db } from '../config/database';
import { authenticate } from '../middleware/auth';

const router = Router();

// Odds table mirrors the client's legacy `_drawLuckyMultipliers` weights so the
// economy stays consistent, but the draw itself now runs ONLY on the server.
const ODDS: { multiplier: number; weight: number }[] = [
  { multiplier: 0, weight: 650 },
  { multiplier: 1, weight: 200 },
  { multiplier: 2, weight: 90 },
  { multiplier: 5, weight: 40 },
  { multiplier: 10, weight: 15 },
  { multiplier: 50, weight: 4 },
  { multiplier: 100, weight: 1 },
  { multiplier: 500, weight: 1 },
];

const TOTAL_WEIGHT = ODDS.reduce((sum, o) => sum + o.weight, 0);

function secureRandomInt(max: number): number {
  const bytes = new Uint32Array(1);
  // Node >= 18 has globalThis.crypto; fall back to Math.random if unavailable.
  if (typeof globalThis !== 'undefined' && (globalThis as any).crypto?.getRandomValues) {
    (globalThis as any).crypto.getRandomValues(bytes);
  } else {
    bytes[0] = Math.floor(Math.random() * 0xffffffff);
  }
  return bytes[0] % max;
}

function drawMultipliers(count: number): number[] {
  const clamped = count < 4 ? 4 : count > 8 ? 8 : count;
  const results: number[] = [];
  for (let c = 0; c < clamped; c++) {
    const roll = secureRandomInt(TOTAL_WEIGHT);
    let current = 0;
    let selected = ODDS[0].multiplier;
    for (const item of ODDS) {
      current += item.weight;
      if (roll < current) {
        selected = item.multiplier;
        break;
      }
    }
    results.push(selected);
  }
  return results;
}

function asInt(v: unknown): number {
  if (typeof v === 'number') return Math.trunc(v);
  const n = parseInt(String(v ?? ''), 10);
  return Number.isFinite(n) ? n : 0;
}

/**
 * POST /api/v1/lucky/draw
 * Server-authoritative lucky gift draw:
 *  - reads the verified gift config (price + asset URLs)
 *  - draws multipliers server-side
 *  - deducts coins from sender, credits winnings, credits receiver diamonds
 *  - writes sent_lucky_gifts + room_messages (with gift_payload for the strip)
 * All inside ONE Firestore transaction via Admin SDK.
 */
router.post('/draw', authenticate, async (req: Request, res: Response) => {
  const senderId = req.user?.uid;
  if (!senderId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { giftId, receiverId, roomId, count: rawCount, comboCount, comboId: rawComboId } = req.body ?? {};
  const count = Math.max(1, Math.min(100, Number(rawCount) || 1));
  if (!giftId || !receiverId || !roomId) {
    res.status(400).json({ error: 'Missing giftId/receiverId/roomId' });
    return;
  }

  const comboId = String(rawComboId ?? 'combo_' + String(Date.now()));

  try {
    const giftRef = db.collection('gifts').doc(String(giftId));
    const senderRef = db.collection('users').doc(senderId);

    const result = await db.runTransaction(async (txn) => {
      const [senderSnap, giftSnap] = await Promise.all([
        txn.get(senderRef),
        txn.get(giftRef),
      ]);

      if (!giftSnap.exists) throw new Error('gift_not_found');
      const gift = giftSnap.data() ?? {};
      if (gift.is_active === false) throw new Error('gift_inactive');

      const value = asInt(gift.value);
      if (value <= 0) throw new Error('invalid_gift_value');

      const totalCost = value * count;
      if (!senderSnap.exists) throw new Error('sender_not_found');
      const coins = asInt(senderSnap.data()?.coins);
      if (coins < totalCost) throw new Error('insufficient_coins');

      const multipliers = drawMultipliers(count);
      const totalWonCoins = multipliers.reduce((s, m) => s + value * m, 0);
      const isBigWin = multipliers.some((m) => m >= 50);
      const maxMultiplier = multipliers.length
        ? multipliers.reduce((a, b) => (a > b ? a : b), 0)
        : 0;

      const giftName = String(gift.name ?? '');
      const giftNameAr = String(gift.name_ar ?? gift.name ?? '');
      const giftIconUrl = String(gift.icon_url ?? gift.icon_asset ?? '');
      const giftCoverUrl = String(gift.default_image ?? gift.icon_url ?? giftIconUrl);
      const giftBgUrl = giftCoverUrl;
      const svgaAnimUrl = String(gift.animation_asset ?? '');

      const id = `${Date.now()}_${senderId}_${giftId}`;
      const senderSnapData = senderSnap.data() ?? {};

      txn.set(db.collection('sent_lucky_gifts').doc(id), {
        id,
        gift_id: giftId,
        gift_name: giftName,
        gift_name_ar: giftNameAr,
        gift_icon_url: giftIconUrl,
        sender_id: senderId,
        sender_name: String(senderSnapData.name ?? ''),
        sender_photo_url: String(senderSnapData.photo_url ?? senderSnapData.photoUrl ?? ''),
        receiver_id: receiverId,
        receiver_name: '',
        room_id: roomId,
        value,
        count,
        combo_id: String(comboId ?? id),
        combo_count: Math.max(1, Number(comboCount) || 1),
        won_coins: totalWonCoins,
        multipliers,
        is_big_win: isBigWin,
        created_at: new Date().toISOString(),
      });

      // Broadcast to the room so the lucky gift strip/cards show for everyone.
      const pay = {
        roomId,
        sender: {
          id: senderId,
          nickname: String(senderSnapData.name ?? ''),
          avatar: String(senderSnapData.photo_url ?? senderSnapData.photoUrl ?? ''),
        },
        receiver: { id: receiverId, nickname: '' },
        gift: {
          id: giftId,
          giftName,
          giftNameAr,
          coinPrice: value,
          giftIconUrl,
          giftCoverUrl,
          giftBgUrl,
          svgaAnimUrl,
        },
        combo: {
          comboId: String(comboId ?? id),
          comboCount: Math.max(1, Number(comboCount) || 1),
          times: count,
        },
        results: {
          multipliers,
          cards: multipliers.map((m, i) => ({
            index: i,
            multiplier: m,
            wonCoins: value * m,
            giftName: giftNameAr,
            giftIcon: giftIconUrl,
          })),
          totalWonCoins,
          maxMultiplier,
          isBigWin,
        },
      };
      txn.set(db.collection('room_messages').doc(), {
        msg_id: id,
        room_id: roomId,
        sender_uid: senderId,
        sender_name: String(senderSnapData.name ?? ''),
        type: 'lucky_gift',
        text: `🍀 ${giftNameAr} x${count} (فاز بـ ${totalWonCoins} 🪙)`,
        gift_payload: pay,
        created_at: new Date().toISOString(),
      });

      // Deduct + credit atomically.
      txn.update(senderRef, {
        coins: coins - totalCost + totalWonCoins,
        total_gifts_sent: asInt(senderSnapData.total_gifts_sent) + totalCost,
      });

      const receiverRef = db.collection('users').doc(String(receiverId));
      const receiverSnap = await txn.get(receiverRef);
      const receiverSnapData = receiverSnap.data() ?? {};
      txn.update(receiverRef, {
        diamonds: asInt(receiverSnapData.diamonds) + totalCost,
        total_gifts_received: asInt(receiverSnapData.total_gifts_received) + totalCost,
      });

      const roomRef = db.collection('rooms').doc(String(roomId));
      const roomSnap = await txn.get(roomRef);
      if (roomSnap.exists) {
        const roomData = roomSnap.data() ?? {};
        txn.update(roomRef, {
          total_gifts: asInt(roomData.total_gifts) + totalCost,
          hot_value: asInt(roomData.hot_value) + totalCost,
        });
      }

      return {
        success: true,
        id,
        wonCoins: totalWonCoins,
        multipliers,
        maxMultiplier,
        isBigWin,
      };
    });

    if (result.isBigWin) {
      db.collection('global_announcements').add({
        type: 'lucky_big_win',
        sender_name: '',
        gift_name: '',
        room_id: String(roomId),
        multiplier: result.maxMultiplier,
        total_won: result.wonCoins,
        created_at: new Date().toISOString(),
      }).catch(() => {});
    }

    res.json(result);
  } catch (err: any) {
    const message = String(err?.message ?? 'server_error');
    res.status(400).json({ error: message });
  }
});

export default router;