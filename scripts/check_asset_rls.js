const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ query: sql }) });
  return await r.text();
}
(async () => {
  // Check RLS policies for app_assets
  let r = await q(`
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
    FROM pg_policies
    WHERE tablename = 'app_assets'
  `);
  console.log('RLS policies:', r);

  // Check realtime publication
  r = await q(`
    SELECT tablename FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
  `);
  console.log('Realtime tables:', r);

  // Check app_assets table exists and RLS is enabled
  r = await q(`
    SELECT relname, relrowsecurity FROM pg_class
    WHERE relname = 'app_assets' AND relnamespace = 'public'::regnamespace
  `);
  console.log('app_assets RLS:', r);

  // Check a few recent assets
  r = await q(`
    SELECT key, name, remote_url, is_active, created_at
    FROM public.app_assets
    ORDER BY created_at DESC
    LIMIT 10
  `);
  console.log('Recent assets:', r);

  // Check total count
  r = await q(`
    SELECT COUNT(*) AS cnt FROM public.app_assets
  `);
  console.log('Total assets:', r);

  // Check RLS for anon role specifically
  r = await q(`
    SELECT schemaname, tablename, policyname, roles, cmd
    FROM pg_policies
    WHERE tablename = 'app_assets' AND 'anon' = ANY(roles)
  `);
  console.log('Anon policies:', r);
})();
