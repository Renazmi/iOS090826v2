/// Beta tester students — enrolled in the roster for self-registration (not pre-registered).
class BetaTesterRosterEntry {
  const BetaTesterRosterEntry({
    required this.studentId,
    required this.fullName,
    required this.gmail,
    this.section = '3B',
  });

  final String studentId;
  final String fullName;
  final String gmail;
  final String section;
}

/// Gmail ↔ student ID pairs for Play Store / beta testers.
const betaTesterRosterEntries = <BetaTesterRosterEntry>[
  BetaTesterRosterEntry(
    studentId: '2025999012',
    fullName: 'Abe Turtogo',
    gmail: 'abeturtogo@gmail.com',
    section: '3B',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999013',
    fullName: 'Drizza Rivera',
    gmail: 'drizza647@gmail.com',
    section: '2A',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999014',
    fullName: 'Gicelle Santos',
    gmail: 'gicellesantos02@gmail.com',
    section: '3A',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999015',
    fullName: 'Jei An Diamzon',
    gmail: 'jeiandiamzon04@gmail.com',
    section: '2B',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999016',
    fullName: 'Kia Santos',
    gmail: 'kia35931a@gmail.com',
    section: '3C',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999017',
    fullName: 'Lance Enri Diamzon',
    gmail: 'lanceenridiamzon2929@gmail.com',
    section: '3B',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999018',
    fullName: 'Lancelot Fanny',
    gmail: 'lancelotfanny01@gmail.com',
    section: '4A',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999019',
    fullName: 'Nhard Santos',
    gmail: 'nhardsantos4@gmail.com',
    section: '2C',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999020',
    fullName: 'Sean Murf',
    gmail: 'ssmurf802@gmail.com',
    section: '1B',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999021',
    fullName: 'TNC Pro Team',
    gmail: 'tncproteam11@gmail.com',
    section: '4B',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999022',
    fullName: 'Faith Turtogo',
    gmail: 'turtogofaith@gmail.com',
    section: '3A',
  ),
  BetaTesterRosterEntry(
    studentId: '2025999023',
    fullName: 'YT Kids',
    gmail: 'ytkidsx01@gmail.com',
    section: '1A',
  ),
];
