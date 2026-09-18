import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../utils/firebase_action_link.dart';
import '../utils/password_hash.dart';
import '../utils/password_reset_link.dart';
import '../utils/settings_validation.dart';
import 'firestore_sync_service.dart';
import 'officer_auth_service.dart';
import 'sections_service.dart';
import 'storage_service.dart';
import 'student_auth_service.dart';

enum _AuthUserState { created, existing }

enum RecoveryAccountKind { student, officer, admin, coAdmin }

class RecoveryStudentIdLookup {
  const RecoveryStudentIdLookup._({
    required this.success,
    this.hasRecoveryContact = false,
    this.studentId,
    this.studentName,
    this.maskedGmail,
    this.recoveryEmail,
    this.error,
  });

  const RecoveryStudentIdLookup.fail(String message)
      : this._(success: false, error: message);

  const RecoveryStudentIdLookup.noRecoveryContact({
    required String studentName,
    required String error,
    String? studentId,
  }) : this._(
          success: true,
          hasRecoveryContact: false,
          studentId: studentId,
          studentName: studentName,
          error: error,
        );

  const RecoveryStudentIdLookup.ok({
    required String studentId,
    required String studentName,
    required String maskedGmail,
    required String recoveryEmail,
  }) : this._(
          success: true,
          hasRecoveryContact: true,
          studentId: studentId,
          studentName: studentName,
          maskedGmail: maskedGmail,
          recoveryEmail: recoveryEmail,
        );

  final bool success;
  final bool hasRecoveryContact;
  final String? studentId;
  final String? studentName;
  final String? maskedGmail;
  final String? recoveryEmail;
  final String? error;
}

class RecoveryAccountLookup {
  const RecoveryAccountLookup._({
    required this.success,
    this.kind,
    this.email,
    this.displayName,
    this.maskedEmail,
    this.studentId,
    this.officerId,
    this.error,
  });

  const RecoveryAccountLookup.fail(String message)
      : this._(success: false, error: message);

  const RecoveryAccountLookup.ok({
    required RecoveryAccountKind kind,
    required String email,
    required String displayName,
    required String maskedEmail,
    String? studentId,
    int? officerId,
  }) : this._(
          success: true,
          kind: kind,
          email: email,
          displayName: displayName,
          maskedEmail: maskedEmail,
          studentId: studentId,
          officerId: officerId,
        );

  final bool success;
  final RecoveryAccountKind? kind;
  final String? email;
  final String? displayName;
  final String? maskedEmail;
  final String? studentId;
  final int? officerId;
  final String? error;
}

class RecoveryCodeResult {
  const RecoveryCodeResult._({required this.success, this.maskedEmail, this.error});

  const RecoveryCodeResult.ok(String maskedEmail)
      : this._(success: true, maskedEmail: maskedEmail);

  const RecoveryCodeResult.fail(String message) : this._(success: false, error: message);

  final bool success;
  final String? maskedEmail;
  final String? error;
}

class RecoveryVerifyResult {
  const RecoveryVerifyResult._({required this.valid, this.error});

  const RecoveryVerifyResult.ok() : this._(valid: true);
  const RecoveryVerifyResult.fail(String message) : this._(valid: false, error: message);

  final bool valid;
  final String? error;
}

class RecoveryResetResult {
  const RecoveryResetResult._({required this.success, this.loginId, this.error});

  const RecoveryResetResult.ok(String loginId) : this._(success: true, loginId: loginId);
  const RecoveryResetResult.fail(String message) : this._(success: false, error: message);

  final bool success;
  final String? loginId;
  final String? error;
}

class RecoveryLinkResolveResult {
  const RecoveryLinkResolveResult._({
    required this.success,
    this.kind,
    this.email,
    this.displayName,
    this.maskedEmail,
    this.studentId,
    this.error,
  });

  const RecoveryLinkResolveResult.fail(String message)
      : this._(success: false, error: message);

  const RecoveryLinkResolveResult.ok({
    required RecoveryAccountKind kind,
    required String email,
    required String displayName,
    required String maskedEmail,
    String? studentId,
  }) : this._(
          success: true,
          kind: kind,
          email: email,
          displayName: displayName,
          maskedEmail: maskedEmail,
          studentId: studentId,
        );

