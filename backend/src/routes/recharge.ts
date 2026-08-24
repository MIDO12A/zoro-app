import { Router, Request, Response } from 'express';
import { db } from '../config/database';
import { authenticate, requireRole } from '../middleware/auth';
import { getRechargePlans, createOrder, completeOrder, getUserOrders } from '../services/rechargeService';

const router = Router();

router.get('/plans', (_req: Request, res: Response) => {
  res.json({ plans: getRechargePlans() });
});

router.post('/create-order', authenticate, async (req: Request, res: Response) => {
  try {
    const { planId } = req.body;
    const uid = req.user!.uid;

    const result = await createOrder(uid, planId);

    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }

    res.status(201).json({ order: result.order, plan: result.plan });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/complete-order', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { orderId } = req.body;
    const adminUid = req.user!.uid;

    const result = await completeOrder(orderId, adminUid);

    if (!result.success) {
      res.status(400).json({ error: result.error });
      return;
    }

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/orders', authenticate, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.uid;
    const orders = await getUserOrders(uid);
    res.json({ orders });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/orders/all', authenticate, requireRole('admin'), async (_req: Request, res: Response) => {
  try {
    const snap = await db
      .collection('recharge_orders')
      .orderBy('created_at', 'desc')
      .limit(100)
      .get();

    res.json({ orders: snap.docs.map(d => d.data()) });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
