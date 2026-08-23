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
  return resp.ok ? await resp.text() : 'ERROR: ' + (await resp.text()).slice(0, 500);
}

async function main() {
  // 1. List all public tables
  console.log('=== PUBLIC TABLES ===');
  const tables = await query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
  );
  console.log(tables);

  // 2. Check specific missing tables
  const missingChecks = [
    'profiles', 'host_diamond_ledger', 'store_items', 'gifted_items',
    'unions', 'union_members', 'level_config', 'user_wallets',
    'host_agencies', 'host_agency_members', 'necklaces', 'badges',
    'recharge_plans', 'gift_categories', 'gift_banner_configs',
    'app_config', 'app_assets', 'vip_config', 'rooms'
  ];
  console.log('\n=== CHECK SPECIFIC TABLES ===');
  for (const name of missingChecks) {
    const r = await query(
      "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '" + name + "')"
    );
    const exists = r.includes('true');
    console.log((exists ? '✅' : '❌') + ' ' + name);
  }
}
main().catch(e => console.error(e));
