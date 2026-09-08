/// Mirrors localStorage / sessionStorage keys from the Ionic TrackIT web app.
abstract final class StorageKeys {
  // Students
  static const students = 'trackit_students';
  static const sectionRoster = 'trackit_section_roster';
  static const sectionTotals = 'trackit_section_totals';
  static const currentStudent = 'trackit_current_student';
  static const pendingProfileStudentId = 'trackit_pending_profile_student_id';

  // Officers
  static const officers = 'trackit_officers';
  static const officerPasswords = 'trackit_officer_passwords';
  static const currentOfficer = 'trackit_current_officer';

  // Organizations & events
  static const organizations = 'trackit_organizations';
  static const events = 'trackit_events';
  static const eventsCatalogVersion = 'trackit_events_catalog_version';

  // Attendance
  static const attendanceOfficers = 'trackit_attendance_officers';
  static const attendanceAttendees = 'trackit_attendance_attendees';

  // Reports & chat
  static const reports = 'trackit_reports';
  static const chatMessages = 'trackit_chat_messages';
  static const chatMembers = 'trackit_chat_members';
  static const announcements = 'trackit_announcements';

  // Mobile session (role + id bundle)
  static const mobileSession = 'trackit_mobile_session';
  static const mobileAuthResetVersion = 'trackit_mobile_auth_reset_version';

  // Appearance
  static const mobileTheme = 'trackit_mobile_theme';

  // Login remember-me (mirrors web localStorage key)
  static const rememberLogin = 'trackit_remember_login';

  // Admin (mirrors web localStorage keys — used for account recovery)
  static const adminPassword = 'trackit_admin_password';
  static const adminUsername = 'trackit_admin_username';
  static const adminDisplayName = 'trackit_admin_display_name';
  static const coAdmins = 'trackit_coadmins';

  // Account recovery OTP (session-like)
  static const recoveryOtpPrefix = 'trackit_recovery_otp_';
}
