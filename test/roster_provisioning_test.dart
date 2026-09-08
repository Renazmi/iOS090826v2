import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackit_mobile/config/storage_keys.dart';
import 'package:trackit_mobile/services/sections_service.dart';
import 'package:trackit_mobile/services/storage_service.dart';
import 'package:trackit_mobile/utils/student_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('centralized roster provisioning', () {
    test('findStudentById ignores deactivated Student IDs', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      await storage.writeJsonObject(StorageKeys.sectionRoster, {
        '1A': [
          {
            'studentId': '202501010',
            'name': 'Active Student',
            'section': '1A',
            'status': 'active',
          },
          {
            'studentId': '202501011',
            'name': 'Deactivated Student',
            'section': '1A',
            'status': 'inactive',
          },
        ],
      });

      final sections = SectionsService(storage);
      await sections.initialize();

      expect(sections.findStudentById('202501010')?.name, 'Active Student');
      expect(sections.findStudentById('202501011'), isNull);
      expect(sections.findStudentByIdAny('202501011')?.isActive, isFalse);
    });

    test('Student ID accepts digits only', () {
      expect(normalizeStudentId('2025-010-10'), '202501010');
      expect(normalizeStudentId('ID#2025abc'), '2025');
      expect(isValidStudentId('202501010'), isTrue);
      expect(isValidStudentId('2025-01010'), isTrue);
      expect(isValidStudentId('abc'), isFalse);
      expect(isValidStudentId('12'), isFalse);
      expect(isValidStudentId('1234567890123'), isFalse);
    });
  });
}
