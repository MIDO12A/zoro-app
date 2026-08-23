-- ============================================================
-- Supabase Schema: Zero App (Firebase → Supabase Migration)
-- Instructions: Paste this entire file into Supabase SQL Editor
--               and run it once.
-- ============================================================

-- 1. USERS
CREATE TABLE users (
  uid TEXT PRIMARY KEY,
  custom_id TEXT UNIQUE,
  name TEXT,
  email TEXT,
  photo_url TEXT,
  coins BIGINT DEFAULT 0,
  diamonds BIGINT DEFAULT 0,
  gender TEXT,
  active_frame TEXT,
  active_headwear TEXT,
  active_bubble TEXT,
  active_entrance TEXT,
  active_car TEXT,
  active_cover TEXT,
  owned_items JSONB DEFAULT '[]',
  owned_badges JSONB DEFAULT '[]',
  hosted_room_id TEXT,
  followed_rooms JSONB DEFAULT '[]',
  total_gifts_sent BIGINT DEFAULT 0,
  total_gifts_received BIGINT DEFAULT 0,
  level INT DEFAULT 1,
  experience BIGINT DEFAULT 0,
  followers INT DEFAULT 0,
  following INT DEFAULT 0,
  visitors INT DEFAULT 0,
  charm BIGINT DEFAULT 0,
  wealth_level INT DEFAULT 1,
  wealth_exp BIGINT DEFAULT 0,
  recharge_level INT DEFAULT 1,
  recharge_exp BIGINT DEFAULT 0,
  gems_level INT DEFAULT 1,
  gems_exp BIGINT DEFAULT 0,
  owned_level_frames JSONB DEFAULT '[]',
  owned_level_badges JSONB DEFAULT '[]',
  phone TEXT DEFAULT '',
  last_ip TEXT DEFAULT '',
  banned BOOLEAN DEFAULT false,
  ban_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. ROOMS
CREATE TABLE rooms (
  room_id TEXT PRIMARY KEY,
  name TEXT,
  description TEXT,
  room_photo_url TEXT,
  host_uid TEXT REFERENCES users(uid),
  host_name TEXT,
  host_photo_url TEXT,
  member_count INT DEFAULT 0,
  max_members INT,
  is_locked BOOLEAN DEFAULT false,
  category TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  password TEXT,
  seat_count INT,
  seat_style TEXT,
  seat_color TEXT,
  total_gifts BIGINT DEFAULT 0,
  hot_value BIGINT DEFAULT 0,
  moderators TEXT[] DEFAULT '{}'
);

-- 3. ROOM MESSAGES
CREATE TABLE room_messages (
  msg_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT REFERENCES rooms(room_id) ON DELETE CASCADE,
  sender_uid TEXT REFERENCES users(uid),
  sender_name TEXT,
  sender_photo_url TEXT,
  text TEXT,
  type TEXT,
  image_url TEXT,
  active_bubble TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ROOM MEMBERS
CREATE TABLE room_members (
  room_id TEXT REFERENCES rooms(room_id) ON DELETE CASCADE,
  uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
  name TEXT,
  photo_url TEXT,
  role TEXT,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (room_id, uid)
);

-- 5. ROOM SEATS
CREATE TABLE room_seats (
  room_id TEXT REFERENCES rooms(room_id) ON DELETE CASCADE,
  seat_index INT,
  uid TEXT REFERENCES users(uid),
  name TEXT,
  photo_url TEXT,
  active_frame TEXT,
  active_car TEXT,
  is_muted BOOLEAN DEFAULT false,
  taken_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (room_id, seat_index)
);

-- 6. GIFTS CATALOG
CREATE TABLE gifts (
  id TEXT PRIMARY KEY,
  name TEXT,
  value INT,
  icon_asset TEXT,
  animation_asset TEXT,
  is_vap BOOLEAN DEFAULT false,
  is_lucky BOOLEAN DEFAULT false,
  is_star BOOLEAN DEFAULT false,
  is_music BOOLEAN DEFAULT false,
  package_count INT,
  sort_order INT,
  name_key TEXT,
  photo_key TEXT,
  default_image TEXT,
  wealth_xp INT DEFAULT 0,
  gems_xp INT DEFAULT 0
);

-- 7. SENT GIFTS
CREATE TABLE sent_gifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT REFERENCES rooms(room_id),
  gift_id TEXT REFERENCES gifts(id),
  gift_name TEXT,
  animation_asset TEXT,
  sender_id TEXT REFERENCES users(uid),
  sender_name TEXT,
  sender_photo_url TEXT,
  receiver_id TEXT REFERENCES users(uid),
  receiver_name TEXT,
  value INT,
  count INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. STORE ITEMS
CREATE TABLE store_items (
  item_id TEXT PRIMARY KEY,
  name TEXT,
  category TEXT,
  icon_asset TEXT,
  price INT,
  svga_asset TEXT,
  is_premium BOOLEAN DEFAULT false,
  name_key TEXT,
  photo_key TEXT,
  default_image TEXT
);

-- 9. BANNERS
CREATE TABLE banners (
  id TEXT PRIMARY KEY,
  image_url TEXT,
  link_url TEXT,
  title TEXT,
  sort_order INT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. UNIONS
CREATE TABLE unions (
  id TEXT PRIMARY KEY,
  name TEXT,
  description TEXT,
  creator_id TEXT REFERENCES users(uid),
  creator_name TEXT,
  logo_url TEXT,
  member_count INT DEFAULT 1,
  level INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. UNION MEMBERS
CREATE TABLE union_members (
  union_id TEXT REFERENCES unions(id) ON DELETE CASCADE,
  uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
  role TEXT DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (union_id, uid)
);

-- 12. GIFTED ITEMS (admin-gifted inventory items with expiry)
CREATE TABLE gifted_items (
  id TEXT PRIMARY KEY,
  uid TEXT REFERENCES users(uid),
  item_id TEXT,
  item_category TEXT,
  item_name TEXT,
  item_icon TEXT,
  svga_asset TEXT,
  sent_by TEXT,
  sent_by_name TEXT,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

-- 13. LEVEL CONFIG
CREATE TABLE level_config (
  type TEXT,
  level INT,
  min_exp BIGINT,
  max_exp BIGINT,
  title TEXT,
  image_url TEXT,
  frame_url TEXT,
  badge_url TEXT,
  rewards JSONB DEFAULT '{}',
  progress_color TEXT DEFAULT '#DE880F',
  box_image_url TEXT,
  PRIMARY KEY (type, level)
);

ALTER TABLE level_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "level_config_select_all" ON level_config
  FOR SELECT USING (true);

CREATE POLICY "level_config_all_admin" ON level_config
  USING (true);

-- 14. VIP CONFIG
CREATE TABLE vip_config (
  tier INT PRIMARY KEY,
  name TEXT,
  min_spend BIGINT,
  price BIGINT,
  color TEXT,
  image_url TEXT,
  bg_url TEXT,
  logo_url TEXT,
  medal_url TEXT,
  medal_img_url TEXT,
  medal_name TEXT,
  headwear_url TEXT,
  headwear_img_url TEXT,
  headwear_name TEXT,
  entrance_url TEXT,
  entrance_img_url TEXT,
  entrance_name TEXT,
  bubble_url TEXT,
  bubble_img_url TEXT,
  bubble_name TEXT,
  necklace_url TEXT,
  necklace_img_url TEXT,
  necklace_name TEXT,
  benefits JSONB DEFAULT '[]',
  accessories JSONB DEFAULT '[]',
   items JSONB DEFAULT '[]',
   additional_files JSONB DEFAULT '[]',
   intro_video_url TEXT
);

-- Allow public read & admin write on vip_config
DROP POLICY IF EXISTS "anon_read_vip_config" ON vip_config;
CREATE POLICY "anon_read_vip_config" ON vip_config
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "service_write_vip_config" ON vip_config;
CREATE POLICY "service_write_vip_config" ON vip_config
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_write_vip_config" ON vip_config;
CREATE POLICY "anon_write_vip_config" ON vip_config
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_vip_config" ON vip_config;
CREATE POLICY "anon_update_vip_config" ON vip_config
  FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_vip_config" ON vip_config;
CREATE POLICY "anon_delete_vip_config" ON vip_config
  FOR DELETE USING (true);

-- 23. Storage bucket for admin uploads
INSERT INTO storage.buckets (id, name, public) VALUES ('admin-uploads', 'admin-uploads', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public read access to admin-uploads
DROP POLICY IF EXISTS "Public read access" ON storage.objects;
CREATE POLICY "Public read access" ON storage.objects
  FOR SELECT USING (bucket_id = 'admin-uploads');

-- Allow anon uploads to admin-uploads (for admin dashboard using anon key)
DROP POLICY IF EXISTS "Anon upload access" ON storage.objects;
CREATE POLICY "Anon upload access" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'admin-uploads');

DROP POLICY IF EXISTS "Anon update access" ON storage.objects;
CREATE POLICY "Anon update access" ON storage.objects
  FOR UPDATE USING (bucket_id = 'admin-uploads');

DROP POLICY IF EXISTS "Anon delete access" ON storage.objects;
CREATE POLICY "Anon delete access" ON storage.objects
  FOR DELETE USING (bucket_id = 'admin-uploads');

-- 24. USER VIPS (purchased VIP memberships)
CREATE TABLE user_vips (
  uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
  tier INT,
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  gifted_by TEXT,
  PRIMARY KEY (uid, tier)
);

-- 15. BADGES
CREATE TABLE badges (
  id TEXT PRIMARY KEY,
  name TEXT,
  svga_url TEXT,
  image_url TEXT
);

-- 16. NECKLACES
CREATE TABLE necklaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  svga_url TEXT,
  image_url TEXT,
  price INT DEFAULT 0,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE necklaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "necklaces_select_all" ON necklaces
  FOR SELECT USING (true);

CREATE POLICY "necklaces_all_admin" ON necklaces
  USING (true);

-- 16. CONVERSATIONS (private message threads per user)
CREATE TABLE conversations (
  uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
  conv_id TEXT,
  last_message TEXT,
  last_sender_uid TEXT,
  last_timestamp TIMESTAMPTZ,
  unread_count INT DEFAULT 0,
  PRIMARY KEY (uid, conv_id)
);

-- 17. PRIVATE MESSAGES
CREATE TABLE private_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conv_id TEXT,
  sender_uid TEXT REFERENCES users(uid),
  sender_name TEXT,
  sender_photo_url TEXT,
  text TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 18. BUG REPORTS
CREATE TABLE bug_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  error TEXT,
  stack_trace TEXT,
  device_info JSONB,
  type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bug_reports_insert_all" ON bug_reports FOR INSERT WITH CHECK (true);
CREATE POLICY "bug_reports_select_all" ON bug_reports FOR SELECT USING (true);

-- 19. APP CONFIG (key-value store)
CREATE TABLE app_config (
  key TEXT PRIMARY KEY,
  value JSONB
);

-- 20. AGENCIES
CREATE TABLE agencies (
  id TEXT PRIMARY KEY,
  name TEXT,
  data JSONB DEFAULT '{}'
);

-- 21. CPS
CREATE TABLE cps (
  id TEXT PRIMARY KEY,
  name TEXT,
  data JSONB DEFAULT '{}'
);

-- 22. BDS
CREATE TABLE bds (
  id TEXT PRIMARY KEY,
  name TEXT,
  data JSONB DEFAULT '{}'
);

-- ============================================================
-- ENABLE REALTIME for tables that need live subscriptions
-- Run these AFTER creating the tables
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE room_members;
ALTER PUBLICATION supabase_realtime ADD TABLE room_seats;
ALTER PUBLICATION supabase_realtime ADD TABLE room_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE sent_gifts;
ALTER PUBLICATION supabase_realtime ADD TABLE private_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE gifted_items;
ALTER PUBLICATION supabase_realtime ADD TABLE users;
ALTER PUBLICATION supabase_realtime ADD TABLE store_items;
ALTER PUBLICATION supabase_realtime ADD TABLE banners;

-- ============================================================
-- RPC FUNCTIONS
-- ============================================================
CREATE OR REPLACE FUNCTION add_room_moderator(p_room_id TEXT, p_uid TEXT)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE rooms
  SET moderators = array_append(
    COALESCE(moderators, '{}'),
    p_uid
  )
  WHERE room_id = p_room_id AND NOT (p_uid = ANY(COALESCE(moderators, '{}')));
END;
$$;

CREATE OR REPLACE FUNCTION remove_room_moderator(p_room_id TEXT, p_uid TEXT)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE rooms
  SET moderators = array_remove(COALESCE(moderators, '{}'), p_uid)
  WHERE room_id = p_room_id;
END;
$$;

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_room_messages_room_id ON room_messages(room_id);
CREATE INDEX idx_room_messages_created_at ON room_messages(created_at);
CREATE INDEX idx_room_members_uid ON room_members(uid);
CREATE INDEX idx_sent_gifts_room_id ON sent_gifts(room_id);
CREATE INDEX idx_sent_gifts_receiver_id ON sent_gifts(receiver_id);
CREATE INDEX idx_private_messages_conv_id ON private_messages(conv_id);
CREATE INDEX idx_private_messages_created_at ON private_messages(created_at);
CREATE INDEX idx_gifted_items_uid ON gifted_items(uid);
CREATE INDEX idx_rooms_hot_value ON rooms(hot_value DESC);

-- ============================================================
-- ROW LEVEL SECURITY (basic setup - expand as needed)
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_seats ENABLE ROW LEVEL SECURITY;
ALTER TABLE sent_gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_items ENABLE ROW LEVEL SECURITY;

-- Users can read/update their own data
CREATE POLICY "users_select_self" ON users FOR SELECT USING (uid = auth.uid()::text);
CREATE POLICY "users_update_self" ON users FOR UPDATE USING (uid = auth.uid()::text);
CREATE POLICY "users_insert_self" ON users FOR INSERT WITH CHECK (uid = auth.uid()::text);
CREATE POLICY "users_delete_self" ON users FOR DELETE USING (uid = auth.uid()::text);

-- Admin can read/update all users (for dashboard)
CREATE POLICY "users_select_all_admin" ON users FOR SELECT USING (auth.role() = 'service_role' OR auth.role() = 'authenticated' OR auth.role() = 'anon');
CREATE POLICY "users_update_all_admin" ON users FOR UPDATE USING (auth.role() = 'service_role' OR auth.role() = 'authenticated');
CREATE POLICY "users_delete_all_admin" ON users FOR DELETE USING (auth.role() = 'service_role' OR auth.role() = 'authenticated');

-- Public read for rooms, only host can write
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'rooms' AND policyname = 'rooms_select_all') THEN
    CREATE POLICY "rooms_select_all" ON rooms FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'rooms' AND policyname = 'rooms_insert_host') THEN
    CREATE POLICY "rooms_insert_host" ON rooms FOR INSERT WITH CHECK (host_uid = auth.uid()::text);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'rooms' AND policyname = 'rooms_update_host') THEN
    CREATE POLICY "rooms_update_host" ON rooms FOR UPDATE USING (
      host_uid = auth.uid()::text OR auth.uid()::text = ANY(moderators)
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'rooms' AND policyname = 'rooms_delete_host') THEN
    CREATE POLICY "rooms_delete_host" ON rooms FOR DELETE USING (host_uid = auth.uid()::text);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'room_members' AND policyname = 'room_members_select') THEN
    CREATE POLICY "room_members_select" ON room_members FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'room_members' AND policyname = 'room_members_insert') THEN
    CREATE POLICY "room_members_insert" ON room_members FOR INSERT WITH CHECK (uid = auth.uid()::text);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'room_members' AND policyname = 'room_members_delete') THEN
    CREATE POLICY "room_members_delete" ON room_members FOR DELETE USING (uid = auth.uid()::text);
  END IF;
