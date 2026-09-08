import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackit_mobile/data/beta_tester_students.dart';
import 'package:trackit_mobile/services/sections_service.dart';
import 'package:trackit_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('beta tester student roster', () {
    late SectionsService sections;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      sections = SectionsService(storage);
      await sections.initialize();
    });

    test('seeds all 12 beta tester student IDs in the roster', () {
      expect(betaTesterRosterEntries.length, 12);

      for (final entry in betaTesterRosterEntries) {
        final enrolled = sections.findStudentById(entry.studentId);
        expect(enrolled, isNotNull, reason: 'Missing roster entry for ${entry.studentId}');
        expect(
          enrolled!.name.toLowerCase(),
          entry.fullName.toLowerCase(),
          reason: 'Name mismatch for ${entry.studentId}',
        );
      }
    });

    test('each gmail maps to a unique student id', () {
      final gmails = betaTesterRosterEntries.map((e) => e.gmail.toLowerCase()).toList();
      expect(gmails.toSet().length, gmails.length);

      final ids = betaTesterRosterEntries.map((e) => e.studentId).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
