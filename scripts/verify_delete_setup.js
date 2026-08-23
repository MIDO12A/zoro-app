const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
const fs = require('fs');

async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  return { ok: r.ok, text: await r.text() };
}

(async () => {
  const checks = [
    ["handle_new_auth_user", "SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_auth_user')"],
    ["on_auth_user_created", "SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created')"],
    ["delete_user_account", "SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'delete_user_account')"],
    ["delete_auth_user_on_user_delete", "SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'delete_auth_user_on_user_delete')"],
    ["on_user_delete", "SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_user_delete')"],
  ];
  for (const [name, sql] of checks) {
    const r = await q(sql);
    console.log(name + ':', r.text.includes('true') ? 'OK' : 'MISSING');
  }
})();
