const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  return { ok: r.ok, text: await r.text() };
}

async function main() {
  const r = await q(`
CREATE OR REPLACE FUNCTION public.get_host_dashboard_v2(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member record;
BEGIN
  SELECT ham.*, ha.name as agency_name, ha.commission_rate
  INTO v_member
  FROM public.host_agency_members ham
  JOIN public.host_agencies ha ON ha.id = ham.agency_id
  WHERE ham.user_id = p_user_id AND ham.status = 'active';

  IF v_member.id IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'status', 'ok',
    'member_id', v_member.id,
    'agency_id', v_member.agency_id,
    'agency_name', v_member.agency_name,
    'role', v_member.role,
    'commission_rate', v_member.commission_rate,
    'diamonds_balance', COALESCE(v_member.diamonds_balance, 0),
    'diamonds_available', COALESCE(v_member.diamonds_available, 0),
    'diamonds_pending_withdrawal', COALESCE(v_member.diamonds_pending_withdrawal, 0),
    'diamonds_earned_monthly', COALESCE((SELECT SUM(hdl.diamond_host) FROM public.host_diamond_ledger hdl WHERE hdl.host_id = p_user_id AND date_trunc('month', hdl.created_at) = date_trunc('month', now())), 0),
    'diamonds_earned_cumulative', COALESCE((SELECT SUM(hdl.diamond_host) FROM public.host_diamond_ledger hdl WHERE hdl.host_id = p_user_id), 0),
    'is_in_trial', COALESCE(v_member.is_in_trial, false),
    'trial_ends_at', v_member.trial_ends_at,
    'join_date', v_member.joined_at,
    'targets', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', hm.id, 'title_ar', hm.title_ar, 'target_diamonds', hm.target_diamonds, 'reward_type', hm.reward_type, 'reward_value', hm.reward_value, 'diamonds_earned', COALESCE(hmp.diamonds_earned, 0), 'is_completed', COALESCE(hmp.is_completed, false), 'period_start', hmp.period_start)) FROM public.host_milestones hm LEFT JOIN public.host_milestone_progress hmp ON hmp.milestone_id = hm.id AND hmp.user_id = p_user_id AND hmp.period_start = date_trunc('month', now())::date WHERE hm.is_active = true), '[]'::jsonb),
    'recent_ledger', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', hdl.id, 'amount', hdl.diamond_host, 'direction', 1, 'reason', hdl.source_type, 'created_at', hdl.created_at) ORDER BY hdl.created_at DESC) FROM (SELECT id, diamond_host, source_type, created_at FROM public.host_diamond_ledger WHERE host_id = p_user_id ORDER BY created_at DESC LIMIT 20) hdl), '[]'::jsonb),
    'engine', jsonb_build_object('exchange_rate', 0.9, 'min_withdrawal', 100, 'max_withdrawal', 50000)
  );
END;
$$;
`);
  console.log('get_host_dashboard_v2:', r.ok ? 'OK' : r.text.slice(0, 120));
}
main().catch(e => console.error(e));
