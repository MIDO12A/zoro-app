import { Router, Request, Response } from 'express';
import { supabase } from '../config/database';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

router.get('/search', authenticate, async (req: Request, res: Response) => {
  try {
    const { q, custom_id } = req.query;

    let query = supabase.from('users').select('uid, custom_id, name, photo_url, level, vip_tier');

    if (custom_id) {
      query = query.eq('custom_id', custom_id as string);
    } else if (q) {
      query = query.or(`name.ilike.%${q}%,custom_id.ilike.%${q}%`);
    } else {
      res.status(400).json({ error: 'Provide q or custom_id' });
      return;
    }

    const { data, error } = await query.limit(20);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ users: data });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:uid/profile', authenticate, async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;

    const { data: user, error } = await supabase
      .from('users')
      .select('uid, custom_id, name, photo_url, gender, level, experience, vip_tier, coins, diamonds, total_gifts_sent, total_gifts_received, followers, following, visitors, charm, active_frame, active_headwear, active_bubble, active_entrance, active_car, active_cover, owned_badges, owned_level_frames, owned_level_badges, owned_necklaces')
      .eq('uid', uid)
      .single();

    if (error) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ user });
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

    const { error } = await supabase.from('users').update(updates).eq('uid', uid);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/by-custom/:customId', authenticate, async (req: Request, res: Response) => {
  try {
    const { customId } = req.params;

    const { data: user, error } = await supabase
      .from('users')
      .select('uid, custom_id, name, photo_url, level')
      .eq('custom_id', customId)
      .single();

    if (error) {
      res.status(404).json({ error: 'User not found with this ID' });
      return;
    }

    res.json({ user });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:uid/ban', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;
    const { reason } = req.body;

    const { error } = await supabase
      .from('users')
      .update({ banned: true, ban_reason: reason || 'No reason' })
      .eq('uid', uid);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:uid/unban', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;

    const { error } = await supabase
      .from('users')
      .update({ banned: false, ban_reason: '' })
      .eq('uid', uid);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

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
      const { data: existing } = await supabase
        .from('users')
        .select('custom_id')
        .eq('custom_id', customId)
        .maybeSingle();
      if (!existing) break;
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

    const { error } = await supabase
      .from('users')
      .update({ role: 'admin' })
      .eq('uid', uid);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
