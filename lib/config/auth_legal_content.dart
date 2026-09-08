/// Legal documents for auth screens — mirrors `auth-legal.constants.ts`.
abstract final class AuthLegalContent {
  static const consentText =
      'By continuing, you agree to our Terms of Use and acknowledge our Privacy Policy.';

  static const developmentTeam = [
    DevelopmentTeamMember(
      role: 'Software Engineer',
      name: 'Lance Enri B Diamzon',
      photoAsset: 'assets/images/lance1.jpg',
    ),
    DevelopmentTeamMember(
      role: 'Project Manager',
      name: 'Faith B Turtogo',
      photoAsset: 'assets/images/faith1.jpg',
    ),
    DevelopmentTeamMember(
      role: 'QA Tester',
      name: 'Jhun Patrick P Ramos',
      photoAsset: 'assets/images/jhun1.jpg',
    ),
    DevelopmentTeamMember(
      role: 'Designer',
      name: 'Gicelle S Santos',
      photoAsset: 'assets/images/gicelle1.jpg',
    ),
  ];

  static const projectAdviser = DevelopmentTeamMember(
    role: 'Project Adviser',
    name: 'Airon Prince C Beltran',
    photoAsset: 'assets/images/airon1.jpg',
  );

  static const documents = {
    AuthLegalDocumentId.terms: AuthLegalDocument(
      id: AuthLegalDocumentId.terms,
      title: 'Terms of Use',
      updated: 'June 2026',
      sections: [
        AuthLegalSection(
          heading: '1. Authorized access',
          body:
              'TrackIT is provided exclusively for authorized administrators, officers, and students of participating student organizations and their institution. You must use only credentials issued or approved by your school. Sharing accounts or allowing others to use your login is prohibited.',
        ),
        AuthLegalSection(
          heading: '2. Acceptable use',
          body:
              'You agree to use TrackIT only for legitimate academic and organizational purposes, including attendance, events, officer records, voting, and related reporting. You may not attempt to access data outside your role, disrupt the service, or upload unlawful or harmful content.',
        ),
        AuthLegalSection(
          heading: '3. Account security',
          body:
              'You are responsible for safeguarding your password and any device used to access TrackIT. Report suspected unauthorized access to your organization adviser or IT office immediately. The institution may suspend or revoke access for policy violations.',
        ),
        AuthLegalSection(
          heading: '4. Service availability',
          body:
              'TrackIT is provided on an “as available” basis for campus operations. Scheduled maintenance, updates, or circumstances beyond our control may temporarily affect access. Critical records should follow your organization’s backup and documentation policies.',
        ),
        AuthLegalSection(
          heading: '5. Changes',
          body:
              'These terms may be updated to reflect legal, security, or institutional requirements. Continued use after notice of changes constitutes acceptance of the revised terms.',
        ),
      ],
    ),
    AuthLegalDocumentId.privacy: AuthLegalDocument(
      id: AuthLegalDocumentId.privacy,
      title: 'Privacy Policy',
      updated: 'June 2026',
      sections: [
        AuthLegalSection(
          heading: 'Information we collect',
          body:
              'TrackIT processes information needed to operate organization management: student and officer identifiers, names, contact details (e.g., Gmail, phone), attendance and event participation, voting activity where applicable, profile photos you upload, and administrative audit logs of system actions.',
        ),
        AuthLegalSection(
          heading: 'How we use information',
          body:
              'Data is used to authenticate users, record attendance and events, manage officers and organizations, generate reports, send organization-related communications, maintain security, and comply with institutional policies. We do not sell personal information to third parties.',
        ),
        AuthLegalSection(
          heading: 'Sharing and disclosure',
          body:
              'Information may be shared with authorized school personnel, organization advisers, and system administrators as required for legitimate educational and organizational purposes. Disclosure may also occur when required by law or to protect the safety and rights of users and the institution.',
        ),
        AuthLegalSection(
          heading: 'Retention',
          body:
              'Records are retained according to your institution’s academic and organizational policies, and for as long as needed to provide the service, resolve disputes, and meet legal obligations. Archived officer and attendance data may be kept for historical reporting.',
        ),
        AuthLegalSection(
          heading: 'Your choices',
          body:
              'You may update certain profile information within the application. Requests to access, correct, or delete personal data should be directed to your organization or the school’s data protection contact, subject to applicable law and institutional rules.',
        ),
        AuthLegalSection(
          heading: 'Data Privacy Act notice',
          body:
              'This notice is issued in line with the Data Privacy Act of 2012 (Republic Act No. 10173) and its implementing rules. TrackIT processes personal data to support student organization operations, including membership, attendance tracking, elections, reporting, and secure administration.',
        ),
        AuthLegalSection(
          heading: 'Personal data processed',
          body:
              'Depending on your role, we may process: full name, student ID, email address, mobile number, year level and section, organization affiliation, position, attendance timestamps, event check-in data, selfies or images submitted for verification where enabled, and system activity logs.',
        ),
        AuthLegalSection(
          heading: 'Legal basis & consent',
          body:
              'Processing is based on your institution’s legitimate educational interests, contractual necessity for organization membership, compliance with school policies, and—where required—your consent. By signing in or registering, you acknowledge this policy and the institution’s authority to process data for TrackIT operations.',
        ),
        AuthLegalSection(
          heading: 'Data protection measures',
          body:
              'We apply role-based access, encrypted connections where supported, audit trails for administrative actions, and access limited to authorized personnel. Users must not circumvent security controls or export data except as permitted by policy.',
        ),
        AuthLegalSection(
          heading: 'Rights of data subjects',
          body:
              'Under applicable law, you may have the right to be informed, to access, object, rectify, erase or block, and to file a complaint with the National Privacy Commission. To exercise rights, contact your organization adviser or the institution’s Data Protection Officer (DPO).',
        ),
        AuthLegalSection(
          heading: 'Contact',
          body:
              'For privacy inquiries regarding TrackIT at your campus, please reach out to your student affairs office, organization faculty adviser, or the designated institutional DPO. Include your full name, student ID, and a clear description of your request.',
        ),
      ],
    ),
  };
}

enum AuthLegalDocumentId { terms, privacy }

class AuthLegalDocument {
  const AuthLegalDocument({
    required this.id,
    required this.title,
    required this.updated,
    required this.sections,
  });

  final AuthLegalDocumentId id;
  final String title;
  final String updated;
  final List<AuthLegalSection> sections;
}

class AuthLegalSection {
  const AuthLegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

class DevelopmentTeamMember {
  const DevelopmentTeamMember({
    required this.role,
    required this.name,
    this.photoAsset,
  });

  final String role;
  final String name;
  final String? photoAsset;
}
