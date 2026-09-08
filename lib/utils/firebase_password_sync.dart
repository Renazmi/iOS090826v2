import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_sync_service.dart';

/// Keeps Firebase Auth passwords aligned with in-app change/reset on iOS and Android.
Future<void> _ensureFirebaseReady() async {
  if (!FirestoreSyncService.instance.isReady) {
    await FirestoreSyncService.instance.initialize();
  }
}

/// Signs in with [email]/[password] against Firebase Auth.
/// Returns true when Firebase accepts the credentials.
Future<bool> tryFirebasePasswordSignIn(String email, String password) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty || password.isEmpty) return false;

  try {
    await _ensureFirebaseReady();
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: normalized, password: password);
    await auth.signOut();
    return true;
  } on FirebaseAuthException {
    return false;
  } catch (_) {
    return false;
  }
}

/// Updates (or creates) the Firebase Auth password after a successful local change.
/// Failures are ignored so the in-app password still applies for login.
Future<void> syncFirebaseAccountPassword({
  required String email,
  required String currentPassword,
  required String newPassword,
}) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty || newPassword.isEmpty) return;

  try {
    await _ensureFirebaseReady();
    final auth = FirebaseAuth.instance;
    await auth.signOut();

    try {
      await auth.signInWithEmailAndPassword(
        email: normalized,
        password: currentPassword,
      );
      await auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      if (!_isMissingOrWrongCredential(error)) rethrow;
      try {
        await auth.createUserWithEmailAndPassword(
          email: normalized,
          password: newPassword,
        );
      } on FirebaseAuthException catch (createError) {
        if (createError.code != 'email-already-in-use') rethrow;
      }
    }
  } catch (_) {
    // Local password is already saved. Firebase can catch up via reset email.
  } finally {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}

bool _isMissingOrWrongCredential(FirebaseAuthException error) {
  return error.code == 'user-not-found' ||
      error.code == 'wrong-password' ||
      error.code == 'invalid-credential' ||
      error.code == 'invalid-login-credentials';
}
