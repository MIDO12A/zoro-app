const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

async function query(sql) {
  const resp = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await resp.text();
  return { ok: resp.ok, text };
}

async function main() {
  const stmts = [
    // Drop existing policies first (idempotent)
    `DROP POLICY IF EXISTS "commission_settings_read" ON public.commission_settings;`,
    `DROP POLICY IF EXISTS "commission_settings_admin" ON public.commission_settings;`,
    `DROP POLICY IF EXISTS "ha_read" ON public.host_agencies;`,
    `DROP POLICY IF EXISTS "ha_admin" ON public.host_agencies;`,
    `DROP POLICY IF EXISTS "ha_owner_read" ON public.host_agencies;`,
    `DROP POLICY IF EXISTS "ha_owner_insert" ON public.host_agencies;`,
    `DROP POLICY IF EXISTS "ham_read" ON public.host_agency_members;`,
    `DROP POLICY IF EXISTS "ham_admin" ON public.host_agency_members;`,
    `DROP POLICY IF EXISTS "ham_owner_insert" ON public.host_agency_members;`,
    `DROP POLICY IF EXISTS "ham_owner_update" ON public.host_agency_members;`,

    // commission_settings
    `CREATE POLICY "commission_settings_read" ON public.commission_settings FOR SELECT TO authenticated USING (true);`,
    `CREATE POLICY "commission_settings_admin" ON public.commission_settings FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    // host_agencies
    `CREATE POLICY "ha_read" ON public.host_agencies FOR SELECT TO authenticated USING (true);`,
    `CREATE POLICY "ha_admin" ON public.host_agencies FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,
    `CREATE POLICY "ha_owner_read" ON public.host_agencies FOR SELECT TO authenticated USING (owner_id = auth.uid() OR owner_user_id = auth.uid());`,
    `CREATE POLICY "ha_owner_insert" ON public.host_agencies FOR INSERT TO authenticated WITH CHECK (owner_id = auth.uid() OR owner_user_id = auth.uid());`,

    // host_agency_members
    `CREATE POLICY "ham_read" ON public.host_agency_members FOR SELECT TO authenticated USING (true);`,
    `CREATE POLICY "ham_admin" ON public.host_agency_members FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,
    `CREATE POLICY "ham_owner_insert" ON public.host_agency_members FOR INSERT TO authenticated WITH CHECK (
      EXISTS (SELECT 1 FROM public.host_agencies ha WHERE ha.id = agency_id AND (ha.owner_id = auth.uid() OR ha.owner_user_id = auth.uid()))
      OR user_id = auth.uid()
    );`,
    `CREATE POLICY "ham_owner_update" ON public.host_agency_members FOR UPDATE TO authenticated
      USING (EXISTS (SELECT 1 FROM public.host_agencies ha WHERE ha.id = agency_id AND (ha.owner_id = auth.uid() OR ha.owner_user_id = auth.uid())))
      WITH CHECK (EXISTS (SELECT 1 FROM public.host_agencies ha WHERE ha.id = agency_id AND (ha.owner_id = auth.uid() OR ha.owner_user_id = auth.uid())));`,

    // agency_diamond_ledger
    `CREATE POLICY "adl_self" ON public.agency_diamond_ledger FOR SELECT TO authenticated USING (user_id = auth.uid());`,
    `CREATE POLICY "adl_admin" ON public.agency_diamond_ledger FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    // agency_withdrawal_requests
    `CREATE POLICY "awr_self" ON public.agency_withdrawal_requests FOR SELECT TO authenticated USING (user_id = auth.uid());`,
    `CREATE POLICY "awr_admin" ON public.agency_withdrawal_requests FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    // agency_announcements
    `CREATE POLICY "aa_read" ON public.agency_announcements FOR SELECT TO authenticated USING (true);`,

    // agency_free_agents
    `CREATE POLICY "afa_self" ON public.agency_free_agents FOR SELECT TO authenticated USING (user_id = auth.uid());`,

    // agency_blacklist
    `CREATE POLICY "ab_self" ON public.agency_blacklist FOR SELECT TO authenticated USING (user_id = auth.uid());`,

    // Realtime - without IF NOT EXISTS
    `ALTER PUBLICATION supabase_realtime ADD TABLE public.host_agency_members;`,
    `ALTER PUBLICATION supabase_realtime ADD TABLE public.agency_diamond_ledger;`,
    `ALTER PUBLICATION supabase_realtime ADD TABLE public.host_agencies;`,
  ];

  for (let i = 0; i < stmts.length; i++) {
    const label = stmts[i].split('\n')[0].trim().slice(0, 100);
    process.stdout.write(`[${i+1}/${stmts.length}] ${label}... `);
    const r = await query(stmts[i]);
    if (r.ok) {
      console.log('✅');
    } else {
      const err = r.text.slice(0, 200);
      console.log(`❌ ${err}`);
    }
    await new Promise(r => setTimeout(r, 200));
  }

  console.log('\n✅ RLS + Realtime setup complete!');
}

main().catch(e => console.error(e));
