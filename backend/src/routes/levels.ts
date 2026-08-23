import { Router, Request, Response } from 'express';
import { supabase } from '../config/database';
import { authenticate, requireRole } from '../middleware/auth';
import { getLevelConfig, getLevelByXp, addXp } from '../services/levelService';

const router = Router();

router.get('/config', (_req: Request, res: Response) => {
  res.json({ levels: getLevelConfig() });
});

router.get('/:uid', authenticate, async (req: Request, res: Response) => {
  try {
    const { uid } = req.params;

    const { data: user, error } = await supabase
      .from('users')
      .select('uid, level, experience, wealth_level, wealth_exp, recharge_level, recharge_exp, gems_level, gems_exp, owned_level_frames, owned_level_badges')
      .eq('uid', uid)
      .single();

    if (error) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const mainLevel = getLevelByXp(user.experience);
    const wealthLevel = getLevelByXp(user.wealth_exp);
    const rechargeLevel = getLevelByXp(user.recharge_exp);
    const gemsLevel = getLevelByXp(user.gems_exp);

    res.json({
      main: { ...mainLevel, db_level: user.level },
      wealth: { ...wealthLevel, db_level: user.wealth_level },
      recharge: { ...rechargeLevel, db_level: user.recharge_level },
      gems: { ...gemsLevel, db_level: user.gems_level },
      owned_frames: user.owned_level_frames,
      owned_badges: user.owned_level_badges,
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/add-xp', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { uid, amount, type } = req.body;

    if (!uid || !amount || !type) {
      res.status(400).json({ error: 'uid, amount, and type (experience|wealth_exp|recharge_exp|gems_exp) required' });
      return;
    }

    await addXp(uid, amount, type);

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
