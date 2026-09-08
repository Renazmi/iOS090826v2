import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Client-side password digest for local demo storage (mirrors Angular `password-hash.ts`).
const passwordPepper = 'trackit-local-v1';
const passwordHashPrefix = 'h1:';

String hashPassword(String plaintext) {
  final value = plaintext;
  if (value.isEmpty) return '';
  final bytes = utf8.encode('$passwordPepper$value');
  return '$passwordHashPrefix${sha256.convert(bytes).toString()}';
}

bool verifyPassword(String plaintext, String? stored) {
  final input = plaintext;
  final saved = stored ?? '';
  if (input.isEmpty || saved.isEmpty) return false;
  if (saved.startsWith(passwordHashPrefix)) {
    return hashPassword(input) == saved;
  }
  return input == saved;
}

String normalizeStoredPassword(String stored) {
  if (stored.isEmpty || stored.startsWith(passwordHashPrefix)) return stored;
  return hashPassword(stored);
}

bool isHashedPassword(String? stored) {
  return (stored ?? '').startsWith(passwordHashPrefix);
}
