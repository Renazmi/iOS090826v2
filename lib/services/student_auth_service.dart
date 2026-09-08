import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/seed_data.dart';
import '../models/student_account.dart';
import '../utils/firebase_password_sync.dart';
import '../utils/password_hash.dart';
import '../utils/profile_photo_picker.dart';
import '../utils/settings_validation.dart';
import '../utils/student_id.dart' as student_id_util;
import 'api_service.dart';
import 'firestore_sync_service.dart';
import 'sections_service.dart';
import 'storage_service.dart';

/// Mirrors `StudentAuthService` from the Ionic web app.
class StudentAuthService {
  StudentAuthService(this._storage, this._api, this._sections);

  final StorageService _storage;
  final ApiService _api;
  final SectionsService _sections;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  bool _seededFirestore = false;
  bool _applyingFirestoreSnapshot = false;
  void Function()? _onChanged;

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> dispose() async {
    await _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  Future<void> initialize() async {
    await _migrateStoredStudentPasswords();
    await _ensureSeededStudents();
    await _startFirestoreListener();
  }

  String normalizeStudentId(String studentId) =>
      student_id_util.normalizeStudentId(studentId);

  List<StudentAccount> _readStudentsFromStorage() {
    final rows = _storage.readJsonList(StorageKeys.students);
    return rows.map((row) {
      final student = StudentAccount.fromJson(row);
      final password = isHashedPassword(student.password)
          ? student.password
          : normalizeStoredPassword(student.password);
      return StudentAccount(
        studentId: student_id_util.normalizeStudentId(student.studentId),
        fullName: student.fullName,
        phone: student.phone,
        gmail: student.gmail,
        password: password,
        verified: student.verified,
        profileCompleted: student.profileCompleted,
        createdAt: student.createdAt,
        profilePictureUrl: student.profilePictureUrl,
      );
    }).toList();
  }

  List<StudentAccount> _readStudents() {
    return _readStudentsFromStorage();
  }

  Future<void> _migrateStoredStudentPasswords() async {
    final list = _readStudentsFromStorage();
    var changed = false;
    final migrated = list.map((student) {
      if (isHashedPassword(student.password)) return student;
      changed = true;
      return student.copyWith(password: normalizeStoredPassword(student.password));
    }).toList();
    if (changed) {
      await _writeStudents(migrated, syncFirestore: false);
    }
  }

  Future<void> _writeStudents(
    List<StudentAccount> list, {
    bool syncFirestore = true,
  }) async {
    await _api.saveCollection(
      StorageKeys.students,
      list.map((s) => s.toJson()).toList(),
    );
    if (syncFirestore && !_applyingFirestoreSnapshot) {
      await _writeAllStudentsToFirestore(list);
    }
    _onChanged?.call();
  }

  Future<void> _writeAllStudentsToFirestore(List<StudentAccount> list) async {
    if (!FirestoreSyncService.instance.isReady) return;
    for (final student in list) {
      await _writeStudentToFirestore(student);
    }
  }

  Future<String?> _writeStudentToFirestore(StudentAccount student) async {
    if (_applyingFirestoreSnapshot) return null;
    try {
      if (!FirestoreSyncService.instance.isReady) {
        await FirestoreSyncService.instance.initialize();
      }
      if (!FirestoreSyncService.instance.isReady) {
        return 'Saved on this device, but could not sync to TrackIT admin. Check your connection.';
      }
      await FirestoreSyncService.instance.db
          .collection(FirestoreCollections.students)
          .doc(student_id_util.normalizeStudentId(student.studentId))
          .set(student.toJson());
      return null;
    } catch (_) {
      return 'Saved on this device, but could not sync to TrackIT admin. Try a smaller photo or check your connection.';
    }
  }

  Future<void> _startFirestoreListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    await _firestoreSub?.cancel();
    _firestoreSub = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.students)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) {
        _seededFirestore = true;
        return;
      }

      _seededFirestore = true;
      _applyingFirestoreSnapshot = true;
      try {
        final list = snap.docs
            .map((doc) => StudentAccount.fromJson({...doc.data(), 'studentId': doc.id}))
            .map((student) {
              final password = isHashedPassword(student.password)
                  ? student.password
                  : normalizeStoredPassword(student.password);
              return StudentAccount(
                studentId: student_id_util.normalizeStudentId(student.studentId),
                fullName: student.fullName,
                phone: student.phone,
                gmail: student.gmail,
                password: password,
                verified: student.verified,
                profileCompleted: student.profileCompleted,
                createdAt: student.createdAt,
                profilePictureUrl: student.profilePictureUrl,
              );
            })
            .toList();

        await _api.saveCollection(
          StorageKeys.students,
          list.map((s) => s.toJson()).toList(),
        );
        _onChanged?.call();
      } finally {
        _applyingFirestoreSnapshot = false;
      }
    });
  }

  Future<void> _seedFirestoreFromLocal() async {
    final list = _readStudents();
    if (list.isEmpty) {
      await _ensureSeededStudents();
    }
    await _writeAllStudentsToFirestore(_readStudents());
  }

  Future<void> _ensureSeededStudents() async {
    final list = _readStudentsFromStorage();
    var changed = false;

    for (final seed in defaultSeededStudents) {
      final exists = list.any((s) => s.studentId == seed.studentId);
      if (!exists) {
        list.add(
          StudentAccount(
            studentId: seed.studentId,
            fullName: seed.fullName,
            phone: seed.phone,
            gmail: seed.gmail,
            password: hashPassword(seed.password),
            verified: true,
            profileCompleted: true,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        changed = true;
      }
    }

    if (changed) {
      await _writeStudents(list);
    }
  }

  StudentAccount? getStudentById(String studentId) {
    final id = normalizeStudentId(studentId);
    if (id.isEmpty) return null;
    return _readStudents().where((s) => s.studentId == id).firstOrNull;
  }

  bool hasRegisteredAccount(String studentId) {
    return getStudentById(normalizeStudentId(studentId)) != null;
  }

  Future<StudentUpdateResult> createStudentAccount({
    required String studentId,
    required String fullName,
    required String phone,
    required String gmail,
    required String password,
    required String confirmPassword,
    required String profilePictureUrl,
  }) async {
    final id = normalizeStudentId(studentId);
    if (!student_id_util.isValidStudentId(id)) {
      return const StudentUpdateResult.fail(
        'Student ID must contain numbers only (4–12 digits).',
      );
    }
    final trimmedName = fullName.trim();
    final trimmedPhone = phone.trim();
    final trimmedGmail = gmail.trim().toLowerCase();

    final validationError = SettingsValidation.validateStudentRegistration(
      fullName: trimmedName,
      gmail: trimmedGmail,
      phone: trimmedPhone,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (validationError != null) {
      return StudentUpdateResult.fail(validationError);
    }

    final enrolledAny = await _sections.fetchStudentByIdAny(id);
    if (enrolledAny != null && !enrolledAny.isActive) {
      return const StudentUpdateResult.fail(
        'This Student ID has been deactivated. Contact your administrator.',
      );
    }
    final enrolled = enrolledAny != null && enrolledAny.isActive ? enrolledAny : null;
    if (enrolled == null) {
      return const StudentUpdateResult.fail('Student ID not found in the system.');
    }

    if (trimmedName.toLowerCase() != enrolled.name.trim().toLowerCase()) {
      return const StudentUpdateResult.fail(
        'Full name must match the name on file for this Student ID.',
      );
    }

    if (!isValidProfilePhotoDataUrl(profilePictureUrl)) {
      return const StudentUpdateResult.fail(
        'A profile photo showing your face is required to finish registration.',
      );
    }

    if (hasRegisteredAccount(id)) {
      return const StudentUpdateResult.fail(
        'This Student ID already has a TrackIT account.',
      );
    }

    final list = _readStudents();
    if (list.any((s) => s.gmail.toLowerCase() == trimmedGmail)) {
      return const StudentUpdateResult.fail(
        'This Gmail is already used by another account.',
      );
    }

    list.add(
      StudentAccount(
        studentId: id,
        fullName: trimmedName,
        phone: trimmedPhone,
        gmail: trimmedGmail,
        password: hashPassword(password),
        verified: true,
        profileCompleted: true,
        createdAt: DateTime.now().toIso8601String(),
        profilePictureUrl: profilePictureUrl,
      ),
    );
    await _writeStudents(list);
    return const StudentUpdateResult.ok();
  }

  StudentAccount? verifyStudentLogin(String login, String password) {
    final raw = login.trim();
    if (raw.isEmpty || password.isEmpty) return null;

    final StudentAccount? student;
    if (raw.contains('@')) {
      student = findStudentByGmail(raw);
    } else {
      student = getStudentById(normalizeStudentId(raw));
    }

    if (student == null || !student.verified || !verifyPassword(password, student.password)) {
      return null;
    }
    return student;
  }

  StudentAccount? getCurrentStudentAccount() {
    final session = _storage.readJsonObject(StorageKeys.currentStudent);
    if (session == null) return null;
    final id = normalizeStudentId('${session['studentId'] ?? ''}');
    return getStudentById(id);
  }

  Future<void> setCurrentStudent(StudentAccount student) async {
    if (student.needsProfileCompletion) {
      await _storage.writeString(
        StorageKeys.pendingProfileStudentId,
        normalizeStudentId(student.studentId),
      );
      return;
    }
    await _storage.remove(StorageKeys.pendingProfileStudentId);
    await _storage.writeJsonObject(StorageKeys.currentStudent, {
      'studentId': normalizeStudentId(student.studentId),
      'fullName': student.fullName,
    });
  }

  Future<void> clearCurrentStudent() async {
    await _storage.remove(StorageKeys.currentStudent);
  }

  Future<StudentUpdateResult> updateStudentAccount(
    String studentId, {
    String? fullName,
    String? phone,
    String? gmail,
    String? password,
    String? profilePictureUrl,
  }) async {
    final id = normalizeStudentId(studentId);
    if (id.isEmpty) {
      return const StudentUpdateResult.fail('Student ID is required.');
    }

    final list = _readStudents();
    final index = list.indexWhere((s) => s.studentId == id);
    if (index < 0) {
      return const StudentUpdateResult.fail('Student account not found.');
    }

    final current = list[index];
    final trimmedName = fullName?.trim();
    final trimmedPhone = phone?.trim();
    final trimmedGmail = gmail?.trim().toLowerCase();

    if (trimmedName != null ||
        trimmedPhone != null ||
        trimmedGmail != null) {
      final validationError = SettingsValidation.validateStudentProfile(
        fullName: trimmedName ?? current.fullName,
        gmail: trimmedGmail ?? current.gmail,
        phone: trimmedPhone ?? current.phone,
      );
      if (validationError != null) {
        return StudentUpdateResult.fail(validationError);
      }
    }

    if (trimmedGmail != null) {
      final duplicate = list.any(
        (s) => s.studentId != id && s.gmail.toLowerCase() == trimmedGmail,
      );
      if (duplicate) {
        return const StudentUpdateResult.fail(
          'This Gmail is already used by another account.',
        );
      }
    }

    var updated = current;
    if (trimmedName != null) updated = updated.copyWith(fullName: trimmedName);
    if (trimmedPhone != null) updated = updated.copyWith(phone: trimmedPhone);
    if (trimmedGmail != null) updated = updated.copyWith(gmail: trimmedGmail);
    if (password != null && password.isNotEmpty) {
      if (password.length < SettingsValidation.minPasswordLength) {
        return StudentUpdateResult.fail(
          'Password must be at least ${SettingsValidation.minPasswordLength} characters.',
        );
      }
      updated = updated.copyWith(password: hashPassword(password));
    }
    if (profilePictureUrl != null) {
      final url = profilePictureUrl.trim();
      if (!url.startsWith('data:image/')) {
        return const StudentUpdateResult.fail('Choose a valid image file.');
      }
      updated = updated.copyWith(profilePictureUrl: url);
    }

    list[index] = updated;
    await _writeStudents(list, syncFirestore: false);
    final syncError = await _writeStudentToFirestore(updated);

    final refreshed = getStudentById(id);
    if (refreshed != null && getCurrentStudentAccount()?.studentId == id) {
      await setCurrentStudent(refreshed);
    }
    return StudentUpdateResult.ok(warning: syncError);
  }

  Future<StudentUpdateResult> updateCurrentStudentProfile({
    String? fullName,
    String? phone,
    String? gmail,
  }) async {
    final student = getCurrentStudentAccount();
    if (student == null) {
      return const StudentUpdateResult.fail('You are not signed in.');
    }

    final result = await updateStudentAccount(
      student.studentId,
      fullName: fullName,
      phone: phone,
      gmail: gmail,
    );
    if (!result.success) return result;

    final updated = getStudentById(student.studentId);
    if (updated != null) {
      await setCurrentStudent(updated);
    }
    return result;
  }

  Future<StudentUpdateResult> changeStudentPassword(
    String studentId,
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    final student = getStudentById(normalizeStudentId(studentId));
    if (student == null) {
      return const StudentUpdateResult.fail('Student account not found.');
    }
    if (!verifyPassword(currentPassword, student.password)) {
      return const StudentUpdateResult.fail('Current password is incorrect.');
    }

    final validationError = SettingsValidation.validateStudentPasswordChange(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (validationError != null) {
      return StudentUpdateResult.fail(validationError);
    }

    final result = await updateStudentAccount(studentId, password: newPassword);
    if (result.success) {
      final email = student.gmail.trim().toLowerCase();
      if (email.isNotEmpty) {
        await syncFirebaseAccountPassword(
          email: email,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }
    }
    return result;
  }

  Future<StudentAccount?> acceptRemotePasswordIfValid(String login, String password) async {
    final raw = login.trim();
    if (raw.isEmpty || password.isEmpty) return null;

    final student = raw.contains('@')
        ? findStudentByGmail(raw)
        : getStudentById(normalizeStudentId(raw));
    if (student == null || !student.verified) return null;

    final email = student.gmail.trim().toLowerCase();
    if (email.isEmpty) return null;

    final accepted = await tryFirebasePasswordSignIn(email, password);
    if (!accepted) return null;

    final result = await updateStudentAccount(student.studentId, password: password);
    if (!result.success) return null;
    return getStudentById(student.studentId);
  }

  StudentAccount? findStudentByGmail(String gmail) {
    final normalized = gmail.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return _readStudents().where((s) => s.gmail.toLowerCase() == normalized).firstOrNull;
  }

  StudentPasswordResetLookup lookupStudentForPasswordReset(String studentId) {
    final id = normalizeStudentId(studentId);
    if (id.isEmpty) {
      return const StudentPasswordResetLookup.fail('Enter your Student ID.');
    }

    final student = getStudentById(id);
    if (student == null) {
      return const StudentPasswordResetLookup.fail(
        'No TrackIT account found for this Student ID.',
      );
    }

    final hasGmail = student.gmail.trim().isNotEmpty;
    final hasPhone = student.phone.trim().isNotEmpty;

    if (!hasGmail) {
      return StudentPasswordResetLookup.noRecoveryContact(
        studentName: student.fullName,
        error:
            'This account has no Gmail on file. Please contact your administrator to reset your password.',
      );
    }

    return StudentPasswordResetLookup.ok(
      studentName: student.fullName,
      maskedGmail: _maskEmail(student.gmail),
      maskedPhone: hasPhone ? _maskPhone(student.phone) : null,
    );
  }

  StudentPasswordResetLookup lookupStudentByGmailForPasswordReset(String gmail) {
    final value = gmail.trim().toLowerCase();
    if (value.isEmpty) {
      return const StudentPasswordResetLookup.fail('Enter your registered Gmail address.');
    }

    final student = findStudentByGmail(value);
    if (student == null) {
      return const StudentPasswordResetLookup.fail(
        'No TrackIT account found for this Gmail address.',
      );
    }

    final registeredGmail = student.gmail.trim();
    if (registeredGmail.isEmpty) {
      return StudentPasswordResetLookup.noRecoveryContact(
        studentName: student.fullName,
        studentId: student.studentId,
        error:
            'This account has no Gmail on file. Please contact your administrator to reset your password.',
      );
    }

    return StudentPasswordResetLookup.ok(
      studentId: student.studentId,
      studentName: student.fullName,
      maskedGmail: _maskEmail(registeredGmail),
    );
  }

  StudentRecoveryResult verifyRecoveryGmail(String studentId, String gmail) {
    final student = getStudentById(normalizeStudentId(studentId));
    if (student == null) {
      return const StudentRecoveryResult.fail('Account not found.');
    }

    final value = gmail.trim().toLowerCase();
    if (value.isEmpty) {
      return const StudentRecoveryResult.fail('Enter your registered Gmail address.');
    }

    final registered = student.gmail.trim().toLowerCase();
    if (registered.isEmpty) {
      return const StudentRecoveryResult.fail('This account has no Gmail on file.');
    }

    if (registered != value) {
      return const StudentRecoveryResult.fail(
        'That Gmail address does not match our records for this Student ID.',
      );
    }

    return const StudentRecoveryResult.ok();
  }

  StudentRecoveryCodeResult sendStudentRecoveryCode(String studentId, String gmail) {
    final verification = verifyRecoveryGmail(studentId, gmail);
    if (!verification.valid) {
      return StudentRecoveryCodeResult.fail(verification.error ?? 'Verification failed.');
    }

    final id = normalizeStudentId(studentId);
    final student = getStudentById(id);
    final registeredGmail = student?.gmail.trim();
    if (student == null || registeredGmail == null || registeredGmail.isEmpty) {
      return const StudentRecoveryCodeResult.fail('No Gmail is on file for this account.');
    }

    final code = _generateRecoveryCode();
    _storeRecoveryOtp(id, code);

    return StudentRecoveryCodeResult.ok(maskedGmail: _maskEmail(registeredGmail));
  }

  StudentRecoveryCodeResult sendStudentRecoveryCodeByGmail(String gmail) {
    final lookup = lookupStudentByGmailForPasswordReset(gmail);
    if (!lookup.success) {
      return StudentRecoveryCodeResult.fail(lookup.error ?? 'Could not find your account.');
    }
    if (!lookup.hasRecoveryContact || lookup.studentId == null) {
      return StudentRecoveryCodeResult.fail(
        lookup.error ?? 'No Gmail is on file for this account.',
      );
    }

    final result = sendStudentRecoveryCode(lookup.studentId!, gmail);
    if (!result.success) {
      return StudentRecoveryCodeResult.fail(result.error ?? 'Could not send verification code.');
    }

    return StudentRecoveryCodeResult.ok(
      studentId: lookup.studentId,
      maskedGmail: result.maskedGmail ?? lookup.maskedGmail ?? '',
    );
  }

  StudentRecoveryResult verifyStudentRecoveryCode(String studentId, String code) {
    final id = normalizeStudentId(studentId);
    if (id.isEmpty) {
      return const StudentRecoveryResult.fail('Enter your Student ID.');
    }

    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      return const StudentRecoveryResult.fail('Enter the verification code from your Gmail.');
    }

    if (!_matchesRecoveryOtp(id, trimmedCode)) {
      return const StudentRecoveryResult.fail(
        'Incorrect or expired verification code. Request a new code and try again.',
      );
    }

    return const StudentRecoveryResult.ok();
  }

  Future<StudentUpdateResult> resetStudentPasswordWithCode({
    required String studentId,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final verification = verifyStudentRecoveryCode(studentId, code);
    if (!verification.valid) {
      return StudentUpdateResult.fail(verification.error ?? 'Verification failed.');
    }

    if (newPassword.length < SettingsValidation.minPasswordLength) {
      return StudentUpdateResult.fail(
        'Password must be at least ${SettingsValidation.minPasswordLength} characters.',
      );
    }

    if (newPassword != confirmPassword) {
      return const StudentUpdateResult.fail('Passwords do not match.');
    }

    final result = await updateStudentAccount(studentId, password: newPassword);
    if (result.success) {
      await _clearRecoveryOtp(normalizeStudentId(studentId));
    }
    return result;
  }

  StudentRecoveryResult verifyRecoveryContact(String studentId, String contact) {
    final student = getStudentById(normalizeStudentId(studentId));
    if (student == null) {
      return const StudentRecoveryResult.fail('Account not found.');
    }

    final value = contact.trim();
    if (value.isEmpty) {
      return const StudentRecoveryResult.fail('Enter your registered Gmail or phone number.');
    }

    final gmailMatch = student.gmail.trim().toLowerCase() == value.toLowerCase();
    final phoneMatch = _normalizePhone(student.phone) == _normalizePhone(value);
    if (!gmailMatch && !phoneMatch) {
      return const StudentRecoveryResult.fail(
        'That Gmail or phone number does not match our records.',
      );
    }

    return const StudentRecoveryResult.ok();
  }

  Future<StudentUpdateResult> resetStudentPassword({
    required String studentId,
    required String contact,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final verification = verifyRecoveryContact(studentId, contact);
    if (!verification.valid) {
      return StudentUpdateResult.fail(verification.error ?? 'Verification failed.');
    }

    if (newPassword.length < SettingsValidation.minPasswordLength) {
      return StudentUpdateResult.fail(
        'Password must be at least ${SettingsValidation.minPasswordLength} characters.',
      );
    }

    if (newPassword != confirmPassword) {
      return const StudentUpdateResult.fail('Passwords do not match.');
    }

    return updateStudentAccount(studentId, password: newPassword);
  }

  String _normalizePhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  String _generateRecoveryCode() {
    final value = 100000 + (DateTime.now().microsecondsSinceEpoch % 900000);
    return '$value';
  }

  String _recoveryOtpKey(String studentId) =>
      'trackit_student_recovery_otp_${normalizeStudentId(studentId)}';

  Future<void> _storeRecoveryOtp(String studentId, String code) async {
    await _storage.writeJsonObject(_recoveryOtpKey(studentId), {
      'code': code,
      'expiresAt': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
    });
  }

  bool _matchesRecoveryOtp(String studentId, String code) {
    final raw = _storage.readJsonObject(_recoveryOtpKey(studentId));
    if (raw == null) return false;
    final storedCode = '${raw['code'] ?? ''}';
    final expiresAt = raw['expiresAt'];
    if (storedCode.isEmpty || expiresAt is! num) {
      return false;
    }
    if (DateTime.now().millisecondsSinceEpoch > expiresAt.toInt()) {
      _clearRecoveryOtp(studentId);
      return false;
    }
    return storedCode == code.trim();
  }

  Future<void> _clearRecoveryOtp(String studentId) async {
    await _storage.remove(_recoveryOtpKey(studentId));
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

  String _maskPhone(String phone) {
    final digits = _normalizePhone(phone);
    if (digits.length < 4) return '***';
    return '${digits.substring(0, 2)}${'*' * (digits.length - 4).clamp(0, digits.length)}${digits.substring(digits.length - 2)}';
  }

  Future<StudentUpdateResult> setCurrentStudentProfilePicture(String dataUrl) async {
    final student = getCurrentStudentAccount();
    if (student == null) {
      return const StudentUpdateResult.fail('You are not signed in.');
    }
    final url = dataUrl.trim();
    if (!url.startsWith('data:image/')) {
      return const StudentUpdateResult.fail('Choose a valid image file.');
    }
    return updateStudentAccount(student.studentId, profilePictureUrl: url);
  }

  Future<StudentUpdateResult> clearCurrentStudentProfilePicture() async {
    final student = getCurrentStudentAccount();
    if (student == null) {
      return const StudentUpdateResult.fail('You are not signed in.');
    }
    final list = _readStudents();
    final index = list.indexWhere((s) => s.studentId == student.studentId);
    if (index < 0) {
      return const StudentUpdateResult.fail('Student account not found.');
    }
    list[index] = list[index].copyWith(clearProfilePicture: true);
    await _writeStudents(list, syncFirestore: false);
    final updated = getStudentById(student.studentId);
    if (updated != null) {
      await setCurrentStudent(updated);
    }
    final syncError = updated == null ? null : await _writeStudentToFirestore(updated);
    return StudentUpdateResult.ok(warning: syncError);
  }
}

class StudentUpdateResult {
  const StudentUpdateResult._({required this.success, this.error, this.warning});

  const StudentUpdateResult.ok({this.warning})
      : success = true,
        error = null;
  const StudentUpdateResult.fail(String message)
      : success = false,
        error = message,
        warning = null;

  final bool success;
  final String? error;
  final String? warning;
}

class StudentPasswordResetLookup {
  const StudentPasswordResetLookup._({
    required this.success,
    this.hasRecoveryContact = false,
    this.studentId,
    this.studentName,
    this.maskedGmail,
    this.maskedPhone,
    this.error,
  });

  const StudentPasswordResetLookup.ok({
    String? studentId,
    required String studentName,
    String? maskedGmail,
    String? maskedPhone,
  }) : this._(
          success: true,
          hasRecoveryContact: true,
          studentId: studentId,
          studentName: studentName,
          maskedGmail: maskedGmail,
          maskedPhone: maskedPhone,
        );

  const StudentPasswordResetLookup.noRecoveryContact({
    required String studentName,
    String? studentId,
    required String error,
  }) : this._(
          success: true,
          hasRecoveryContact: false,
          studentId: studentId,
          studentName: studentName,
          error: error,
        );

  const StudentPasswordResetLookup.fail(String message)
      : this._(success: false, error: message);

  final bool success;
  final bool hasRecoveryContact;
  final String? studentId;
  final String? studentName;
  final String? maskedGmail;
  final String? maskedPhone;
  final String? error;
}

class StudentRecoveryResult {
  const StudentRecoveryResult._({required this.valid, this.error});

  const StudentRecoveryResult.ok() : this._(valid: true);
  const StudentRecoveryResult.fail(String message) : this._(valid: false, error: message);

  final bool valid;
  final String? error;
}

class StudentRecoveryCodeResult {
  const StudentRecoveryCodeResult._({
    required this.success,
    this.studentId,
    this.maskedGmail,
    this.error,
  });

  const StudentRecoveryCodeResult.ok({String? studentId, required String maskedGmail})
      : this._(success: true, studentId: studentId, maskedGmail: maskedGmail);

  const StudentRecoveryCodeResult.fail(String message)
      : this._(success: false, error: message);

  final bool success;
  final String? studentId;
  final String? maskedGmail;
  final String? error;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
