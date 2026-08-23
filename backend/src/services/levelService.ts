import { supabase } from '../config/database';

interface LevelConfig {
  level: number;
  xp_required: number;
  title: string;
  rewards: { type: string; value: number }[];
}

const LEVEL_CONFIGS: LevelConfig[] = [];

for (let i = 1; i <= 100; i++) {
  LEVEL_CONFIGS.push({
    level: i,
    xp_required: Math.floor(100 * Math.pow(1.15, i - 1)),
    title: i <= 10 ? 'مبتدئ' : i <= 30 ? 'متقدم' : i <= 60 ? 'خبير' : i <= 80 ? 'أسطورة' : 'خرافي',
    rewards: i % 10 === 0 ? [{ type: 'coins', value: i * 500 }] : [],
  });
}

export function getLevelConfig(): LevelConfig[] {
  return LEVEL_CONFIGS;
}

export function getLevelByXp(xp: number): { level: number; xp: number; nextLevelXp: number; progress: number } {
  let level = 1;
  let remaining = xp;

  for (const cfg of LEVEL_CONFIGS) {
    if (remaining >= cfg.xp_required) {
      remaining -= cfg.xp_required;
      level = cfg.level + 1;
    } else {
      break;
    }
  }

  level = Math.min(level, 100);
  const currentLevelXp = LEVEL_CONFIGS[Math.min(level - 1, LEVEL_CONFIGS.length - 1)].xp_required;
  const nextLevelXp = level < 100 ? LEVEL_CONFIGS[level].xp_required : currentLevelXp;

  return {
    level,
    xp: remaining,
    nextLevelXp,
    progress: currentLevelXp > 0 ? remaining / currentLevelXp : 0,
  };
}

export async function addXp(uid: string, amount: number, field: 'experience' | 'wealth_exp' | 'recharge_exp' | 'gems_exp'): Promise<void> {
  const { data: user, error } = await supabase
    .from('users')
    .select(`${field}, level, coins`)
    .eq('uid', uid)
    .single();

  if (error || !user) throw new Error('User not found');

  const newXp = ((user as any)[field] || 0) + amount;
  const updates: Record<string, number> = { [field]: newXp };

  if (field === 'experience') {
    const { level: newLevel } = getLevelByXp(newXp);
    if (newLevel > user.level) {
      updates.level = newLevel;
      const reward = LEVEL_CONFIGS.find(l => l.level === newLevel)?.rewards?.[0];
      if (reward?.type === 'coins') {
        const { data: currentUser } = await supabase
          .from('users')
          .select('coins')
          .eq('uid', uid)
          .single();
        if (currentUser) {
          updates.coins = (currentUser.coins || 0) + (reward.value as number);
        }
      }
    }
  }

  const { error: updateError } = await supabase
    .from('users')
    .update(updates)
    .eq('uid', uid);

  if (updateError) throw updateError;
}
