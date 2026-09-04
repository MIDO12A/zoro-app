import { Router, Request, Response } from 'express';
import { db } from '../config/database';
import { authenticate } from '../middleware/auth';

const router = Router();

/**
 * Build a multiplier distribution whose EXACT expected value equals the
 * configured RTP (Return To Player).
 *
 *   MYSTERY: Σ P(m)·m = RTP             (m = multiplier, "1" = tie, "0" = loss)
 *   P(m) = w_m / Z for winning multis; P(0) = w_0 / Z.
 *
 * Base weights decay as w(m) = m^-1.15 (heavy on small wins, thin on the
 * jackpot). We then solve for w₀ = (Σw·m)/RTP − Σw so the sum hits RTP exactly,
 * and normalize Z = w₀ + Σw. This makes the house edge mathematical — the only
 * thing that matters — instead of a hand-tuned weight table.
 */
function buildOdds(maxMultiplier: number, rtpPercent: number) {
  const rtp = Math.max(0.5, Math.min(1.0, (rtpPercent || 85) / 100));
  const candidates = [1, 2, 5, 10, 50, 100, 500, 1000];
  const multis = candidates.filter((m) => m <= maxMultiplier);
  if (multis.length === 0) multis.push(1);

  const weights = multis.map((m) => Math.pow(m, -1.15));
  const sumW = weights.reduce((s, w) => s + w, 0);
  const sumWM = multis.reduce((s, m, i) => s + m * weights[i], 0);

  // Solve w₀ = sumWM/rtp − sumW ; clamp at 0 so a crazy-high RTP just yields
  // "near-certain tie" instead of a negative loss bucket.
  let w0 = sumWM / rtp - sumW;
  if (!isFinite(w0) || w0 < 0) w0 = 0;

  const Z = w0 + sumW;
  const odds = multis.map((m, i) => ({
    multiplier: m,
    probability: weights[i] / Z,
  }));
  odds.push({ multiplier: 0, probability: w0 / Z });

  return odds;
}

function drawFromOdds(odds: { multiplier: number; probability: number }[]): number {
  const roll = secureRandomInt(1000000) / 1000000;
  let cumulative = 0;
  for (const item of odds) {
    cumulative += item.probability;
    if (roll < cumulative) return item.multiplier;
  }
  return 0;
}

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

function drawMultipliers(count: number, odds: { multiplier: number; probability: number }[]): number[] {
  const clamped = count < 4 ? 4 : count > 8 ? 8 : count;
  const results: number[] = [];
  for (let c = 0; c < clamped; c++) {
    results.push(drawFromOdds(odds));
  }
  return results;
}

function asInt(v: unknown): number {
  if (typeof v === 'number') return Math.trunc(v);
  const n = parseInt(String(v ?? ''), 10);
  return Number.isFinite(n) ? n : 0;
}

// ── Lightweight per-user rate limiter (in-memory; clear on process restart).
// Limit: 12 draws / 60s per user. Blocks bot bursts without blocking play.
const hitWindow = new Map<string, number[]>();
const RATE_LIMIT = 12;
const RATE_WINDOW_MS = 60_000;

function rateLimited(uid: string): boolean {
  const now = Date.now();
  const hits = (hitWindow.get(uid) ?? []).filter((t) => now - t < RATE_WINDOW_MS);
  if (hits.length >= RATE_LIMIT) {
    hitWindow.set(uid, hits);
    return true;
  }
  hits.push(now);
  hitWindow.set(uid, hits);
  return false;
}

/**
 * POST /api/v1/lucky/draw
 * Server-authoritative lucky gift draw:
 *  - requires the gift to be flagged is_lucky
 *  - builds a probability table whose EV == configured RTP (per gift)
 *  - draws multipliers server-side with a per-user rate limiter
 *  - deducts coins from sender, credits winnings back to the SENDER
 *  - broadcasts the strip to the whole room via room_messages
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
  if (!giftId || !roomId) {
    res.status(400).json({ error: 'Missing giftId/roomId' });
    return;
  }

  if (rateLimited(senderId)) {
    res.status(429).json({ error: 'rate_limited' });
    return;
  }

  const comboId = String(rawComboId ?? 'combo_' + String(Date.now()));

  try {
    const giftRef = db.collection('gifts').doc(String(giftId));
    const senderRef = db.collection('users').doc(senderId);
    const roomRef = db.collection('rooms').doc(String(roomId));

    const result = await db.runTransaction(async (txn) => {
      // ── ALL READS FIRST ──
      // Firestore transactions forbid ANY read after the first write.
      // Reading roomSnap after the writes below cancelled the whole
      // transaction (rolled back), so coins were never deducted/credited.
      const [senderSnap, giftSnap, roomSnap] = await Promise.all([
        txn.get(senderRef),
        txn.get(giftRef),
        txn.get(roomRef),
      ]);

      if (!giftSnap.exists) throw new Error('gift_not_found');
      const gift = giftSnap.data() ?? {};
      if (gift.is_active === false) throw new Error('gift_inactive');
      if (gift.is_lucky !== true) throw new Error('not_a_lucky_gift');

      const value = asInt(gift.value);
      if (value <= 0) throw new Error('invalid_gift_value');

      // Per-gift RTP + max multiplier (admin-controlled, defaults 85% / 100X).
      const rtp = asInt(gift.lucky_rtp ?? gift.rtp ?? 85);
      const maxMult = asInt(gift.lucky_max_multiplier ?? gift.max_multiplier ?? 100);
      const odds = buildOdds(maxMult, rtp);

      const totalCost = value * count;
      if (!senderSnap.exists) throw new Error('sender_not_found');
      const coins = asInt(senderSnap.data()?.coins);
      if (coins < totalCost) throw new Error('insufficient_coins');

      const multipliers = drawMultipliers(count, odds);
      const totalWonCoins = multipliers.reduce((s, m) => s + value * m, 0);
      const isBigWin = multipliers.some((m) => m >= 50);
      const maxWinner = multipliers.length
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
        receiver_id: String(receiverId ?? ''),
        receiver_name: '',
        room_id: roomId,
        value,
        count,
        rtp,
        max_multiplier: maxMult,
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
        receiver: { id: String(receiverId ?? ''), nickname: '' },
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
          maxMultiplier: maxWinner,
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

      // Deduct + credit back to the SENDER atomically (winner = sender).
      txn.update(senderRef, {
        coins: coins - totalCost + totalWonCoins,
        total_gifts_sent: asInt(senderSnapData.total_gifts_sent) + totalCost,
      });

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
        maxMultiplier: maxWinner,
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