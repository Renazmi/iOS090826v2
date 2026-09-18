import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_sync_service.dart';

/// Keeps Firebase Auth passwords aligned with in-app change/reset on iOS and Android.
Future<void> _ensureFirebaseReady() async {
  if (!FirestoreSyncService.instance.isReady) {
    await FirestoreSyncService.instance.initialize();
  }
}

enum FirebasePasswordProbe { accepted, rejected, noUser, unavailable, unknown }

bool isStaleStoredPassword(FirebasePasswordProbe probe, bool authLinked) {
  return probe == FirebasePasswordProbe.rejected ||
      (probe == FirebasePasswordProbe.unknown && authLinked);
}

/// Checks this email/password against Firebase Auth.
Future<FirebasePasswordProbe> probeFirebasePasswordSignIn(
  String email,
  String password,
) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty || password.isEmpty) {
    return FirebasePasswordProbe.unavailable;
  }

  try {
    await _ensureFirebaseReady();
    if (!FirestoreSyncService.instance.isReady) {
      return FirebasePasswordProbe.unavailable;
    }
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: normalized, password: password);
    await auth.signOut();
    return FirebasePasswordProbe.accepted;
  } on FirebaseAuthException catch (error) {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (error.code == 'user-not-found') return FirebasePasswordProbe.noUser;
    if (error.code == 'wrong-password' || error.code == 'user-disabled') {
      return FirebasePasswordProbe.rejected;
    }
    if (error.code == 'invalid-credential' || error.code == 'invalid-login-credentials') {
      return FirebasePasswordProbe.unknown;
    }
    return FirebasePasswordProbe.unavailable;
  } catch (_) {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    return FirebasePasswordProbe.unavailable;
  }
}

/// Signs in with [email]/[password] against Firebase Auth.
/// Returns true when Firebase accepts the credentials.
Future<bool> tryFirebasePasswordSignIn(String email, String password) async {
  return (await probeFirebasePasswordSignIn(email, password)) ==
      FirebasePasswordProbe.accepted;
}

enum FirebasePasswordBind { inSync, bound, conflict, unavailable }

/// Used only after the stored TrackIT password already matched.
Future<FirebasePasswordBind> bindFirebasePasswordOrDetectConflict(
  String email,
  String password,
) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty || password.isEmpty) {
    return FirebasePasswordBind.unavailable;
  }

  try {
    await _ensureFirebaseReady();
    if (!FirestoreSyncService.instance.isReady) {
      return FirebasePasswordBind.unavailable;
    }
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    try {
      await auth.signInWithEmailAndPassword(email: normalized, password: password);
      return FirebasePasswordBind.inSync;
    } on FirebaseAuthException catch (error) {
      if (!_isMissingOrWrongCredential(error)) return FirebasePasswordBind.unavailable;
      try {
        await auth.createUserWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        return FirebasePasswordBind.bound;
      } on FirebaseAuthException catch (createError) {
        if (createError.code == 'email-already-in-use') {
          return FirebasePasswordBind.conflict;
        }
        return FirebasePasswordBind.unavailable;
      }
    }
  } catch (_) {
    return FirebasePasswordBind.unavailable;
  } finally {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}

class StoredPasswordAuthResolution {
  const StoredPasswordAuthResolution({
    required this.allow,
    required this.markLinked,
  });

  final bool allow;
  final bool markLinked;
}

Future<StoredPasswordAuthResolution> resolveStoredPasswordAfterAuthProbe({
  required String email,
  required String password,
  required FirebasePasswordProbe probe,
  required bool authLinked,
}) async {
  if (isStaleStoredPassword(probe, authLinked)) {
    return const StoredPasswordAuthResolution(allow: false, markLinked: false);
  }
  if (probe == FirebasePasswordProbe.unknown && !authLinked) {
    final bind = await bindFirebasePasswordOrDetectConflict(email, password);
    if (bind == FirebasePasswordBind.conflict) {
      return const StoredPasswordAuthResolution(allow: false, markLinked: false);
    }
    if (bind == FirebasePasswordBind.bound || bind == FirebasePasswordBind.inSync) {
      return const StoredPasswordAuthResolution(allow: true, markLinked: true);
    }
    return const StoredPasswordAuthResolution(allow: true, markLinked: false);
  }
  return const StoredPasswordAuthResolution(allow: true, markLinked: false);
}

/// Updates (or creates) the Firebase Auth password after a successful local change.
/// Returns false when Firebase is configured but the password could not be saved.
Future<bool> syncFirebaseAccountPassword({
  required String email,
  required String currentPassword,
  required String newPassword,
}) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty || newPassword.isEmpty) return true;

  try {
    await _ensureFirebaseReady();
    if (!FirestoreSyncService.instance.isReady) return true;
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
        return false;
      }
    }
    return true;
  } catch (_) {
    return false;
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
