import cron from 'node-cron';
import { supabase } from '../config/database';

interface RankReward {
  id: number;
  period: string;
  rank_position: number;
  slot_index: number;
  label_ar: string;
  label_en: string;
  svga_url: string;
  image_url: string;
  sort_order: number;
}

interface PeriodConfig {
  period_type: string;
  custom_days: number;
  reward_duration_days: number;
  last_distribution: string;
  next_distribution: string;
  last_period_start: string;
}

interface ActiveReward {
  user_uid: string;
  couple_id: string;
  rank: number;
  period: string;
  period_start: string;
  period_end: string;
  rewards: {
    type: string;
    label_ar: string;
    label_en: string;
    svga_url: string;
    image_url: string;
    slot_index: number;
    expires_at: string;
  }[];
  awarded_at: string;
}

interface CpCouple {
  id: string;
  user1_uid: string;
  user2_uid: string;
  week_score: number;
  month_score: number;
  total_score: number;
  started_at: string;
}

const SETTINGS_KEYS = {
  PERIOD_CONFIG: 'cp_reward_period_config',
  ACTIVE_REWARDS: 'cp_active_rewards',
  RANK_REWARDS_DATA: 'cp_rank_rewards_data',
  DISTRIBUTION_HISTORY: 'cp_distribution_history',
};

async function getSetting(key: string): Promise<string | null> {
  const { data, error } = await supabase
    .from('cp_settings')
    .select('value')
    .eq('key', key)
    .single();
  if (error || !data) return null;
  return data.value;
}

async function setSetting(key: string, value: string): Promise<void> {
  await supabase.from('cp_settings').upsert(
    { key, value, updated_at: new Date().toISOString() },
    { onConflict: 'key' }
  );
}

function parseJson<T>(raw: string | null, fallback: T): T {
  if (!raw) return fallback;
  try { return JSON.parse(raw); } catch { return fallback; }
}

async function getPeriodConfig(): Promise<PeriodConfig> {
  const raw = await getSetting(SETTINGS_KEYS.PERIOD_CONFIG);
  return parseJson(raw, {
    period_type: 'weekly',
    custom_days: 0,
    reward_duration_days: 7,
    last_distribution: new Date(0).toISOString(),
    next_distribution: new Date(0).toISOString(),
    last_period_start: new Date(0).toISOString(),
  });
}

async function savePeriodConfig(cfg: PeriodConfig): Promise<void> {
  await setSetting(SETTINGS_KEYS.PERIOD_CONFIG, JSON.stringify(cfg));
}

async function getActiveRewards(): Promise<ActiveReward[]> {
  const raw = await getSetting(SETTINGS_KEYS.ACTIVE_REWARDS);
  return parseJson(raw, []);
}

async function saveActiveRewards(rewards: ActiveReward[]): Promise<void> {
  await setSetting(SETTINGS_KEYS.ACTIVE_REWARDS, JSON.stringify(rewards));
}

async function getRankRewardsList(): Promise<RankReward[]> {
  const raw = await getSetting(SETTINGS_KEYS.RANK_REWARDS_DATA);
  return parseJson(raw, []);
}

function calcNextDistribution(cfg: PeriodConfig): string {
  const now = new Date();
  let next = new Date(now);

  switch (cfg.period_type) {
    case 'daily':
      next.setDate(next.getDate() + 1);
      next.setHours(0, 0, 0, 0);
      break;
    case 'weekly':
      next.setDate(next.getDate() + (7 - next.getDay()));
      next.setHours(0, 0, 0, 0);
      break;
    case 'monthly':
      next = new Date(next.getFullYear(), next.getMonth() + 1, 1, 0, 0, 0, 0);
      break;
    default:
      if (cfg.custom_days > 0) {
        next.setDate(next.getDate() + cfg.custom_days);
        next.setHours(0, 0, 0, 0);
      } else {
        next.setDate(next.getDate() + 7);
        next.setHours(0, 0, 0, 0);
      }
  }
  return next.toISOString();
}

async function getTopCouples(limit: number, period: string): Promise<CpCouple[]> {
  const orderCol = period === 'week' ? 'week_score'
    : period === 'month' ? 'month_score'
    : 'total_score';

  const { data, error } = await supabase
    .from('cp_couples')
    .select('id, user1_uid, user2_uid, week_score, month_score, total_score, started_at')
    .is('ended_at', null)
    .order(orderCol, { ascending: false })
    .limit(limit);

  if (error) {
    console.error('[CP Rewards] getTopCouples error:', error);
    return [];
  }
  return (data || []) as CpCouple[];
}

function getPeriodEndDisplay(cfg: PeriodConfig): string {
  const next = new Date(cfg.next_distribution);
  return next.toLocaleDateString('ar-EG', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
  });
}

