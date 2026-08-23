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
  let r = await q(`
    SELECT conname, conrelid::regclass AS table_name, pg_get_constraintdef(oid) AS def
    FROM pg_constraint
    WHERE contype = 'f' AND confrelid = 'auth.users'::regclass
  `);
  console.log('FKs into auth.users:', r);
})();
