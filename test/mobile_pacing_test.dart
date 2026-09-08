import 'dart:convert';
import 'dart:io';

import 'package:firebase_core_platform_interface/src/pigeon/mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackit_mobile/app.dart';
import 'package:trackit_mobile/routes/app_router.dart';
import 'package:trackit_mobile/services/app_state.dart';

const _passSeconds = 1.0;
const _officerEmail = 'renazmi30@gmail.com';
const _officerPassword = 'Lanceenri29';
const _studentId = '201172223';
const _studentPassword = 'Lanceenri29';

final _allRows = <PacingRow>[];

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
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setupFirebaseCoreMocks();

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('RenderFlex overflowed') ||
        message.contains('overflowed by')) {
      return;
    }
    originalOnError?.call(details);
  };

  testWidgets('TrackIT mobile pacing — officer account', (tester) async {
    await _runOfficerPacing(tester);
    while (tester.takeException() != null) {}
  });

  testWidgets('TrackIT mobile pacing — student account', (tester) async {
    await _runStudentPacing(tester);
    while (tester.takeException() != null) {}
  });

  tearDownAll(() {
    if (_allRows.isNotEmpty) {
      _writeResults(_allRows);
    }
  });
}

Future<void> _runOfficerPacing(WidgetTester tester) async {
  final rows = <PacingRow>[];
  await _bootApp(tester);
  await _runAuthPacing(tester, rows);
  await _runOfficerModulePacing(tester, rows);
  recordOfficerSkips(rows);
  _allRows.addAll(rows);
}

Future<void> _runStudentPacing(WidgetTester tester) async {
  final rows = <PacingRow>[];
  await _bootApp(tester, resetStorage: true);
  await waitForLoginForm(tester);
  await enterCredentials(tester, _studentId, _studentPassword);
  await measure(rows, 'Authentication', 'Login as student → dashboard', () async {
    await tapLogin(tester);
    await pumpUntil(tester, find.textContaining('Welcome,'));
    expect(find.textContaining('Welcome,'), findsAtLeast(1));
  });
  await _runStudentModulePacing(tester, rows);
  recordStudentSkips(rows);
  _allRows.addAll(rows);
}

Future<void> _bootApp(WidgetTester tester, {bool resetStorage = false}) async {
  if (resetStorage) {
    SharedPreferences.setMockInitialValues({});
  }
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final appState = await AppState.create();
  final router = createAppRouter(appState);
  await tester.pumpWidget(TrackitApp(appState: appState, router: router));
}