export async function getStatus(): Promise<{
  periodConfig: PeriodConfig;
  activeRewardsCount: number;
  periodEndDisplay: string;
  canDistribute: boolean;
}> {
  const periodConfig = await getPeriodConfig();
  const active = await getActiveRewards();
  const now = new Date();
  const canDistribute = now >= new Date(periodConfig.next_distribution);

  return {
    periodConfig,
    activeRewardsCount: active.length,
    periodEndDisplay: getPeriodEndDisplay(periodConfig),
    canDistribute,
  };
}

export async function distributeRewards(): Promise<{ success: boolean; message: string; details?: any }> {
  try {
    const cfg = await getPeriodConfig();
    const rankRewards = await getRankRewardsList();
    const now = new Date();

    const periodKey = cfg.period_type === 'daily' ? 'week'
      : cfg.period_type === 'weekly' ? 'week'
      : cfg.period_type === 'monthly' ? 'month'
      : 'week';

    const topCouples = await getTopCouples(3, periodKey);

    if (topCouples.length === 0) {
      const newNext = calcNextDistribution(cfg);
      cfg.last_distribution = now.toISOString();
      cfg.next_distribution = newNext;
      cfg.last_period_start = now.toISOString();
      await savePeriodConfig(cfg);
      return { success: true, message: 'No couples to reward. Period advanced.' };
    }

    const activeRewards = await getActiveRewards();
    const periodStart = now.toISOString();
    const expiresAt = new Date(now.getTime() + cfg.reward_duration_days * 86400000).toISOString();

    for (let rank = 1; rank <= Math.min(topCouples.length, 3); rank++) {
      const couple = topCouples[rank - 1];
      const slotRewards = rankRewards.filter(r => r.rank_position === rank);

      const entries: ActiveReward['rewards'] = slotRewards.map(sr => ({
        type: sr.label_ar.includes('إطار') || sr.label_ar.includes('frame') || sr.label_ar.includes('ايطار') ? 'frame'
          : sr.label_ar.includes('وسام') || sr.label_ar.includes('badge') ? 'badge'
          : sr.label_ar.includes('قلادة') || sr.label_ar.includes('necklace') ? 'necklace'
          : 'frame',
        label_ar: sr.label_ar,
        label_en: sr.label_en,
        svga_url: sr.svga_url,
        image_url: sr.image_url,
        slot_index: sr.slot_index,
        expires_at: expiresAt,
      }));

      const rewardRecord: ActiveReward = {
        user_uid: couple.user1_uid,
        couple_id: couple.id,
        rank,
        period: cfg.period_type,
        period_start: periodStart,
        period_end: expiresAt,
        rewards: entries,
        awarded_at: now.toISOString(),
      };
      activeRewards.push(rewardRecord);

      const rewardRecord2: ActiveReward = {
        ...rewardRecord,
        user_uid: couple.user2_uid,
      };
      activeRewards.push(rewardRecord2);

      await assignRewardsToUser(couple.user1_uid, entries);
      await assignRewardsToUser(couple.user2_uid, entries);

      console.log(`[CP Rewards] Rank ${rank}: ${couple.user1_uid}, ${couple.user2_uid} awarded ${entries.length} rewards`);
    }

    await saveActiveRewards(activeRewards);

    const scoreCol = periodKey === 'month' ? 'month_score' : 'week_score';
    await supabase.from('cp_couples').update({ [scoreCol]: 0 })
      .is('ended_at', null);

    const newNext = calcNextDistribution(cfg);
    cfg.last_distribution = now.toISOString();
    cfg.next_distribution = newNext;
    cfg.last_period_start = periodStart;
    await savePeriodConfig(cfg);

    const detail = topCouples.map((c, i) => ({
      rank: i + 1,
      user1: c.user1_uid,
      user2: c.user2_uid,
      score: periodKey === 'month' ? c.month_score : c.week_score,
      rewards: rankRewards.filter(r => r.rank_position === i + 1).length,
    }));

    await logDistribution(detail, now.toISOString());

    return {
      success: true,
      message: `Distributed rewards to ${topCouples.length} couple(s)`,
      details: detail,
    };
  } catch (err: any) {
    console.error('[CP Rewards] distributeRewards error:', err);
    return { success: false, message: err.message };
  }
}

