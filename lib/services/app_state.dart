import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/storage_keys.dart';
import '../data/class_roster_officers.dart';
import '../models/trackit_role.dart';
import 'account_recovery_service.dart';
import 'announcements_service.dart';
import 'api_service.dart';
import 'attendance_flow_service.dart';
import 'attendance_service.dart';
import 'auth_service.dart';
import 'chat_members_service.dart';
import 'chat_service.dart';
import 'typing_service.dart';
import 'dashboard_service.dart';
import 'events_service.dart';
import 'firestore_sync_service.dart';
import 'officer_auth_service.dart';
import 'organizations_service.dart';
import 'permission_service.dart';
import 'reports_service.dart';
import 'role_service.dart';
import 'sections_service.dart';
import 'storage_service.dart';
import 'student_auth_service.dart';

/// Root app state — initializes services mirroring the Ionic Angular providers.
class AppState extends ChangeNotifier {
  AppState._({
    required this.storage,
    required this.api,
    required this.studentAuth,
    required this.sections,
    required this.officerAuth,
    required this.accountRecovery,
    required this.auth,
    required this.roles,
    required this.permissions,
    required this.events,
    required this.organizations,
    required this.reports,
    required this.chat,
    required this.chatMembers,
    required this.typing,
    required this.announcements,
    required this.attendance,
    required this.attendanceFlow,
    required this.dashboard,
  });

  final StorageService storage;
  final ApiService api;
  final StudentAuthService studentAuth;
  final SectionsService sections;
  final OfficerAuthService officerAuth;
  final AccountRecoveryService accountRecovery;
  final AuthService auth;
  final RoleService roles;
  final PermissionService permissions;
  final EventsService events;
  final OrganizationsService organizations;
  final ReportsService reports;
  final ChatService chat;
  final ChatMembersService chatMembers;
  final TypingService typing;
  final AnnouncementsService announcements;
  final AttendanceService attendance;
  final AttendanceFlowService attendanceFlow;
  final DashboardService dashboard;

  bool _ready = false;
  bool get isReady => _ready;

  bool _darkMode = false;
  bool get isDarkMode => _darkMode;

  static Future<AppState> create() async {
    await FirestoreSyncService.instance.initialize();

    final storage = await StorageService.create();
    final api = ApiService(storage);
    final sections = SectionsService(storage);
    final studentAuth = StudentAuthService(storage, api, sections);
    final officerAuth = OfficerAuthService(storage, api);
    final accountRecovery = AccountRecoveryService(storage, studentAuth, officerAuth, sections);
    final chatMembers = ChatMembersService(storage);
    final auth = AuthService(storage, studentAuth, officerAuth, chatMembers);
    final roles = RoleService(auth);
    final permissions = PermissionService(roles, auth);
    final events = EventsService(storage, api);
    final organizations = OrganizationsService(storage, api);
    final reports = ReportsService(storage, api);
    final chat = ChatService(storage);
    final typing = TypingService();
    final announcements = AnnouncementsService(storage);
    final attendance = AttendanceService(events, storage);
    final attendanceFlow = AttendanceFlowService();
    final dashboard = DashboardService(
      auth,
      events,
      organizations,
      officerAuth,
      reports,
      chat,
      attendance,
    );

    final state = AppState._(
      storage: storage,
      api: api,
      studentAuth: studentAuth,
      sections: sections,
      officerAuth: officerAuth,
      accountRecovery: accountRecovery,
      auth: auth,
      roles: roles,
      permissions: permissions,
      events: events,
      organizations: organizations,
      reports: reports,
      chat: chat,
      chatMembers: chatMembers,
      typing: typing,
      announcements: announcements,
      attendance: attendance,
      attendanceFlow: attendanceFlow,
      dashboard: dashboard,
    );

    await state.initialize();
    return state;
  }

  void _wireFirestoreRefresh() {
    void refresh() => notifyListeners();
    events.setOnChanged(() {
      refresh();
      unawaited(attendance.reconcileEventCountsFromRecords());
    });
    studentAuth.setOnChanged(() {
      refresh();
      unawaited(auth.refreshStudentSession());
    });
    sections.setOnChanged(refresh);
    chat.setOnChanged(refresh);
    chatMembers.setOnChanged(refresh);
    typing.setOnChanged(refresh);
    announcements.setOnChanged(refresh);
    attendance.setOnChanged(refresh);
    officerAuth.setOnChanged(refresh);
    organizations.setOnChanged(refresh);
  }

  bool canAccessMessages({int? officerId}) {
    final id = officerId ?? auth.currentOfficer?.id;
    if (id == null) return false;
    return chatMembers.isMember(id);
  }

  Future<void> initialize() async {
    await auth.initialize();
    await sections.initialize();
    await events.initialize();
    await organizations.initialize();
    await reports.initialize();
    await chat.initialize();
    final eliteMemberIds = officerAuth.officers
        .where((o) => o.organizationId == 1)
        .map((o) => o.id)
        .toList();
    final chatMemberIds = [...eliteMemberIds, ...classRosterOfficerIds];
    await chatMembers.initialize(defaultEliteMemberIds: chatMemberIds);
    await chatMembers.syncEliteMembersFromRoster(chatMemberIds);
    await typing.initialize();
    await announcements.initialize();
    _wireFirestoreRefresh();
    await attendance.initialize();
    _darkMode = storage.readString(StorageKeys.mobileTheme) != 'light';
    _ready = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_darkMode == enabled) return;
    _darkMode = enabled;
    await storage.writeString(StorageKeys.mobileTheme, enabled ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> toggleDarkMode() => setDarkMode(!_darkMode);

  Future<void> refreshDashboards() async {
    notifyListeners();
  }

  @override
  void dispose() {
    events.dispose();
    studentAuth.dispose();
    unawaited(sections.dispose());
    chat.dispose();
    chatMembers.dispose();
    typing.dispose();
    announcements.dispose();
    attendance.dispose();
    unawaited(officerAuth.dispose());
    unawaited(organizations.dispose());
    super.dispose();
  }

  void notifyAuthChanged() {
    notifyListeners();
  }

  String? redirectForAuth(String location) {
    if (!_ready) return null;

    final loggedIn = roles.isAuthenticated;
    final onAuthScreen = location == '/login' || location == '/register';

    if (!loggedIn && !onAuthScreen) return '/login';
    if (loggedIn && onAuthScreen) {
      return roles.currentRole == TrackitRole.officer
          ? '/officer/dashboard'
          : '/student/dashboard';
    }

    if (loggedIn && location.startsWith('/student') && !roles.isStudent) {
      return '/officer/dashboard';
    }
    if (loggedIn && location.startsWith('/officer') && !roles.isOfficer) {
      return '/student/dashboard';
    }

    return null;
  }
}
