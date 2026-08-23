const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
(async () => {
  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname='public' AND (tablename LIKE 'agency_%' OR tablename LIKE 'host_%' OR tablename LIKE 'commission_%') ORDER BY tablename`
    })
  });
  const d = await r.json();
  if (Array.isArray(d)) {
    console.log('Tables:', d.map(t => t.tablename).join(', '));
  } else {
    console.log('Response:', JSON.stringify(d).slice(0, 500));
  }
})();
