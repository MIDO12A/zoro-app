import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import levelRoutes from './routes/levels';
import vipRoutes from './routes/vip';
import rechargeRoutes from './routes/recharge';
import agencyRoutes from './routes/agencies';
import rankingRoutes from './routes/rankings';
import cpRewardRoutes from './routes/cpRewards';

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/levels', levelRoutes);
app.use('/api/v1/vip', vipRoutes);
app.use('/api/v1/recharge', rechargeRoutes);
app.use('/api/v1/agencies', agencyRoutes);
app.use('/api/v1/rankings', rankingRoutes);
app.use('/api/v1/cp-rewards', cpRewardRoutes);

app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.use((err: any, _req: any, res: any, _next: any) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

export default app;
