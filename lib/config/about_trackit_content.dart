import 'package:flutter/material.dart';

/// About TrackIT copy — mirrors `admin-top-nav.component.ts` in the Angular app.
abstract final class AboutTrackitContent {
  static const version = '1.0.0';
  static const updated = 'June 2026';
  static const tagline = 'Student organization management platform';

  static const overview =
      'TrackIT is a web-based student organization management system built for campus operations. '
      'It centralizes officer records, event planning, attendance tracking, student accounts, voting, '
      'reports, and administrative oversight in one secure workspace.';

  static const purpose =
      'The system helps organizations run day-to-day operations with accountability—admins can publish '
      'events, monitor attendance by section, manage credentials, review officer performance, and keep a '
      'full audit trail of important actions.';

  static const techStackIntro =
      'TrackIT ships as two clients — an Angular/Ionic web admin app and a native Flutter mobile app for officers — both synced through Firebase.';

  static const features = [
    AboutFeature(
      icon: Icons.dashboard_outlined,
      title: 'Dashboard',
      description: 'Summary view of officers, events, attendance, reports, and recent activity.',
    ),
    AboutFeature(
      icon: Icons.people_outline,
      title: 'Officers & Organizations',
      description: 'Manage officer profiles, positions, organizations, rankings, and term history.',
    ),
    AboutFeature(
      icon: Icons.calendar_today_outlined,
      title: 'Events',
      description: 'Publish events, assign officers, set venues, and generate QR codes for check-ins.',
    ),
    AboutFeature(
      icon: Icons.check_circle_outline,
      title: 'Attendance',
      description: 'Track officer and student attendance by event, section, and time-in/time-out records.',
    ),
    AboutFeature(
      icon: Icons.school_outlined,
      title: 'Students & Sections',
      description: 'Maintain section rosters, import student lists, and link students to their accounts.',
    ),
    AboutFeature(
      icon: Icons.key_outlined,
      title: 'Accounts',
      description: 'Register and manage admin, officer, and student login credentials in one place.',
    ),
    AboutFeature(
      icon: Icons.how_to_vote_outlined,
      title: 'Voting',
      description: 'Create elections, manage ballots, and record student organization voting activity.',
    ),
    AboutFeature(
      icon: Icons.description_outlined,
      title: 'Reports',
      description: 'Collect and review officer submissions such as minutes and accomplishment reports.',
    ),
    AboutFeature(
      icon: Icons.list_alt_outlined,
      title: 'Activity Log',
      description: 'Review a chronological audit trail of administrative changes across the system.',
    ),
    AboutFeature(
      icon: Icons.chat_bubble_outline,
      title: 'Messaging',
      description: 'Send announcements and communicate with officers through the built-in message module.',
    ),
  ];

  static const audience = [
    AboutAudience(
      label: 'Administrators',
      description:
          'Super admins and admins who configure the system, manage accounts, and oversee operations.',
    ),
    AboutAudience(
      label: 'Officers',
      description: 'Organization officers who participate in events, submit reports, and use assigned modules.',
    ),
    AboutAudience(
      label: 'Students',
      description: 'Registered students who sign in for attendance, voting, and other organization activities.',
    ),
  ];

