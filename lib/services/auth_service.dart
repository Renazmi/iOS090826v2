import 'package:firebase_auth/firebase_auth.dart';

import '../config/storage_keys.dart';
import '../data/seed_data.dart';
import '../models/auth_session.dart';
import '../models/officer.dart';
import '../models/student_account.dart';
import '../models/trackit_role.dart';
import 'officer_auth_service.dart';
import 'chat_members_service.dart';
import '../data/class_roster_officers.dart';
import 'storage_service.dart';
import 'student_auth_service.dart';

class AuthResult {
  const AuthResult.success(this.session)
      : error = null,
        needsProfileCompletion = false,
        deactivated = false;

  const AuthResult.failure(this.error, {this.deactivated = false})
      : session = null,
        needsProfileCompletion = false;

  const AuthResult.profileRequired(this.session)
      : error = null,
        needsProfileCompletion = true,
        deactivated = false;

  final AuthSession? session;
  final String? error;
  final bool needsProfileCompletion;

  /// The credentials matched but an admin deactivated the account.
  final bool deactivated;

  bool get isSuccess => session != null && error == null;
}

/// Coordinates student and officer authentication — mirrors web login flows.
class AuthService {
  AuthService(
    this._storage,
    this._studentAuth,
    this._officerAuth,
    this._chatMembers,
  );

  final StorageService _storage;
  final StudentAuthService _studentAuth;
  final OfficerAuthService _officerAuth;
  final ChatMembersService _chatMembers;

  AuthSession? _session;

  AuthSession? get session => _session;

  Future<void> initialize() async {
    await _studentAuth.initialize();
    await _officerAuth.initialize();
    await _enforceAuthResetIfNeeded();
    await _restoreSession();
  }

  /// Clears any saved login when the app build reset version changes.
  Future<void> _enforceAuthResetIfNeeded() async {
    final stored = _storage.readInt(StorageKeys.mobileAuthResetVersion);
    if (stored == mobileAuthResetVersion) return;

    _session = null;
    await _storage.remove(StorageKeys.mobileSession);
    await _studentAuth.clearCurrentStudent();
    await _officerAuth.clearCurrentOfficer();
    await _storage.writeInt(StorageKeys.mobileAuthResetVersion, mobileAuthResetVersion);
  }

  Future<void> _restoreSession() async {
    final raw = _storage.readJsonObject(StorageKeys.mobileSession);
    if (raw == null) {
      _session = null;
      return;
    }
    final restored = AuthSession.fromJson(raw);
    if (!restored.isAuthenticated) {
      _session = null;
      return;
    }
    if (restored.role == TrackitRole.student) {
      final student = _studentAuth.getCurrentStudentAccount();
      if (student == null) {
        await logout();
        return;
      }
      _session = AuthSession(
        role: TrackitRole.student,
        studentId: student.studentId,
        displayName: student.fullName,
      );
    } else if (restored.role == TrackitRole.officer) {
      var officer = _officerAuth.getCurrentOfficer();
      officer ??=
          restored.officerId != null ? _officerAuth.getOfficerById(restored.officerId!) : null;
      if (officer == null) {
        await logout();
        return;
      }
      if (_officerAuth.getCurrentOfficer() == null) {
        await _officerAuth.setCurrentOfficer(officer.id);
      }
      _session = AuthSession(
        role: TrackitRole.officer,
        officerId: officer.id,
        displayName: officer.name,
      );
    }
  }

  Future<AuthResult> loginStudent(String studentId, String password) async {
    await _studentAuth.refreshStudentFromServer(studentId);
    final result = await _studentAuth.completeStudentPasswordLogin(studentId, password);
    if (result.deactivated) {
      return const AuthResult.failure(studentDeactivatedLoginMessage, deactivated: true);
    }

    final student = result.student;
    if (student == null) {
      return const AuthResult.failure('Invalid Student ID or password.');
    }
    if (student.needsProfileCompletion) {
      await _studentAuth.setCurrentStudent(student);
      return AuthResult.profileRequired(
        AuthSession(
          role: TrackitRole.student,
          studentId: student.studentId,
          displayName: student.fullName,
        ),
      );
    }
    await _studentAuth.setCurrentStudent(student);
    _session = AuthSession(
      role: TrackitRole.student,
      studentId: student.studentId,
      displayName: student.fullName,
    );
    await _persistSession();
    return AuthResult.success(_session!);
  }

  Future<AuthResult> loginOfficer(String email, String password) async {
    await _officerAuth.refreshOfficerFromServer(email);
    final officer = await _officerAuth.completeOfficerPasswordLogin(email, password);
    if (officer == null) {
      return const AuthResult.failure('Invalid officer email or password.');
    }
    await _officerAuth.setCurrentOfficer(officer.id);
    final eliteIds = _officerAuth.officers
        .where((o) => o.organizationId == 1)
        .map((o) => o.id)
        .toList();
    await _chatMembers.syncEliteMembersFromRoster([...eliteIds, ...classRosterOfficerIds]);
    _session = AuthSession(
      role: TrackitRole.officer,
      officerId: officer.id,
      displayName: officer.name,
    );
    await _persistSession();
    return AuthResult.success(_session!);
  }

  Future<void> logout() async {
    _session = null;
    await _storage.remove(StorageKeys.mobileSession);
    await _studentAuth.clearCurrentStudent();
    await _officerAuth.clearCurrentOfficer();
    await _storage.remove(StorageKeys.pendingProfileStudentId);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  Future<void> _persistSession() async {
    if (_session == null) return;
    await _storage.writeJsonObject(
      StorageKeys.mobileSession,
      _session!.toJson(),
    );
  }

  StudentAccount? get currentStudent => _studentAuth.getCurrentStudentAccount();

  Officer? get currentOfficer {
    final stored = _officerAuth.getCurrentOfficer();
    if (stored != null) return stored;

    final officerId = _session?.officerId;
    if (officerId == null) return null;
    return _officerAuth.getOfficerById(officerId);
  }

  Future<void> refreshOfficerSession() async {
    if (_session?.role != TrackitRole.officer) return;
    final officer = currentOfficer;
    if (officer == null) return;
    _session = AuthSession(
      role: TrackitRole.officer,
      officerId: officer.id,
      displayName: officer.name,
    );
    await _persistSession();
  }

  Future<void> refreshStudentSession() async {
    if (_session?.role != TrackitRole.student) return;
    final student = currentStudent;
    if (student == null) return;
    _session = AuthSession(
      role: TrackitRole.student,
      studentId: student.studentId,
      displayName: student.fullName,
    );
    await _persistSession();
  }
}
