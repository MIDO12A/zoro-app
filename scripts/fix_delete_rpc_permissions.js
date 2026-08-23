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
  -- Allow: user self-delete, admin, or service_role
  IF p_uid IS DISTINCT FROM auth.uid()
     AND COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public._is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'forbidden');
  END IF;

  -- 0. Delete ALL sent_gifts on the user's rooms BEFORE deleting rooms
  --    because sent_gifts_room_id_fkey has NO ON DELETE CASCADE
  DELETE FROM public.sent_gifts
  WHERE room_id IN (SELECT room_id FROM public.rooms WHERE host_uid = v_uid_text);

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

  -- 3. Rooms (FK cascade handles room_messages/members/seats)
  DELETE FROM public.rooms WHERE host_uid = v_uid_text;

  -- 4. Reports
  DELETE FROM public.reports WHERE reporter_uid  = v_uid_text;
  DELETE FROM public.reports WHERE reported_uid  = v_uid_text;

  -- 5. Agency tables (auth.users UUID refs)
  UPDATE public.host_agencies SET owner_id = NULL, owner_user_id = NULL
  WHERE owner_id = p_uid OR owner_user_id = p_uid;
  DELETE FROM public.host_agency_members       WHERE user_id = p_uid;
  DELETE FROM public.host_agency_join_requests WHERE user_id = p_uid;
  DELETE FROM public.host_diamond_ledger       WHERE host_id = p_uid;
  DELETE FROM public.user_wallets              WHERE user_id = p_uid;
  DELETE FROM public.notifications             WHERE user_id = p_uid;
  DELETE FROM public.agency_diamond_ledger     WHERE user_id = p_uid;
  DELETE FROM public.agency_free_agents        WHERE agent_id = p_uid;
  DELETE FROM public.store_items               WHERE user_id = p_uid;
  DELETE FROM public.bug_reports               WHERE user_id = p_uid;
  DELETE FROM public.dashboard_bans            WHERE user_id = p_uid;
  DELETE FROM public.ranking_frames            WHERE user_id = p_uid;
  DELETE FROM public.room_gift_ledger          WHERE sender_id = p_uid;
  DELETE FROM public.room_gift_ledger          WHERE receiver_id = p_uid;
  DELETE FROM public.diamond_exchange_ledger   WHERE user_id = p_uid;
  DELETE FROM public.agency_recharge_ledger    WHERE agent_id = p_uid;
  DELETE FROM public.agency_recharge_ledger    WHERE recipient_user_id = p_uid;
  DELETE FROM public.agency_blacklist          WHERE user_id = p_uid;

  -- 5b. Tables that may not exist
  BEGIN
    DELETE FROM public.agency_milestone_progress
    WHERE agency_id IN (SELECT id FROM public.host_agencies WHERE owner_id = p_uid OR owner_user_id = p_uid);
  EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN
    DELETE FROM public.agency_milestones
    WHERE agency_id IN (SELECT id FROM public.host_agencies WHERE owner_id = p_uid OR owner_user_id = p_uid);
  EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN
    DELETE FROM public.host_milestones
    WHERE agency_id IN (SELECT id FROM public.host_agencies WHERE owner_id = p_uid OR owner_user_id = p_uid);
  EXCEPTION WHEN undefined_table THEN NULL; END;

  -- 6. Profiles (FK ON DELETE CASCADE to auth.users)
  DELETE FROM public.profiles WHERE id = p_uid;

  -- 7. public.users (FK trigger -> auth.users)
  DELETE FROM public.users WHERE uid = v_uid_text;

  -- 8. Before deleting auth.users, nullify non-cascade FK refs in public tables
  BEGIN
    UPDATE public.agency_withdrawal_requests SET reviewed_by = NULL WHERE reviewed_by = p_uid;
  EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN
    UPDATE public.agency_announcements SET created_by = NULL WHERE created_by = p_uid;
  EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN
    UPDATE public.commission_settings SET updated_by = NULL WHERE updated_by = p_uid;
  EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN
    UPDATE public.host_diamond_ledger SET sender_id = NULL WHERE sender_id = p_uid;
  EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN
    UPDATE public.host_agency_join_requests SET reviewed_by = NULL WHERE reviewed_by = p_uid;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  -- 9. Finally, delete from auth.users (all auth-schema FKs have ON DELETE CASCADE)
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