  final bool success;
  final RecoveryAccountKind? kind;
  final String? email;
  final String? displayName;
  final String? maskedEmail;
  final String? studentId;
  final String? error;
}

/// Unified Gmail recovery for students, officers, and admins — uses Firebase Auth reset emails (Spark plan).
class AccountRecoveryService {
  AccountRecoveryService(
    this._storage,
    this._studentAuth,
    this._officerAuth,
    this._sections,
  );

  static const defaultAdminEmail = 'renazmi29@gmail.com';
  static const _minPasswordLength = 8;

  final StorageService _storage;
  final StudentAuthService _studentAuth;
  final OfficerAuthService _officerAuth;
  final SectionsService _sections;

  String? _recoveryOobCode;
  String? _recoveryEmail;

  Future<RecoveryAccountLookup> lookupAccount(String identifier) async {
    final raw = identifier.trim();
    if (raw.isEmpty) {
      return const RecoveryAccountLookup.fail(
        'Enter the Gmail address associated with your account.',
      );
    }

    if (!SettingsValidation.isValidEmailFormat(raw)) {
      return const RecoveryAccountLookup.fail('Enter a valid Gmail address.');
    }

    final email = raw.toLowerCase();
    await _pullAdminCredentialsFromServer();
    await _studentAuth.refreshStudentFromServer(email);
    await _officerAuth.refreshOfficerFromServer(email);
    return lookupAccountByGmail(email);
  }

  RecoveryAccountLookup lookupAccountByGmail(String gmail) {
    final email = gmail.trim().toLowerCase();
    if (email.isEmpty) {
      return const RecoveryAccountLookup.fail('Enter your Gmail address.');
    }
    if (!SettingsValidation.isValidEmailFormat(email)) {
      return const RecoveryAccountLookup.fail('Enter a valid Gmail address.');
    }

    final mainAdminEmail = _getMainAdminEmail();
    if (mainAdminEmail == email) {
      return RecoveryAccountLookup.ok(
        kind: RecoveryAccountKind.admin,
        email: email,
        displayName: _storage.readString(StorageKeys.adminDisplayName) ?? 'Administrator',
        maskedEmail: _maskEmail(email),
      );
    }

    final coAdmin = _findCoAdmin(email);
    if (coAdmin != null) {
      return RecoveryAccountLookup.ok(
        kind: RecoveryAccountKind.coAdmin,
        email: email,
        displayName: '${coAdmin['displayName'] ?? 'Co-Admin'}',
        maskedEmail: _maskEmail(email),
      );
    }

    final officer = _officerAuth.findOfficerByEmail(email);
    if (officer != null) {
      return RecoveryAccountLookup.ok(
        kind: RecoveryAccountKind.officer,
        email: officer.email.toLowerCase(),
        displayName: officer.name,
        officerId: officer.id,
        maskedEmail: _maskEmail(officer.email),
      );
    }

    final student = _studentAuth.findStudentByGmail(email);
    if (student != null) {
      if (!_studentAuth.isStudentActive(student.studentId)) {
        return const RecoveryAccountLookup.fail(studentDeactivatedLoginMessage);
      }
      if (student.gmail.trim().isEmpty) {
        return const RecoveryAccountLookup.fail(
          'This account has no Gmail on file. Please contact your administrator to reset your password.',
        );
      }
      return RecoveryAccountLookup.ok(
        kind: RecoveryAccountKind.student,
        email: student.gmail.toLowerCase(),
        displayName: student.fullName,
        studentId: student.studentId,
        maskedEmail: _maskEmail(student.gmail),
      );
    }

    return const RecoveryAccountLookup.fail('No TrackIT account found for this Gmail address.');
  }

