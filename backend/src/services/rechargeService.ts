import { v4 as uuidv4 } from 'uuid';
import { supabase } from '../config/database';
import { calculateVipLevel } from './vipService';
import { addXp } from './levelService';

export interface RechargePlan {
  id: number;
  name: string;
  price: number;
  diamonds: number;
  bonus_diamonds: number;
  popular: boolean;
}

const RECHARGE_PLANS: RechargePlan[] = [
  { id: 1, name: '50 Diamonds', price: 1, diamonds: 50, bonus_diamonds: 0, popular: false },
  { id: 2, name: '200 Diamonds', price: 2, diamonds: 200, bonus_diamonds: 10, popular: false },
  { id: 3, name: '500 Diamonds', price: 5, diamonds: 500, bonus_diamonds: 25, popular: false },
  { id: 4, name: '1,200 Diamonds', price: 10, diamonds: 1200, bonus_diamonds: 50, popular: true },
  { id: 5, name: '2,500 Diamonds', price: 20, diamonds: 2500, bonus_diamonds: 150, popular: false },
  { id: 6, name: '6,000 Diamonds', price: 50, diamonds: 6000, bonus_diamonds: 400, popular: false },
  { id: 7, name: '15,000 Diamonds', price: 100, diamonds: 15000, bonus_diamonds: 1500, popular: true },
  { id: 8, name: '40,000 Diamonds', price: 250, diamonds: 40000, bonus_diamonds: 5000, popular: false },
  { id: 9, name: '100,000 Diamonds', price: 500, diamonds: 100000, bonus_diamonds: 20000, popular: false },
  { id: 10, name: '250,000 Diamonds', price: 1000, diamonds: 250000, bonus_diamonds: 75000, popular: true },
];

export function getRechargePlans(): RechargePlan[] {
  return RECHARGE_PLANS;
}

export async function createOrder(userId: string, planId: number): Promise<{ order: any; plan: RechargePlan } | { error: string }> {
  const plan = RECHARGE_PLANS.find(p => p.id === planId);
  if (!plan) return { error: 'Invalid plan' };

  const order = {
    id: uuidv4(),
    user_id: userId,
    plan_id: planId,
    amount: plan.price,
    diamonds: plan.diamonds + plan.bonus_diamonds,
    status: 'pending',
    payment_method: 'manual',
    created_at: new Date().toISOString(),
    completed_at: null,
  };

  const { error } = await supabase.from('recharge_orders').insert(order);
  if (error) return { error: error.message };

  return { order, plan };
}

export async function completeOrder(orderId: string, adminUid: string): Promise<{ success: boolean; error?: string }> {
  const { data: order, error: fetchError } = await supabase
    .from('recharge_orders')
    .select('*')
    .eq('id', orderId)
    .single();

  if (fetchError || !order) return { success: false, error: 'Order not found' };
  if (order.status !== 'pending') return { success: false, error: 'Order already processed' };

  const userUid = order.user_id;

  const { data: user } = await supabase
    .from('users')
    .select('diamonds, recharge_level, recharge_exp')
    .eq('uid', userUid)
    .single();

  if (!user) return { success: false, error: 'User not found' };

  const totalDiamonds = (user.diamonds || 0) + order.diamonds;
  const rechargeXp = (user.recharge_exp || 0) + order.amount;

  await supabase
    .from('recharge_orders')
    .update({ status: 'completed', completed_at: new Date().toISOString() })
    .eq('id', orderId);

  await supabase
    .from('users')
    .update({
      diamonds: totalDiamonds,
      recharge_exp: rechargeXp,
      vip_tier: calculateVipLevel(rechargeXp),
    })
    .eq('uid', userUid);

  try {
    await addXp(userUid, order.amount * 10, 'recharge_exp');
  } catch {}

  return { success: true };
}

export async function getUserOrders(userId: string): Promise<any[]> {
  const { data } = await supabase
    .from('recharge_orders')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(50);

  return data || [];
}