END $$;

-- Room seats: public read, authenticated user owns their seat
CREATE POLICY "room_seats_select" ON room_seats FOR SELECT USING (true);
CREATE POLICY "room_seats_insert" ON room_seats FOR INSERT WITH CHECK (uid = auth.uid()::text);
CREATE POLICY "room_seats_update" ON room_seats FOR UPDATE USING (uid = auth.uid()::text);
CREATE POLICY "room_seats_delete" ON room_seats FOR DELETE USING (uid = auth.uid()::text);

-- Store: public read
CREATE POLICY "store_items_select" ON store_items FOR SELECT USING (true);

-- Sent gifts: public read, authenticated send
CREATE POLICY "sent_gifts_select" ON sent_gifts FOR SELECT USING (true);
CREATE POLICY "sent_gifts_insert" ON sent_gifts FOR INSERT WITH CHECK (sender_id = auth.uid()::text);

-- Private messages: only participants can read
CREATE POLICY "private_messages_select" ON private_messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM conversations WHERE conv_id = private_messages.conv_id AND uid = auth.uid()::text)
);
CREATE POLICY "private_messages_insert" ON private_messages FOR INSERT WITH CHECK (sender_uid = auth.uid()::text);

-- Conversations: only the user can see their own
CREATE POLICY "conversations_select" ON conversations FOR SELECT USING (uid = auth.uid()::text);
CREATE POLICY "conversations_insert" ON conversations FOR INSERT WITH CHECK (uid = auth.uid()::text);
CREATE POLICY "conversations_update" ON conversations FOR UPDATE USING (uid = auth.uid()::text);

