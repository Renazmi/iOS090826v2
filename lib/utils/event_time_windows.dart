import '../models/event_item.dart';

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

  /// Time in is gated by the window start only. The window end is the
  /// Present/Late threshold, so it never blocks a late time in.
  static String? getTimeInOpensMessage(String whenDate, String? start, {DateTime? now}) {
    final startTrimmed = start?.trim() ?? '';
    if (startTrimmed.isEmpty) return null;
    final startDt = parseLocalDateTime(whenDate, startTrimmed);
    if (startDt == null) return null;
    if ((now ?? DateTime.now()).isBefore(startDt)) {
      return 'Time in opens $whenDate at $startTrimmed.';
    }
    return null;
  }

  static bool isTimeInOpen(String whenDate, String? start, {DateTime? now}) =>
      getTimeInOpensMessage(whenDate, start, now: now) == null;

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

  static EventStatus resolveLiveEventStatus({
    required String whenDate,
    String? whenTime,
    String? timeInWindowStart,
    String? timeOutWindowEnd,
    String? timeOutWindowEndDate,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final startTime = (whenTime ?? '00:00').trim().isEmpty ? '00:00' : (whenTime ?? '00:00').trim();
    var start = parseLocalDateTime(whenDate, startTime);
    // Time in may open before the scheduled time, so the event turns current then.
    final inStart = timeInWindowStart?.trim();
    if (start != null && inStart != null && inStart.isNotEmpty) {
      final windowStart = parseLocalDateTime(whenDate, inStart);
      if (windowStart != null && windowStart.isBefore(start)) {
        start = windowStart;
      }
    }
    if (start == null) {
      final today = todayDateKey();
      if (whenDate.compareTo(today) > 0) return EventStatus.upcoming;
      if (whenDate.compareTo(today) < 0) return EventStatus.previous;
      return EventStatus.current;
    }

    if (clock.isBefore(start)) return EventStatus.upcoming;

    var end = DateTime(start.year, start.month, start.day, 23, 59, 59, 999);
    final outEnd = timeOutWindowEnd?.trim();
    if (outEnd != null && outEnd.isNotEmpty) {
      final endDate = (timeOutWindowEndDate?.trim().isNotEmpty == true)
          ? timeOutWindowEndDate!.trim()
          : whenDate;
      final windowEnd = parseLocalDateTime(endDate, outEnd);
      if (windowEnd != null && windowEnd.isAfter(end)) {
        end = windowEnd;
      }
    }

    if (clock.isAfter(end)) return EventStatus.previous;
    return EventStatus.current;
  }
}