async function assignRewardsToUser(userUid: string, rewards: ActiveReward['rewards']): Promise<void> {
  const { data: user } = await supabase
    .from('users')
    .select('owned_level_frames, owned_level_badges, owned_level_necklaces, active_frame')
    .eq('uid', userUid)
    .single();

  if (!user) return;

  let frames: any[] = user.owned_level_frames || [];
  let badges: any[] = user.owned_level_badges || [];
  let necklaces: any[] = user.owned_level_necklaces || [];

  for (const r of rewards) {
    const entry = {
      id: `cp_rank_${r.slot_index}_${Date.now()}`,
      name_ar: r.label_ar,
      name_en: r.label_en,
      svga_url: r.svga_url,
      image_url: r.image_url,
      source: 'cp_reward',
      expires_at: r.expires_at,
    };

    if (r.type === 'frame') {
      frames.push({ ...entry, type: 'frame' });
    } else if (r.type === 'badge') {
      badges.push({ ...entry, type: 'badge' });
    } else if (r.type === 'necklace') {
      necklaces.push({ ...entry, type: 'necklace' });
    }
  }

  const updates: any = {};
  if (frames.length > 0) updates.owned_level_frames = frames;
  if (badges.length > 0) updates.owned_level_badges = badges;
  if (necklaces.length > 0) updates.owned_level_necklaces = necklaces;

  if (Object.keys(updates).length > 0) {
    await supabase.from('users').update(updates).eq('uid', userUid);
  }
}

async function logDistribution(details: any, timestamp: string): Promise<void> {
  const raw = await getSetting(SETTINGS_KEYS.DISTRIBUTION_HISTORY);
  const history: any[] = parseJson(raw, []);
  history.push({ timestamp, details });
  if (history.length > 100) history.splice(0, history.length - 100);
  await setSetting(SETTINGS_KEYS.DISTRIBUTION_HISTORY, JSON.stringify(history));
}

export async function expireRewards(): Promise<{ removed: number }> {
  try {
    const activeRewards = await getActiveRewards();
    const now = new Date();
    const before = activeRewards.length;

    const expiredUserUids = new Set<string>();

    const validRewards = activeRewards.filter(ar => {
      const expiresAt = new Date(ar.period_end);
      if (expiresAt <= now) {
        expiredUserUids.add(ar.user_uid);
        return false;
      }
      return true;
    });

    await saveActiveRewards(validRewards);

    for (const uid of expiredUserUids) {
      await removeExpiredFromUser(uid);
    }

    const removed = before - validRewards.length;
    if (removed > 0) {
      console.log(`[CP Rewards] Expired and removed ${removed} reward record(s)`);
    }
    return { removed };
  } catch (err: any) {
    console.error('[CP Rewards] expireRewards error:', err);
    return { removed: 0 };
  }
}

async function removeExpiredFromUser(userUid: string): Promise<void> {
  const { data: user } = await supabase
    .from('users')
    .select('owned_level_frames, owned_level_badges, owned_level_necklaces, active_frame')
    .eq('uid', userUid)
    .single();

  if (!user) return;

  const now = new Date();
  let changed = false;
  const updates: any = {};

  for (const col of ['owned_level_frames', 'owned_level_badges', 'owned_level_necklaces'] as const) {
    const items: any[] = (user as any)[col] || [];
    const filtered = items.filter((item: any) => {
      if (!item.expires_at) return true;
      return new Date(item.expires_at) > now;
    });
    if (filtered.length !== items.length) {
      updates[col] = filtered;
      changed = true;
    }
  }

  if (changed) {
    const activeFrame = user.active_frame;
    if (activeFrame) {
      const frameStillValid = (updates.owned_level_frames || user.owned_level_frames)
        .some((f: any) => f.id === activeFrame);
      if (!frameStillValid) {
        updates.active_frame = null;
      }
    }
    await supabase.from('users').update(updates).eq('uid', userUid);
  }
}

export async function triggerCheck(): Promise<{
  distributed: boolean;
  distributionResult?: any;
  expiredCount: number;
}> {
  const expiredResult = await expireRewards();
  const status = await getStatus();

  let distResult = null;
  let distributed = false;

  if (status.canDistribute) {
    distResult = await distributeRewards();
    distributed = distResult.success;
  }

  return {
    distributed,
    distributionResult: distResult,
    expiredCount: expiredResult.removed,
  };
}

export function startCron(): void {
  cron.schedule('*/10 * * * *', async () => {
    console.log('[CP Rewards Cron] Checking for distribution/expiry...');
    try {
      const result = await triggerCheck();
      if (result.distributed) {
        console.log('[CP Rewards Cron] Distribution completed:', JSON.stringify(result.distributionResult?.details));
      }
      if (result.expiredCount > 0) {
        console.log(`[CP Rewards Cron] Expired ${result.expiredCount} reward(s)`);
      }
    } catch (err) {
      console.error('[CP Rewards Cron] Error:', err);
    }
  });

  console.log('[CP Rewards Cron] Started (every 10 minutes)');
}
