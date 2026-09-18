import '../models/event_item.dart';
import 'event_time_windows.dart';

enum PunctualityStatus { present, late }

String punctualityLabel(PunctualityStatus status) =>
    status == PunctualityStatus.late ? 'Late' : 'Present';

/// Attendance Status for attendees. Never used as Assignment Status.
String attendeeAttendanceLabel(String? status) {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'late':
      return 'Late';
    case 'absent':
      return 'Absent';
    case 'excused':
      return 'Excused';
    case 'present':
      return 'Present';
    default:
      return '—';
  }
}

PunctualityStatus? parseStoredPunctuality(Object? value) {
  final raw = (value is String ? value : '').trim().toLowerCase();
  if (raw == 'present') return PunctualityStatus.present;
  if (raw == 'late') return PunctualityStatus.late;
  return null;
}

String punctualityToJson(PunctualityStatus status) =>
    status == PunctualityStatus.late ? 'late' : 'present';

/// Last moment that still counts as Present: the time-in window end when set,
/// otherwise the scheduled event time.
DateTime? resolvePunctualityDeadline(EventItem event) {
  final windowEnd = event.timeInWindowEnd?.trim() ?? '';
  if (windowEnd.isNotEmpty) {
    final endDateKey = event.timeInWindowEndDate?.trim().isNotEmpty == true
        ? event.timeInWindowEndDate!.trim()
        : event.whenDate.trim();
    final deadline = EventTimeWindows.parseLocalDateTime(endDateKey, windowEnd);
    if (deadline != null) return deadline;
  }

  final scheduled = event.whenTime.trim();
  if (scheduled.isEmpty) return null;
  return EventTimeWindows.parseLocalDateTime(event.whenDate, scheduled);
}

/// Present when timed in at or before the deadline minute, Late from the next
/// minute onward. No grace period unless an administrator configures one.
PunctualityStatus resolvePunctualityStatus(EventItem event, int timedInAt) {
  final deadline = resolvePunctualityDeadline(event);
  if (deadline == null) return PunctualityStatus.present;

  final grace = event.lateGraceMinutes ?? 0;
  final allowedUntil = DateTime(
    deadline.year,
    deadline.month,
    deadline.day,
    deadline.hour,
    deadline.minute,
  ).add(Duration(minutes: grace < 0 ? 0 : grace));

  final clockIn = DateTime.fromMillisecondsSinceEpoch(timedInAt);
  final clockInMinute =
      DateTime(clockIn.year, clockIn.month, clockIn.day, clockIn.hour, clockIn.minute);
  return clockInMinute.isAfter(allowedUntil) ? PunctualityStatus.late : PunctualityStatus.present;
}
