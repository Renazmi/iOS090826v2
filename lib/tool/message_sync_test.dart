import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../services/chat_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/storage_service.dart';

/// Run on Android device:
///   flutter run -d <device-id> -t lib/tool/message_sync_test.dart
///
/// Pass marker via dart-define:
///   flutter run ... --dart-define=TEST_MARKER=E2E-MSG-123
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const marker = String.fromEnvironment('TEST_MARKER', defaultValue: '');
  if (marker.isEmpty) {
    stderr.writeln('TEST_FAILED: pass --dart-define=TEST_MARKER=your-id');
    exit(1);
  }

  await FirestoreSyncService.instance.initialize();
  final storage = await StorageService.create();
  final chat = ChatService(storage);
  final completer = Completer<void>();

  void checkMessages() {
    final found = chat.messages.any((m) => m.text.contains(marker));
    if (found && !completer.isCompleted) {
      debugPrint('FLUTTER_RECEIVED: $marker');
      completer.complete();
    }
  }

  chat.setOnChanged(checkMessages);
  await chat.initialize();
  checkMessages();

  if (completer.isCompleted) {
    debugPrint('TEST_PASSED');
    await Future<void>.delayed(const Duration(seconds: 2));
    exit(0);
  }

  debugPrint('FLUTTER_LISTENING: $marker');

  try {
    await completer.future.timeout(const Duration(seconds: 90));
    debugPrint('TEST_PASSED');
    await Future<void>.delayed(const Duration(seconds: 2));
    exit(0);
  } on TimeoutException {
    debugPrint('TEST_FAILED: timeout after 90s');
    exit(1);
  }
}
