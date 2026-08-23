import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for project `zeroappzero-e1b4a`.
///
/// Values were taken from `android/app/google-services.json`.
/// If this project uses a different Firebase project, replace these values
/// with the Web config from Firebase Console:
///   Project settings -> Your apps -> Web app -> SDK setup and configuration
class FirebaseConfig {
  static const String projectId = 'zeroappzero-e1b4a';
  static const String apiKey = 'AIzaSyBV61UNM2iTTTZcBEALxvWxvi17EFD9XOU';
  static const String appId = '1:95008435096:android:70ef1c429c3d04683099ed';
  static const String messagingSenderId = '95008435096';
  static const String databaseURL = 'https://zeroappzero-e1b4a-default-rtdb.firebaseio.com';
  static const String storageBucket = 'zeroappzero-e1b4a.firebasestorage.app';
  static const String authDomain = 'zeroappzero-e1b4a.firebaseapp.com';

  static const FirebaseOptions options = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    databaseURL: databaseURL,
    storageBucket: storageBucket,
    authDomain: authDomain,
  );

  /// The project id of the Firebase project (used for Firestore/Storage rules).
  static String get project => projectId;
}