  RecoveryStudentIdLookup lookupStudentByIdForRecovery(String studentId) {
    final id = _studentAuth.normalizeStudentId(studentId);
    if (id.isEmpty) {
      return const RecoveryStudentIdLookup.fail('Enter your Student ID.');
    }
    if (!RegExp(r'^\d{4,12}$').hasMatch(id)) {
      return const RecoveryStudentIdLookup.fail(
        'Student ID must contain numbers only.',
      );
    }

    final enrolled = _sections.findStudentById(id);
    if (enrolled == null) {
      return const RecoveryStudentIdLookup.fail('Student ID not found in the system.');
    }

    if (!_studentAuth.hasRegisteredAccount(id)) {
      return const RecoveryStudentIdLookup.fail(
        'No TrackIT account found for this Student ID.',
      );
    }

    if (!_studentAuth.isStudentActive(id)) {
      return const RecoveryStudentIdLookup.fail(studentDeactivatedLoginMessage);
    }

    final lookup = _studentAuth.lookupStudentForPasswordReset(id);
    if (!lookup.success) {
      return RecoveryStudentIdLookup.fail(
        lookup.error ?? 'No TrackIT account found for this Student ID.',
      );
    }

    if (!lookup.hasRecoveryContact) {
      return RecoveryStudentIdLookup.noRecoveryContact(
        studentId: id,
        studentName: lookup.studentName ?? enrolled.name,
        error: lookup.error ??
            'This account has no Gmail on file. Please contact your administrator to reset your password.',
      );
    }

    final student = _studentAuth.getStudentById(id);
    final recoveryEmail = student?.gmail.trim().toLowerCase() ?? '';
    if (recoveryEmail.isEmpty) {
      return RecoveryStudentIdLookup.noRecoveryContact(
        studentId: id,
        studentName: lookup.studentName ?? enrolled.name,
        error:
            'This account has no Gmail on file. Please contact your administrator to reset your password.',
      );
    }

    return RecoveryStudentIdLookup.ok(
      studentId: id,
      studentName: lookup.studentName ?? enrolled.name,
      maskedGmail: lookup.maskedGmail ?? _maskEmail(recoveryEmail),
      recoveryEmail: recoveryEmail,
    );
  }

  Future<RecoveryCodeResult> sendRecoveryCodeForStudentId(String studentId) async {
    await _studentAuth.refreshStudentFromServer(studentId);
    final lookup = lookupStudentByIdForRecovery(studentId);
    if (!lookup.success) {
      return RecoveryCodeResult.fail(lookup.error ?? 'Could not find your account.');
    }
    if (!lookup.hasRecoveryContact || lookup.recoveryEmail == null) {
      return RecoveryCodeResult.fail(
        lookup.error ??
            'This account has no Gmail on file. Please contact your administrator to reset your password.',
      );
    }

    return sendRecoveryCode(lookup.recoveryEmail!);
  }

  Future<RecoveryCodeResult> sendRecoveryCode(String identifier) async {
    final lookup = await lookupAccount(identifier);
    if (!lookup.success || lookup.email == null) {
      return RecoveryCodeResult.fail(lookup.error ?? 'Could not find your account.');
    }

    _clearRecoverySession();

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      final authState = await _ensureAuthUser(auth, lookup.email!);
      await auth.sendPasswordResetEmail(
        email: lookup.email!,
        actionCodeSettings: trackitFirebasePasswordResetSettings(),
      );
      if (authState == _AuthUserState.existing) {
        await _markLookupAuthLinked(lookup);
      }
    } on FirebaseAuthException catch (error) {
      return RecoveryCodeResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RecoveryCodeResult.fail(
        'Could not send reset email. Check your connection and try again.',
      );
    }

