import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_sync_service.dart';
import '../utils/firebase_action_link.dart';

class StudentRegistrationVerificationService {
  Future<RegistrationSendResult> sendGmailVerification({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      return RegistrationSendResult.fail('Gmail and password are required before verification.');
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      await auth.signOut();

      User? user;
      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        user = credential.user;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') {
          return RegistrationSendResult.fail(_mapAuthError(error));
        }

        try {
          final existing = await auth.signInWithEmailAndPassword(
            email: normalized,
            password: password,
          );
          user = existing.user;
          if (user?.emailVerified == true) {
            await auth.signOut();
            return const RegistrationSendResult.ok();
          }
        } on FirebaseAuthException catch (signInError) {
          return RegistrationSendResult.fail(
            _mapExistingAccountSignInError(signInError),
          );
        }
      }

      if (user == null) {
        return const RegistrationSendResult.fail('Could not prepare Gmail verification.');
      }

      await user.sendEmailVerification(trackitFirebaseActionCodeSettings());
      await auth.signOut();
      return const RegistrationSendResult.ok();
    } on FirebaseAuthException catch (error) {
      return RegistrationSendResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RegistrationSendResult.fail(
        'Could not send verification email. Check your connection and try again.',
      );
    }
  }

  Future<RegistrationVerifyResult> verifyGmailLink({
    required String code,
    required String expectedEmail,
  }) async {
    final oobCode = parseFirebaseOobCode(code);
    final email = expectedEmail.trim().toLowerCase();
    if (oobCode == null) {
      return const RegistrationVerifyResult.fail(
        'Enter the verification code from your Gmail email, or paste the full verification link.',
      );
    }
    if (email.isEmpty) {
      return const RegistrationVerifyResult.fail('Enter your Gmail address.');
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      final info = await auth.checkActionCode(oobCode);
      final verifiedEmail = '${info.data['email'] ?? ''}'.trim().toLowerCase();
      if (verifiedEmail.isEmpty || verifiedEmail != email) {
        return const RegistrationVerifyResult.fail(
          'This verification code does not match the Gmail address you entered.',
        );
      }
      await auth.applyActionCode(oobCode);
      await auth.signOut();
      return const RegistrationVerifyResult.ok();
    } on FirebaseAuthException catch (error) {
      if (_isConsumedActionCode(error)) {
        return const RegistrationVerifyResult.fail(
          'This verification link was already used. If you tapped Verify in Gmail, tap "I verified in Gmail" again.',
        );
      }
      return RegistrationVerifyResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RegistrationVerifyResult.fail(
        'Could not verify Gmail. Check your connection and try again.',
      );
    }
  }

  /// After the user taps the link in Gmail, confirm verification without pasting the code.
  Future<RegistrationVerifyResult> verifyGmailBySignIn({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      return const RegistrationVerifyResult.fail('Gmail and password are required.');
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      final credential = await auth.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      await credential.user?.reload();
      final user = auth.currentUser;
      if (user?.emailVerified != true) {
        await auth.signOut();
        return const RegistrationVerifyResult.fail(
          'Gmail is not verified yet. Open the email from Google, tap Verify, then try again.',
        );
      }
      await auth.signOut();
      return const RegistrationVerifyResult.ok();
    } on FirebaseAuthException catch (error) {
      return RegistrationVerifyResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RegistrationVerifyResult.fail(
        'Could not confirm Gmail verification. Check your connection and try again.',
      );
    }
  }

  /// Confirm Gmail verification after the user returns from their inbox.
  ///
  /// Sign-in is tried first because the verification link is often already
  /// consumed when Gmail or the app opens it. A pending link code is only used
  /// when sign-in reports the address is still unverified.
  Future<RegistrationVerifyResult> confirmGmailVerified({
    required String email,
    required String password,
    String? oobCode,
  }) async {
    var result = await verifyGmailBySignIn(email: email, password: password);
    if (result.valid) {
      return result;
    }

    final pendingCode = oobCode?.trim();
    if (pendingCode == null || pendingCode.isEmpty) {
      return result;
    }

    final linkResult = await verifyGmailLink(
      code: pendingCode,
      expectedEmail: email,
    );
    if (linkResult.valid) {
      return verifyGmailBySignIn(email: email, password: password);
    }

    if (_isConsumedActionCodeMessage(linkResult.error)) {
      final retry = await verifyGmailBySignIn(email: email, password: password);
      if (retry.valid) {
        return retry;
      }
    }

    if (_isNotVerifiedMessage(result.error)) {
      return linkResult;
    }

    return result;
  }

  Future<void> _ensureFirebaseReady() async {
    if (!FirestoreSyncService.instance.isReady) {
      await FirestoreSyncService.instance.initialize();
    }
  }

  String _mapExistingAccountSignInError(FirebaseAuthException error) {
    if (_isCredentialError(error)) {
      return 'This Gmail was already used in a previous sign-up attempt with a different password. '
          'Use the same password as before, or reset it from the login screen, then try again.';
    }
    return _mapAuthError(error);
  }

  bool _isCredentialError(FirebaseAuthException error) {
    return error.code == 'wrong-password' ||
        error.code == 'invalid-credential' ||
        error.code == 'invalid-login-credentials';
  }

  bool _isConsumedActionCode(FirebaseAuthException error) {
    return error.code == 'invalid-action-code' ||
        error.code == 'invalid-credential' ||
        error.code == 'expired-action-code';
  }

  bool _isConsumedActionCodeMessage(String? message) {
    final text = message?.toLowerCase() ?? '';
    return text.contains('already used') ||
        text.contains('invalid verification link') ||
        text.contains('expired');
  }

  bool _isNotVerifiedMessage(String? message) {
    return message?.toLowerCase().contains('not verified yet') ?? false;
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid Gmail address.';
      case 'email-already-in-use':
        return 'This Gmail is already registered. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Could not verify this Gmail with the password you entered. '
            'If you tried registering before, use the same password or reset it from the login screen.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'user-disabled':
        return 'This Gmail account is disabled. Contact support or use another Gmail.';
      case 'expired-action-code':
        return 'This verification link has expired. Request a new verification email.';
      case 'invalid-action-code':
        return 'This verification link was already used or is invalid. Request a new verification email.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Something went wrong. Try again.';
    }
  }
}

class RegistrationSendResult {
  const RegistrationSendResult._({required this.success, this.error});

  const RegistrationSendResult.ok() : this._(success: true);
  const RegistrationSendResult.fail(String message) : this._(success: false, error: message);

  final bool success;
  final String? error;
}

class RegistrationVerifyResult {
  const RegistrationVerifyResult._({required this.valid, this.error});

  const RegistrationVerifyResult.ok() : this._(valid: true);
  const RegistrationVerifyResult.fail(String message) : this._(valid: false, error: message);

  final bool valid;
  final String? error;
}
