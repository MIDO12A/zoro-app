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
  const chunks = [
    `CREATE TABLE IF NOT EXISTS public.profiles (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      display_name TEXT, username TEXT, avatar_url TEXT, country TEXT,
      app_role TEXT NOT NULL DEFAULT 'user',
      level INTEGER NOT NULL DEFAULT 1,
      coins BIGINT NOT NULL DEFAULT 0,
      diamonds BIGINT NOT NULL DEFAULT 0,
      kayan_id TEXT,
      kayan_entity_kind TEXT NOT NULL DEFAULT 'user',
      internal_entity_id BIGINT,
      serial_id BIGSERIAL,
      is_recharge_agent BOOLEAN NOT NULL DEFAULT false,
      agent_public_id TEXT, agency_name TEXT, host_status TEXT,
      is_banned BOOLEAN NOT NULL DEFAULT false,
      is_platform_banned BOOLEAN NOT NULL DEFAULT false,
      financial_banned BOOLEAN NOT NULL DEFAULT false,
      terms_accepted_at TIMESTAMPTZ, terms_version TEXT,
      birth_date DATE, age_confirmed_at TIMESTAMPTZ,
      push_token TEXT, vip_expires_at TIMESTAMPTZ, active_frame_id UUID,
      pin_hash TEXT, enabled BOOLEAN NOT NULL DEFAULT true,
      daily_limit INTEGER, agent_quick_amounts INTEGER[],
      deleted_at TIMESTAMPTZ, updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );`,

    `ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;`,

    `CREATE POLICY "Profiles are viewable by authenticated users"
      ON public.profiles FOR SELECT TO authenticated USING (true);`,

    `CREATE POLICY "Users can insert their own profile"
      ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);`,

    `CREATE POLICY "Users can update own profile"
      ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);`,

    `GRANT ALL ON public.profiles TO authenticated;`,
    `GRANT ALL ON public.profiles TO service_role;`,

    // Backfill from auth.users
    `INSERT INTO public.profiles (id, display_name, username, avatar_url, created_at, updated_at)
      SELECT id, COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', email),
        COALESCE(raw_user_meta_data->>'username', raw_user_meta_data->>'name', email),
        raw_user_meta_data->>'avatar_url', created_at, updated_at
      FROM auth.users
      ON CONFLICT (id) DO NOTHING;`,

    // Create trigger for new users
    `CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
    BEGIN
      INSERT INTO public.profiles (id, display_name, username, avatar_url, created_at, updated_at)
      VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', NEW.email),
        COALESCE(NEW.raw_user_meta_data->>'username', NEW.raw_user_meta_data->>'name', NEW.email),
        NEW.raw_user_meta_data->>'avatar_url',
        NEW.created_at, NEW.updated_at
      )
      ON CONFLICT (id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        username = EXCLUDED.username,
        avatar_url = EXCLUDED.avatar_url;
      RETURN NEW;
    END;
    $$;`,

    `DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;`,
    `CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();`,
  ];

  console.log(`Executing ${chunks.length} SQL statements...\n`);
  for (let i = 0; i < chunks.length; i++) {
    const label = chunks[i].split('\n')[0].trim().slice(0, 90);
    process.stdout.write(`[${i + 1}/${chunks.length}] ${label}... `);
    const r = await query(chunks[i]);
    if (r.ok) {
      console.log('OK');
    } else {
      const err = r.text.slice(0, 200);
      console.log(`ERROR: ${err}`);
    }
    await new Promise(r => setTimeout(r, 200));
  }
  console.log('\nDone.');
}
main().catch(e => console.error(e));
