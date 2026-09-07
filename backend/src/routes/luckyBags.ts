import { Router, Request, Response } from 'express';
import { db } from '../config/database';
import { authenticate } from '../middleware/auth';
import type { DocumentReference } from '@google-cloud/firestore';

const router = Router();

function asInt(v: unknown): number {
  if (typeof v === 'number') return Math.trunc(v);
  const n = parseInt(String(v ?? ''), 10);
  return Number.isFinite(n) ? n : 0;
}

// Active-bag expiry TTL (ms). Admin configurable via app_config/lucky_bag_config
async function bagTtlMs(): Promise<number> {
  try {
    const cfg = await db.collection('app_config').doc('lucky_bag_config').get();
    const t = asInt(cfg.data()?.ttl_seconds);
    if (t > 0) return t * 1000;
  } catch (_) {}
  return 60_000; // default 60s
}

const GRAB_RATE_WINDOW_MS = 30_000;
const grabWindow = new Map<string, number[]>();
function grabRateLimited(uid: string): boolean {
  const now = Date.now();
  const hits = (grabWindow.get(uid) ?? []).filter((t) => now - t < GRAB_RATE_WINDOW_MS);
  if (hits.length >= 10) {
    grabWindow.set(uid, hits);
    return true;
  }
  hits.push(now);
  grabWindow.set(uid, hits);
  return false;
}

/**
 * POST /api/v1/lucky-bags/send
 * Server-authoritative creation of a room-wide luck bag (حقيبة الحظ):
 *  - type: 'coins' | 'gift' | 'gold'
 *  - scope: 'room' (anyone in room) | 'mic' (only users on the mic)
 *  - count: number of bags to scatter (default 3, max 20)
 *  - value: per-grab pool size (the total pool = value * count)
 * Deducts the total from the sender's coins in ONE transaction and
 * broadcasts room_messages type 'lucky_bag' so every member sees the banner.
 */
