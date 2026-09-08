import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackit_mobile/data/seed_data.dart';
import 'package:trackit_mobile/services/api_service.dart';
import 'package:trackit_mobile/services/officer_auth_service.dart';
import 'package:trackit_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mobile test officer logins', () {
    late OfficerAuthService officerAuth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      officerAuth = OfficerAuthService(storage, ApiService(storage));
      await officerAuth.initialize();
    });

    test('seeds all 15 dedicated mobile test officers', () {
      for (final login in mobileTestOfficerLogins) {
        final officer = officerAuth.getOfficerById(login.officerId);
        expect(officer, isNotNull, reason: 'Missing officer ${login.officerId}');
        expect(
          officer!.email.toLowerCase(),
          login.email.toLowerCase(),
          reason: 'Email mismatch for officer ${login.officerId}',
        );
      }
      expect(mobileTestOfficerLogins.length, 15);
    });

    test('each mobile test officer can sign in with email and password', () {
      for (final login in mobileTestOfficerLogins) {
        final verified = officerAuth.verifyOfficerLogin(login.email, login.password);
        expect(
          verified,
          isNotNull,
          reason: 'Login failed for ${login.email}',
        );
        expect(verified!.id, login.officerId);
      }
    });

    test('rejects wrong password for mobile test officers', () {
      for (final login in mobileTestOfficerLogins) {
        final verified = officerAuth.verifyOfficerLogin(login.email, '${login.password}x');
        expect(verified, isNull, reason: 'Wrong password accepted for ${login.email}');
      }
    });

    test('changed officer password persists after app restart', () async {
      final login = mobileTestOfficerLogins.first;
      const newPassword = 'ChangedOff99!';

      final changed = await officerAuth.changeOfficerPassword(
        login.officerId,
        login.password,
        newPassword,
        newPassword,
      );
      expect(changed.success, isTrue);
      expect(officerAuth.verifyOfficerLogin(login.email, newPassword), isNotNull);
      expect(officerAuth.verifyOfficerLogin(login.email, login.password), isNull);

      final storage = await StorageService.create();
      final restarted = OfficerAuthService(storage, ApiService(storage));
      await restarted.initialize();
      expect(restarted.verifyOfficerLogin(login.email, newPassword), isNotNull);
      expect(restarted.verifyOfficerLogin(login.email, login.password), isNull);
    });
  });
}
