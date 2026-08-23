const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
(async () => {
  // Test querying host_agencies directly
  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: `SELECT * FROM public.host_agencies LIMIT 5` })
  });
  const d = await r.json();
  console.log('host_agencies query:', r.status, JSON.stringify(d).slice(0, 500));
})();
