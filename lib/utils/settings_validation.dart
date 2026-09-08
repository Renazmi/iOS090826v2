/// Settings form validation — mirrors web `input-validation` and password rules.
abstract final class SettingsValidation {
  static const minPasswordLength = 8;

  static final _lettersPattern = RegExp(r"^[A-Za-zÑñ\s.'-]+$");
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidLetters(String value, {int minLength = 1}) {
    final trimmed = value.trim();
    return trimmed.length >= minLength && _lettersPattern.hasMatch(trimmed);
  }

  static bool isValidDigits(String value, {int min = 10, int max = 15}) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= min && digits.length <= max;
  }

  static bool isValidEmailFormat(String value) {
    return _emailPattern.hasMatch(value.trim().toLowerCase());
  }

  static String? validateStudentRegistration({
    required String fullName,
    required String gmail,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    final name = fullName.trim();
    if (name.isEmpty) {
      return 'Full name is required.';
    }
    if (!isValidLetters(name, minLength: 2)) {
      return 'Full name must contain letters only.';
    }

    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return 'Phone number is required.';
    }
    if (!isValidRegistrationPhone(trimmedPhone)) {
      return 'Phone number must be exactly 11 digits.';
    }

    final trimmedGmail = gmail.trim().toLowerCase();
    if (trimmedGmail.isEmpty || !isValidGmailAddress(trimmedGmail)) {
      return 'A valid Gmail address is required (@gmail.com).';
    }

    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }

    return null;
  }

  static String? validateRegistrationStudentId(String studentId) {
    final id = studentId.trim();
    if (id.isEmpty) {
      return 'Enter your Student ID.';
    }
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      return 'Student ID must contain digits only.';
    }
    if (id.length < 4 || id.length > 12) {
      return 'Student ID must be 4–12 digits.';
    }
    return null;
  }

  static bool isValidGmailAddress(String value) {
    return RegExp(r'^[^\s@]+@gmail\.com$', caseSensitive: false).hasMatch(value.trim());
  }

  static bool isValidRegistrationPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11;
  }

  static String? validateOfficerProfile({
    required String fullName,
    required String email,
    required String phone,
  }) {
    final name = fullName.trim();
    if (name.isEmpty) {
      return 'Enter your full name.';
    }
    if (!isValidLetters(name, minLength: 2)) {
      return 'Full name must contain letters only (at least 2 characters).';
    }

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return 'Gmail / username is required.';
    }
    if (!isValidEmailFormat(trimmedEmail)) {
      return 'Enter a valid email address (e.g. name@gmail.com).';
    }

    final trimmedPhone = phone.trim();
    if (trimmedPhone.isNotEmpty && !isValidDigits(trimmedPhone)) {
      return 'Phone number must contain 10–15 digits.';
    }

    return null;
  }

  static String? validateStudentProfile({
    required String fullName,
    required String gmail,
    required String phone,
  }) {
    final name = fullName.trim();
    if (name.isEmpty) {
      return 'Enter your full name.';
    }
    if (!isValidLetters(name, minLength: 2)) {
      return 'Full name must contain letters only.';
    }

    final trimmedGmail = gmail.trim().toLowerCase();
    if (trimmedGmail.isNotEmpty &&
        (!trimmedGmail.endsWith('@gmail.com') || !isValidEmailFormat(trimmedGmail))) {
      return 'Enter a valid Gmail address (@gmail.com).';
    }

    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return 'Enter your phone number.';
    }
    if (!isValidDigits(trimmedPhone)) {
      return 'Phone number must contain digits only (10–15 digits).';
    }

    return null;
  }

  static String? validateStudentPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (currentPassword.trim().isEmpty) {
      return 'Enter your current password.';
    }
    if (newPassword.trim().isEmpty) {
      return 'Enter a new password.';
    }
    if (newPassword.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    final strengthError = validateStrongPassword(newPassword);
    if (strengthError != null) {
      return strengthError;
    }
    if (newPassword != confirmPassword) {
      return 'New password and confirmation do not match.';
    }
    if (newPassword == currentPassword) {
      return 'New password must be different from your current password.';
    }
    return null;
  }

  static String? validateOfficerPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (currentPassword.trim().isEmpty) {
      return 'Enter your current password.';
    }
    if (newPassword.trim().isEmpty) {
      return 'Enter a new password.';
    }
    if (newPassword.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    final strengthError = validateStrongPassword(newPassword);
    if (strengthError != null) {
      return strengthError;
    }
    if (newPassword != confirmPassword) {
      return 'New password and confirmation do not match.';
    }
    if (newPassword == currentPassword) {
      return 'New password must be different from your current password.';
    }
    return null;
  }

  static List<PasswordRuleCheck> passwordRuleChecks(String password) {
    return [
      PasswordRuleCheck(
        id: 'length',
        label: 'At least $minPasswordLength characters',
        met: password.length >= minPasswordLength,
      ),
      PasswordRuleCheck(
        id: 'upper',
        label: 'One uppercase letter (A–Z)',
        met: RegExp(r'[A-Z]').hasMatch(password),
      ),
      PasswordRuleCheck(
        id: 'lower',
        label: 'One lowercase letter (a–z)',
        met: RegExp(r'[a-z]').hasMatch(password),
      ),
      PasswordRuleCheck(
        id: 'number',
        label: 'One number (0–9)',
        met: RegExp(r'[0-9]').hasMatch(password),
      ),
      PasswordRuleCheck(
        id: 'symbol',
        label: 'One symbol (! @ # \$ …)',
        met: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
      ),
    ];
  }

  static bool passwordStrengthMet(String password) {
    return passwordRuleChecks(password).every((rule) => rule.met);
  }

  static String? validateStrongPassword(String password) {
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include at least one number.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Password must include at least one symbol (e.g. ! @ # \$).';
    }
    return null;
  }
}

class PasswordRuleCheck {
  const PasswordRuleCheck({
    required this.id,
    required this.label,
    required this.met,
  });

  final String id;
  final String label;
  final bool met;
}
