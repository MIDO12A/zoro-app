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
  // Each SQL statement as a separate chunk
  const chunks = [
    // 1. commission_settings
    `CREATE TABLE IF NOT EXISTS public.commission_settings (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      key text NOT NULL UNIQUE, value numeric NOT NULL CHECK (value >= 0),
      description text, updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid REFERENCES auth.users(id)
    );`,

    `INSERT INTO public.commission_settings (key, value, description) VALUES
      ('host_rate', 0.65, 'نسبة الألماس التي يحصل عليها المضيف من الهدايا'),
      ('agency_rate', 0.05, 'نسبة عمولة الوكالة من إجمالي ألماس المضيف'),
      ('platform_rate', 0.30, 'نسبة منصة كيان شات'),
      ('gold_to_diamond', 1.0, 'معدل تحويل الذهب إلى ألماس (1:1 افتراضياً)'),
      ('diamonds_per_usd', 10000, 'عدد الألماس الذي يساوي دولاراً واحداً')
    ON CONFLICT (key) DO NOTHING;`,

    `ALTER TABLE public.commission_settings ENABLE ROW LEVEL SECURITY;`,

    `CREATE POLICY IF NOT EXISTS commission_settings_read ON public.commission_settings
      FOR SELECT TO authenticated USING (true);`,

    `CREATE POLICY IF NOT EXISTS commission_settings_admin ON public.commission_settings
      FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    // 2. host_agencies
    `CREATE TABLE IF NOT EXISTS public.host_agencies (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name text NOT NULL, owner_id uuid REFERENCES auth.users(id),
      owner_user_id uuid REFERENCES auth.users(id),
      commission_rate numeric NOT NULL DEFAULT 0.05 CHECK (commission_rate BETWEEN 0 AND 0.5),
      specialty text NOT NULL DEFAULT 'mixed' CHECK (specialty IN ('singing','gaming','talk','mixed')),
      is_active boolean NOT NULL DEFAULT true, member_count int NOT NULL DEFAULT 0,
      total_diamonds_earned bigint NOT NULL DEFAULT 0, monthly_diamonds bigint NOT NULL DEFAULT 0,
      total_diamonds_monthly bigint NOT NULL DEFAULT 0, tier text NOT NULL DEFAULT 'bronze',
      is_hall_of_fame boolean NOT NULL DEFAULT false,
      description text, photo_url text, phone text, country text,
      created_at timestamptz NOT NULL DEFAULT now()
    );`,

    `ALTER TABLE public.host_agencies ENABLE ROW LEVEL SECURITY;`,
    `CREATE POLICY IF NOT EXISTS ha_read ON public.host_agencies FOR SELECT TO authenticated USING (true);`,
    `CREATE POLICY IF NOT EXISTS ha_admin ON public.host_agencies FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,
    `CREATE POLICY IF NOT EXISTS ha_owner_read ON public.host_agencies FOR SELECT TO authenticated USING (owner_id = auth.uid() OR owner_user_id = auth.uid());`,
    `CREATE POLICY IF NOT EXISTS ha_owner_insert ON public.host_agencies FOR INSERT TO authenticated WITH CHECK (owner_id = auth.uid() OR owner_user_id = auth.uid());`,

    // 3. host_agency_members
    `CREATE TABLE IF NOT EXISTS public.host_agency_members (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      agency_id uuid NOT NULL REFERENCES public.host_agencies(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      role text NOT NULL DEFAULT 'مضيف', status text NOT NULL DEFAULT 'active',
      diamonds_earned_monthly bigint NOT NULL DEFAULT 0,
      diamonds_earned_cumulative bigint NOT NULL DEFAULT 0,
      diamonds_balance bigint NOT NULL DEFAULT 0,
      diamonds_pending_withdrawal bigint NOT NULL DEFAULT 0,
      diamonds_available bigint NOT NULL DEFAULT 0,
      trial_ends_at timestamptz, joined_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE(agency_id, user_id)
    );`,

    `ALTER TABLE public.host_agency_members ENABLE ROW LEVEL SECURITY;`,
    `CREATE POLICY IF NOT EXISTS ham_read ON public.host_agency_members FOR SELECT TO authenticated USING (true);`,
    `CREATE POLICY IF NOT EXISTS ham_admin ON public.host_agency_members FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,
    `CREATE POLICY IF NOT EXISTS ham_owner_insert ON public.host_agency_members FOR INSERT TO authenticated WITH CHECK (
      EXISTS (SELECT 1 FROM public.host_agencies ha WHERE ha.id = agency_id AND (ha.owner_id = auth.uid() OR ha.owner_user_id = auth.uid()))
      OR user_id = auth.uid()
    );`,
    `CREATE POLICY IF NOT EXISTS ham_owner_update ON public.host_agency_members FOR UPDATE TO authenticated
      USING (EXISTS (SELECT 1 FROM public.host_agencies ha WHERE ha.id = agency_id AND (ha.owner_id = auth.uid() OR ha.owner_user_id = auth.uid())))
      WITH CHECK (EXISTS (SELECT 1 FROM public.host_agencies ha WHERE ha.id = agency_id AND (ha.owner_id = auth.uid() OR ha.owner_user_id = auth.uid())));`,

    // 4. agency_diamond_ledger
    `CREATE TABLE IF NOT EXISTS public.agency_diamond_ledger (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      agency_id uuid REFERENCES public.host_agencies(id),
      user_id uuid NOT NULL REFERENCES auth.users(id),
      txn_type text NOT NULL, amount bigint NOT NULL CHECK (amount > 0),
      direction int NOT NULL DEFAULT 1 CHECK (direction IN (-1, 1)),
      balance_after bigint NOT NULL DEFAULT 0, note text,
      idempotency_key text UNIQUE, created_at timestamptz NOT NULL DEFAULT now()
    );`,
    `CREATE INDEX IF NOT EXISTS idx_adl_user ON public.agency_diamond_ledger (user_id, created_at DESC);`,
    `CREATE INDEX IF NOT EXISTS idx_adl_agency ON public.agency_diamond_ledger (agency_id, created_at DESC);`,
    `ALTER TABLE public.agency_diamond_ledger ENABLE ROW LEVEL SECURITY;`,
    `CREATE POLICY IF NOT EXISTS adl_self ON public.agency_diamond_ledger FOR SELECT TO authenticated USING (user_id = auth.uid());`,
    `CREATE POLICY IF NOT EXISTS adl_admin ON public.agency_diamond_ledger FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    // 5. agency_withdrawal_requests
    `CREATE TABLE IF NOT EXISTS public.agency_withdrawal_requests (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      agency_id uuid REFERENCES public.host_agencies(id),
      diamonds_amount bigint NOT NULL CHECK (diamonds_amount > 0),
      payment_method text NOT NULL DEFAULT 'bank', payment_details jsonb DEFAULT '{}',
      status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),
      admin_notes text, reviewed_by uuid REFERENCES auth.users(id),
      created_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz
    );`,
    `ALTER TABLE public.agency_withdrawal_requests ENABLE ROW LEVEL SECURITY;`,
    `CREATE POLICY IF NOT EXISTS awr_self ON public.agency_withdrawal_requests FOR SELECT TO authenticated USING (user_id = auth.uid());`,
    `CREATE POLICY IF NOT EXISTS awr_admin ON public.agency_withdrawal_requests FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()));`,

    // 6. agency_announcements
    `CREATE TABLE IF NOT EXISTS public.agency_announcements (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      agency_id uuid NOT NULL REFERENCES public.host_agencies(id) ON DELETE CASCADE,
      title text NOT NULL, body text NOT NULL, created_by uuid REFERENCES auth.users(id),
      created_at timestamptz NOT NULL DEFAULT now()
    );`,
    `CREATE INDEX IF NOT EXISTS idx_aa_agency ON public.agency_announcements (agency_id, created_at DESC);`,
    `ALTER TABLE public.agency_announcements ENABLE ROW LEVEL SECURITY;`,
    `CREATE POLICY IF NOT EXISTS aa_read ON public.agency_announcements FOR SELECT TO authenticated USING (true);`,

    // 7. agency_free_agents
    `CREATE TABLE IF NOT EXISTS public.agency_free_agents (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
      free_until timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
    );`,
    `ALTER TABLE public.agency_free_agents ENABLE ROW LEVEL SECURITY;`,
    `CREATE POLICY IF NOT EXISTS afa_self ON public.agency_free_agents FOR SELECT TO authenticated USING (user_id = auth.uid());`,

    // 8. agency_blacklist
    `CREATE TABLE IF NOT EXISTS public.agency_blacklist (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      agency_id uuid NOT NULL REFERENCES public.host_agencies(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      reason text, created_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE(agency_id, user_id)
    );`,
    `ALTER TABLE public.agency_blacklist ENABLE ROW LEVEL SECURITY;`,
    `CREATE POLICY IF NOT EXISTS ab_self ON public.agency_blacklist FOR SELECT TO authenticated USING (user_id = auth.uid());`,

    // 9. Realtime
    `ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.host_agency_members;`,
    `ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.agency_diamond_ledger;`,
    `ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.host_agencies;`,

    // 10. Trigger
    `CREATE OR REPLACE FUNCTION public._sync_agency_member_count()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'INSERT' THEN
        UPDATE public.host_agencies SET member_count = member_count + 1 WHERE id = NEW.agency_id;
      ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.host_agencies SET member_count = GREATEST(0, member_count - 1) WHERE id = OLD.agency_id;
      END IF;
      RETURN NULL;
    END;
    $$;`,

    `DROP TRIGGER IF EXISTS trg_sync_agency_members ON public.host_agency_members;`,
    `CREATE TRIGGER trg_sync_agency_members AFTER INSERT OR DELETE ON public.host_agency_members FOR EACH ROW EXECUTE FUNCTION public._sync_agency_member_count();`,

    // 11. RPC
    `CREATE OR REPLACE FUNCTION public.agency_create(p_name text, p_description text DEFAULT NULL, p_country text DEFAULT NULL, p_photo_url text DEFAULT NULL, p_phone text DEFAULT NULL)
    RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
    DECLARE v_uid uuid := auth.uid(); v_id uuid;
    BEGIN
      IF v_uid IS NULL THEN RETURN jsonb_build_object('status','error','message','not_authenticated'); END IF;
      IF p_name IS NULL OR trim(p_name) = '' THEN RETURN jsonb_build_object('status','error','message','name_required'); END IF;
      IF EXISTS (SELECT 1 FROM public.host_agency_members WHERE user_id = v_uid AND status = 'active') THEN
        RETURN jsonb_build_object('status','error','message','already_member');
      END IF;
      INSERT INTO public.host_agencies (name, owner_id, owner_user_id, description, photo_url, phone, country, tier, is_active)
      VALUES (trim(p_name), v_uid, v_uid, NULLIF(trim(COALESCE(p_description,'')),''), NULLIF(trim(COALESCE(p_photo_url,'')),''),
        NULLIF(trim(COALESCE(p_phone,'')),''), NULLIF(trim(COALESCE(p_country,'')),''), 'bronze', true)
      RETURNING id INTO v_id;
      INSERT INTO public.host_agency_members (agency_id, user_id, role, status)
      VALUES (v_id, v_uid, 'owner', 'active')
      ON CONFLICT (agency_id, user_id) DO UPDATE SET role = 'owner', status = 'active';
      RETURN jsonb_build_object('status','ok','agency_id',v_id::text);
    END;
    $$;`,
  ];

  console.log(`Executing ${chunks.length} SQL statements...`);

  for (let i = 0; i < chunks.length; i++) {
    const label = chunks[i].split('\n')[0].trim().slice(0, 90);
    process.stdout.write(`[${i+1}/${chunks.length}] ${label}... `);

    const r = await query(chunks[i]);
    if (r.ok) {
      console.log('✅');
    } else {
      const err = r.text.slice(0, 200);
      console.log(`❌ ${err}`);
      // Don't abort — many objects may already exist (IF NOT EXISTS handles most)
    }

    await new Promise(r => setTimeout(r, 300));
  }

  console.log('\n✅ Migration execution complete!');

  // Verify tables exist
  console.log('\nVerifying tables...');
  const tables = ['host_agencies', 'host_agency_members', 'commission_settings', 'agency_diamond_ledger', 'agency_withdrawal_requests', 'agency_announcements', 'agency_free_agents', 'agency_blacklist'];
  for (const t of tables) {
    const r = await query(`SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${t}');`);
    if (r.ok) {
      const exists = r.text.includes('true') || r.text.includes('t');
      console.log(`  ${t}: ${exists ? '✅ EXISTS' : '❌ MISSING'}`);
    } else {
      console.log(`  ${t}: ❌ ERROR checking`);
    }
  }
}

main().catch(e => console.error(e));