-- Add country column to rooms (for country filter)
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS country TEXT DEFAULT '';

-- Notifications table (dashboard sends → app receives)
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target TEXT DEFAULT 'all',
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID
);

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifications_select_all" ON notifications FOR SELECT USING (true);
CREATE POLICY "notifications_insert_all" ON notifications FOR INSERT WITH CHECK (true);

-- ============================================================
-- GIFT CATEGORIES (for categorizing gifts in the panel)
-- ============================================================
CREATE TABLE IF NOT EXISTS gift_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gift_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "gift_categories_select_all" ON gift_categories FOR SELECT USING (true);
CREATE POLICY "gift_categories_insert_admin" ON gift_categories FOR INSERT WITH CHECK (true);
CREATE POLICY "gift_categories_update_admin" ON gift_categories FOR UPDATE USING (true);
CREATE POLICY "gift_categories_delete_admin" ON gift_categories FOR DELETE USING (true);

ALTER PUBLICATION supabase_realtime ADD TABLE gift_categories;

-- ============================================================
-- ADD CATEGORY_ID TO GIFTS TABLE
-- ============================================================
ALTER TABLE gifts ADD COLUMN IF NOT EXISTS category_id TEXT REFERENCES gift_categories(id);

-- ============================================================
-- GIFT BANNER CONFIGS (SVGA overlay strip for high-value gifts)
-- ============================================================
CREATE TABLE IF NOT EXISTS gift_banner_configs (
  id TEXT PRIMARY KEY,
  category_id TEXT REFERENCES gift_categories(id),
  threshold_coins INT DEFAULT 5000,
  svga_url TEXT NOT NULL,
  user_r_key TEXT DEFAULT 'user_r',
  user_l_key TEXT DEFAULT 'user_l',
  number_key TEXT DEFAULT 'number',
  gift_key TEXT DEFAULT 'gift',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gift_banner_configs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "gift_banner_configs_select_all" ON gift_banner_configs FOR SELECT USING (true);
CREATE POLICY "gift_banner_configs_insert_admin" ON gift_banner_configs FOR INSERT WITH CHECK (true);
CREATE POLICY "gift_banner_configs_update_admin" ON gift_banner_configs FOR UPDATE USING (true);
CREATE POLICY "gift_banner_configs_delete_admin" ON gift_banner_configs FOR DELETE USING (true);

ALTER PUBLICATION supabase_realtime ADD TABLE gift_banner_configs;

-- Seed default gift categories
INSERT INTO gift_categories (id, name, sort_order) VALUES
  ('general', 'عام', 0),
  ('celebrity', 'المشاهير', 1),
  ('idol', 'المعبود', 2),
  ('lucky', 'الحظ', 3),
  ('cp', 'CP', 4),
  ('event', 'الحدث', 5)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- AUTO-CREATE PUBLIC.USERS ROW ON AUTH.USERS INSERT
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (uid, name, email, photo_url, coins, diamonds, custom_id)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'name',
      SPLIT_PART(NEW.email, '@', 1),
      'User'
    ),
    COALESCE(NEW.email, ''),
    COALESCE(
      NEW.raw_user_meta_data->>'avatar_url',
      NEW.raw_user_meta_data->>'photoUrl',
      ''
    ),
    0,
    0,
    SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 8)
  )
  ON CONFLICT (uid) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- Auto-delete auth.users when public.users row is removed
