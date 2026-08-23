import '../supabase_compat.dart';

abstract final class AuthService {
  static Session? get currentSession =>
      Supabase.instance.client.auth.currentSession;

  static UserCompat? get currentUser =>
      Supabase.instance.client.auth.currentUser;

  static String? get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;
}
