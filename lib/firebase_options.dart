import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for TrackIT mobile (`trackit-fac8a`).
///
/// Run `flutterfire configure` from the `mobile/` folder to regenerate this file
/// with your Android/iOS app IDs and `google-services.json`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('TrackIT mobile Firebase is not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAwYG70UkKIEEvoE8GE0lhwkOY9Eu2K0aE',
    appId: '1:323396504255:web:e2e21c0c9dbea56100140a',
    messagingSenderId: '323396504255',
    projectId: 'trackit-fac8a',
    authDomain: 'trackit-fac8a.firebaseapp.com',
    storageBucket: 'trackit-fac8a.firebasestorage.app',
    measurementId: 'G-00BXJVXE0C',
  );

  /// Replace `appId` after registering the Android app in Firebase Console
  /// or by running `flutterfire configure`.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBGEj3KS_EqN2QWh3uZFGYUCWtMZpNG1cY',
    appId: '1:323396504255:android:4c383b8acb515faa00140a',
    messagingSenderId: '323396504255',
    projectId: 'trackit-fac8a',
    storageBucket: 'trackit-fac8a.firebasestorage.app',
  );
  /// Replace `appId` after registering the iOS app in Firebase Console
  /// or by running `flutterfire configure`.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCX8IOzWtRJEy2o2US8PIU_FolRf44Mjgk',
    appId: '1:323396504255:ios:ce93746759c5a61600140a',
    messagingSenderId: '323396504255',
    projectId: 'trackit-fac8a',
    storageBucket: 'trackit-fac8a.firebasestorage.app',
    iosBundleId: 'com.trackit.trackitMobile',
  );
}
