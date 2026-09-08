String? parsePasswordResetCode(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.contains('oobCode=')) {
    final queryStart = trimmed.indexOf('?');
    final query = queryStart >= 0 ? trimmed.substring(queryStart + 1) : trimmed;
    final params = Uri.splitQueryString(query);
    final fromParams = params['oobCode'];
    if (fromParams != null && fromParams.isNotEmpty) {
      return fromParams;
    }

    try {
      final uri = Uri.parse(trimmed);
      final code = uri.queryParameters['oobCode'];
      if (code != null && code.isNotEmpty) return code;
    } catch (_) {}
  }

  if (trimmed.length >= 20 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed)) {
    return trimmed;
  }

  return null;
}
