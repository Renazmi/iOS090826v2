import 'class_roster_officers.dart';
import '../models/event_item.dart';
import '../models/geofence_coordinate.dart';
import '../models/officer.dart';
import '../models/organization.dart';
import '../models/student_account.dart';

/// Bump to force logout on next app launch (e.g. after a fresh install/update).
const mobileAuthResetVersion = 10;

/// Default catalog version — mirrors `EVENTS_CATALOG_VERSION` in events.service.ts.
const eventsCatalogVersion = 5;

/// Reserved id — protected attendance beta test event (time in/out).
const attendanceTestEventId = 9001;

/// BETA TEST schedule: Aug 19 10:00 PM through Aug 20 11:00 PM.
const attendanceTestWhenDate = '2026-08-19';
const attendanceTestWindowEndDate = '2026-08-20';
const attendanceTestWindowStart = '22:00';
const attendanceTestWindowEnd = '23:00';

bool isProtectedEventId(int id) => id == attendanceTestEventId;

/// Pre-seeded students — canonical test account only (roster accounts are officers).
const defaultSeededStudents = [
  StudentAccount(
    studentId: '201172224',
    fullName: 'Renaz Mi',
    phone: '09163827406',
    gmail: 'renaz.student@gmail.com',
    password: 'RenazMi224',
  ),
  StudentAccount(
    studentId: '2025999001',
    fullName: 'Mobile Test Student',
    phone: '09171234567',
    gmail: 'mobiletest.student@gmail.com',
    password: 'MobileTest01',
  ),
  StudentAccount(
    studentId: '2025999002',
    fullName: 'Mobile Student Alpha',
    phone: '09171234568',
    gmail: 'mobile.alpha@gmail.com',
    password: 'MobileTest02',
  ),
  StudentAccount(
    studentId: '2025999003',
    fullName: 'Mobile Student Beta',
    phone: '09171234569',
    gmail: 'mobile.beta@gmail.com',
    password: 'MobileTest03',
  ),
  StudentAccount(
    studentId: '2025999004',
    fullName: 'Mobile Student Gamma',
    phone: '09171234570',
    gmail: 'mobile.gamma@gmail.com',
    password: 'MobileTest04',
  ),
  StudentAccount(
    studentId: '2025999005',
    fullName: 'Mobile Student Delta',
    phone: '09171234571',
    gmail: 'mobile.delta@gmail.com',
    password: 'MobileTest05',
  ),
  StudentAccount(
    studentId: '2025999006',
    fullName: 'Mobile Student Epsilon',
    phone: '09171234572',
    gmail: 'mobile.epsilon@gmail.com',
    password: 'MobileTest06',
  ),
  StudentAccount(
    studentId: '2025999007',
    fullName: 'Mobile Student Zeta',
    phone: '09171234573',
    gmail: 'mobile.zeta@gmail.com',
    password: 'MobileTest07',
  ),
  StudentAccount(
    studentId: '2025999008',
    fullName: 'Mobile Student Eta',
    phone: '09171234574',
    gmail: 'mobile.eta@gmail.com',
    password: 'MobileTest08',
  ),
  StudentAccount(
    studentId: '2025999009',
    fullName: 'Mobile Student Theta',
    phone: '09171234575',
    gmail: 'mobile.theta@gmail.com',
    password: 'MobileTest09',
  ),
  StudentAccount(
    studentId: '2025999010',
    fullName: 'Mobile Student Iota',
    phone: '09171234576',
    gmail: 'mobile.iota@gmail.com',
    password: 'MobileTest10',
  ),
  StudentAccount(
    studentId: '2025999011',
    fullName: 'Mobile Student Kappa',
    phone: '09171234577',
    gmail: 'mobile.kappa@gmail.com',
    password: 'MobileTest11',
  ),
];

/// Officer login passwords — mirrors `DEFAULT_SEEDED_OFFICER_PASSWORDS`.
const defaultOfficerPasswords = <int, String>{
  1: 'Lanceenri29',
  2: 'Lanceenri29',
  3: 'Gicellesantos01',
  4: 'Jhunepatrick01',
  5: 'Bongarfaith01',
  6: 'Bangatediamzon01',
  12: 'Michaeltorres01',
  13: 'Sarahlopez01',
  15: 'DemoOfficer1',
  9011: 'MobileOff01',
  9012: 'MobileOff02',
  9013: 'MobileOff03',
  9014: 'MobileOff04',
  9015: 'MobileOff05',
  9016: 'MobileOff06',
  9017: 'MobileOff07',
  9018: 'MobileOff08',
  9019: 'MobileOff09',
  9020: 'MobileOff10',
  9021: 'MobileOff11',
  9022: 'MobileOff12',
  9023: 'MobileOff13',
  9024: 'MobileOff14',
  9025: 'MobileOff15',
};