-- NOTE: OLD.uid is TEXT, auth.users.id is UUID, must cast with ::uuid
CREATE OR REPLACE FUNCTION public.delete_auth_user_on_user_delete()
RETURNS TRIGGER
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  DELETE FROM auth.users WHERE id = OLD.uid::uuid;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_user_delete ON public.users;
CREATE TRIGGER on_user_delete
  AFTER DELETE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.delete_auth_user_on_user_delete();

-- Backfill existing auth users that lack a public.users row
INSERT INTO public.users (uid, name, email, photo_url, coins, diamonds, custom_id)
SELECT
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'name',
    SPLIT_PART(au.email, '@', 1),
    'User'
  ),
  COALESCE(au.email, ''),
  COALESCE(
    au.raw_user_meta_data->>'avatar_url',
    au.raw_user_meta_data->>'photoUrl',
    ''
  ),
  0,
  0,
  SUBSTRING(REPLACE(au.id::text, '-', ''), 1, 8)
FROM auth.users au
LEFT JOIN public.users pu ON pu.uid = au.id
WHERE pu.uid IS NULL;

-- ============================================================
-- FOLLOWS TABLE & RPCs
-- ============================================================
CREATE TABLE IF NOT EXISTS follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  following_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_uid, following_uid)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_uid);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_uid);

ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "follows_select" ON follows FOR SELECT USING (true);
CREATE POLICY "follows_insert" ON follows FOR INSERT WITH CHECK (auth.uid()::text = follower_uid);
CREATE POLICY "follows_delete" ON follows FOR DELETE USING (auth.uid()::text = follower_uid);

