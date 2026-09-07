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
  return 90_000; // default 90s for red envelopes
}

const GRAB_RATE_WINDOW_MS = 30_000;
const grabWindow = new Map<string, number[]>();
function grabRateLimited(uid: string): boolean {
  const now = Date.now();
  const hits = (grabWindow.get(uid) ?? []).filter((t) => now - t < GRAB_RATE_WINDOW_MS);
  if (hits.length >= 15) {
    grabWindow.set(uid, hits);
    return true;
  }
  hits.push(now);
  grabWindow.set(uid, hits);
  return false;
}

/**
 * POST /api/v1/lucky-bags/send
 * Server-authoritative creation of a room-wide Red Envelope / Lucky Bag (المظروف الأحمر / حقيبة الحظ):
 *  - type: 'coins' | 'super' | 'gift' | 'gold'
 *  - scope: 'room' (anyone in room) | 'mic' (only users on the mic)
 *  - count: number of shares/bags (e.g. 5, 10, 20, 50, 100)
 *  - value: total coins or per-bag amount
 *  - totalCoins: optional explicit total coin pool
 *  - greetingText: custom blessing/greeting text
 *  - isSuper: boolean for Super Red Packet
 */
router.post('/send', authenticate, async (req: Request, res: Response) => {
  const ownerId = req.user?.uid;
  if (!ownerId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const {
    roomId,
    type: rawType,
    scope: rawScope,
    value: rawValue,
    count: rawCount,
    totalCoins: rawTotalCoins,
    greetingText: rawGreeting,
    isSuper: rawIsSuper,
  } = req.body ?? {};

  const roomIdStr = String(roomId ?? '');
  if (!roomIdStr) {
    res.status(400).json({ error: 'Missing roomId' });
    return;
  }

  const type = rawType === 'super' || rawType === 'gift' || rawType === 'gold' ? rawType : 'coins';
  const isSuper = rawIsSuper === true || type === 'super';
  const scope = rawScope === 'mic' ? 'mic' : 'room';
  const count = Math.max(1, Math.min(200, asInt(rawCount) || 5));
  
  // If totalCoins is explicitly passed, use it; otherwise value * count
  let totalCost = asInt(rawTotalCoins);
  if (totalCost <= 0) {
    const value = Math.max(1, asInt(rawValue));
    totalCost = value * count;
  }
  totalCost = Math.max(count, Math.min(10_000_000, totalCost));

  const greeting = String(rawGreeting ?? '').trim() || (isSuper ? '🧧 بركة وسعادة للجميع ✨' : '🧧 حظ سعيد للجميع 🎁');

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
      const bagId = `red_${now}_${ownerId}_${Math.floor(Math.random() * 1e6)}`;
      const ownerName = String(ownerData.name ?? 'عضو');
      const ownerPhoto = String(ownerData.photo_url ?? ownerData.photoUrl ?? '');
      const ownerVip = asInt(ownerData.vip_level ?? ownerData.vipLevel ?? 0);
      const ownerLevel = asInt(ownerData.level ?? 1);

      txn.set(db.collection('lucky_bags').doc(bagId), {
        id: bagId,
        bag_id: bagId,
        room_id: roomIdStr,
        owner_id: ownerId,
        owner_name: ownerName,
        owner_photo: ownerPhoto,
        owner_vip: ownerVip,
        owner_level: ownerLevel,
        type,
        scope,
        is_super: isSuper,
        greeting_text: greeting,
        total_value: totalCost,
        remaining_value: totalCost,
        total_bags: count,
        total_shares: count,
        bags_taken: 0,
        claimed_shares: 0,
        luckiest_user_id: '',
        luckiest_name: '',
        luckiest_amount: 0,
        created_at: new Date(now).toISOString(),
        expires_at: new Date(now + ttl).toISOString(),
        status: 'active',
      });

      const text = isSuper
        ? `🧧🌟 أرسل ${ownerName} مظروفاً أحمر سوبر بمجموع ${totalCost} 🪙 (${count} نصيب) : "${greeting}"`
        : `🧧 أرسل ${ownerName} مظروف الحظ (${count} نصيب) بمجموع ${totalCost} 🪙 : "${greeting}"`;

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
          ownerVip,
          ownerLevel,
          type,
          scope,
          isSuper,
          greetingText: greeting,
          value: Math.floor(totalCost / count),
          totalBags: count,
          totalShares: count,
          totalValue: totalCost,
          remainingValue: totalCost,
          claimedShares: 0,
          status: 'active',
          expiresAt: new Date(now + ttl).toISOString(),
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

      return {
        success: true,
        bagId,
        totalValue: totalCost,
        totalShares: count,
        isSuper,
        greetingText: greeting,
        expiresAt: now + ttl,
      };
    });

    res.json(result);
  } catch (err: any) {
    res.status(400).json({ error: String(err?.message ?? 'server_error') });
  }
});

