import '../config/org_constants.dart';
import '../config/role_access.dart';
import '../models/officer.dart';
import 'auth_service.dart';
import 'role_service.dart';

/// Permission checks — mirrors `AccessControlService` module guards.
class PermissionService {
  PermissionService(this._roles, this._auth);

  final RoleService _roles;
  final AuthService _auth;

  bool canAccessModule(AccessModule module) {
    final role = _roles.currentRole;
    if (role == null) return false;
    if (module == AccessModule.eventsPublish && canManageEvents()) {
      return true;
    }
    return RoleAccess.canAccess(role, module);
  }

  /// ELITE org President may publish and edit campus events on mobile.
  bool canManageEvents() {
    if (!_roles.isOfficer) return false;
    final officer = _auth.currentOfficer;
    if (officer == null) return false;
    return isElitePresident(officer);
  }

  static bool isElitePresident(Officer officer) {
    return officer.organizationId == OrgConstants.eliteOrganizationId &&
        officer.position.trim().toLowerCase() == 'president';
  }

  bool canRecordEventAttendance() =>
      _roles.isStudent || _roles.isOfficer;

  bool canViewOutstandingOfficerStats() =>
      _roles.isOfficer; // Admin also on web; mobile phase excludes admin.

  bool canManageOwnReportsOnly() => _roles.isOfficer;

  bool isModuleBlockedForCurrentRole(AccessModule module) {
    return !canAccessModule(module);
  }
}
