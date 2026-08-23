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
  // FK referencing rooms
  let r = await q("SELECT conname, conrelid::regclass::text FROM pg_constraint WHERE confrelid = 'rooms'::regclass");
  console.log('FKs referencing rooms:', r);

  // FK referencing users
  r = await q("SELECT conname, conrelid::regclass::text FROM pg_constraint WHERE confrelid = 'users'::regclass");
  console.log('FKs referencing users:', r);
})();
