import 'package:firebase_core/firebase_core.dart';

/// Provide Firebase configuration for your project.
///
/// Replace the placeholder values with the credentials generated
/// from the Firebase console. If you use the native `google-services`
/// files on mobile, you can return `null` to rely on default options.
FirebaseOptions? get firebaseOptions => const FirebaseOptions(
      apiKey: "<YOUR_FIREBASE_API_KEY>",
      appId: "<YOUR_FIREBASE_APP_ID>",
      messagingSenderId: "<YOUR_FIREBASE_MESSAGING_SENDER_ID>",
      projectId: "<YOUR_FIREBASE_PROJECT_ID>",
      storageBucket: "<YOUR_FIREBASE_STORAGE_BUCKET>",
    );