    _recoveryEmail = lookup.email;
    return RecoveryCodeResult.ok(lookup.maskedEmail ?? _maskEmail(lookup.email!));
  }

  Future<RecoveryLinkResolveResult> resolveRecoveryFromLink(String code) async {
    final oobCode = parsePasswordResetCode(code);
    if (oobCode == null) {
      return const RecoveryLinkResolveResult.fail(
        'Paste the reset link from your Gmail, or copy the code from that link.',
      );
    }

    try {
      await _ensureFirebaseReady();
      final resetEmail =
          (await FirebaseAuth.instance.verifyPasswordResetCode(oobCode)).trim().toLowerCase();
      _recoveryOobCode = oobCode;
      _recoveryEmail = resetEmail;

      final lookup = await lookupAccount(resetEmail);
      if (!lookup.success || lookup.kind == null || lookup.email == null) {
        return RecoveryLinkResolveResult.fail(
          lookup.error ?? 'No TrackIT account found for this reset link.',
        );
      }

      return RecoveryLinkResolveResult.ok(
        kind: lookup.kind!,
        email: lookup.email!,
        displayName: lookup.displayName ?? '',
        maskedEmail: lookup.maskedEmail ?? _maskEmail(lookup.email!),
        studentId: lookup.studentId,
      );
    } on FirebaseAuthException catch (error) {
      return RecoveryLinkResolveResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RecoveryLinkResolveResult.fail(
        'Could not verify reset link. Check your connection and try again.',
      );
    }
  }

  Future<RecoveryVerifyResult> verifyRecoveryCode(String gmail, String code) async {
    final email = gmail.trim().toLowerCase();
    if (email.isEmpty) {
      return const RecoveryVerifyResult.fail('Enter your Gmail address.');
    }

    final oobCode = parsePasswordResetCode(code);
    if (oobCode == null) {
      return const RecoveryVerifyResult.fail(
        'Paste the reset link from your Gmail, or copy the code from that link.',
      );
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      final resetEmail = (await auth.verifyPasswordResetCode(oobCode)).trim().toLowerCase();
      if (resetEmail != email) {
        return const RecoveryVerifyResult.fail(
          'This reset link does not match the Gmail address you entered.',
        );
      }
      _recoveryOobCode = oobCode;
      _recoveryEmail = resetEmail;
      return const RecoveryVerifyResult.ok();
    } on FirebaseAuthException catch (error) {
      return RecoveryVerifyResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RecoveryVerifyResult.fail(
        'Could not verify reset link. Check your connection and try again.',
      );
    }
  }

  Future<RecoveryResetResult> resetPassword(
    String gmail,
    String code,
    String newPassword,
    String confirmPassword,
  ) async {
    final lookup = await lookupAccount(gmail);
    if (!lookup.success || lookup.kind == null || lookup.email == null) {
      return RecoveryResetResult.fail(lookup.error ?? 'Account not found.');
    }

    final email = lookup.email!;
    final oobReady = _recoveryOobCode != null && (_recoveryEmail == null || _recoveryEmail == email);

    if (!oobReady) {
      final verification = await verifyRecoveryCode(gmail, code);
      if (!verification.valid) {
        return RecoveryResetResult.fail(verification.error ?? 'Verification failed.');
      }
    }

    if (_recoveryOobCode == null) {
      return const RecoveryResetResult.fail(
        'This reset link has expired. Request a new reset email and try again.',
      );
    }

    if (newPassword.length < _minPasswordLength) {
      return RecoveryResetResult.fail(
        'Password must be at least $_minPasswordLength characters.',
      );
    }

    if (newPassword != confirmPassword) {
      return const RecoveryResetResult.fail('Passwords do not match.');
    }

    final persist = await _persistRecoveredPassword(lookup, newPassword);
    if (!persist.success) {
      return persist;
    }

    try {
      await _ensureFirebaseReady();
      await FirebaseAuth.instance.confirmPasswordReset(
        code: _recoveryOobCode!,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (error) {
      if (persist.loginId == null) {
        return RecoveryResetResult.fail(_mapAuthError(error));
      }
    } catch (_) {
      if (persist.loginId == null) {
        return const RecoveryResetResult.fail(
          'Could not reset password. Check your connection and try again.',
        );
      }
    } finally {
      _clearRecoverySession();
    }

    return persist;
  }

  Future<RecoveryResetResult> _persistRecoveredPassword(
    RecoveryAccountLookup lookup,
    String newPassword,
  ) async {
    switch (lookup.kind!) {
      case RecoveryAccountKind.student:
        if (lookup.studentId == null) {
          return const RecoveryResetResult.fail('Student account not found.');
        }
        final result = await _studentAuth.updateStudentAccount(
          lookup.studentId!,
          password: newPassword,
        );
        if (!result.success) {
          return RecoveryResetResult.fail(result.error ?? 'Could not reset your password.');
        }
        if (result.warning != null && result.warning!.isNotEmpty) {
          return RecoveryResetResult.fail(result.warning!);
        }
        await _studentAuth.refreshStudentFromServer(lookup.studentId!);
        await _studentAuth.markStudentFirebaseAuthLinked(lookup.studentId!);
        return RecoveryResetResult.ok(lookup.studentId!);

      case RecoveryAccountKind.officer:
        if (lookup.officerId == null) {
          return const RecoveryResetResult.fail('Officer account not found.');
        }
        await _officerAuth.resetOfficerPasswordFromRecovery(lookup.officerId!, newPassword);
        await _officerAuth.markOfficerFirebaseAuthLinked(lookup.officerId!);
        return RecoveryResetResult.ok(lookup.email!);

      case RecoveryAccountKind.admin:
        final saved = await _persistMainAdminPassword(newPassword);
        if (!saved) {
          return const RecoveryResetResult.fail(
            'Could not save to the account server. Check your connection and try again.',
          );
        }
        await _markAdminFirebaseAuthLinked();
        return RecoveryResetResult.ok(lookup.email!);

      case RecoveryAccountKind.coAdmin:
        final saved = await _updateCoAdminPassword(lookup.email!, newPassword, linked: true);
        if (!saved) {
          return const RecoveryResetResult.fail('Could not reset your password.');
        }
        return RecoveryResetResult.ok(lookup.email!);
    }
  }

  Future<void> _ensureFirebaseReady() async {
    if (!FirestoreSyncService.instance.isReady) {
      await FirestoreSyncService.instance.initialize();
    }
  }

  Future<_AuthUserState> _ensureAuthUser(FirebaseAuth auth, String email) async {
    final random = Random.secure();
    final buffer = List.generate(16, (_) => random.nextInt(256));
    final tempPassword = '${base64UrlEncode(buffer)}Aa1!';

    try {
      await auth.createUserWithEmailAndPassword(email: email, password: tempPassword);
      await auth.signOut();
      return _AuthUserState.created;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') {
        rethrow;
      }
      return _AuthUserState.existing;
    }
  }

  Future<void> _markLookupAuthLinked(RecoveryAccountLookup lookup) async {
    switch (lookup.kind) {
      case RecoveryAccountKind.student:
        if (lookup.studentId != null) {
          await _studentAuth.markStudentFirebaseAuthLinked(lookup.studentId!);
        }
        break;
      case RecoveryAccountKind.officer:
        if (lookup.officerId != null) {
          await _officerAuth.markOfficerFirebaseAuthLinked(lookup.officerId!);
        }
        break;
      case RecoveryAccountKind.admin:
        await _markAdminFirebaseAuthLinked();
        break;
      case RecoveryAccountKind.coAdmin:
        if (lookup.email != null) {
          await _updateCoAdminPassword(lookup.email!, null, linked: true);
        }
        break;
      case null:
        break;
    }
  }

  void _clearRecoverySession() {
    _recoveryOobCode = null;
    _recoveryEmail = null;
  }

  String _mapAuthError(FirebaseAuthException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid Gmail address.';
      case 'user-not-found':
        return 'No account found for this Gmail address.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'expired-action-code':
        return 'This reset link has expired. Request a new reset email.';
      case 'invalid-action-code':
        return 'Invalid reset link or code. Request a new reset email and try again.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase. Enable it under Authentication → Sign-in method.';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  String _getMainAdminEmail() {
    final stored = _storage.readString(StorageKeys.adminUsername)?.trim();
    if (stored != null && stored.isNotEmpty) {
      if (stored.toLowerCase() == 'renazmi29') {
        return defaultAdminEmail;
      }
      return stored.toLowerCase();
    }
    return defaultAdminEmail;
  }

  Future<void> _pullAdminCredentialsFromServer() async {
    try {
      await _ensureFirebaseReady();
      if (!FirestoreSyncService.instance.isReady) return;
      final snap = await FirestoreSyncService.instance.db
          .collection(FirestoreCollections.adminAccounts)
          .doc('credentials')
          .get(const GetOptions(source: Source.server));
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final username = '${data['username'] ?? data['loginEmail'] ?? data['email'] ?? ''}'
          .trim()
          .toLowerCase();
      if (username.isNotEmpty) {
        await _storage.writeString(StorageKeys.adminUsername, username);
      }
      final passwordHash = '${data['passwordHash'] ?? ''}'.trim();
      if (passwordHash.isNotEmpty) {
        await _storage.writeString(
          StorageKeys.adminPassword,
          isHashedPassword(passwordHash) ? passwordHash : hashPassword(passwordHash),
        );
      }
      final coAdmins = data['coAdmins'];
      if (coAdmins is List) {
        await _storage.writeString(StorageKeys.coAdmins, jsonEncode(coAdmins));
      }
      if (data['firebaseAuthLinked'] == true) {
        await _storage.writeString(StorageKeys.adminFirebaseAuthLinked, '1');
      }
    } catch (_) {}
  }

  Future<bool> _persistMainAdminPassword(String newPassword) async {
    final hashed = hashPassword(newPassword);
    await _storage.writeString(StorageKeys.adminPassword, hashed);
    try {
      await _ensureFirebaseReady();
      if (!FirestoreSyncService.instance.isReady) return false;
      final username = _getMainAdminEmail();
      await FirestoreSyncService.instance.db
          .collection(FirestoreCollections.adminAccounts)
          .doc('credentials')
          .set(
            {
              'username': username,
              'loginEmail': username,
              'email': username,
              'passwordHash': hashed,
              'firebaseAuthLinked': true,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            },
            SetOptions(merge: true),
          );
      await _storage.writeString(StorageKeys.adminFirebaseAuthLinked, '1');
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _findCoAdmin(String email) {
    final raw = _storage.readString(StorageKeys.coAdmins);
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return null;
      for (final item in parsed) {
        if (item is Map) {
          final itemEmail = '${item['email'] ?? ''}'.trim().toLowerCase();
          if (itemEmail == email) {
            return Map<String, dynamic>.from(item);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _markAdminFirebaseAuthLinked() async {
    await _storage.writeString(StorageKeys.adminFirebaseAuthLinked, '1');
    try {
      await _ensureFirebaseReady();
      if (!FirestoreSyncService.instance.isReady) return;
      await FirestoreSyncService.instance.db
          .collection(FirestoreCollections.adminAccounts)
          .doc('credentials')
          .set(
            {
              'firebaseAuthLinked': true,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            },
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  Future<bool> _updateCoAdminPassword(
    String email,
    String? newPassword, {
    bool linked = false,
  }) async {
    final raw = _storage.readString(StorageKeys.coAdmins);
    if (raw == null || raw.isEmpty) return false;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return false;
      var changed = false;
      final updated = parsed.map((item) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          if ('${map['email'] ?? ''}'.trim().toLowerCase() == email) {
            if (newPassword != null) {
              map['password'] = hashPassword(newPassword);
            }
            if (linked) {
              map['firebaseAuthLinked'] = true;
            }
            changed = true;
          }
          return map;
        }
        return item;
      }).toList();
      if (!changed) return false;
      await _storage.writeString(StorageKeys.coAdmins, jsonEncode(updated));
      try {
        await _ensureFirebaseReady();
        if (!FirestoreSyncService.instance.isReady) return false;
        await FirestoreSyncService.instance.db
            .collection(FirestoreCollections.adminAccounts)
            .doc('credentials')
            .set(
              {
                'coAdmins': updated,
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              },
              SetOptions(merge: true),
            );
      } catch (_) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  String _maskEmail(String email) {
    final trimmed = email.trim();
    final at = trimmed.indexOf('@');
    if (at <= 0) return '***';
    final local = trimmed.substring(0, at);
    final domain = trimmed.substring(at + 1);
    final visible = local.substring(0, local.length.clamp(0, 2));
    return '$visible***@$domain';
  }
}
