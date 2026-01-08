// File generated manually from Firebase app configs for the dev project.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Dev [FirebaseOptions] for use with your Firebase apps.
///
/// This points at the Firebase project: `alluwal-dev`.
class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DevFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DevFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDS9nYN3GPN3p9adopyEC0oETjlmhEinGc',
    appId: '1:222814950724:web:734f42c0980c9c30f5b311',
    messagingSenderId: '222814950724',
    projectId: 'alluwal-dev',
    authDomain: 'alluwal-dev.firebaseapp.com',
    storageBucket: 'alluwal-dev.firebasestorage.app',
    measurementId: 'G-9T98VV4GPR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNsp4GeWXKxQWaG-VTTPRZaTExaHGPyR8',
    appId: '1:222814950724:android:7fa50d0e06d8f92ff5b311',
    messagingSenderId: '222814950724',
    projectId: 'alluwal-dev',
    storageBucket: 'alluwal-dev.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyByUERI5f0gwaF4WUdkKkBjtb99FElxNMk',
    appId: '1:222814950724:ios:571f462daa251fbbf5b311',
    messagingSenderId: '222814950724',
    projectId: 'alluwal-dev',
    storageBucket: 'alluwal-dev.firebasestorage.app',
    iosBundleId: 'com.example.alluwalacademyadmin',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyByUERI5f0gwaF4WUdkKkBjtb99FElxNMk',
    appId: '1:222814950724:ios:571f462daa251fbbf5b311',
    messagingSenderId: '222814950724',
    projectId: 'alluwal-dev',
    storageBucket: 'alluwal-dev.firebasestorage.app',
    iosBundleId: 'com.example.alluwalacademyadmin',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDS9nYN3GPN3p9adopyEC0oETjlmhEinGc',
    appId: '1:222814950724:web:3c09237ea7c80cf9f5b311',
    messagingSenderId: '222814950724',
    projectId: 'alluwal-dev',
    authDomain: 'alluwal-dev.firebaseapp.com',
    storageBucket: 'alluwal-dev.firebasestorage.app',
    measurementId: 'G-9S9TC527MW',
  );
}