/// Primary mobile login accounts — emails stay in sync; changed passwords are kept.
const primaryOfficerLogins = <({int officerId, String email, String password})>[
  (officerId: 1, email: 'renazmi30@gmail.com', password: 'Lanceenri29'),
  (officerId: 2, email: 'lanceenridiamzon@gmail.com', password: 'Lanceenri29'),
];

/// Dedicated mobile beta-test officer logins (passwords persist after change/reset).
const mobileTestOfficerLogins = <({int officerId, String email, String password})>[
  (officerId: 9011, email: 'mobile.officer1@gmail.com', password: 'MobileOff01'),
  (officerId: 9012, email: 'mobile.officer2@gmail.com', password: 'MobileOff02'),
  (officerId: 9013, email: 'mobile.officer3@gmail.com', password: 'MobileOff03'),
  (officerId: 9014, email: 'mobile.officer4@gmail.com', password: 'MobileOff04'),
  (officerId: 9015, email: 'mobile.officer5@gmail.com', password: 'MobileOff05'),
  (officerId: 9016, email: 'mobile.officer6@gmail.com', password: 'MobileOff06'),
  (officerId: 9017, email: 'mobile.officer7@gmail.com', password: 'MobileOff07'),
  (officerId: 9018, email: 'mobile.officer8@gmail.com', password: 'MobileOff08'),
  (officerId: 9019, email: 'mobile.officer9@gmail.com', password: 'MobileOff09'),
  (officerId: 9020, email: 'mobile.officer10@gmail.com', password: 'MobileOff10'),
  (officerId: 9021, email: 'mobile.officer11@gmail.com', password: 'MobileOff11'),
  (officerId: 9022, email: 'mobile.officer12@gmail.com', password: 'MobileOff12'),
  (officerId: 9023, email: 'mobile.officer13@gmail.com', password: 'MobileOff13'),
  (officerId: 9024, email: 'mobile.officer14@gmail.com', password: 'MobileOff14'),
  (officerId: 9025, email: 'mobile.officer15@gmail.com', password: 'MobileOff15'),
];

/// Alternate login emails that map to an existing officer record.
const defaultOfficerEmailAliases = <String, int>{
  'elite.president@trackit.local': 1,
  'john.delacruz@trackit.local': 1,
  'faith.turtogo@trackit.local': 1,
};

int _seedScore(int officerId, int salt, int min, int max) {
  var n = officerId * 9301 + salt * 49297;
  n = (n ^ (n >> 16)) * 2246822519;
  n = (n ^ (n >> 13)) * 3266489917;
  n = (n ^ (n >> 16)) >>> 0;
  return min + (n % (max - min + 1));
}

Officer _officer(
  int id,
  String name,
  String position,
  String email,
  String yearLevel,
  String section,
  int organizationId, {
  String? studentId,
  String? phone,
  String? bio,
  String? hobby,
  List<String>? achievements,
  String? profilePictureUrl,
}) {
  return Officer(
    id: id,
    name: name,
    position: position,
    email: email,
    yearLevel: yearLevel,
    section: section,
    attendanceCount: _seedScore(id, 11, 12, 48),
    dailyAttendanceCount: _seedScore(id, 29, 10, 45),
    organizationId: organizationId,
    studentId: studentId,
    phone: phone,
    bio: bio,
    hobby: hobby,
    achievements: achievements,
    profilePictureUrl: profilePictureUrl,
  );
}

