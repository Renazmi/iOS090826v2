import '../models/trackit_role.dart';
import 'module_flags.dart';

/// Mobile modules — mirrors `src/app/config/role-access.config.ts` (student & officer only).
enum AccessModule {
  dashboard,
  officers,
  organizations,
  events,
  eventsPublish,
  attendance,
  students,
  accounts,
  outstanding,
  messages,
  voting,
  reports,
  activityLog,
  profile,
  settings,
}

abstract final class RoleAccess {
  static const studentModules = {
    AccessModule.dashboard,
    AccessModule.events,
    AccessModule.organizations,
    AccessModule.outstanding,
    AccessModule.voting,
    AccessModule.profile,
    AccessModule.settings,
  };

  static const officerModules = {
    AccessModule.dashboard,
    AccessModule.organizations,
    AccessModule.events,
    AccessModule.messages,
    AccessModule.reports,
    AccessModule.outstanding,
    AccessModule.voting,
    AccessModule.settings,
  };

  static Set<AccessModule> modulesFor(TrackitRole role) {
    switch (role) {
      case TrackitRole.student:
        return studentModules;
      case TrackitRole.officer:
        return officerModules;
      case TrackitRole.admin:
        return const {};
    }
  }

  static bool canAccess(TrackitRole role, AccessModule module) {
    if (module == AccessModule.voting && !ModuleFlags.votingEnabled) {
      return false;
    }
    return modulesFor(role).contains(module);
  }

  static String defaultRoute(TrackitRole role) {
    switch (role) {
      case TrackitRole.student:
        return '/student/dashboard';
      case TrackitRole.officer:
        return '/officer/dashboard';
      case TrackitRole.admin:
        return '/login';
    }
  }
}