/**
 * POST /api/v1/lucky-bags/grab
 * Server-authoritative grab/open for Red Envelopes:
 * - Checks double claiming (one claim per user per envelope)
 * - Computes randomized lucky distribution
 * - Crowns the luckiest winner (ملك الحظ)
 * - Credits claimer coins in a single atomic transaction
 */
router.post('/grab', authenticate, async (req: Request, res: Response) => {
  const claimerId = req.user?.uid;
  if (!claimerId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  const { roomId, bagId: targetBagId } = req.body ?? {};
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
    let bagRef: DocumentReference | null = null;
    let bagData: Record<string, any> = {};

    if (targetBagId) {
      const doc = await db.collection('lucky_bags').doc(String(targetBagId)).get();
      if (doc.exists) {
        bagRef = doc.ref;
        bagData = doc.data() ?? {};
      }
    }

    if (!bagRef) {
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
    }

    if (!bagRef) {
      res.status(404).json({ error: 'no_active_bag' });
      return;
    }

    const currentBagId = String(bagData.id ?? bagData.bag_id ?? '');

    // Check if user already claimed this bag
    const existingClaimQ = await db.collection('lucky_bag_claims')
      .where('bag_id', '==', currentBagId)
      .where('claimer_id', '==', claimerId)
      .limit(1)
      .get();

    if (!existingClaimQ.empty) {
      const existingData = existingClaimQ.docs[0].data();
      res.status(400).json({
        error: 'already_claimed',
        amount: asInt(existingData.amount),
        claimId: existingData.id,
      });
      return;
    }

    const scope = String(bagData.scope ?? 'room');
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
        isOnMic = true;
      }
    }

    const result = await db.runTransaction(async (txn) => {
      const claimerRef = db.collection('users').doc(claimerId);
      const ownerRef = db.collection('users').doc(String(bagData.owner_id ?? ''));

      const [bSnap, claimerSnap, ownerSnap] = await Promise.all([
        txn.get(bagRef!),
        txn.get(claimerRef),
        txn.get(ownerRef),
      ]);

      if (!bSnap.exists) throw new Error('bag_not_found');
      const b = bSnap.data() ?? {};
      if (b.status !== 'active') throw new Error('bag_inactive');
      const remaining = asInt(b.remaining_value);
      if (remaining <= 0) throw new Error('bag_empty');
      if (new Date(String(b.expires_at)).getTime() <= Date.now()) throw new Error('bag_expired');
      if (scope === 'mic' && !isOnMic) throw new Error('mic_only');
      if (!claimerSnap.exists) throw new Error('claimer_not_found');
      const cd = claimerSnap.data() ?? {};

      const totalShares = asInt(b.total_shares ?? b.total_bags ?? 1);
      const claimedShares = asInt(b.claimed_shares ?? b.bags_taken ?? 0);
      const remainingShares = Math.max(1, totalShares - claimedShares);

      let amount = 1;
      if (remainingShares === 1) {
        amount = remaining;
      } else {
        const avg = remaining / remainingShares;
        const maxDraw = Math.max(1, Math.floor(avg * 2));
        amount = Math.max(1, Math.min(remaining - (remainingShares - 1), Math.floor(1 + Math.random() * maxDraw)));
      }

      const newRemaining = Math.max(0, remaining - amount);
      const newClaimedShares = claimedShares + 1;
      const isDone = newRemaining <= 0 || newClaimedShares >= totalShares;
      const newStatus = isDone ? 'done' : 'active';

      const currentLuckiestAmount = asInt(b.luckiest_amount ?? 0);
      const isLuckiest = amount > currentLuckiestAmount;
      const newLuckiestId = isLuckiest ? claimerId : String(b.luckiest_user_id ?? '');
      const newLuckiestName = isLuckiest ? String(cd.name ?? '') : String(b.luckiest_name ?? '');
      const newLuckiestAmount = isLuckiest ? amount : currentLuckiestAmount;

      const claimId = `claim_${Date.now()}_${claimerId}_${Math.floor(Math.random() * 1e6)}`;
      const nowIso = new Date(Date.now()).toISOString();

      txn.set(db.collection('lucky_bag_claims').doc(claimId), {
        id: claimId,
        bag_id: currentBagId,
        room_id: roomIdStr,
        claimer_id: claimerId,
        claimer_name: String(cd.name ?? 'عضو'),
        claimer_avatar: String(cd.photo_url ?? cd.photoUrl ?? ''),
        amount,
        is_luckiest: isLuckiest,
        created_at: nowIso,
      });

      txn.update(bagRef!, {
        remaining_value: newRemaining,
        bags_taken: newClaimedShares,
        claimed_shares: newClaimedShares,
        luckiest_user_id: newLuckiestId,
        luckiest_name: newLuckiestName,
        luckiest_amount: newLuckiestAmount,
        status: newStatus,
      });

      txn.update(claimerRef, { coins: asInt(cd.coins) + amount });

      const text = `🧧 فتح ${String(cd.name ?? '')} المظروف وحصل على ${amount} 🪙`;
      txn.set(db.collection('room_messages').doc(), {
        msg_id: claimId,
        room_id: roomIdStr,
        sender_uid: claimerId,
        sender_name: String(cd.name ?? ''),
        type: 'lucky_bag_claim',
        text,
        image_url: '',
        lucky_bag_payload: {
          bagId: currentBagId,
          roomId: roomIdStr,
          claimerName: String(cd.name ?? ''),
          claimerAvatar: String(cd.photo_url ?? cd.photoUrl ?? ''),
          amount,
          remaining: newRemaining,
          isLuckiest,
          isDone,
        },
        created_at: nowIso,
      });

      // If expired with remaining coins, return leftovers to the owner
      if (isDone && newRemaining > 0 && ownerSnap.exists) {
        const od = ownerSnap.data() ?? {};
        txn.update(ownerRef, { coins: asInt(od.coins) + newRemaining });
      }

      return {
        success: true,
        claimId,
        bagId: currentBagId,
        amount,
        remaining: newRemaining,
        isDone,
        isLuckiest,
        type: String(b.type ?? 'coins'),
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

/**
 * GET /api/v1/lucky-bags/details/:bagId
 * Fetches full details and claims list for a Red Envelope
 */
router.get('/details/:bagId', authenticate, async (req: Request, res: Response) => {
  const { bagId } = req.params;
  if (!bagId) {
    res.status(400).json({ error: 'Missing bagId' });
    return;
  }

  try {
    const bagDoc = await db.collection('lucky_bags').doc(String(bagId)).get();
    if (!bagDoc.exists) {
      res.status(404).json({ error: 'bag_not_found' });
      return;
    }

    const bag = bagDoc.data() ?? {};
    const claimsSnap = await db.collection('lucky_bag_claims')
      .where('bag_id', '==', bagId)
      .orderBy('created_at', 'desc')
      .limit(100)
      .get();

    let maxAmount = 0;
    const claims = claimsSnap.docs.map((d) => {
      const data = d.data();
      const amt = asInt(data.amount);
      if (amt > maxAmount) maxAmount = amt;
      return {
        id: d.id,
        claimerId: data.claimer_id,
        claimerName: data.claimer_name,
        claimerAvatar: data.claimer_avatar,
        amount: amt,
        isLuckiest: data.is_luckiest === true,
        createdAt: data.created_at,
      };
    });

    // Mark the luckiest claim
    claims.forEach((c) => {
      if (c.amount === maxAmount && maxAmount > 0) {
        c.isLuckiest = true;
      }
    });

    res.json({
      success: true,
      bag: {
        id: bag.id ?? bag.bag_id,
        roomId: bag.room_id,
        ownerId: bag.owner_id,
        ownerName: bag.owner_name,
        ownerAvatar: bag.owner_photo,
        ownerVip: bag.owner_vip ?? 0,
        ownerLevel: bag.owner_level ?? 1,
        type: bag.type ?? 'coins',
        scope: bag.scope ?? 'room',
        isSuper: bag.is_super === true,
        greetingText: bag.greeting_text ?? '',
        totalValue: bag.total_value ?? 0,
        remainingValue: bag.remaining_value ?? 0,
        totalShares: bag.total_shares ?? bag.total_bags ?? 0,
        claimedShares: bag.claimed_shares ?? bag.bags_taken ?? 0,
        status: bag.status ?? 'active',
        createdAt: bag.created_at,
        expiresAt: bag.expires_at,
      },
      claims,
    });
  } catch (err: any) {
    res.status(500).json({ error: String(err?.message ?? 'server_error') });
  }
});

/**
 * GET /api/v1/lucky-bags/active/:roomId
 * Returns currently active red envelopes in a room
 */
router.get('/active/:roomId', authenticate, async (req: Request, res: Response) => {
  const { roomId } = req.params;
  try {
    const qs = await db.collection('lucky_bags')
      .where('room_id', '==', String(roomId))
      .where('status', '==', 'active')
      .orderBy('created_at', 'desc')
      .limit(10)
      .get();

    const now = Date.now();
    const bags = qs.docs
      .map((d) => d.data())
      .filter((d) => asInt(d.remaining_value) > 0 && new Date(String(d.expires_at)).getTime() > now);

    res.json({ success: true, bags });
  } catch (err: any) {
    res.status(500).json({ error: String(err?.message ?? 'server_error') });
  }
});

export default router;

