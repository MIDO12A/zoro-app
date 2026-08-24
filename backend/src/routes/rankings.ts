import { Router, Request, Response } from 'express';
import { db } from '../config/database';

const router = Router();

router.get('/wealth', async (_req: Request, res: Response) => {
  try {
    const snap = await db
      .collection('users')
      .orderBy('total_gifts_sent', 'desc')
      .limit(100)
      .get();

    const rankings = snap.docs.map(d => {
      const u = d.data();
      return { uid: u.uid, custom_id: u.custom_id, name: u.name, photo_url: u.photo_url, total_gifts_sent: u.total_gifts_sent, level: u.level };
    });

    res.json({ rankings });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/charm', async (_req: Request, res: Response) => {
  try {
    const snap = await db
      .collection('users')
      .orderBy('total_gifts_received', 'desc')
      .limit(100)
      .get();

    const rankings = snap.docs.map(d => {
      const u = d.data();
      return { uid: u.uid, custom_id: u.custom_id, name: u.name, photo_url: u.photo_url, total_gifts_received: u.total_gifts_received, level: u.level };
    });

    res.json({ rankings });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/room', async (_req: Request, res: Response) => {
  try {
    const snap = await db
      .collection('rooms')
      .orderBy('total_gifts', 'desc')
      .limit(100)
      .get();

    const rankings = snap.docs.map(d => {
      const r = d.data();
      return { room_id: r.room_id, name: r.name, room_photo_url: r.room_photo_url, host_name: r.host_name, total_gifts: r.total_gifts, hot_value: r.hot_value };
    });

    res.json({ rankings });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/recharge', async (_req: Request, res: Response) => {
  try {
    const snap = await db
      .collection('users')
      .orderBy('recharge_exp', 'desc')
      .limit(100)
      .get();

    const rankings = snap.docs.map(d => {
      const u = d.data();
      return { uid: u.uid, custom_id: u.custom_id, name: u.name, photo_url: u.photo_url, recharge_exp: u.recharge_exp, vip_tier: u.vip_tier };
    });

    res.json({ rankings });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/level', async (_req: Request, res: Response) => {
  try {
    const snap = await db
      .collection('users')
      .orderBy('experience', 'desc')
      .limit(100)
      .get();

    const rankings = snap.docs.map(d => {
      const u = d.data();
      return { uid: u.uid, custom_id: u.custom_id, name: u.name, photo_url: u.photo_url, level: u.level, experience: u.experience };
    });

    res.json({ rankings });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
