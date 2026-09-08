import '../models/trackit_role.dart';
import 'auth_service.dart';

/// Exposes the signed-in role — mirrors `AccessControlService.getCurrentRole()`.
class RoleService {
  RoleService(this._auth);

  final AuthService _auth;

  TrackitRole? get currentRole => _auth.session?.role;

  bool get isStudent => currentRole == TrackitRole.student;

  bool get isOfficer => currentRole == TrackitRole.officer;

  bool get isAuthenticated => _auth.session?.isAuthenticated ?? false;

  String get displayName => _auth.session?.displayName ?? 'Guest';

  String get roleLabel {
    switch (currentRole) {
      case TrackitRole.student:
        return 'Student';
      case TrackitRole.officer:
        return 'Officer';
      case TrackitRole.admin:
        return 'Admin';
      case null:
        return 'Guest';
    }
  }
}
