const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ query: sql }) });
  return await r.text();
}
(async () => {
  // Get ALL remote URLs for account/profile screen assets
  const r = await q(`
    SELECT key, remote_url FROM app_assets 
    WHERE key LIKE '%mipmap-xxhdpi_mine_%' AND remote_url IS NOT NULL
    UNION ALL
    SELECT key, remote_url FROM app_assets 
    WHERE key LIKE '%mipmap_xxhdpi_mine_%' AND remote_url IS NOT NULL
  `);
  const rows = JSON.parse(r);
  console.log('Profile screen assets with URLs:\n');
  for (const row of rows) {
    console.log(` ${row.key}`);
    console.log(`   ${row.remote_url.slice(0, 100)}`);
    // Test if URL is accessible
    try {
      const resp = await fetch(row.remote_url, { method: 'HEAD' });
      console.log(`   → HTTP ${resp.status} ${resp.ok ? '✅' : '❌'}`);
    } catch(e) {
      console.log(`   → fetch error: ${e.message.slice(0, 80)}`);
    }
    console.log('');
  }
})();
