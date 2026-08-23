const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ query: sql }) });
  return { ok: r.ok, text: await r.text() };
}
(async () => {
  // Preview count
  let r = await q(`
    SELECT COUNT(*) AS cnt
    FROM app_assets a
    JOIN app_assets b ON a.key = REPLACE(b.key, '-', '_')
    WHERE a.remote_url IS NULL AND b.remote_url IS NOT NULL
      AND a.key LIKE 'assets_mipmap_xxhdpi_%'
  `);
  console.log('Count of dups to clean:', r.text);

  // Delete underscore duplicates that have null url when hyphen version has url
  r = await q(`
    DELETE FROM app_assets a
    USING app_assets b
    WHERE a.remote_url IS NULL
      AND b.remote_url IS NOT NULL
      AND a.key = REPLACE(b.key, '-', '_')
      AND a.key LIKE 'assets_mipmap_xxhdpi_%'
  `);
  console.log('Clean result:', r.ok ? 'OK' : r.text.slice(0, 200));

  // Verify
  r = await q("SELECT key, remote_url IS NOT NULL AS has_url FROM app_assets WHERE key LIKE '%mine_close_ic%' ORDER BY key");
  console.log('After clean:', r.text);
})();
