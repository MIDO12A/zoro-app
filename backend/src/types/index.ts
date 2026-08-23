export interface User {
  uid: string;
  custom_id: string;
  name: string;
  email: string;
  photo_url: string;
  coins: number;
  diamonds: number;
  gender: string;
  phone: string;
  last_ip: string;
  level: number;
  experience: number;
  wealth_level: number;
  wealth_exp: number;
  recharge_level: number;
  recharge_exp: number;
  gems_level: number;
  gems_exp: number;
  total_gifts_sent: number;
  total_gifts_received: number;
  followers: number;
  following: number;
  visitors: number;
  charm: number;
  banned: boolean;
  ban_reason: string;
  role: 'user' | 'agent' | 'admin';
  agency_id: string | null;
  created_at: string;
}

export interface AuthPayload {
  uid: string;
  role: 'user' | 'agent' | 'admin';
}

export interface LevelConfig {
  id: number;
  level: number;
  xp_required: number;
  rewards: LevelReward[];
  title: string;
}

export interface LevelReward {
  type: 'coins' | 'diamonds' | 'frame' | 'badge' | 'necklace' | 'item';
  value: string | number;
}

export interface VipTier {
  id: number;
  tier: number;
  name: string;
  name_ar: string;
  monthly_fee: number;
  benefits: VipBenefit[];
  badge_asset: string;
  card_asset: string;
}

export interface VipBenefit {
  type: 'coins' | 'diamonds' | 'discount' | 'frame' | 'badge' | 'priority' | 'exclusive_item';
  value: string | number;
  description: string;
}

export interface RechargePlan {
  id: number;
  name: string;
  price: number;
  diamonds: number;
  bonus_diamonds: number;
  popular: boolean;
}

export interface RechargeOrder {
  id: string;
  user_id: string;
  plan_id: number;
  amount: number;
  diamonds: number;
  status: 'pending' | 'completed' | 'failed';
  payment_method: string;
  created_at: string;
  completed_at: string | null;
}

export interface Agency {
  id: string;
  name: string;
  code: string;
  owner_uid: string;
  commission_rate: number;
  total_earnings: number;
  member_count: number;
  status: 'active' | 'suspended';
  created_at: string;
}

export interface AgencyMember {
  id: string;
  agency_id: string;
  user_uid: string;
  role: 'agent' | 'sub_agent';
  commission_rate: number;
  joined_at: string;
}