router.post('/send', authenticate, async (req: Request, res: Response) => {
  const ownerId = req.user?.uid;
  if (!ownerId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { roomId, type: rawType, scope: rawScope, value: rawValue, count: rawCount } = req.body ?? {};
  const roomIdStr = String(roomId ?? '');
  if (!roomIdStr) {
    res.status(400).json({ error: 'Missing roomId' });
    return;
  }
  const type = (rawType === 'gift' || rawType === 'gold') ? rawType : 'coins';
  const scope = rawScope === 'mic' ? 'mic' : 'room';
  const value = Math.max(1, Math.min(1_000_000, asInt(rawValue)));
  const count = Math.max(1, Math.min(20, Number(rawCount) || 3));
  const totalCost = value * count;

  try {
    const ownerRef = db.collection('users').doc(ownerId);
    const roomRef = db.collection('rooms').doc(roomIdStr);

    const result = await db.runTransaction(async (txn) => {
      const [ownerSnap, roomSnap] = await Promise.all([txn.get(ownerRef), txn.get(roomRef)]);
      if (!ownerSnap.exists) throw new Error('owner_not_found');
      const ownerData = ownerSnap.data() ?? {};
      const coins = asInt(ownerData.coins);
      if (coins < totalCost) throw new Error('insufficient_coins');

      const ttl = await bagTtlMs();
      const now = Date.now();
      const bagId = `${now}_${ownerId}_${Math.floor(Math.random() * 1e6)}`;
      const ownerName = String(ownerData.name ?? '');
      const ownerPhoto = String(ownerData.photo_url ?? ownerData.photoUrl ?? '');

      // One batch doc — everyone draws from the same remaining pool.
      txn.set(db.collection('lucky_bags').doc(bagId), {
        id: bagId,
        room_id: roomIdStr,
        owner_id: ownerId,
        owner_name: ownerName,
        owner_photo: ownerPhoto,
        type,
        scope,
        total_value: totalCost,
        remaining_value: totalCost,
        total_bags: count,
        bags_taken: 0,
        created_at: new Date(now).toISOString(),
        expires_at: new Date(now + ttl).toISOString(),
        status: 'active',
      });

      const text =
        type === 'coins'
          ? `🛍️ ${ownerName} أرسل أكياس الحظ (${count} كيس) بمجموع ${totalCost} 🪙`
          : `🛍️ ${ownerName} أرسل أكياس الحظ (${count} كيس) 🎁`;
      txn.set(db.collection('room_messages').doc(), {
        msg_id: bagId,
        room_id: roomIdStr,
        sender_uid: ownerId,
        sender_name: ownerName,
        type: 'lucky_bag',
        text,
        image_url: '',
        lucky_bag_payload: {
          bagId,
          roomId: roomIdStr,
          ownerName,
          ownerAvatar: ownerPhoto,
          type,
          scope,
          value,
          totalBags: count,
          totalValue: totalCost,
        },
        created_at: new Date(now).toISOString(),
      });

      txn.update(ownerRef, {
        coins: coins - totalCost,
        total_gifts_sent: asInt(ownerData.total_gifts_sent) + totalCost,
      });

      if (roomSnap.exists) {
        const roomData = roomSnap.data() ?? {};
        txn.update(roomRef, {
          total_gifts: asInt(roomData.total_gifts) + totalCost,
          hot_value: asInt(roomData.hot_value) + totalCost,
        });
      }

      return { success: true, bagId, totalValue: totalCost, expiresAt: now + ttl };
    });

    res.json(result);
  } catch (err: any) {
    res.status(400).json({ error: String(err?.message ?? 'server_error') });
  }
});

/**
 * POST /api/v1/lucky-bags/grab
 * Server-authoritative grab: picks the oldest active bag in the room whose
 * remaining_value > 0 and hasn't expired, draws a random portion, credits the
 * claimer's coins, and returns leftovers to the owner when the bag is exhausted.
 */
router.post('/grab', authenticate, async (req: Request, res: Response) => {
  const claimerId = req.user?.uid;
  if (!claimerId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  const { roomId, bagId: rawBagId } = req.body ?? {};
  const roomIdStr = String(roomId ?? '');
  if (!roomIdStr) {
    res.status(400).json({ error: 'Missing roomId' });
    return;
  }
  if (grabRateLimited(claimerId)) {
    res.status(429).json({ error: 'rate_limited' });
    return;
  }

  try {
    // ── ALL reads/queries OUTSIDE the transaction (queries can't run inside) ──
    let bagRef: DocumentReference | null = null;
    let bagData: Record<string, any> = {};
    const qs = await db.collection('lucky_bags')
      .where('room_id', '==', roomIdStr)
      .where('status', '==', 'active')
      .orderBy('created_at', 'asc')
      .get();
    for (const doc of qs.docs) {
      const d = doc.data();
      if (asInt(d.remaining_value) > 0 && new Date(String(d.expires_at)).getTime() > Date.now()) {
        bagRef = doc.ref;
        bagData = d;
        break;
      }
    }
    if (!bagRef) {
      res.status(404).json({ error: 'no_active_bag' });
      return;
    }

    const scope = String(bagData.scope ?? 'room');
    // Mic-scope bags are only claimable by users currently sitting on a mic.
    let isOnMic = true;
    if (scope === 'mic') {
      try {
        const memberQ = await db.collection('room_members')
          .where('room_id', '==', roomIdStr)
          .where('user_id', '==', claimerId)
          .limit(1)
          .get();
        if (memberQ.empty) {
          res.status(403).json({ error: 'not_in_room' });
          return;
        }
        const md = memberQ.docs[0].data();
        isOnMic = md.mic_index != null || md.micIndex != null || md.on_mic === true;
      } catch (_) {
        isOnMic = true; // fail-open if membership can't be resolved
      }
    }

    const result = await db.runTransaction(async (txn) => {
      const claimerRef = db.collection('users').doc(claimerId);
      const ownerRef = db.collection('users').doc(String(bagData.owner_id ?? ''));
      // ALL READS FIRST (transaction forbids reads after writes).
      const [bSnap, claimerSnap, ownerSnap] = await Promise.all([
        txn.get(bagRef),
        txn.get(claimerRef),
        txn.get(ownerRef),
      ]);

      if (!bSnap.exists) throw new Error('bag_not_found');
      const b = bSnap.data() ?? {};
      if (b.status !== 'active') throw new Error('bag_inactive');
      const remaining = asInt(b.remaining_value);
      if (remaining <= 0) throw new Error('bag_empty');
      if (new Date(String(b.expires_at)).getTime() <= Date.now()) throw new Error('bag_expired');
      if (b.owner_id === claimerId) throw new Error('cannot_claim_own_bag');
      if (scope === 'mic' && !isOnMic) throw new Error('mic_only');
      if (!claimerSnap.exists) throw new Error('claimer_not_found');
      const cd = claimerSnap.data() ?? {};

      // Draw 10–40% of remaining (at least 1).
      const portion = 0.1 + Math.random() * 0.3;
      const amount = Math.max(1, Math.floor(remaining * portion));
      const newRemaining = remaining - amount;
      const newStatus = newRemaining <= 0 ? 'done' : 'active';

      const claimId = `${Date.now()}_${claimerId}_${Math.floor(Math.random() * 1e6)}`;
      const nowIso = new Date(Date.now()).toISOString();

      txn.set(db.collection('lucky_bag_claims').doc(claimId), {
        id: claimId,
        bag_id: String(b.id),
        room_id: roomIdStr,
        claimer_id: claimerId,
        claimer_name: String(cd.name ?? ''),
        amount,
        created_at: nowIso,
      });

      txn.update(bagRef, {
        remaining_value: Math.max(0, newRemaining),
        bags_taken: asInt(b.bags_taken) + 1,
        status: newStatus,
      });

      txn.update(claimerRef, { coins: asInt(cd.coins) + amount });

      const text = `🫳 ${String(cd.name ?? '')} أخذ ${amount} 🪙 من كيس الحظ`;
      txn.set(db.collection('room_messages').doc(), {
        msg_id: claimId,
        room_id: roomIdStr,
        sender_uid: claimerId,
        sender_name: String(cd.name ?? ''),
        type: 'lucky_bag_claim',
        text,
        image_url: '',
        lucky_bag_payload: {
          bagId: String(b.id),
          roomId: roomIdStr,
          claimerName: String(cd.name ?? ''),
          claimerAvatar: String(cd.photo_url ?? cd.photoUrl ?? ''),
          amount,
          remaining: newRemaining,
          isDone: newStatus === 'done',
        },
        created_at: nowIso,
      });

      // Return leftovers to the owner when exhausted.
      if (newStatus === 'done' && ownerSnap.exists) {
        const od = ownerSnap.data() ?? {};
        txn.update(ownerRef, { coins: asInt(od.coins) + newRemaining });
      }

      return {
        success: true,
        claimId,
        amount,
        remaining: newRemaining,
        isDone: newStatus === 'done',
        type: String(b.type),
      };
    });

    res.json(result);
  } catch (err: any) {
    const message = String(err?.message ?? 'server_error');
    const status =
      message === 'cannot_claim_own_bag' || message === 'not_in_room' || message === 'mic_only'
        ? 403
        : message === 'bag_not_found' || message === 'no_active_bag'
        ? 404
        : 400;
    res.status(status).json({ error: message });
  }
});

export default router;
