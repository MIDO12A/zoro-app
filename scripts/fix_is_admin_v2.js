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
    // Create _is_admin based on admin_users table
    `CREATE OR REPLACE FUNCTION public._is_admin(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT au.role IN ('admin','super_admin','owner') FROM public.admin_users au WHERE au.uid = p_uid::text),
    false
  );
$$;`,

    // Now create admin policies
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
  ];

  for (let i = 0; i < stmts.length; i++) {
    const label = stmts[i].split('\n')[0].trim().slice(0, 100);
    process.stdout.write(`[${i+1}/${stmts.length}] ${label}... `);
    const r = await query(stmts[i]);
    if (r.ok) {
      console.log('✅');
    } else {
      const err = r.text.slice(0, 300);
      console.log(`❌ ${err}`);
    }
    await new Promise(r => setTimeout(r, 200));
  }

  console.log('\n✅ _is_admin v2 + admin policies created!');
}

main().catch(e => console.error(e));
