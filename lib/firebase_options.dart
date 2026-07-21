import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
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
    apiKey: 'AIzaSyArGPqb3TQLgeVANPnGpMmRwVZUAq1lZSg',
    appId: '1:655621157294:android:fcea2fc9a29c16db9d583f',
    messagingSenderId: '655621157294',
    projectId: 'whatsapp-clone-976d4',
    storageBucket: 'whatsapp-clone-976d4.firebasestorage.app',
  );
}
