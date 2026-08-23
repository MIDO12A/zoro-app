const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

const queries = [
  `CREATE TABLE IF NOT EXISTS public.host_agencies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    owner_id uuid REFERENCES auth.users(id),
    owner_user_id uuid REFERENCES auth.users(id),
    commission_rate numeric NOT NULL DEFAULT 0.05 CHECK (commission_rate BETWEEN 0 AND 0.5),
    specialty text NOT NULL DEFAULT 'mixed' CHECK (specialty IN ('singing','gaming','talk','mixed')),
    is_active boolean NOT NULL DEFAULT true,
    member_count int NOT NULL DEFAULT 0,
    total_diamonds_earned bigint NOT NULL DEFAULT 0,
    monthly_diamonds bigint NOT NULL DEFAULT 0,
    total_diamonds_monthly bigint NOT NULL DEFAULT 0,
    tier text NOT NULL DEFAULT 'bronze',
    is_hall_of_fame boolean NOT NULL DEFAULT false,
    description text,
    photo_url text,
    phone text,
    country text,
    created_at timestamptz NOT NULL DEFAULT now()
  )`,
  
  `ALTER TABLE public.host_agencies ENABLE ROW LEVEL SECURITY`,
  
  `CREATE POLICY IF NOT EXISTS ha_read ON public.host_agencies FOR SELECT TO authenticated USING (true)`,
  `CREATE POLICY IF NOT EXISTS ha_admin ON public.host_agencies FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  
  `CREATE TABLE IF NOT EXISTS public.host_agency_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES public.host_agencies(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'host' CHECK (role IN ('owner','supervisor','host')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','banned')),
    diamonds_earned_monthly bigint NOT NULL DEFAULT 0,
    diamonds_earned_cumulative bigint NOT NULL DEFAULT 0,
    diamonds_balance bigint NOT NULL DEFAULT 0,
    diamonds_pending_withdrawal bigint NOT NULL DEFAULT 0,
    diamonds_available bigint NOT NULL DEFAULT 0,
    trial_ends_at timestamptz,
    joined_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(agency_id, user_id)
  )`,
  
  `ALTER TABLE public.host_agency_members ENABLE ROW LEVEL SECURITY`,
  
  `CREATE POLICY IF NOT EXISTS ham_read ON public.host_agency_members FOR SELECT TO authenticated USING (true)`,
  `CREATE POLICY IF NOT EXISTS ham_admin ON public.host_agency_members FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  
  `CREATE TABLE IF NOT EXISTS public.host_agency_join_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES public.host_agencies(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
    message text,
    reviewed_by uuid REFERENCES auth.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    reviewed_at timestamptz,
    UNIQUE(agency_id, user_id)
  )`,
  
  `ALTER TABLE public.host_agency_join_requests ENABLE ROW LEVEL SECURITY`,
  
  `CREATE POLICY IF NOT EXISTS hajr_read ON public.host_agency_join_requests FOR SELECT TO authenticated USING (true)`,
  `CREATE POLICY IF NOT EXISTS hajr_admin ON public.host_agency_join_requests FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  
  `CREATE TABLE IF NOT EXISTS public.host_milestones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid REFERENCES public.host_agencies(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    target_diamonds bigint NOT NULL DEFAULT 0,
    reward_type text DEFAULT 'none',
    reward_value text,
    is_active boolean DEFAULT true,
    sort_order int DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
  )`,
  
  `ALTER TABLE public.host_milestones ENABLE ROW LEVEL SECURITY`,
  
  `CREATE POLICY IF NOT EXISTS hm_read ON public.host_milestones FOR SELECT TO authenticated USING (true)`,
  `CREATE POLICY IF NOT EXISTS hm_admin ON public.host_milestones FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  
  `CREATE TABLE IF NOT EXISTS public.agency_diamond_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid REFERENCES public.host_agencies(id),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    txn_type text NOT NULL,
    amount bigint NOT NULL CHECK (amount > 0),
    direction int NOT NULL DEFAULT 1 CHECK (direction IN (-1, 1)),
    balance_after bigint NOT NULL DEFAULT 0,
    note text,
    idempotency_key text UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
  )`,
  
  `ALTER TABLE public.agency_diamond_ledger ENABLE ROW LEVEL SECURITY`,
  
  `CREATE POLICY IF NOT EXISTS adl_self ON public.agency_diamond_ledger FOR SELECT TO authenticated USING (user_id = auth.uid())`,
  `CREATE POLICY IF NOT EXISTS adl_admin ON public.agency_diamond_ledger FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  
  `CREATE TABLE IF NOT EXISTS public.agency_withdrawal_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    agency_id uuid REFERENCES public.host_agencies(id),
    diamonds_amount bigint NOT NULL CHECK (diamonds_amount > 0),
    payment_method text NOT NULL DEFAULT 'bank',
    payment_details jsonb DEFAULT '{}',
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),
    admin_notes text,
    reviewed_by uuid REFERENCES auth.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    reviewed_at timestamptz
  )`,
  
  `ALTER TABLE public.agency_withdrawal_requests ENABLE ROW LEVEL SECURITY`,
  
  `CREATE POLICY IF NOT EXISTS awr_self ON public.agency_withdrawal_requests FOR SELECT TO authenticated USING (user_id = auth.uid())`,
  `CREATE POLICY IF NOT EXISTS awr_admin ON public.agency_withdrawal_requests FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  
  `CREATE TABLE IF NOT EXISTS public.commission_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    key text NOT NULL UNIQUE,
    value numeric NOT NULL CHECK (value >= 0),
    description text,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by uuid REFERENCES auth.users(id)
  )`,
  
  `ALTER TABLE public.commission_settings ENABLE ROW LEVEL SECURITY`,
  
  `CREATE POLICY IF NOT EXISTS cs_read ON public.commission_settings FOR SELECT TO authenticated USING (true)`,
  `CREATE POLICY IF NOT EXISTS cs_admin ON public.commission_settings FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,
  
  `INSERT INTO public.commission_settings (key, value, description) VALUES
    ('host_rate', 0.65, 'Host share from gifts'),
    ('agency_rate', 0.05, 'Agency commission rate'),
    ('platform_rate', 0.30, 'Platform fee'),
    ('diamonds_per_usd', 10000, 'Diamonds per 1 USD')
   ON CONFLICT (key) DO NOTHING`,
   
  `ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.host_agency_members`,
  `ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.host_agencies`
];

async function execute() {
  let successCount = 0;
  let failCount = 0;
  for (let i = 0; i < queries.length; i++) {
    try {
      const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ query: queries[i] })
      });
      const d = await r.text();
      if (r.ok) {
        successCount++;
        console.log(`OK [${i+1}/${queries.length}]: ${queries[i].substring(0, 80)}...`);
      } else {
        failCount++;
        console.log(`FAIL [${i+1}/${queries.length}]: ${d.substring(0, 200)}`);
      }
    } catch (e) {
      failCount++;
      console.log(`ERR [${i+1}/${queries.length}]: ${e.message}`);
    }
  }
  console.log(`\nDone. ${successCount} success, ${failCount} failed.`);
}

execute();
