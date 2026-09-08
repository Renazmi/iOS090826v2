import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence layer — mirrors browser localStorage/sessionStorage keys
/// from the Ionic app. Swap implementations for HTTP when backend is ready.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  List<Map<String, dynamic>> readJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return [];
      return parsed.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeJsonList(String key, List<Map<String, dynamic>> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  Map<String, dynamic>? readJsonObject(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}
    return null;
  }

  Future<void> writeJsonObject(String key, Map<String, dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  int? readInt(String key) => _prefs.getInt(key);

  Future<void> writeInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }
}
