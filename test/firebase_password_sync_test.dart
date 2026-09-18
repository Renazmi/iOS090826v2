import 'package:flutter_test/flutter_test.dart';

import 'package:trackit_mobile/utils/firebase_password_sync.dart';

void main() {
  group('isStaleStoredPassword', () {
    test('rejects a stored hash when Firebase Auth already has a different password', () {
      expect(isStaleStoredPassword(FirebasePasswordProbe.rejected, false), isTrue);
      expect(isStaleStoredPassword(FirebasePasswordProbe.unknown, true), isTrue);
    });

    test('keeps a stored hash when Auth is missing, offline, or in sync', () {
      expect(isStaleStoredPassword(FirebasePasswordProbe.accepted, false), isFalse);
      expect(isStaleStoredPassword(FirebasePasswordProbe.noUser, false), isFalse);
      expect(isStaleStoredPassword(FirebasePasswordProbe.unavailable, false), isFalse);
      expect(isStaleStoredPassword(FirebasePasswordProbe.unknown, false), isFalse);
    });
  });
}
