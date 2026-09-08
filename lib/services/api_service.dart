import 'storage_service.dart';

/// Future REST API client — currently delegates to [StorageService].
/// Replace method bodies with HTTP calls when Firebase/Node backend is connected.
class ApiService {
  ApiService(this._storage);

  final StorageService _storage;

  /// Base URL placeholder for future backend integration.
  static const defaultBaseUrl = 'https://api.trackit.local';

  String baseUrl = defaultBaseUrl;

  Future<List<Map<String, dynamic>>> fetchCollection(String storageKey) async {
    return _storage.readJsonList(storageKey);
  }

  Future<void> saveCollection(
    String storageKey,
    List<Map<String, dynamic>> data,
  ) async {
    await _storage.writeJsonList(storageKey, data);
  }

  Future<Map<String, dynamic>?> fetchDocument(String storageKey) async {
    return _storage.readJsonObject(storageKey);
  }

  Future<void> saveDocument(String storageKey, Map<String, dynamic> data) async {
    await _storage.writeJsonObject(storageKey, data);
  }
}
