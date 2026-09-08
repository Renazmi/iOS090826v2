import '../models/event_item.dart';
import '../models/officer.dart';
import '../models/organization.dart';
import '../models/report.dart';
import '../models/student_account.dart';
import 'attendance_service.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'events_service.dart';
import 'officer_auth_service.dart';
import 'organizations_service.dart';
import 'reports_service.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.displayName,
    required this.roleLabel,
    required this.organizationName,
    required this.positionLabel,
    required this.totalOfficers,
    required this.organizationsCount,
    required this.eventsTodayCount,
    required this.totalReports,
    required this.checkInsToday,
    required this.messagesCount,
  });

  final String displayName;
  final String roleLabel;
  final String organizationName;
  final String positionLabel;
  final int totalOfficers;
  final int organizationsCount;
  final int eventsTodayCount;
  final int totalReports;
  final int checkInsToday;
  final int messagesCount;
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.student,
    required this.ongoingEvents,
    required this.upcomingEvents,
  });

  final StudentAccount student;
  final List<EventItem> ongoingEvents;
  final List<EventItem> upcomingEvents;
}

class OfficerDashboardData {
  const OfficerDashboardData({
    required this.officer,
    required this.organization,
    required this.metrics,
    required this.campusEvents,
    required this.eventsToday,
    required this.recentReports,
  });

  final Officer officer;
  final Organization? organization;
  final DashboardMetrics metrics;
  final List<EventItem> campusEvents;
  final List<EventItem> eventsToday;
  final List<Report> recentReports;
}

/// Aggregates dashboard data — mirrors student home + officer dashboard pages.
class DashboardService {
  DashboardService(
    this._auth,
    this._events,
    this._organizations,
    this._officerAuth,
    this._reports,
    this._chat,
    this._attendance,
  );

  final AuthService _auth;
  final EventsService _events;
  final OrganizationsService _organizations;
  final OfficerAuthService _officerAuth;
  final ReportsService _reports;
  final ChatService _chat;
  final AttendanceService _attendance;

  StudentDashboardData? buildStudentDashboard() {
    final student = _auth.currentStudent;
    if (student == null) return null;
    return StudentDashboardData(
      student: student,
      ongoingEvents: _events.eventsByStatus(EventStatus.current),
      upcomingEvents: _events.eventsByStatus(EventStatus.upcoming),
    );
  }

  OfficerDashboardData? buildOfficerDashboard() {
    final session = _auth.session;
    final officer = _auth.currentOfficer ??
        (session?.officerId != null ? _officerAuth.getOfficerById(session!.officerId!) : null);
    if (officer == null) return null;
    final org = _organizations.getById(officer.organizationId);

    return OfficerDashboardData(
      officer: officer,
      organization: org,
      metrics: DashboardMetrics(
        displayName: officer.name,
        roleLabel: 'Officer',
        organizationName: org?.name ?? '—',
        positionLabel: officer.position,
        totalOfficers: _officerAuth.officers.length,
        organizationsCount: _organizations.organizations.length,
        eventsTodayCount: _events.countEventsToday(),
        totalReports: _reports.reports.length,
        checkInsToday: _attendance.countCheckInsToday(),
        messagesCount: _chat.messages.length,
      ),
      campusEvents: _events.campusEventsPreview(limit: 8),
      eventsToday: _events.eventsToday(),
      recentReports: _reports.recentReports(limit: 4),
    );
  }
}
