const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

const policies = [
  // host_agencies policies
  `DROP POLICY IF EXISTS ha_read ON public.host_agencies`,
  `CREATE POLICY ha_read ON public.host_agencies FOR SELECT TO authenticated USING (true)`,
  `DROP POLICY IF EXISTS ha_admin ON public.host_agencies`,
  `CREATE POLICY ha_admin ON public.host_agencies FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  `DROP POLICY IF EXISTS ha_owner ON public.host_agencies`,
  `CREATE POLICY ha_owner ON public.host_agencies FOR ALL TO authenticated USING (owner_id = auth.uid() OR owner_user_id = auth.uid()) WITH CHECK (owner_id = auth.uid() OR owner_user_id = auth.uid())`,

  // host_agency_members policies
  `DROP POLICY IF EXISTS ham_read ON public.host_agency_members`,
  `CREATE POLICY ham_read ON public.host_agency_members FOR SELECT TO authenticated USING (true)`,
  `DROP POLICY IF EXISTS ham_admin ON public.host_agency_members`,
  `CREATE POLICY ham_admin ON public.host_agency_members FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

  // host_agency_join_requests policies
  `DROP POLICY IF EXISTS hajr_read ON public.host_agency_join_requests`,
  `CREATE POLICY hajr_read ON public.host_agency_join_requests FOR SELECT TO authenticated USING (true)`,
  `DROP POLICY IF EXISTS hajr_admin ON public.host_agency_join_requests`,
  `CREATE POLICY hajr_admin ON public.host_agency_join_requests FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

  // host_milestones policies
  `DROP POLICY IF EXISTS hm_read ON public.host_milestones`,
  `CREATE POLICY hm_read ON public.host_milestones FOR SELECT TO authenticated USING (true)`,
  `DROP POLICY IF EXISTS hm_admin ON public.host_milestones`,
  `CREATE POLICY hm_admin ON public.host_milestones FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

  // agency_diamond_ledger policies
  `DROP POLICY IF EXISTS adl_read ON public.agency_diamond_ledger`,
  `CREATE POLICY adl_read ON public.agency_diamond_ledger FOR SELECT TO authenticated USING (true)`,
  `DROP POLICY IF EXISTS adl_admin ON public.agency_diamond_ledger`,
  `CREATE POLICY adl_admin ON public.agency_diamond_ledger FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

  // agency_withdrawal_requests policies
  `DROP POLICY IF EXISTS awr_read ON public.agency_withdrawal_requests`,
  `CREATE POLICY awr_read ON public.agency_withdrawal_requests FOR SELECT TO authenticated USING (true)`,
  `DROP POLICY IF EXISTS awr_admin ON public.agency_withdrawal_requests`,
  `CREATE POLICY awr_admin ON public.agency_withdrawal_requests FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

  // commission_settings policies
  `DROP POLICY IF EXISTS cs_read ON public.commission_settings`,
  `CREATE POLICY cs_read ON public.commission_settings FOR SELECT TO authenticated USING (true)`,
  `DROP POLICY IF EXISTS cs_admin ON public.commission_settings`,
  `CREATE POLICY cs_admin ON public.commission_settings FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

  // supabase_realtime
  `ALTER PUBLICATION supabase_realtime ADD TABLE public.host_agency_members`,
  `ALTER PUBLICATION supabase_realtime ADD TABLE public.host_agencies`,

  // Ref: trigger to sync member_count
  `CREATE OR REPLACE FUNCTION public._sync_agency_member_count() RETURNS TRIGGER LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'INSERT' THEN
        UPDATE public.host_agencies SET member_count = member_count + 1 WHERE id = NEW.agency_id;
      ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.host_agencies SET member_count = GREATEST(0, member_count - 1) WHERE id = OLD.agency_id;
      END IF;
      RETURN NULL;
    END;
  $$`,
  `DROP TRIGGER IF EXISTS trg_sync_agency_members ON public.host_agency_members`,
  `CREATE TRIGGER trg_sync_agency_members AFTER INSERT OR DELETE ON public.host_agency_members FOR EACH ROW EXECUTE FUNCTION public._sync_agency_member_count()`
];

async function execute() {
  for (let i = 0; i < policies.length; i++) {
    try {
      const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ query: policies[i] })
      });
      const d = await r.text();
      if (r.ok) {
        console.log(`OK [${i+1}/${policies.length}]: ${policies[i].substring(0, 80)}...`);
      } else {
        console.log(`FAIL [${i+1}/${policies.length}]: ${d.substring(0, 200)}`);
      }
    } catch (e) {
      console.log(`ERR [${i+1}/${policies.length}]: ${e.message}`);
    }
  }
  console.log('Done with RLS policies + triggers');
}

execute();
