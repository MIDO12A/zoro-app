-- Drop the trigger that auto-creates minimal users rows on signup.
-- The Flutter app's SetupProfileScreen handles this properly with full data.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_auth_user;
