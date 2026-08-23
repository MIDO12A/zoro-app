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
    // 1. Create _is_admin function
    `CREATE OR REPLACE FUNCTION public._is_admin(p_uid uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT pr.app_role = 'admin' FROM public.profiles pr WHERE pr.id = p_uid), false);
$$;`,

    // 2. Now create admin policies (drop first for idempotency)
    `DROP POLICY IF EXISTS "commission_settings_admin" ON public.commission_settings;`,
    `CREATE POLICY "commission_settings_admin" ON public.commission_settings FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    `DROP POLICY IF EXISTS "ha_admin" ON public.host_agencies;`,
    `CREATE POLICY "ha_admin" ON public.host_agencies FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    `DROP POLICY IF EXISTS "ham_admin" ON public.host_agency_members;`,
    `CREATE POLICY "ham_admin" ON public.host_agency_members FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    `DROP POLICY IF EXISTS "adl_admin" ON public.agency_diamond_ledger;`,
    `CREATE POLICY "adl_admin" ON public.agency_diamond_ledger FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    `DROP POLICY IF EXISTS "awr_admin" ON public.agency_withdrawal_requests;`,
    `CREATE POLICY "awr_admin" ON public.agency_withdrawal_requests FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    // 3. Create app_assets_vw helper used by admin
    `CREATE OR REPLACE VIEW public.app_assets_vw AS SELECT * FROM public.app_assets;`,
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

  console.log('\n✅ _is_admin + admin policies + views created!');
}

main().catch(e => console.error(e));
