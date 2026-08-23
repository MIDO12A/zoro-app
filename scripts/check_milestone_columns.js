const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ query: sql }) });
  return await r.text();
}
(async () => {
  let r = await q("SELECT column_name, is_nullable, data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='agency_milestone_progress' ORDER BY ordinal_position");
  console.log('agency_milestone_progress:', r);
  r = await q("SELECT column_name, is_nullable, data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='host_milestones' ORDER BY ordinal_position");
  console.log('host_milestones:', r);
})();