CREATE OR REPLACE FUNCTION increment_follow(p_uid TEXT, p_field TEXT)
RETURNS void
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
  IF p_field = 'followers' THEN
    UPDATE users SET followers = followers + 1 WHERE uid = p_uid;
  ELSIF p_field = 'following' THEN
    UPDATE users SET following = following + 1 WHERE uid = p_uid;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_follow(p_uid TEXT, p_field TEXT)
RETURNS void
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
  IF p_field = 'followers' THEN
    UPDATE users SET followers = GREATEST(followers - 1, 0) WHERE uid = p_uid;
  ELSIF p_field = 'following' THEN
    UPDATE users SET following = GREATEST(following - 1, 0) WHERE uid = p_uid;
  END IF;
END;
$$;

-- ============================================================
-- Migration: Add owned_necklaces to users + type/level to necklaces
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_necklaces JSONB DEFAULT '[]';
ALTER TABLE necklaces ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'admin';
ALTER TABLE necklaces ADD COLUMN IF NOT EXISTS required_recharge_level INT DEFAULT 0;

-- ============================================================
-- REPORTS TABLE (user-generated reports)
-- ============================================================
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  reported_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending',
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_reported ON reports(reported_uid);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reports_insert" ON reports FOR INSERT WITH CHECK (auth.uid()::text = reporter_uid);
CREATE POLICY "reports_select_own" ON reports FOR SELECT USING (auth.uid()::text = reporter_uid OR auth.uid()::text = reported_uid);
CREATE POLICY "reports_select_all_admin" ON reports FOR SELECT USING (auth.role() = 'service_role');

