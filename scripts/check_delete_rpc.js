const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  });
  return { ok: r.ok, text: await r.text() };
}

q("SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'delete_user_account')").then(r => console.log('delete_user_account:', r.text.includes('true') ? 'OK' : 'MISSING'));
q("SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'delete_auth_user_on_user_delete')").then(r => console.log('delete_auth_user_on_user_delete:', r.text.includes('true') ? 'OK' : 'MISSING'));
q("SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_user_delete')").then(r => console.log('on_user_delete trigger:', r.text.includes('true') ? 'OK' : 'MISSING'));
