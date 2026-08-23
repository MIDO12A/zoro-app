const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  return await r.text();
}

(async () => {
  let r = await q("SELECT polname, polcmd FROM pg_policy WHERE polrelid = 'app_assets'::regclass");
  console.log('app_assets policies:', r);
})();
