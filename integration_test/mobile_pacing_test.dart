import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trackit_mobile/app.dart';
import 'package:trackit_mobile/routes/app_router.dart';
import 'package:trackit_mobile/services/app_state.dart';

const _passSeconds = 1.0;
const _officerEmail = 'renazmi30@gmail.com';
const _officerPassword = 'Lanceenri29';
const _studentId = '201172223';
const _studentPassword = 'Lanceenri29';

class PacingRow {
  PacingRow({
    required this.module,
    required this.action,
    this.seconds,
    required this.status,
    this.note,
  });

  final String module;
  final String action;
  final double? seconds;
  final String status;
  final String? note;

  String get secondsLabel =>
      seconds == null ? '—' : '${seconds!.toStringAsFixed(2)} s';

  Map<String, dynamic> toJson() => {
        'module': module,
        'action': action,
        'seconds': seconds,
        'secondsLabel': secondsLabel,
        'status': status,
        if (note != null) 'note': note,
      };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final rows = <PacingRow>[];

  Future<void> measure(
    String module,
    String action,
    Future<void> Function() fn, {
    String? skipNote,
  }) async {
    if (skipNote != null) {
      rows.add(PacingRow(
        module: module,
        action: action,
        status: 'Skip',
        note: skipNote,
      ));
      return;
    }

    final sw = Stopwatch()..start();
    try {
      await fn();
      sw.stop();
      final seconds = sw.elapsedMilliseconds / 1000;
      rows.add(PacingRow(
        module: module,
        action: action,
        seconds: seconds,
        status: seconds <= _passSeconds ? 'Pass' : 'Fail',
      ));
    } catch (e) {
      sw.stop();
      rows.add(PacingRow(
        module: module,
        action: action,
        status: 'Fail',
        note: e.toString().split('\n').first,
      ));
    }
  }

