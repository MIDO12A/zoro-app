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
    // 1. follows
    `CREATE TABLE IF NOT EXISTS public.follows (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      follower_uid  TEXT NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
      following_uid TEXT NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
      created_at    TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(follower_uid, following_uid)
    )`,
    `ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS follows_all ON public.follows`,
    `CREATE POLICY follows_all ON public.follows FOR ALL TO authenticated USING (follower_uid = auth.uid()::text) WITH CHECK (follower_uid = auth.uid()::text)`,

    // 2. reports
    `CREATE TABLE IF NOT EXISTS public.reports (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      reporter_uid  TEXT,
      reported_uid  TEXT,
      reason        TEXT,
      description   TEXT,
      status        TEXT DEFAULT 'pending',
      resolved_at   TIMESTAMPTZ,
      created_at    TIMESTAMPTZ DEFAULT NOW()
    )`,
    `ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS reports_select ON public.reports`,
    `CREATE POLICY reports_select ON public.reports FOR SELECT TO authenticated USING (reporter_uid = auth.uid()::text OR public._is_admin(auth.uid()))`,
    `DROP POLICY IF EXISTS reports_insert ON public.reports`,
    `CREATE POLICY reports_insert ON public.reports FOR INSERT TO authenticated WITH CHECK (reporter_uid = auth.uid()::text)`,

    // 3. blocks
    `CREATE TABLE IF NOT EXISTS public.blocks (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      blocker_uid   TEXT,
      blocked_uid   TEXT,
      created_at    TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(blocker_uid, blocked_uid)
    )`,
    `ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS blocks_all ON public.blocks`,
    `CREATE POLICY blocks_all ON public.blocks FOR ALL TO authenticated USING (blocker_uid = auth.uid()::text) WITH CHECK (blocker_uid = auth.uid()::text)`,
  ];

  console.log(`Executing ${chunks.length} SQL statements...\n`);
  for (let i = 0; i < chunks.length; i++) {
    const label = chunks[i].split('\n')[0].trim().slice(0, 90);
    process.stdout.write(`[${i + 1}/${chunks.length}] ${label}... `);
    const r = await query(chunks[i]);
    if (r.ok) {
      console.log('OK');
    } else {
      console.log(`ERROR: ${r.text.slice(0, 250)}`);
    }
    await new Promise(r => setTimeout(r, 200));
  }
  console.log('\nDone.');
}
main().catch(e => console.error(e));
