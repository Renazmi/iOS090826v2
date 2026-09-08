/// Shared HH:mm window helpers for event time-in / time-out.
class EventTimeWindows {
  static int? parseTimeMinutes(String hhmm) {
    final trimmed = hhmm.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  static DateTime? parseLocalDateTime(String dateKey, String hhmm) {
    final parts = dateKey.trim().split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    final totalMinutes = parseTimeMinutes(hhmm);
    if (year == null || month == null || day == null || totalMinutes == null) return null;
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return DateTime(year, month, day, hours, mins);
  }

  static String todayDateKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  static bool isEventDateToday(String whenDate) => whenDate.trim() == todayDateKey();

  static String? getTimeWindowValidationError(String? start, String? end, String label) {
    final startTrimmed = start?.trim() ?? '';
    final endTrimmed = end?.trim() ?? '';
    if (startTrimmed.isEmpty && endTrimmed.isEmpty) return null;
    if (startTrimmed.isEmpty || endTrimmed.isEmpty) {
      return 'Set both $label start and end times, or leave both blank.';
    }
    final startMinutes = parseTimeMinutes(startTrimmed);
    final endMinutes = parseTimeMinutes(endTrimmed);
    if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
      return '$label end must be after the start time.';
    }
    return null;
  }

  static String? getConfiguredWindowBlockMessage(
    String whenDate,
    String? start,
    String? end,
    String actionLabel, {
    String? endDate,
  }) {
    final startTrimmed = start?.trim() ?? '';
    final endTrimmed = end?.trim() ?? '';
    if (startTrimmed.isEmpty || endTrimmed.isEmpty) return null;

    final endDateKey = (endDate?.trim().isNotEmpty == true ? endDate!.trim() : whenDate.trim());
    final startDt = parseLocalDateTime(whenDate, startTrimmed);
    final endDt = parseLocalDateTime(endDateKey, endTrimmed);
    if (startDt == null || endDt == null) return null;

    final now = DateTime.now();
    final capitalized = actionLabel.isEmpty
        ? actionLabel
        : '${actionLabel[0].toUpperCase()}${actionLabel.substring(1)}';

    if (now.isBefore(startDt)) {
      return '$capitalized opens $whenDate at $startTrimmed.';
    }
    if (now.isAfter(endDt)) {
      return '$capitalized closed $endDateKey at $endTrimmed.';
    }
    return null;
  }

  static bool isWithinConfiguredWindow(
    String whenDate,
    String? start,
    String? end, {
    String? endDate,
  }) {
    if (start?.trim().isEmpty != false || end?.trim().isEmpty != false) return true;
    return getConfiguredWindowBlockMessage(
          whenDate,
          start,
          end,
          'time in',
          endDate: endDate,
        ) ==
        null;
  }
}