  Future<void> waitForLoginForm(WidgetTester tester) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (find.text('LOGIN').evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('LOGIN'), findsOneWidget);
  }

  Future<void> enterCredentials(
    WidgetTester tester,
    String id,
    String password,
  ) async {
    final fields = find.byType(TextField);
    expect(fields, findsAtLeast(2));
    await tester.enterText(fields.at(0), id);
    await tester.enterText(fields.at(1), password);
    await tester.pump();
  }

  Future<void> tapLogin(WidgetTester tester) async {
    await tester.tap(find.text('LOGIN'));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester, {Duration max = const Duration(seconds: 5)}) async {
    await tester.pumpAndSettle(max);
  }

  Future<void> tapBottomNav(WidgetTester tester, String label) async {
    final matches = find.text(label);
    expect(matches, findsWidgets);
    await tester.tap(matches.last);
    await tester.pump();
    await settle(tester);
  }

  testWidgets('TrackIT mobile pacing — officer and student', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = await AppState.create();
    final router = createAppRouter(appState);
    await tester.pumpWidget(TrackitApp(appState: appState, router: router));

    // ── Shared authentication ──
    await measure('Authentication', 'Display login page (splash + form ready)', () async {
      await waitForLoginForm(tester);
    });

    await measure('Authentication', 'Display login identifier field', () async {
      expect(find.text('Email or Username'), findsOneWidget);
    });

    await measure('Authentication', 'Toggle login password visibility', () async {
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    await measure('Authentication', 'Switch to Register screen', () async {
      await tester.tap(find.text('Sign up'));
      await settle(tester);
      expect(find.text('Create Account'), findsOneWidget);
    });

    await measure('Authentication', 'Switch back to Login screen', () async {
      await tester.tap(find.text('Sign in'));
      await settle(tester);
      await waitForLoginForm(tester);
    });

    await measure('Authentication', 'Open forgot password dialog', () async {
      await tester.tap(find.text('Forgot Password?'));
      await settle(tester);
      expect(find.text('Reset password'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
    });

    // ── Officer login ──
    await enterCredentials(tester, _officerEmail, _officerPassword);
    await measure('Authentication', 'Login as officer → dashboard', () async {
      await tapLogin(tester);
      await settle(tester, max: const Duration(seconds: 8));
      expect(find.textContaining('Campus events'), findsWidgets);
    });

    await measure('Dashboard', 'Load dashboard (officer)', () async {
      expect(find.text('Dashboard'), findsWidgets);
    });

    await measure('Dashboard', 'View all events link (officer)', () async {
      await tester.tap(find.text('View all'));
      await settle(tester);
      expect(find.text('Event list'), findsOneWidget);
      await tapBottomNav(tester, 'Dashboard');
    });

    await measure('Events', 'Open Events tab (officer)', () async {
      await tapBottomNav(tester, 'Events');
      expect(find.text('Event list'), findsOneWidget);
    });

    await measure('Events', 'Open Publish event screen (officer)', () async {
      await tester.tap(find.text('Publish event'));
      await settle(tester);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);
    });

    await measure('Message', 'Open Message tab (officer)', () async {
      await tapBottomNav(tester, 'Message');
      expect(
        find.textContaining('ELITE').evaluate().isNotEmpty ||
            find.text('No messages yet').evaluate().isNotEmpty,
        isTrue,
      );
    });

    await measure('Settings', 'Open Settings tab (officer)', () async {
      await tapBottomNav(tester, 'Settings');
      expect(find.text('Settings'), findsOneWidget);
    });

    await measure('Scan QR', 'Open Scan QR tab (officer)', () async {
      await tester.tap(find.byIcon(Icons.add));
      await settle(tester, max: const Duration(seconds: 4));
      expect(find.textContaining('Scan'), findsWidgets);
    });

    recordOfficerSkips(rows);

    // Log out for student flow
    await appState.auth.logout();
    appState.notifyAuthChanged();
    await settle(tester);
    await waitForLoginForm(tester);

    // ── Student login ──
    await enterCredentials(tester, _studentId, _studentPassword);
    await measure('Authentication', 'Login as student → dashboard', () async {
      await tapLogin(tester);
      await settle(tester, max: const Duration(seconds: 8));
      expect(find.textContaining('Welcome,'), findsOneWidget);
    });

    await measure('Dashboard', 'Load dashboard (student)', () async {
      expect(find.text('Dashboard'), findsWidgets);
    });

    await measure('Dashboard', 'View all events link (student)', () async {
      await tester.tap(find.text('View all'));
      await settle(tester);
      expect(find.text('Event list'), findsOneWidget);
      await tapBottomNav(tester, 'Dashboard');
    });

    await measure('Events', 'Open Events tab (student)', () async {
      await tapBottomNav(tester, 'Events');
      expect(find.text('Event list'), findsOneWidget);
    });

    await measure('Organizations', 'Open Org tab (student)', () async {
      await tapBottomNav(tester, 'Org');
      expect(find.text('Organization officers'), findsOneWidget);
    });

    await measure('Settings', 'Open Settings tab (student)', () async {
      await tapBottomNav(tester, 'Settings');
      expect(find.text('Settings'), findsOneWidget);
    });

    await measure('Scan QR', 'Open Scan QR tab (student)', () async {
      await tester.tap(find.byIcon(Icons.add));
      await settle(tester, max: const Duration(seconds: 4));
      expect(find.textContaining('Scan'), findsWidgets);
    });

    recordStudentSkips(rows);

    final pass = rows.where((r) => r.status == 'Pass').length;
    final fail = rows.where((r) => r.status == 'Fail').length;
    final skip = rows.where((r) => r.status == 'Skip').length;

    final output = {
      'tableTitle': 'Pacing Time Result (TrackIT Mobile — Flutter)',
      'system': 'TrackIT Mobile — Flutter (Officer & Student)',
      'platform': 'Flutter integration test (Windows desktop, 390×844 viewport)',
      'environment': 'integration_test on Windows',
      'testedAt': DateTime.now().toUtc().toIso8601String(),
      'passThresholdSeconds': _passSeconds,
      'methodology':
          'Elapsed seconds from user action until target UI is visible. Pass if <= 1.0 s.',
      'credentials': {
        'officer': _officerEmail,
        'student': _studentId,
      },
      'summary': {
        'total': rows.length,
        'pass': pass,
        'fail': fail,
        'skip': skip,
        'measured': rows.where((r) => r.status != 'Skip').length,
      },
      'results': rows.map((r) => r.toJson()).toList(),
    };

    // ignore: avoid_print
    print('PACING_JSON:${jsonEncode(output)}');

    final outFile = Platform.environment['MOBILE_PACING_OUT'];
    if (outFile != null && outFile.isNotEmpty) {
      File(outFile).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
    }
  });
}

void recordOfficerSkips(List<PacingRow> rows) {
  const skips = [
    ('Message', 'Send chat message (officer)', 'Skip: requires ELITE chat membership'),
    ('Settings', 'Save profile settings (officer)', 'Skip: form submit flow'),
    ('Settings', 'Toggle dark mode (officer)', 'Skip: settings toggle'),
    ('Scan QR', 'Complete QR scan attendance (officer)', 'Skip: camera / hardware'),
    ('Scan QR', 'Selfie attendance capture (officer)', 'Skip: camera access'),
  ];
  for (final (module, action, note) in skips) {
    rows.add(PacingRow(module: module, action: action, status: 'Skip', note: note));
  }
}

void recordStudentSkips(List<PacingRow> rows) {
  const skips = [
    ('Settings', 'Save profile settings (student)', 'Skip: form submit flow'),
    ('Settings', 'Toggle dark mode (student)', 'Skip: settings toggle'),
    ('Scan QR', 'Complete QR scan attendance (student)', 'Skip: camera / hardware'),
    ('Scan QR', 'Selfie attendance capture (student)', 'Skip: camera access'),
  ];
  for (final (module, action, note) in skips) {
    rows.add(PacingRow(module: module, action: action, status: 'Skip', note: note));
  }
}