-- ============================================================
-- BLOCKS TABLE (user-to-user blocking)
-- ============================================================
CREATE TABLE IF NOT EXISTS blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  blocked_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(blocker_uid, blocked_uid)
);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON blocks(blocker_uid);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_uid);

ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blocks_select" ON blocks FOR SELECT USING (auth.uid()::text IN (blocker_uid, blocked_uid));
CREATE POLICY "blocks_insert" ON blocks FOR INSERT WITH CHECK (auth.uid()::text = blocker_uid);
CREATE POLICY "blocks_delete" ON blocks FOR DELETE USING (auth.uid()::text = blocker_uid);

-- ============================================================
-- RANKING FRAMES CONFIG (animated frames for top 1/2/3 in each category)
-- ============================================================
CREATE TABLE IF NOT EXISTS ranking_frames (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL,
  rank INT NOT NULL CHECK (rank >= 1 AND rank <= 3),
  asset_url TEXT NOT NULL,
  asset_type TEXT NOT NULL DEFAULT 'webp',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(category, rank)
);

ALTER TABLE ranking_frames ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ranking_frames_select_all" ON ranking_frames FOR SELECT USING (true);
CREATE POLICY "ranking_frames_insert_admin" ON ranking_frames FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "ranking_frames_update_admin" ON ranking_frames FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "ranking_frames_delete_admin" ON ranking_frames FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

