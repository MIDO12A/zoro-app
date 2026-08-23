import { Router, Request, Response } from 'express';
import {
  getStatus,
  distributeRewards,
  expireRewards,
  triggerCheck,
} from '../services/cpRewardService';

const router = Router();

router.get('/status', async (_req: Request, res: Response) => {
  try {
    const status = await getStatus();
    res.json({ success: true, ...status });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/distribute', async (_req: Request, res: Response) => {
  try {
    const result = await distributeRewards();
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/expire', async (_req: Request, res: Response) => {
  try {
    const result = await expireRewards();
    res.json({ success: true, ...result });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/check', async (_req: Request, res: Response) => {
  try {
    const result = await triggerCheck();
    res.json({ success: true, ...result });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

export default router;