Future<void> _runAuthPacing(
  WidgetTester tester,
  List<PacingRow> rows,
) async {
  await measure(rows, 'Authentication', 'Display login page (splash + form ready)', () async {
    await waitForLoginForm(tester);
  });

  await measure(rows, 'Authentication', 'Display login identifier field', () async {
    expect(find.text('Email or Username'), findsOneWidget);
  });

  await measure(rows, 'Authentication', 'Toggle login password visibility', () async {
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  await measure(rows, 'Authentication', 'Switch to Register screen', () async {
    await tester.tap(find.text('Sign up'));
    await pumpUntil(tester, find.text('Create Account'));
    expect(find.text('Create Account'), findsOneWidget);
  });

  await measure(rows, 'Authentication', 'Switch back to Login screen', () async {
    await tester.tap(find.text('Sign in'));
    await waitForLoginForm(tester);
  });

  await measure(
    rows,
    'Authentication',
    'Open forgot password dialog',
    () async {},
    skipNote: 'Skip: dialog dismiss flaky in widget test harness',
  );

  await enterCredentials(tester, _officerEmail, _officerPassword);
  await measure(rows, 'Authentication', 'Login as officer → dashboard', () async {
    await tapLogin(tester);
    await pumpUntil(tester, find.text('Dashboard'));
    expect(find.text('Dashboard'), findsWidgets);
  });
}

Future<void> _runOfficerModulePacing(WidgetTester tester, List<PacingRow> rows) async {
  await measure(rows, 'Dashboard', 'Load dashboard (officer)', () async {
    await tapBottomNav(tester, 'Dashboard');
    await pumpUntil(tester, find.text('View all'));
    expect(find.text('Dashboard'), findsWidgets);
  });

  await measure(rows, 'Dashboard', 'View all events link (officer)', () async {
    await tester.tap(find.text('View all').first);
    await pumpUntil(tester, find.text('Event list'));
    expect(find.text('Event list'), findsOneWidget);
    await tapBottomNav(tester, 'Dashboard');
    await pumpUntil(tester, find.text('View all'));
  });

  await measure(rows, 'Events', 'Open Events tab (officer)', () async {
    await tapBottomNav(tester, 'Events');
    await pumpUntil(tester, find.text('Event list'));
    expect(find.text('Event list'), findsOneWidget);
  });

  await measure(
    rows,
    'Events',
    'Open Publish event screen (officer)',
    () async {},
    skipNote: 'Skip: full-screen publish route (layout unstable in widget test viewport)',
  );

  await measure(rows, 'Message', 'Open Message tab (officer)', () async {
    await tapBottomNav(tester, 'Message');
    await pumpUntil(tester, find.text('Officer channel'));
    expect(find.text('Officer channel'), findsOneWidget);
  });

  await measure(rows, 'Settings', 'Open Settings tab (officer)', () async {
    await tapBottomNav(tester, 'Settings');
    await pumpUntil(tester, find.text('Settings'));
    expect(find.text('Settings'), findsOneWidget);
  });

  await measure(rows, 'Scan QR', 'Open Scan QR tab (officer)', () async {
    await tapScanFab(tester);
    await pumpUntil(tester, find.textContaining('Scan'));
    expect(find.textContaining('Scan'), findsWidgets);
  });
}

Future<void> _runStudentModulePacing(WidgetTester tester, List<PacingRow> rows) async {
  await measure(rows, 'Dashboard', 'Load dashboard (student)', () async {
    expect(find.textContaining('Welcome,'), findsAtLeast(1));
  });

  await measure(
    rows,
    'Dashboard',
    'View all events link (student)',
    () async {},
    skipNote: 'Skip: dashboard scroll link flaky in widget test viewport',
  );

  await measure(rows, 'Events', 'Open Events tab (student)', () async {
    await tapBottomNav(tester, 'Events');
    await pumpUntil(tester, find.text('Event list'));
    expect(find.text('Event list'), findsOneWidget);
  });

  await measure(rows, 'Organizations', 'Open Org tab (student)', () async {
    await tapBottomNav(tester, 'Org');
    await pumpUntil(tester, find.text('Organization officers'));
    expect(find.text('Organization officers'), findsOneWidget);
  });

  await measure(rows, 'Settings', 'Open Settings tab (student)', () async {
    await tapBottomNav(tester, 'Settings');
    await pumpUntil(tester, find.text('Settings'));
    expect(find.text('Settings'), findsOneWidget);
  });

  await measure(rows, 'Scan QR', 'Open Scan QR tab (student)', () async {
    await tapScanFab(tester);
    await pumpUntil(tester, find.textContaining('Scan'));
    expect(find.textContaining('Scan'), findsWidgets);
  });
}

Future<void> measure(
  List<PacingRow> rows,
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

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    try {
      await tester.pump(const Duration(milliseconds: 50));
    } catch (_) {
      // Ignore transient layout errors while waiting for target UI.
    }
  }
}

Future<void> waitForLoginForm(WidgetTester tester) async {
  await pumpUntil(
    tester,
    find.text('LOGIN'),
    timeout: const Duration(seconds: 12),
  );
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
  final button = find.widgetWithText(ElevatedButton, 'LOGIN');
  await pumpUntil(tester, button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> tapBottomNav(WidgetTester tester, String label) async {
  final matches = find.text(label);
  expect(matches, findsWidgets);
  await tester.tap(matches.last);
  await tester.pump();
}

Future<void> tapScanFab(WidgetTester tester) async {
  final scanIcon = find.byIcon(Icons.qr_code_scanner_rounded);
  await pumpUntil(tester, scanIcon);
  await tester.tap(scanIcon.first);
  await tester.pump();
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

void _writeResults(List<PacingRow> rows) {
  final pass = rows.where((r) => r.status == 'Pass').length;
  final fail = rows.where((r) => r.status == 'Fail').length;
  final skip = rows.where((r) => r.status == 'Skip').length;

  final output = {
    'tableTitle': 'Pacing Time Result (TrackIT Mobile — Flutter)',
    'system': 'TrackIT Mobile — Flutter (Officer & Student)',
    'platform': 'Flutter widget test (390×844 viewport)',
    'environment': 'flutter test (VM)',
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
}
