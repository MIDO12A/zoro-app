import { Router, Request, Response } from 'express';
import { db } from '../config/database';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

const USER_PUBLIC_FIELDS = ['uid', 'custom_id', 'name', 'photo_url', 'gender', 'level', 'experience', 'vip_tier', 'coins', 'diamonds', 'total_gifts_sent', 'total_gifts_received', 'followers', 'following', 'visitors', 'charm', 'active_frame', 'active_headwear', 'active_bubble', 'active_entrance', 'active_car', 'active_cover', 'owned_badges', 'owned_level_frames', 'owned_level_badges', 'owned_necklaces'];

function pickFields(data: any, fields: string[]): Record<string, any> {
  const out: Record<string, any> = {};
  for (const f of fields) {
    if (data[f] !== undefined) out[f] = data[f];
  }
  return out;
}

router.get('/search', authenticate, async (req: Request, res: Response) => {
  try {
    const { q, custom_id } = req.query;

    const usersRef = db.collection('users');
    let snap;

    if (custom_id) {
      snap = await usersRef.where('custom_id', '==', custom_id as string).limit(20).get();
    } else if (q) {
      const term = (q as string).trim();
      if (/^\d+$/.test(term)) {
        snap = await usersRef.where('custom_id', '==', term).limit(20).get();
        if (snap.empty) {
          // fall back to prefix match on name for numeric-looking names
          snap = await usersRef.orderBy('name').startAt(term).endAt(term + '\uf8ff').limit(20).get();
        }
      } else {
        snap = await usersRef.orderBy('name').startAt(term).endAt(term + '\uf8ff').limit(20).get();
      }
    } else {
      res.status(400).json({ error: 'Provide q or custom_id' });
      return;
    }

    const users = snap.docs.map(d => pickFields(d.data(), ['uid', 'custom_id', 'name', 'photo_url', 'level', 'vip_tier']));
    res.json({ users });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:uid/profile', authenticate, async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;

    const doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ user: pickFields(doc.data()!, USER_PUBLIC_FIELDS) });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/profile', authenticate, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.uid;
    const allowedFields = ['name', 'photo_url', 'gender'];
    const updates: Record<string, any> = {};

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    }

    if (Object.keys(updates).length === 0) {
      res.status(400).json({ error: 'No valid fields to update' });
      return;
    }

    await db.collection('users').doc(uid).set(updates, { merge: true });

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/by-custom/:customId', authenticate, async (req: Request, res: Response) => {
  try {
    const { customId } = req.params;

    const snap = await db.collection('users').where('custom_id', '==', customId).limit(1).get();
    if (snap.empty) {
      res.status(404).json({ error: 'User not found with this ID' });
      return;
    }

    const d = snap.docs[0].data();
    res.json({ user: pickFields(d, ['uid', 'custom_id', 'name', 'photo_url', 'level']) });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:uid/ban', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;
    const { reason } = req.body;

    await db.collection('users').doc(uid).set({ banned: true, ban_reason: reason || 'No reason' }, { merge: true });

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:uid/unban', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;

    await db.collection('users').doc(uid).set({ banned: false, ban_reason: '' }, { merge: true });

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/generate-id', authenticate, async (_req: Request, res: Response) => {
  try {
    let customId: string;
    let attempts = 0;
    const maxAttempts = 50;

    do {
      const num = 1000000 + Math.floor(Math.random() * 9000000);
      customId = String(num);
      const existing = await db.collection('users').where('custom_id', '==', customId).limit(1).get();
      if (existing.empty) break;
      attempts++;
    } while (attempts < maxAttempts);

    if (attempts >= maxAttempts) {
      res.status(500).json({ error: 'Failed to generate unique ID' });
      return;
    }

    res.json({ customId });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/make-admin', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { uid } = req.body;

    await db.collection('users').doc(uid).set({ role: 'admin' }, { merge: true });

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
