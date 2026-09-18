import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import 'firestore_sync_service.dart';
import '../utils/firebase_action_link.dart';

const gmailAlreadyInUseMessage =
    'This Gmail is already in use. Please use a different Gmail.';

class StudentRegistrationVerificationService {
  Future<RegistrationSendResult> sendGmailVerification({
    required String email,
    required String password,
    bool Function(String email)? isGmailBoundToAccount,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      return RegistrationSendResult.fail('Gmail and password are required before verification.');
    }

    if (isGmailBoundToAccount?.call(normalized) == true) {
      return const RegistrationSendResult.fail(gmailAlreadyInUseMessage);
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      await auth.signOut();

      final user = await _createOrReuseAuthUser(
        email: normalized,
        password: password,
        isGmailBoundToAccount: isGmailBoundToAccount,
      );
      if (user == null) {
        return const RegistrationSendResult.fail('Could not prepare Gmail verification.');
      }

      if (isGmailBoundToAccount?.call(normalized) == true) {
        await auth.signOut();
        return const RegistrationSendResult.fail(gmailAlreadyInUseMessage);
      }

      await _rememberPendingPassword(normalized, password);
      if (user.emailVerified != true) {
        await _sendVerificationEmail(user);
      }
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
        'Open Gmail and confirm the verification email, then tap Continue.',
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
          'Gmail was already confirmed. Tap Continue to keep going.',
        );
      }
      return RegistrationVerifyResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RegistrationVerifyResult.fail(
        'Could not verify Gmail. Check your connection and try again.',
      );
    }
  }

  /// After the student confirms in Gmail (including Spam),
  /// check Firebase marked the address verified — same flow as web.
  Future<RegistrationVerifyResult> confirmGmailVerified({
    required String email,
    required String password,
    String? oobCode,
    bool Function(String email)? isGmailBoundToAccount,
  }) async {
    var result = await _confirmByAuthUser(
      email: email,
      password: password,
      isGmailBoundToAccount: isGmailBoundToAccount,
    );
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
      return _confirmByAuthUser(
        email: email,
        password: password,
        isGmailBoundToAccount: isGmailBoundToAccount,
      );
    }

    if (_isConsumedActionCodeMessage(linkResult.error)) {
      final retry = await _confirmByAuthUser(
        email: email,
        password: password,
        isGmailBoundToAccount: isGmailBoundToAccount,
      );
      if (retry.valid) {
        return retry;
      }
    }

    if (_isNotVerifiedMessage(result.error)) {
      return linkResult;
    }

    return result;
  }

  Future<RegistrationVerifyResult> _confirmByAuthUser({
    required String email,
    required String password,
    bool Function(String email)? isGmailBoundToAccount,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      return const RegistrationVerifyResult.fail('Gmail and password are required.');
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      final user = await _createOrReuseAuthUser(
        email: normalized,
        password: password,
        isGmailBoundToAccount: isGmailBoundToAccount,
      );
      if (user == null) {
        return const RegistrationVerifyResult.fail('Could not confirm Gmail verification.');
      }
      await user.reload();
      final verified = auth.currentUser?.emailVerified == true;
      await auth.signOut();
      if (!verified) {
        return const RegistrationVerifyResult.fail(
          'Gmail is not verified yet. Open Gmail (check Spam or Promotions), confirm the email from Google, then tap Continue.',
        );
      }
      return const RegistrationVerifyResult.ok();
    } on FirebaseAuthException catch (error) {
      return RegistrationVerifyResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RegistrationVerifyResult.fail(
        'Could not confirm Gmail verification. Check your connection and try again.',
      );
    }
  }

  Future<User?> _createOrReuseAuthUser({
    required String email,
    required String password,
    bool Function(String email)? isGmailBoundToAccount,
  }) async {
    final auth = FirebaseAuth.instance;
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') {
        rethrow;
      }
    }

    if (isGmailBoundToAccount?.call(email) == true) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }

    if (await _signInWithKnownPassword(email, password)) {
      final current = auth.currentUser;
      if (current != null) {
        try {
          await current.updatePassword(password);
        } catch (_) {}
      }
      return auth.currentUser;
    }

    final released = await _releaseIncompleteAuthUser(email);
    if (!released) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message:
            'Could not continue with this Gmail. Use the same password from your first attempt, then tap Verify Gmail again.',
      );
    }

    final recreated = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return recreated.user;
  }

  Future<bool> _releaseIncompleteAuthUser(String email) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.postUrl(
        Uri.parse(
          'https://us-central1-trackit-fac8a.cloudfunctions.net/releaseIncompleteRegistrationEmail',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'data': {'email': email}})));
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      if (body.contains('ALREADY_EXISTS') || body.contains('already in use')) {
        throw FirebaseAuthException(code: 'email-already-in-use');
      }
      return false;
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _signInWithKnownPassword(String email, String password) async {
    final auth = FirebaseAuth.instance;
    final pending = await _readPendingPassword(email);
    final candidates = <String>{password, if (pending != null && pending.isNotEmpty) pending};
    for (final candidate in candidates) {
      try {
        await auth.signInWithEmailAndPassword(email: email, password: candidate);
        return true;
      } on FirebaseAuthException {
        await auth.signOut();
      }
    }
    return false;
  }

  Future<void> _rememberPendingPassword(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.pendingGmailRegistration,
      '$email\u0001$password',
    );
  }

  Future<String?> _readPendingPassword(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.pendingGmailRegistration);
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('\u0001');
    if (parts.length != 2) return null;
    if (parts[0].toLowerCase() != email) return null;
    return parts[1];
  }

  Future<void> _sendVerificationEmail(User user) async {
    try {
      await user.sendEmailVerification(
        ActionCodeSettings(
          url: 'https://$trackitFirebaseAuthDomain/',
          handleCodeInApp: false,
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (error.code != 'unauthorized-continue-uri') {
        rethrow;
      }
      await user.sendEmailVerification();
    }
  }

  Future<void> _ensureFirebaseReady() async {
    if (!FirestoreSyncService.instance.isReady) {
      await FirestoreSyncService.instance.initialize();
    }
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
        return gmailAlreadyInUseMessage;
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Could not continue with this Gmail. Use the same password from your first attempt, then tap Verify Gmail again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'user-disabled':
        return 'This Gmail account is disabled. Contact support or use another Gmail.';
      case 'expired-action-code':
        return 'This verification has expired. Request a new verification email.';
      case 'invalid-action-code':
        return 'Open Gmail and confirm the verification email, then tap Continue.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'unauthorized-continue-uri':
        return 'Gmail verification is blocked because this app domain is not allowlisted in Firebase Authentication.';
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
