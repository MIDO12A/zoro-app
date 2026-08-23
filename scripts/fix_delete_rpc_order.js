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

(async () => {
  // Recreate delete_user_account with correct FK order
  const sql = `
CREATE OR REPLACE FUNCTION public.delete_user_account(p_uid uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid_text text := p_uid::text;
  v_result jsonb;
BEGIN
  IF p_uid != auth.uid() AND NOT public._is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'forbidden');
  END IF;

  -- 1. Junction tables that reference BOTH users(uid) AND rooms(id)
  DELETE FROM public.sent_gifts     WHERE sender_id   = v_uid_text;
  DELETE FROM public.sent_gifts     WHERE receiver_id = v_uid_text;
  DELETE FROM public.room_messages  WHERE sender_uid  = v_uid_text;
  DELETE FROM public.room_seats     WHERE uid         = v_uid_text;
  DELETE FROM public.room_members   WHERE uid         = v_uid_text;
  DELETE FROM public.gifted_items   WHERE uid         = v_uid_text;

  -- 2. Tables referencing only users(uid)
  DELETE FROM public.private_messages WHERE sender_uid = v_uid_text;
  DELETE FROM public.unions           WHERE creator_id = v_uid_text;
  DELETE FROM public.union_members    WHERE uid        = v_uid_text;
  DELETE FROM public.user_vips        WHERE uid        = v_uid_text;
  DELETE FROM public.conversations    WHERE uid        = v_uid_text;
  DELETE FROM public.follows          WHERE follower_uid  = v_uid_text;
  DELETE FROM public.follows          WHERE following_uid = v_uid_text;
  DELETE FROM public.blocks           WHERE blocker_uid   = v_uid_text;
  DELETE FROM public.blocks           WHERE blocked_uid   = v_uid_text;

  -- 3. Rooms now (none of the prev-tables ref rooms anymore)
  DELETE FROM public.rooms          WHERE host_uid = v_uid_text;

  -- 4. Reports don't ref rooms — safe
  DELETE FROM public.reports        WHERE reporter_uid  = v_uid_text;
  DELETE FROM public.reports        WHERE reported_uid  = v_uid_text;

  -- 5. Agency tables (auth.users UUID refs)
  UPDATE public.host_agencies       SET owner_id = NULL, owner_user_id = NULL WHERE owner_id = p_uid OR owner_user_id = p_uid;
  DELETE FROM public.host_agency_members       WHERE user_id = p_uid;
  DELETE FROM public.host_agency_join_requests WHERE user_id = p_uid;
  DELETE FROM public.host_diamond_ledger       WHERE host_id = p_uid;
  DELETE FROM public.host_milestone_progress   WHERE host_id = p_uid;
  DELETE FROM public.user_wallets              WHERE user_id = p_uid;
  DELETE FROM public.notifications             WHERE user_id = p_uid;
  DELETE FROM public.agency_diamond_ledger     WHERE user_id = p_uid;
  DELETE FROM public.agency_free_agents        WHERE agent_id = p_uid;
  DELETE FROM public.store_items               WHERE user_id = p_uid;
  DELETE FROM public.bug_reports               WHERE user_id = p_uid;
  DELETE FROM public.dashboard_bans            WHERE user_id = p_uid;
  DELETE FROM public.ranking_frames            WHERE user_id = p_uid;

  -- 6. Profiles
  DELETE FROM public.profiles WHERE id = p_uid;

  -- 7. public.users → trigger → auth.users
  DELETE FROM public.users WHERE uid = v_uid_text;

  -- 8. auth.users fallback
  DELETE FROM auth.users WHERE id = p_uid;

  v_result := jsonb_build_object('status', 'ok');
  RETURN v_result;
EXCEPTION WHEN OTHERS THEN
  v_result := jsonb_build_object('status', 'error', 'message', SQLERRM);
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account(uuid) TO service_role;
`;
  const r = await q(sql);
  console.log(r.ok ? 'OK' : r.text.slice(0, 200));
})();
