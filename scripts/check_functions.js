const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  return r.ok ? await r.text() : 'ERR';
}

async function main() {
  const checks = [
    '_is_admin', 'agency_get_dashboard', 'get_host_dashboard_v3',
    'agency_create', 'agency_get_engine_settings', 'agency_get_leaderboard',
    'agency_get_profile', 'agency_request_join', 'get_host_dashboard_v2',
    'agency_request_exit', 'agency_pay_penalty_exit', 'agency_exchange_diamonds',
    'agency_request_withdrawal', 'agency_transfer_to_recharge', 'host_transfer_diamonds_to_agent',
    'agency_send_announcement', 'agency_accept_member', 'agency_kick_member',
    'agency_get_owner_dashboard', 'agency_owner_exchange_diamonds', 'agency_owner_request_withdrawal',
    'agency_send_chat_message', 'agency_view_once_open', 'agency_report_screenshot',
    'agency_mute_member_chat', 'agency_invite_by_kayan_id', 'agency_assign_supervisor',
    'agency_revoke_supervisor',
  ];
  for (const name of checks) {
    const r = await q("SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = '" + name + "')");
    console.log((r.includes('true') ? 'OK' : '--') + ' ' + name);
  }
}
main().catch(e => console.error(e));
