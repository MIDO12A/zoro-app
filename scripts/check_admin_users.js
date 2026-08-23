const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

async function query(sql) {
  const resp = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await resp.text();
  return { ok: resp.ok, text };
}

async function main() {
  const r = await query('SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = \'public\' AND table_name = \'admin_users\' ORDER BY ordinal_position');
  console.log('admin_users columns:', r.text);
}

main().catch(e => console.error(e));
