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
  return resp.ok ? await resp.text() : 'ERROR: ' + (await resp.text()).slice(0, 200);
}

async function main() {
  const names = ['host_diamond_ledger', 'user_wallets'];
  for (const name of names) {
    const r = await query(
      "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '" + name + "')"
    );
    console.log((r.includes('true') ? '✅' : '❌') + ' ' + name);
  }
}
main().catch(e => console.error(e));
