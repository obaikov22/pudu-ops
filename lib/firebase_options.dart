// Generated from google-services.json for project pudu-ops
// Re-run `flutterfire configure` to regenerate if Firebase settings change.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDoLnu1JkH6oboz85XslEwEdexXGCRXy5g',
    appId: '1:887177882880:android:ddaf77a39b4edc656717e5',
    messagingSenderId: '887177882880',
    projectId: 'pudu-ops',
    storageBucket: 'pudu-ops.firebasestorage.app',
  );
}
