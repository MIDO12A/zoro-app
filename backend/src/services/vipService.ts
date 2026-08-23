export interface VipTier {
  tier: number;
  name: string;
  name_ar: string;
  monthly_price: number;
  benefits: string[];
  badge_asset: string;
  card_asset: string;
}

const VIP_TIERS: VipTier[] = [
  { tier: 0, name: 'None', name_ar: 'عادي', monthly_price: 0, benefits: [], badge_asset: '', card_asset: '' },
  { tier: 1, name: 'VIP 1', name_ar: 'VIP 1', monthly_price: 50, benefits: ['chat_effects', 'special_badge'], badge_asset: 'vip1_badge', card_asset: 'vip1_card' },
  { tier: 2, name: 'VIP 2', name_ar: 'VIP 2', monthly_price: 100, benefits: ['chat_effects', 'special_badge', 'name_color'], badge_asset: 'vip2_badge', card_asset: 'vip2_card' },
  { tier: 3, name: 'VIP 3', name_ar: 'VIP 3', monthly_price: 200, benefits: ['chat_effects', 'special_badge', 'name_color', 'exclusive_items'], badge_asset: 'vip3_badge', card_asset: 'vip3_card' },
  { tier: 4, name: 'VIP 4', name_ar: 'VIP 4', monthly_price: 350, benefits: ['chat_effects', 'special_badge', 'name_color', 'exclusive_items', 'priority_support'], badge_asset: 'vip4_badge', card_asset: 'vip4_card' },
  { tier: 5, name: 'VIP 5', name_ar: 'VIP 5', monthly_price: 500, benefits: ['all', 'gold_name', 'unique_frame'], badge_asset: 'vip5_badge', card_asset: 'vip5_card' },
  { tier: 6, name: 'VIP 6', name_ar: 'VIP 6', monthly_price: 1000, benefits: ['all', 'gold_name', 'unique_frame', 'custom_emoji'], badge_asset: 'vip6_badge', card_asset: 'vip6_card' },
  { tier: 7, name: 'VIP 7', name_ar: 'VIP 7', monthly_price: 2000, benefits: ['all', 'diamond_name', 'premium_frame', 'custom_emoji', 'priority_matchmaking'], badge_asset: 'vip7_badge', card_asset: 'vip7_card' },
  { tier: 8, name: 'VIP 8', name_ar: 'VIP 8', monthly_price: 3500, benefits: ['all', 'royal_name', 'royal_frame', 'custom_emoji', 'priority_matchmaking', 'exclusive_room'], badge_asset: 'vip8_badge', card_asset: 'vip8_card' },
  { tier: 9, name: 'VIP 9', name_ar: 'VIP 9', monthly_price: 5000, benefits: ['all', 'legendary_name', 'legendary_frame', 'custom_emoji', 'priority_matchmaking', 'exclusive_room', 'dedicated_support'], badge_asset: 'vip9_badge', card_asset: 'vip9_card' },
  { tier: 10, name: 'VIP 10', name_ar: 'VIP 10', monthly_price: 10000, benefits: ['all_previous', 'custom_tag', 'animated_frame', 'global_effects'], badge_asset: 'vip10_badge', card_asset: 'vip10_card' },
  { tier: 11, name: 'VIP 11', name_ar: 'VIP 11', monthly_price: 15000, benefits: ['all_previous', 'emperor_tag', 'animated_card', 'vip_room'], badge_asset: 'vip11_badge', card_asset: 'vip11_card' },
  { tier: 12, name: 'VIP 12', name_ar: 'VIP 12', monthly_price: 25000, benefits: ['all_previous', 'god_tag', 'animated_card', 'vip_room', 'gift_discount'], badge_asset: 'vip12_badge', card_asset: 'vip12_card' },
  { tier: 13, name: 'VIP 13', name_ar: 'VIP 13', monthly_price: 50000, benefits: ['all', 'supreme_tag', 'animated_card', 'vip_room', 'max_discount'], badge_asset: 'vip13_badge', card_asset: 'vip13_card' },
  { tier: 14, name: 'VIP 14', name_ar: 'VIP 14', monthly_price: 75000, benefits: ['all', 'immortal_tag', 'animated_card', 'vip_room', 'max_discount', 'custom_room_theme'], badge_asset: 'vip14_badge', card_asset: 'vip14_card' },
  { tier: 15, name: 'VIP 15', name_ar: 'VIP 15', monthly_price: 100000, benefits: ['all', 'creator_tag', 'animated_card', 'vip_room', 'max_discount', 'custom_room_theme', 'global_admin_access'], badge_asset: 'vip15_badge', card_asset: 'vip15_card' },
];

export function getVipTiers(): VipTier[] {
  return VIP_TIERS;
}

export function getVipTier(tier: number): VipTier | undefined {
  return VIP_TIERS.find(t => t.tier === tier);
}

export function calculateVipLevel(totalRecharge: number): number {
  if (totalRecharge >= 100000) return 15;
  if (totalRecharge >= 75000) return 14;
  if (totalRecharge >= 50000) return 13;
  if (totalRecharge >= 25000) return 12;
  if (totalRecharge >= 15000) return 11;
  if (totalRecharge >= 10000) return 10;
  if (totalRecharge >= 5000) return 9;
  if (totalRecharge >= 3500) return 8;
  if (totalRecharge >= 2000) return 7;
  if (totalRecharge >= 1000) return 6;
  if (totalRecharge >= 500) return 5;
  if (totalRecharge >= 350) return 4;
  if (totalRecharge >= 200) return 3;
  if (totalRecharge >= 100) return 2;
  if (totalRecharge >= 50) return 1;
  return 0;
}
