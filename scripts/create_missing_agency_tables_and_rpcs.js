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
  const text = await r.text();
  return { ok: r.ok, text };
}

async function main() {
  // 1. Create missing milestone tables (from 20260425000000_host_agency_commission_milestones.sql)
  const stmts = [
    // agency_milestones - agency-level milestones definition
    `CREATE TABLE IF NOT EXISTS public.agency_milestones (
      id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      title_ar          text NOT NULL,
      title_en          text,
      target_diamonds   bigint NOT NULL DEFAULT 0,
      reward_type       text NOT NULL DEFAULT 'coins',
      reward_value      bigint NOT NULL DEFAULT 0,
      reward_description text,
      sort_order        int NOT NULL DEFAULT 0,
      is_active         bool NOT NULL DEFAULT true,
      created_at        timestamptz NOT NULL DEFAULT now()
    )`,

    // agency_milestone_progress - per-agency monthly progress
    `CREATE TABLE IF NOT EXISTS public.agency_milestone_progress (
      id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      agency_id       uuid NOT NULL REFERENCES public.host_agencies(id) ON DELETE CASCADE,
      milestone_id    uuid NOT NULL REFERENCES public.agency_milestones(id) ON DELETE CASCADE,
      period_start    date NOT NULL DEFAULT date_trunc('month', now())::date,
      diamonds_earned bigint NOT NULL DEFAULT 0,
      is_completed    bool NOT NULL DEFAULT false,
      completed_at    timestamptz,
      updated_at      timestamptz NOT NULL DEFAULT now(),
      UNIQUE(agency_id, milestone_id, period_start)
    )`,

    // 2. RLS for agency_milestones
    `ALTER TABLE public.agency_milestones ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS agency_milestones_select_all ON public.agency_milestones`,
    `CREATE POLICY agency_milestones_select_all ON public.agency_milestones
      FOR SELECT USING (true)`,

    `DROP POLICY IF EXISTS agency_milestones_insert_admin ON public.agency_milestones`,
    `CREATE POLICY agency_milestones_insert_admin ON public.agency_milestones
      FOR INSERT WITH CHECK (public._is_admin(auth.uid()))`,

    `DROP POLICY IF EXISTS agency_milestones_update_admin ON public.agency_milestones`,
    `CREATE POLICY agency_milestones_update_admin ON public.agency_milestones
      FOR UPDATE USING (public._is_admin(auth.uid()))`,

    `DROP POLICY IF EXISTS agency_milestones_delete_admin ON public.agency_milestones`,
    `CREATE POLICY agency_milestones_delete_admin ON public.agency_milestones
      FOR DELETE USING (public._is_admin(auth.uid()))`,

    // RLS for agency_milestone_progress
    `ALTER TABLE public.agency_milestone_progress ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS amp_select ON public.agency_milestone_progress`,
    `CREATE POLICY amp_select ON public.agency_milestone_progress
      FOR SELECT USING (true)`,

    `DROP POLICY IF EXISTS amp_insert ON public.agency_milestone_progress`,
    `CREATE POLICY amp_insert ON public.agency_milestone_progress
      FOR INSERT WITH CHECK (public._is_admin(auth.uid()))`,

    `DROP POLICY IF EXISTS amp_update ON public.agency_milestone_progress`,
    `CREATE POLICY amp_update ON public.agency_milestone_progress
      FOR UPDATE USING (public._is_admin(auth.uid()))`,

    // Realtime publication
    `ALTER PUBLICATION supabase_realtime ADD TABLE public.agency_milestones`,
    `ALTER PUBLICATION supabase_realtime ADD TABLE public.agency_milestone_progress`,
  ];

  for (const stmt of stmts) {
    process.stdout.write(stmt.slice(0, 70).padEnd(72) + ' ');
    const r = await q(stmt);
    console.log(r.ok ? 'OK' : 'ERR: ' + r.text.slice(0, 80));
    await new Promise(r => setTimeout(r, 200));
  }

  // 3. Create minimal get_host_dashboard_v3
  {
    const r = await q(`
      CREATE OR REPLACE FUNCTION public.get_host_dashboard_v3(p_user_id uuid)
      RETURNS jsonb
      LANGUAGE plpgsql
      STABLE SECURITY DEFINER
      SET search_path = public
      AS $$
      DECLARE
        v_agency_id uuid;
        v_member    record;
      BEGIN
        SELECT agency_id, role, diamonds_available, diamonds_balance
        INTO v_agency_id, v_member.role, v_member.diamonds_available, v_member.diamonds_balance
        FROM public.host_agency_members
        WHERE user_id = p_user_id AND status = 'active'
        LIMIT 1;

        IF v_agency_id IS NULL THEN
          RETURN jsonb_build_object('status', 'not_found');
        END IF;

        RETURN jsonb_build_object(
          'status', 'ok',
          'engine_enabled', true,
          'agency_id', v_agency_id,
          'role', v_member.role,
          'diamonds_available', COALESCE(v_member.diamonds_available, 0),
          'diamonds_balance', COALESCE(v_member.diamonds_balance, 0),
          'today_earned', COALESCE((
            SELECT SUM(hdl.diamond_host) FROM public.host_diamond_ledger hdl
            WHERE hdl.host_id = p_user_id AND hdl.created_at >= date_trunc('day', now())
          ), 0),
          'week_earned', COALESCE((
            SELECT SUM(hdl.diamond_host) FROM public.host_diamond_ledger hdl
            WHERE hdl.host_id = p_user_id AND hdl.created_at >= date_trunc('week', now())
          ), 0),
          'month_earned', COALESCE((
            SELECT SUM(hdl.diamond_host) FROM public.host_diamond_ledger hdl
            WHERE hdl.host_id = p_user_id AND hdl.created_at >= date_trunc('month', now())
          ), 0)
        );
      END;
      $$;
    `);
    console.log('get_host_dashboard_v3: ' + (r.ok ? 'OK' : r.text.slice(0, 100)));
  }

  // 4. Create minimal get_host_dashboard_v2
  {
    const r = await q(`
      CREATE OR REPLACE FUNCTION public.get_host_dashboard_v2(p_user_id uuid)
      RETURNS jsonb
      LANGUAGE plpgsql
      STABLE SECURITY DEFINER
      SET search_path = public
      AS $$
      DECLARE
        v_member    record;
        v_agency    record;
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
          'diamonds_earned_monthly', COALESCE((
            SELECT SUM(hdl.diamond_host) FROM public.host_diamond_ledger hdl
            WHERE hdl.host_id = p_user_id AND date_trunc('month', hdl.created_at) = date_trunc('month', now())
          ), 0),
          'diamonds_earned_cumulative', COALESCE((
            SELECT SUM(hdl.diamond_host) FROM public.host_diamond_ledger hdl
            WHERE hdl.host_id = p_user_id
          ), 0),
          'is_in_trial', COALESCE(v_member.is_in_trial, false),
          'trial_ends_at', v_member.trial_ends_at,
          'join_date', v_member.joined_at,
          'targets', COALESCE((
            SELECT jsonb_agg(
              jsonb_build_object(
                'id', hm.id,
                'title_ar', hm.title_ar,
                'target_diamonds', hm.target_diamonds,
                'reward_type', hm.reward_type,
                'reward_value', hm.reward_value,
                'diamonds_earned', COALESCE(hmp.diamonds_earned, 0),
                'is_completed', COALESCE(hmp.is_completed, false),
                'period_start', hmp.period_start
              )
            )
            FROM public.host_milestones hm
            LEFT JOIN public.host_milestone_progress hmp
              ON hmp.milestone_id = hm.id AND hmp.user_id = p_user_id
              AND hmp.period_start = date_trunc('month', now())::date
            WHERE hm.is_active = true
          ), '[]'::jsonb),
          'recent_ledger', COALESCE((
            SELECT jsonb_agg(
              jsonb_build_object(
                'id', hdl.id,
                'amount', hdl.diamond_host,
                'direction', 1,
                'reason', hdl.source_type,
                'created_at', hdl.created_at
              )
              ORDER BY hdl.created_at DESC
              LIMIT 20
            )
            FROM public.host_diamond_ledger hdl
            WHERE hdl.host_id = p_user_id
          ), '[]'::jsonb),
          'engine', jsonb_build_object(
            'exchange_rate', 0.9,
            'min_withdrawal', 100,
            'max_withdrawal', 50000
          )
        );
      END;
      $$;
    `);
    console.log('get_host_dashboard_v2: ' + (r.ok ? 'OK' : r.text.slice(0, 100)));
  }

  // 5. Create minimal agency_get_engine_settings
  {
    const r = await q(`
      CREATE OR REPLACE FUNCTION public.agency_get_engine_settings()
      RETURNS jsonb
      LANGUAGE plpgsql
      STABLE SECURITY DEFINER
      SET search_path = public
      AS $$
      BEGIN
        RETURN (
          SELECT jsonb_build_object(
            'exchange_rate', COALESCE(cs.exchange_rate, 0.9),
            'min_withdrawal', COALESCE(cs.min_withdrawal, 100),
            'max_withdrawal', COALESCE(cs.max_withdrawal, 50000)
          )
          FROM public.commission_settings cs
          LIMIT 1
        );
      END;
      $$;
    `);
    console.log('agency_get_engine_settings: ' + (r.ok ? 'OK' : r.text.slice(0, 100)));
  }

  // 6. Create minimal agency_get_leaderboard
  {
    const r = await q(`
      CREATE OR REPLACE FUNCTION public.agency_get_leaderboard(
        p_country text DEFAULT NULL,
        p_limit int DEFAULT 50,
        p_offset int DEFAULT 0
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      STABLE SECURITY DEFINER
      SET search_path = public
      AS $$
      DECLARE
        v_result jsonb;
      BEGIN
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'rank', row_number() OVER (ORDER BY ha.total_diamonds_monthly DESC),
            'agency_id', ha.id,
            'name', ha.name,
            'photo_url', ha.photo_url,
            'tier', ha.tier,
            'monthly_diamonds', ha.total_diamonds_monthly,
            'member_count', ha.member_count,
            'country', ha.country,
            'is_hall_of_fame', ha.is_hall_of_fame
          )
        ), '[]'::jsonb) INTO v_result
        FROM public.host_agencies ha
        WHERE ha.is_active = true
          AND (p_country IS NULL OR ha.country = p_country)
        ORDER BY ha.total_diamonds_monthly DESC
        LIMIT p_limit OFFSET p_offset;

        RETURN v_result;
      END;
      $$;
    `);
    console.log('agency_get_leaderboard: ' + (r.ok ? 'OK' : r.text.slice(0, 100)));
  }

  // 7. Create minimal agency_get_profile
  {
    const r = await q(`
      CREATE OR REPLACE FUNCTION public.agency_get_profile(p_agency_id uuid)
      RETURNS jsonb
      LANGUAGE plpgsql
      STABLE SECURITY DEFINER
      SET search_path = public
      AS $$
      DECLARE
        v_result jsonb;
      BEGIN
        SELECT jsonb_build_object(
          'id', ha.id,
          'name', ha.name,
          'description', ha.description,
          'photo_url', ha.photo_url,
          'cover_url', ha.cover_url,
          'tier', ha.tier,
          'country', ha.country,
          'member_count', ha.member_count,
          'total_diamonds_monthly', ha.total_diamonds_monthly,
          'total_diamonds_earned', ha.total_diamonds_earned,
          'is_hall_of_fame', ha.is_hall_of_fame,
          'is_active', ha.is_active
        ) INTO v_result
        FROM public.host_agencies ha
        WHERE ha.id = p_agency_id;

        RETURN v_result;
      END;
      $$;
    `);
    console.log('agency_get_profile: ' + (r.ok ? 'OK' : r.text.slice(0, 100)));
  }
}
main().catch(e => console.error(e));
