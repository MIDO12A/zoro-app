import { Router, Request, Response } from 'express';
import { db } from '../config/database';
import { authenticate, requireRole } from '../middleware/auth';
import { getVipTiers, getVipTier, calculateVipLevel } from '../services/vipService';

const router = Router();

router.get('/tiers', (_req: Request, res: Response) => {
  res.json({ tiers: getVipTiers() });
});

router.get('/:uid', authenticate, async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;

    const doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const user = doc.data()!;
    const tier = user.vip_tier || 0;
    const nextTier = calculateVipLevel((user.recharge_exp || 0) + 1);
    const tierInfo = getVipTier(tier);
    const nextTierInfo = tier < 15 ? getVipTier(tier + 1) : null;

    res.json({
      current_tier: tier,
      tier_info: tierInfo || null,
      next_tier: tier < 15 ? tier + 1 : null,
      next_tier_info: nextTierInfo || null,
      recharge_for_next: nextTierInfo ? nextTierInfo.monthly_price - (user.recharge_exp || 0) : 0,
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/set-tier', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { uid, tier } = req.body;

    if (tier < 0 || tier > 15) {
      res.status(400).json({ error: 'Tier must be 0-15' });
      return;
    }

    await db.collection('users').doc(uid).set({ vip_tier: tier }, { merge: true });

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
