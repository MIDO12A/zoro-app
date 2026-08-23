import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// هل تم تهيئة Firebase (بديلاً عن Supabase)؟
bool isSupabaseReady() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (e) {
    debugPrint('[supabase_ready] error: $e');
    return false;
  }
}
