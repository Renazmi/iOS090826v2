import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackit_mobile/config/storage_keys.dart';
import 'package:trackit_mobile/services/api_service.dart';
import 'package:trackit_mobile/services/sections_service.dart';
import 'package:trackit_mobile/services/storage_service.dart';
import 'package:trackit_mobile/services/student_auth_service.dart';
import 'package:trackit_mobile/utils/firebase_action_link.dart';
import 'package:trackit_mobile/utils/password_hash.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('student auth login', () {
    test('verifyStudentLogin accepts registered gmail address', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      final sections = SectionsService(storage);
      final studentAuth = StudentAuthService(storage, ApiService(storage), sections);

      const studentId = '202501002';
      const gmail = 'carlo.login.test@gmail.com';
      const password = 'LoginTest99';

      await storage.writeJsonList(StorageKeys.students, [
        {
          'studentId': studentId,
          'fullName': 'Carlo Mendoza',
          'phone': '09171234599',
          'gmail': gmail,
          'password': hashPassword(password),
          'verified': true,
          'profileCompleted': true,
        },
      ]);

      expect(studentAuth.verifyStudentLogin(studentId, password)?.studentId, studentId);
      expect(studentAuth.verifyStudentLogin(gmail, password)?.studentId, studentId);
      expect(studentAuth.verifyStudentLogin(gmail.toUpperCase(), password)?.studentId, studentId);
      expect(studentAuth.verifyStudentLogin('wrong@gmail.com', password), isNull);
    });

    test('changeStudentPassword updates login and rejects the old password', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      final sections = SectionsService(storage);
      final studentAuth = StudentAuthService(storage, ApiService(storage), sections);

      const studentId = '202501003';
      const gmail = 'carlo.password.change@gmail.com';
      const currentPassword = 'OldPass99';
      const newPassword = 'NewPass88!';

      await storage.writeJsonList(StorageKeys.students, [
        {
          'studentId': studentId,
          'fullName': 'Carlo Mendoza',
          'phone': '09171234588',
          'gmail': gmail,
          'password': hashPassword(currentPassword),
          'verified': true,
          'profileCompleted': true,
        },
      ]);

      final result = await studentAuth.changeStudentPassword(
        studentId,
        currentPassword,
        newPassword,
        newPassword,
      );
      expect(result.success, isTrue);
      expect(studentAuth.verifyStudentLogin(studentId, newPassword)?.studentId, studentId);
      expect(studentAuth.verifyStudentLogin(studentId, currentPassword), isNull);
    });

    test('updateStudentAccount persists name, phone, and gmail locally', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      final sections = SectionsService(storage);
      final studentAuth = StudentAuthService(storage, ApiService(storage), sections);

      const studentId = '202501004';
      await storage.writeJsonList(StorageKeys.students, [
        {
          'studentId': studentId,
          'fullName': 'Old Name',
          'phone': '09171234000',
          'gmail': 'old.name@gmail.com',
          'password': hashPassword('OldPass99!'),
          'verified': true,
          'profileCompleted': true,
        },
      ]);

      final result = await studentAuth.updateStudentAccount(
        studentId,
        fullName: 'New Display Name',
        phone: '09179876543',
        gmail: 'new.display@gmail.com',
      );
      expect(result.success, isTrue);

      final updated = studentAuth.getStudentById(studentId);
      expect(updated?.fullName, 'New Display Name');
      expect(updated?.phone, '09179876543');
      expect(updated?.gmail, 'new.display@gmail.com');
    });
  });

  group('firebase verification code parsing', () {
    test('extracts oobCode from firebase action links', () {
      const code = 'ABC123xyz789012345678';
      expect(
        parseFirebaseOobCode(
          'https://trackit-fac8a.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=$code',
        ),
        code,
      );
      expect(parseFirebaseOobCode(code), code);
    });

    test('registration action code settings open in app', () {
      final settings = trackitFirebaseActionCodeSettings();
      expect(settings.iOSBundleId, trackitIosBundleId);
      expect(settings.androidPackageName, trackitAndroidPackageName);
      expect(settings.handleCodeInApp, isTrue);
    });

    test('password reset action code settings open in the installed app', () {
      final settings = trackitFirebasePasswordResetSettings();
      expect(settings.handleCodeInApp, isTrue);
      expect(settings.iOSBundleId, trackitIosBundleId);
      expect(settings.androidPackageName, trackitAndroidPackageName);
      expect(settings.url, startsWith(trackitWebAppOrigin));
    });

    test('password reset code is read from nested firebase app links', () {
      const code = 'ABC123xyz789012345678';
      final nested = Uri.parse(
        'https://trackit-fac8a.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=$code',
      );
      final wrapper = Uri.parse(
        'com.googleusercontent.apps.example://google/link?deep_link_id=${Uri.encodeComponent(nested.toString())}',
      );
      expect(readPasswordResetCodeFromUri(wrapper), code);
    });

    test('password reset web uri includes mode and oob code', () {
      const code = 'ABC123xyz789012345678';
      final uri = trackitPasswordResetWebUri(code);
      expect(uri.queryParameters['mode'], 'resetPassword');
      expect(uri.queryParameters['oobCode'], code);
    });
  });
}
