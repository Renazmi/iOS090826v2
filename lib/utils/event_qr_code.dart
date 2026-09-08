/// Short event codes for QR scans and manual attendance entry.
class EventQrCode {
  static String shortCode(int eventId) => 'EVT-$eventId';

  static String qrPayload(int eventId) => shortCode(eventId);

  static int? parsePayload(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return null;

    final legacy = RegExp(r'^TRACKIT-EVENT-(\d+)$', caseSensitive: false).firstMatch(trimmed);
    if (legacy != null) return _parsePositiveInt(legacy.group(1)!);

    final short = RegExp(r'^EVT-?(\d+)$', caseSensitive: false).firstMatch(trimmed);
    if (short != null) return _parsePositiveInt(short.group(1)!);

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return _parsePositiveInt(trimmed);
    }

    return null;
  }

  static int? _parsePositiveInt(String raw) {
    final id = int.tryParse(raw);
    if (id == null || id <= 0) return null;
    return id;
  }
}