/// Default officers — mirrors `DEFAULT_OFFICER_RECORDS` in officers.service.ts.
List<Officer> buildDefaultOfficers() {
  return [
    _officer(1, 'Renaz Mi', 'President', 'renazmi30@gmail.com', '3', 'D', 1,
        studentId: '201172224', phone: '+63 916 382 7406',
        bio: 'ELITE President — campus events and organization leadership.',
        hobby: 'Reading, Public speaking, Chess',
        achievements: ['Outstanding Officer 2023', 'Best Thesis Award', 'Leadership Excellence Award'],
        profilePictureUrl: 'assets/images/bangate.jpg'),
    _officer(2, 'Lance Enri Diamzon', 'Vice President', 'lanceenridiamzon@gmail.com', '3', 'B', 1,
        studentId: '2021001235', phone: '+63 923 456 7890'),
    _officer(3, 'Santos Gicelle', 'Secretary', 'carlos.reyes@trackit.local', '3', 'C', 1,
        studentId: '2021001236', phone: '+63 934 567 8901'),
    _officer(4, 'Jhun Patrick Ramos', 'Treasurer', 'anna.garcia@trackit.local', '2', 'A', 1,
        studentId: '2022001237', phone: '+63 945 678 9012'),
    _officer(9, 'Maria Elena Cruz', 'Auditor', 'elena.cruz@trackit.local', '2', 'C', 1,
        studentId: '2022001242', phone: '+63 901 234 5678'),
    _officer(10, 'David Martinez', 'P.R.O.', 'david.martinez.pro@trackit.local', '2', 'D', 1,
        studentId: '2022001243', phone: '+63 902 345 6789'),
    _officer(11, 'Ana Sofia Lopez', 'Member', 'ana.lopez@trackit.local', '1', 'B', 1,
        studentId: '2023001244', phone: '+63 903 456 7890'),
    _officer(5, 'Bongar Faith', 'Literary Editor', 'michael.torres@trackit.local', '2', 'B', 2,
        studentId: '2022001238', phone: '+63 956 789 0123'),
    _officer(6, 'Bangate Diamzon', 'Photo Editor', 'sarah.lopez@trackit.local', '1', 'D', 2,
        studentId: '2023001239', phone: '+63 967 890 1234'),
    _officer(7, 'Santos Gicelle', 'Staff Writer', 'david.martinez@trackit.local', '1', 'C', 2,
        studentId: '2023001240', phone: '+63 978 901 2345'),
    _officer(8, 'Ramos Jhun Patrick', 'Member', 'lisa.fernandez@trackit.local', '4', 'A', 2,
        studentId: '2020001241', phone: '+63 989 012 3456'),
    _officer(12, 'Michael Torres', 'Editor-in-Chief', 'michael.torres.chief@trackit.local', '4', 'D', 2,
        studentId: '2020001245', phone: '+63 904 567 8901'),
    _officer(13, 'Sarah Lopez', 'Managing Editor', 'sarah.lopez.managing@trackit.local', '3', 'A', 2,
        studentId: '2021001246', phone: '+63 905 678 9012'),
    _officer(14, 'Lisa Fernandez', 'News Editor', 'lisa.fernandez.news@trackit.local', '3', 'B', 2,
        studentId: '2021001247', phone: '+63 906 789 0123'),
    _officer(15, 'Demo Officer', 'Member', 'demo.officer@trackit.local', '2', 'A', 1,
        studentId: 'DEMOOFF01', phone: '+63 917 000 0001',
        bio: 'Demo officer account for testing officer permissions.'),
    _officer(16, 'Carlos Reyes', 'President', 'carlos.reyes.asp@trackit.local', '3', 'A', 3,
        studentId: '2021001250', phone: '+63 907 890 1234'),
    _officer(17, 'Anna Garcia', 'Vice President', 'anna.garcia.asp@trackit.local', '3', 'C', 3,
        studentId: '2021001251', phone: '+63 908 901 2345'),
    _officer(18, 'Mark Villanueva', 'Secretary', 'mark.villanueva.asp@trackit.local', '2', 'B', 3,
        studentId: '2022001252', phone: '+63 909 012 3456'),
    _officer(19, 'Patricia Lim', 'Treasurer', 'patricia.lim.asp@trackit.local', '2', 'D', 3,
        studentId: '2022001253', phone: '+63 910 123 4567'),
    _officer(20, 'Gyomei Santos', 'Member', 'gyomei.santos@trackit.local', '3', 'A', 1,
        studentId: '2021001260', phone: '+63 911 234 5678'),
    _officer(21, 'Kyojuro Reyes', 'Member', 'kyojuro.reyes@trackit.local', '2', 'B', 3,
        studentId: '2022001261', phone: '+63 912 345 6780'),
    _officer(22, 'Obanai Mendoza', 'Photo Editor', 'obanai.mendoza@trackit.local', '3', 'C', 2,
        studentId: '2021001262', phone: '+63 913 456 7891'),
    _officer(23, 'Tengen Rivera', 'P.R.O.', 'tengen.rivera@trackit.local', '4', 'D', 3,
        studentId: '2020001263', phone: '+63 914 567 8902'),
    _officer(9011, 'Mobile Officer One', 'Member', 'mobile.officer1@gmail.com', '2', 'A', 1,
        studentId: 'MOBILE9011', phone: '+63 918 000 0001',
        bio: 'Mobile beta-test officer account (ELITE).'),
    _officer(9012, 'Mobile Officer Two', 'Member', 'mobile.officer2@gmail.com', '2', 'B', 1,
        studentId: 'MOBILE9012', phone: '+63 918 000 0002',
        bio: 'Mobile beta-test officer account (ELITE).'),
    _officer(9013, 'Mobile Officer Three', 'Member', 'mobile.officer3@gmail.com', '3', 'C', 2,
        studentId: 'MOBILE9013', phone: '+63 918 000 0003',
        bio: 'Mobile beta-test officer account (Obra).'),
    _officer(9014, 'Mobile Officer Four', 'Member', 'mobile.officer4@gmail.com', '3', 'D', 2,
        studentId: 'MOBILE9014', phone: '+63 918 000 0004',
        bio: 'Mobile beta-test officer account (Obra).'),
    _officer(9015, 'Mobile Officer Five', 'Member', 'mobile.officer5@gmail.com', '2', 'A', 3,
        studentId: 'MOBILE9015', phone: '+63 918 000 0005',
        bio: 'Mobile beta-test officer account (ASP).'),
    _officer(9016, 'Mobile Officer Six', 'Member', 'mobile.officer6@gmail.com', '1', 'A', 1,
        studentId: 'MOBILE9016', phone: '+63 918 000 0006',
        bio: 'Mobile beta-test officer account (ELITE).'),
    _officer(9017, 'Mobile Officer Seven', 'Member', 'mobile.officer7@gmail.com', '1', 'C', 1,
        studentId: 'MOBILE9017', phone: '+63 918 000 0007',
        bio: 'Mobile beta-test officer account (ELITE).'),
    _officer(9018, 'Mobile Officer Eight', 'Member', 'mobile.officer8@gmail.com', '2', 'A', 2,
        studentId: 'MOBILE9018', phone: '+63 918 000 0008',
        bio: 'Mobile beta-test officer account (Obra).'),
    _officer(9019, 'Mobile Officer Nine', 'Member', 'mobile.officer9@gmail.com', '4', 'B', 2,
        studentId: 'MOBILE9019', phone: '+63 918 000 0009',
        bio: 'Mobile beta-test officer account (Obra).'),
    _officer(9020, 'Mobile Officer Ten', 'Member', 'mobile.officer10@gmail.com', '3', 'B', 3,
        studentId: 'MOBILE9020', phone: '+63 918 000 0010',
        bio: 'Mobile beta-test officer account (ASP).'),
    _officer(9021, 'Mobile Officer Eleven', 'Member', 'mobile.officer11@gmail.com', '2', 'C', 1,
        studentId: 'MOBILE9021', phone: '+63 918 000 0011',
        bio: 'Mobile beta-test officer account (ELITE).'),
    _officer(9022, 'Mobile Officer Twelve', 'Member', 'mobile.officer12@gmail.com', '1', 'D', 1,
        studentId: 'MOBILE9022', phone: '+63 918 000 0012',
        bio: 'Mobile beta-test officer account (ELITE).'),
    _officer(9023, 'Mobile Officer Thirteen', 'Member', 'mobile.officer13@gmail.com', '3', 'A', 2,
        studentId: 'MOBILE9023', phone: '+63 918 000 0013',
        bio: 'Mobile beta-test officer account (Obra).'),
    _officer(9024, 'Mobile Officer Fourteen', 'Member', 'mobile.officer14@gmail.com', '2', 'B', 2,
        studentId: 'MOBILE9024', phone: '+63 918 000 0014',
        bio: 'Mobile beta-test officer account (Obra).'),
    _officer(9025, 'Mobile Officer Fifteen', 'Member', 'mobile.officer15@gmail.com', '4', 'A', 3,
        studentId: 'MOBILE9025', phone: '+63 918 000 0015',
        bio: 'Mobile beta-test officer account (ASP).'),
    ...buildClassRosterOfficers(),
  ];
}

