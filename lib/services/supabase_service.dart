// Backward-compatible alias: the app has migrated from Supabase to Firebase.
// Every existing `SupabaseService()` call now resolves to the Firebase (Firestore)
// implementation. Screens may keep the old variable name; behavior is Firebase.
//
// TODO(migration): rename `SupabaseService` -> `FirebaseService` across lib/
// once all direct `Supabase.instance.client` usages are migrated.

export 'firebase_service.dart';
import 'firebase_service.dart';

typedef SupabaseService = FirebaseService;
