import 'dart:convert';
import 'dart:typed_data';

const maxAttendanceSelfieBytes = 2 * 1024 * 1024;

/// Encodes captured selfie bytes as a data URL (matches web storage format).
String encodeAttendanceSelfieDataUrl(Uint8List bytes, {String mime = 'image/jpeg'}) {
  if (bytes.length > maxAttendanceSelfieBytes) {
    throw AttendanceSelfieException('Selfie image must be smaller than 2 MB.');
  }
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

Uint8List decodeAttendanceSelfieDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) {
    throw AttendanceSelfieException('Invalid selfie image data.');
  }
  return base64Decode(dataUrl.substring(comma + 1));
}

bool isValidAttendanceSelfieDataUrl(String value) {
  return value.trim().startsWith('data:image/');
}

class AttendanceSelfieException implements Exception {
  AttendanceSelfieException(this.message);
  final String message;

  @override
  String toString() => message;
}
