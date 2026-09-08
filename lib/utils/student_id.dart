/// Keep digits only — letters, spaces, and special characters are removed.
String normalizeStudentId(String studentId) {
  return studentId.replaceAll(RegExp(r'\D'), '');
}

/// True when the value is a 4–12 digit Student ID with no letters or symbols.
bool isValidStudentId(String studentId) {
  return RegExp(r'^\d{4,12}$').hasMatch(normalizeStudentId(studentId));
}
