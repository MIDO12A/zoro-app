const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
(async () => {
  // Reload PostgREST schema cache
  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: `NOTIFY pgrst, 'reload schema'` })
  });
  const d = await r.text();
  console.log('NOTIFY pgrst:', r.status, d.slice(0, 200));
})();