/// Default organizations — mirrors organizations.service.ts.
const defaultOrganizations = [
  Organization(id: 1, name: 'ELITE'),
  Organization(id: 2, name: 'Obra'),
  Organization(id: 3, name: 'ASP'),
];

EventItem _campusEvent(
  int id,
  String title,
  String description,
  String whenDate,
  String whenTime,
  String where,
  EventStatus status,
  int createdDaysAgo, {
  EventScope eventScope = EventScope.school,
  int officersAttended = 0,
  int attendeesScanned = 0,
  int officersTimedIn = 0,
  int officersTimedOut = 0,
  int attendeesTimedIn = 0,
  int attendeesTimedOut = 0,
}) {
  return EventItem(
    id: id,
    title: title,
    eventScope: eventScope,
    description: description,
    whenDate: whenDate,
    whenTime: whenTime,
    where: where,
    assignAll: true,
    assignedOfficerIds: const [],
    officersAttended: officersAttended,
    attendeesScanned: attendeesScanned,
    officersTimedIn: officersTimedIn,
    officersTimedOut: officersTimedOut,
    attendeesTimedIn: attendeesTimedIn,
    attendeesTimedOut: attendeesTimedOut,
    status: status,
    createdAt: DateTime.now().millisecondsSinceEpoch - (86400000 * createdDaysAgo),
  );
}

