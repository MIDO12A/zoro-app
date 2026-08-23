const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
const q = async (sql) => { const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ query: sql }) }); return await r.text(); };
(async () => {
  const t = await q("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'app_assets' ORDER BY ordinal_position");
  console.log(t);
  const t2 = await q("SELECT key, remote_url, is_active FROM app_assets WHERE key LIKE '%mine_close_ic%' LIMIT 5");
  console.log('sample:', t2);
})();
