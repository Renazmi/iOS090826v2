import '../config/role_access.dart';
import '../models/trackit_role.dart';
import '../services/role_service.dart';

/// Route guard helpers — mirrors `roleGuard` + `role-access.config.ts`.
class RouteGuard {
  RouteGuard(this._roles);

  final RoleService _roles;

  bool canActivateStudentRoute() => _roles.isStudent;

  bool canActivateOfficerRoute() => _roles.isOfficer;

  bool canActivateModule(AccessModule module) {
    final role = _roles.currentRole;
    if (role == null) return false;
    return RoleAccess.canAccess(role, module);
  }

  String homeForRole(TrackitRole role) => RoleAccess.defaultRoute(role);
}
