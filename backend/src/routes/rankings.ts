import { Router, Request, Response } from 'express';
import { supabase } from '../config/database';

const router = Router();

router.get('/wealth', async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('uid, custom_id, name, photo_url, total_gifts_sent, level')
      .order('total_gifts_sent', { ascending: false })
      .limit(100);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ rankings: data });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/charm', async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('uid, custom_id, name, photo_url, total_gifts_received, level')
      .order('total_gifts_received', { ascending: false })
      .limit(100);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ rankings: data });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/room', async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('rooms')
      .select('room_id, name, room_photo_url, host_name, total_gifts, hot_value')
      .order('total_gifts', { ascending: false })
      .limit(100);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ rankings: data });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/recharge', async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('uid, custom_id, name, photo_url, recharge_exp, vip_tier')
      .order('recharge_exp', { ascending: false })
      .limit(100);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ rankings: data });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/level', async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('uid, custom_id, name, photo_url, level, experience')
      .order('experience', { ascending: false })
      .limit(100);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ rankings: data });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