  static const techStackPlatforms = [
    AboutTechStackPlatform(
      platform: 'Web Application',
      description:
          'Angular + Ionic admin dashboard for super admins, admins, and web-based workflows.',
      groups: [
        AboutTechStackGroup(
          title: 'Frontend',
          items: [
            AboutTechStackItem(name: 'Angular 20', icon: 'angular'),
            AboutTechStackItem(name: 'TypeScript', icon: 'typescript'),
            AboutTechStackItem(name: 'Ionic 8', icon: 'ionic'),
            AboutTechStackItem(name: 'RxJS', icon: 'reactivex'),
            AboutTechStackItem(name: 'SCSS & design tokens', icon: 'sass'),
            AboutTechStackItem(name: 'Ionicons', icon: 'ionicons'),
            AboutTechStackItem(name: 'Capacitor 8', icon: 'capacitor'),
          ],
        ),
        AboutTechStackGroup(
          title: 'Backend & Sync',
          items: [
            AboutTechStackItem(name: 'Firebase', icon: 'firebase'),
            AboutTechStackItem(name: 'Cloud Firestore', icon: 'googlecloud'),
          ],
        ),
        AboutTechStackGroup(
          title: 'Maps & Location',
          items: [
            AboutTechStackItem(name: 'Leaflet', icon: 'leaflet'),
            AboutTechStackItem(name: 'OpenStreetMap tiles', icon: 'openstreetmap'),
            AboutTechStackItem(name: 'Nominatim geocoding', icon: 'openstreetmap'),
            AboutTechStackItem(name: 'Browser Geolocation API', icon: 'html5'),
          ],
        ),
        AboutTechStackGroup(
          title: 'Data & Files',
          items: [
            AboutTechStackItem(name: 'SheetJS (xlsx)', icon: 'microsoftexcel'),
            AboutTechStackItem(name: 'docx', icon: 'microsoftword'),
            AboutTechStackItem(name: 'QR code generation', icon: 'qrcode'),
          ],
        ),
        AboutTechStackGroup(
          title: 'Tools & Testing',
          items: [
            AboutTechStackItem(name: 'Angular CLI', icon: 'angular'),
            AboutTechStackItem(name: 'ESLint', icon: 'eslint'),
            AboutTechStackItem(name: 'Karma & Jasmine', icon: 'karma'),
            AboutTechStackItem(name: 'Git', icon: 'git'),
          ],
        ),
      ],
    ),
    AboutTechStackPlatform(
      platform: 'Mobile Application',
      description:
          'Flutter + Dart Android app for officers — attendance, messaging, events, and reports on the go.',
      groups: [
        AboutTechStackGroup(
          title: 'Frontend',
          items: [
            AboutTechStackItem(name: 'Flutter', icon: 'flutter'),
            AboutTechStackItem(name: 'Dart', icon: 'dart'),
            AboutTechStackItem(name: 'Material Design', icon: 'materialdesign'),
            AboutTechStackItem(name: 'Provider (state)', icon: 'provider'),
            AboutTechStackItem(name: 'go_router', icon: 'flutter'),
          ],
        ),
        AboutTechStackGroup(
          title: 'Backend & Sync',
          items: [
            AboutTechStackItem(name: 'Firebase Core', icon: 'firebase'),
            AboutTechStackItem(name: 'Cloud Firestore', icon: 'googlecloud'),
          ],
        ),
        AboutTechStackGroup(
          title: 'Device & Media',
          items: [
            AboutTechStackItem(name: 'geolocator', icon: 'googlemaps'),
            AboutTechStackItem(name: 'mobile_scanner (QR)', icon: 'qrcode'),
            AboutTechStackItem(name: 'image_picker', icon: 'googlephotos'),
            AboutTechStackItem(name: 'file_picker', icon: 'googledrive'),
            AboutTechStackItem(name: 'video_player', icon: 'vlcmediaplayer'),
            AboutTechStackItem(name: 'path_provider', icon: 'android'),
          ],
        ),
        AboutTechStackGroup(
          title: 'Tools & Testing',
          items: [
            AboutTechStackItem(name: 'Flutter SDK', icon: 'flutter'),
            AboutTechStackItem(name: 'flutter_lints', icon: 'eslint'),
            AboutTechStackItem(name: 'Git', icon: 'git'),
          ],
        ),
      ],
    ),
  ];

  static const developmentTeam = [
    AboutTeamMember(
      role: 'Software Engineer',
      name: 'Lance Enri B Diamzon',
      photoAsset: 'assets/images/lance1.jpg',
    ),
    AboutTeamMember(
      role: 'Project Manager',
      name: 'Faith B Turtogo',
      photoAsset: 'assets/images/faith1.jpg',
    ),
    AboutTeamMember(
      role: 'QA Tester',
      name: 'Jhun Patrick P Ramos',
      photoAsset: 'assets/images/jhun1.jpg',
    ),
    AboutTeamMember(
      role: 'Designer',
      name: 'Gicelle S Santos',
      photoAsset: 'assets/images/gicelle1.jpg',
    ),
  ];

  static const projectAdviser = AboutTeamMember(
    role: 'Project Adviser',
    name: 'Airon Prince C Beltran',
    photoAsset: 'assets/images/airon1.jpg',
  );
}

class AboutFeature {
  const AboutFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class AboutAudience {
  const AboutAudience({required this.label, required this.description});

  final String label;
  final String description;
}

class AboutTechStackPlatform {
  const AboutTechStackPlatform({
    required this.platform,
    required this.description,
    required this.groups,
  });

  final String platform;
  final String description;
  final List<AboutTechStackGroup> groups;
}

class AboutTechStackGroup {
  const AboutTechStackGroup({required this.title, required this.items});

  final String title;
  final List<AboutTechStackItem> items;
}

class AboutTechStackItem {
  const AboutTechStackItem({required this.name, required this.icon});

  final String name;
  final String icon;

  String get iconAsset => 'assets/tech-icons/$icon.svg';
}

class AboutTeamMember {
  const AboutTeamMember({
    required this.role,
    required this.name,
    this.photoAsset,
  });

  final String role;
  final String name;
  final String? photoAsset;
}
