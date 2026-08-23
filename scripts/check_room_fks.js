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
    SELECT conname, pg_get_constraintdef(oid) 
    FROM pg_constraint 
    WHERE confrelid = 'rooms'::regclass 
      AND contype = 'f'
  `);
  console.log('FKs referencing rooms:', r);
})();
