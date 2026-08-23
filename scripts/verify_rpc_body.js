const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ query: sql }) });
  return await r.text();
}
(async () => {
  const t = await q("SELECT prosrc FROM pg_proc WHERE proname = 'delete_user_account'");
  const s = JSON.parse(t);
  const body = s[0].prosrc;
  console.log('Has auth.users DELETE:', body.includes('DELETE FROM auth.users'));
  console.log('Has service_role check:', body.includes('service_role'));
  console.log('Has sent_gifts room cleanup:', body.includes('WHERE room_id IN'));
  console.log('Has reviewed_by nullify:', body.includes('reviewed_by'));
  console.log('Has sender_id nullify:', body.includes('sender_id'));
  console.log('Length:', body.length);
})();
