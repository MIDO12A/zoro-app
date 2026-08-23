const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ query: sql }) });
  return await r.text();
}
(async () => {
  const t = await q("SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND (tablename LIKE '%milestone%' OR tablename LIKE '%milestone%')");
  const r = await q("SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public' ORDER BY tablename");
  console.log('milestone tables:', t);
  console.log('all tables:', r);
})();
