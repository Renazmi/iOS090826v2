import 'dart:convert';

import '../config/storage_keys.dart';
import '../services/storage_service.dart';

class SavedLoginCredentials {
  const SavedLoginCredentials({
    required this.loginId,
    required this.password,
    required this.accountKind,
    required this.verifiedLoginId,
  });

  final String loginId;
  final String password;
  final String accountKind;
  final String verifiedLoginId;

  Map<String, dynamic> toJson() => {
        'loginId': loginId,
        'password': password,
        'accountKind': accountKind,
        'verifiedLoginId': verifiedLoginId,
      };

  factory SavedLoginCredentials.fromJson(Map<String, dynamic> json) {
    return SavedLoginCredentials(
      loginId: '${json['loginId'] ?? ''}'.trim(),
      password: '${json['password'] ?? ''}',
      accountKind: '${json['accountKind'] ?? 'student'}',
      verifiedLoginId: '${json['verifiedLoginId'] ?? json['loginId'] ?? ''}'.trim(),
    );
  }
}

SavedLoginCredentials? loadRememberedLogin(StorageService storage) {
  final raw = storage.readString(StorageKeys.rememberLogin);
  if (raw == null || raw.isEmpty) return null;
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! Map) return null;
    final saved = SavedLoginCredentials.fromJson(Map<String, dynamic>.from(parsed));
    if (saved.loginId.isEmpty || saved.password.isEmpty) return null;
    return saved;
  } catch (_) {
    return null;
  }
}

Future<void> saveRememberedLogin(
  StorageService storage,
  SavedLoginCredentials credentials,
) async {
  await storage.writeString(
    StorageKeys.rememberLogin,
    jsonEncode(credentials.toJson()),
  );
}

Future<void> clearRememberedLogin(StorageService storage) async {
  await storage.remove(StorageKeys.rememberLogin);
}

/// Updates a saved remember-me password after change or reset.
Future<void> updateRememberedPassword(
  StorageService storage, {
  required String newPassword,
  String? loginId,
  String? alternateLoginId,
}) async {
  final saved = loadRememberedLogin(storage);
  if (saved == null || newPassword.isEmpty) return;

  final candidates = <String>{
    if (loginId != null) loginId.trim().toLowerCase(),
    if (alternateLoginId != null) alternateLoginId.trim().toLowerCase(),
  }..removeWhere((value) => value.isEmpty);

  if (candidates.isEmpty) return;

  final savedIds = {
    saved.loginId.trim().toLowerCase(),
    saved.verifiedLoginId.trim().toLowerCase(),
  };
  if (savedIds.intersection(candidates).isEmpty) return;

  await saveRememberedLogin(
    storage,
    SavedLoginCredentials(
      loginId: saved.loginId,
      password: newPassword,
      accountKind: saved.accountKind,
      verifiedLoginId: saved.verifiedLoginId,
    ),
  );
}