ALTER PUBLICATION supabase_realtime ADD TABLE ranking_frames;

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_config_select_all" ON app_config FOR SELECT USING (true);
CREATE POLICY "app_config_insert_admin" ON app_config FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "app_config_update_admin" ON app_config FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "app_config_delete_admin" ON app_config FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

ALTER PUBLICATION supabase_realtime ADD TABLE app_config;

-- ============================================================
-- ADMIN USERS TABLE (dashboard login management)
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_users (
  uid TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  display_name TEXT DEFAULT '',
  role TEXT NOT NULL DEFAULT 'moderator' CHECK (role IN ('superadmin', 'admin', 'moderator')),
  permissions JSONB DEFAULT '{}',
  photo_url TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_users_select" ON admin_users FOR SELECT USING (true);
CREATE POLICY "admin_users_insert" ON admin_users FOR INSERT WITH CHECK (
  auth.uid()::text IN (SELECT uid FROM admin_users WHERE role = 'superadmin')
);
CREATE POLICY "admin_users_update" ON admin_users FOR UPDATE USING (
  auth.uid()::text = uid OR auth.uid()::text IN (SELECT uid FROM admin_users WHERE role = 'superadmin')
);
CREATE POLICY "admin_users_delete" ON admin_users FOR DELETE USING (
  auth.uid()::text IN (SELECT uid FROM admin_users WHERE role = 'superadmin')
);

ALTER PUBLICATION supabase_realtime ADD TABLE admin_users;

-- ============================================================
-- ADMIN ACTION LOGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_uid TEXT NOT NULL,
  admin_name TEXT DEFAULT '',
  action TEXT NOT NULL,
  target_type TEXT DEFAULT '',
  target_id TEXT DEFAULT '',
  details JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_action_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_action_logs_select" ON admin_action_logs FOR SELECT USING (true);
CREATE POLICY "admin_action_logs_insert" ON admin_action_logs FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_admin_logs_admin ON admin_action_logs(admin_uid);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created ON admin_action_logs(created_at DESC);

ALTER PUBLICATION supabase_realtime ADD TABLE admin_action_logs;

-- ============================================================
-- DASHBOARD BANS TABLE (ban users from dashboard)
-- ============================================================
CREATE TABLE IF NOT EXISTS dashboard_bans (
  uid TEXT PRIMARY KEY,
  email TEXT DEFAULT '',
  reason TEXT DEFAULT '',
  banned_by TEXT,
  banned_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE dashboard_bans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "dashboard_bans_select" ON dashboard_bans FOR SELECT USING (true);
CREATE POLICY "dashboard_bans_insert" ON dashboard_bans FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');
CREATE POLICY "dashboard_bans_delete" ON dashboard_bans FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

ALTER PUBLICATION supabase_realtime ADD TABLE dashboard_bans;

-- ============================================================
-- MIGRATION: Add missing total_gifts_sent to users table
-- Run this if your users table already exists (e.g. production DB):
-- ALTER TABLE users ADD COLUMN IF NOT EXISTS total_gifts_sent BIGINT DEFAULT 0;
-- After adding the column, backfill historical data:
-- UPDATE users u SET total_gifts_sent = COALESCE((
--   SELECT SUM(value * count) FROM sent_gifts WHERE sender_id = u.uid
-- ), 0);
-- UPDATE users u SET total_gifts_received = COALESCE((
--   SELECT SUM(value * count) FROM sent_gifts WHERE receiver_id = u.uid
-- ), 0);
-- ============================================================