/// Default events — mirrors `DEFAULT_EVENTS` in events.service.ts.
List<EventItem> buildDefaultEvents() {
  return [
    _campusEvent(1, 'Colloquium', 'Student research presentations and academic panel discussions.',
        '2026-09-08', '09:00', 'DCT Auditorium', EventStatus.upcoming, 3, eventScope: EventScope.ccs),
    _campusEvent(2, 'Intramurals', 'Campus-wide sports and games competition among student teams.',
        '2026-10-06', '07:00', 'DCT Gymnasium & Sports Grounds', EventStatus.upcoming, 2),
    _campusEvent(3, 'Foundation Day', 'Annual celebration of the institution’s founding and heritage.',
        '2026-08-15', '08:00', 'DCT Main Grounds', EventStatus.upcoming, 5),
    _campusEvent(4, 'Buwan ng Wika', 'Programs and activities honoring Filipino language and culture.',
        '2026-06-24', '09:00', 'DCT Covered Court', EventStatus.current, 8,
        eventScope: EventScope.school,
        officersAttended: 6, attendeesScanned: 120, officersTimedIn: 6, officersTimedOut: 2,
        attendeesTimedIn: 98, attendeesTimedOut: 45),
    _campusEvent(5, 'Graduation', 'Commencement ceremony honoring graduating students and their families.',
        '2026-04-18', '14:00', 'DCT Auditorium', EventStatus.previous, 70,
        officersAttended: 8, attendeesScanned: 420, officersTimedIn: 8, officersTimedOut: 8,
        attendeesTimedIn: 380, attendeesTimedOut: 375),
    _campusEvent(6, 'Acculturation', 'Welcome program helping new students adjust to campus life.',
        '2026-05-12', '08:30', 'DCT Student Lounge', EventStatus.previous, 45,
        officersAttended: 5, attendeesScanned: 180, officersTimedIn: 5, officersTimedOut: 5,
        attendeesTimedIn: 165, attendeesTimedOut: 160),
    _campusEvent(7, 'Capstone Orientation', 'Briefing on capstone requirements, timelines, and deliverables.',
        '2026-05-20', '13:00', 'DCT Conference Hall', EventStatus.previous, 38,
        eventScope: EventScope.ccs,
        officersAttended: 4, attendeesScanned: 95, officersTimedIn: 4, officersTimedOut: 4,
        attendeesTimedIn: 88, attendeesTimedOut: 85),
    _campusEvent(8, 'OJT Orientation', 'Pre-deployment orientation for on-the-job training requirements.',
        '2026-05-26', '10:00', 'DCT Room 301', EventStatus.previous, 32,
        eventScope: EventScope.ccs,
        officersAttended: 4, attendeesScanned: 110, officersTimedIn: 4, officersTimedOut: 3,
        attendeesTimedIn: 102, attendeesTimedOut: 98),
  ];
}
