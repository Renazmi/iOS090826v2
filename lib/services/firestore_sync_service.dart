import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Bootstraps Firebase and exposes the shared Firestore instance.
class FirestoreSyncService {
  FirestoreSyncService._();

  static final FirestoreSyncService instance = FirestoreSyncService._();

  bool _initialized = false;

  bool get isReady => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app' && Firebase.apps.isEmpty) return;
    } catch (_) {
      if (Firebase.apps.isEmpty) return;
    }
    _initialized = true;
  }

  FirebaseFirestore get db => FirebaseFirestore.instance;
}
