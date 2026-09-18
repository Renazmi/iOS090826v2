import 'package:flutter_test/flutter_test.dart';
import 'package:trackit_mobile/models/event_item.dart';
import 'package:trackit_mobile/utils/attendance_punctuality.dart';

EventItem buildEvent({
  String whenTime = '08:00',
  String? timeInWindowStart = '06:00',
  String? timeInWindowEnd = '07:00',
  String? timeInWindowEndDate,
  int? lateGraceMinutes,
}) {
  return EventItem(
    id: 1,
    title: 'General Assembly',
    whenDate: '2026-09-15',
    whenTime: whenTime,
    where: 'Gym',
    assignAll: true,
    assignedOfficerIds: const [],
    officersAttended: 0,
    attendeesScanned: 0,
    officersTimedIn: 0,
    officersTimedOut: 0,
    attendeesTimedIn: 0,
    attendeesTimedOut: 0,
    status: EventStatus.current,
    createdAt: 0,
    timeInWindowStart: timeInWindowStart,
    timeInWindowEnd: timeInWindowEnd,
    timeInWindowEndDate: timeInWindowEndDate,
    lateGraceMinutes: lateGraceMinutes,
  );
}

int at(int hour, int minute, {int second = 0, int day = 15}) =>
    DateTime(2026, 9, day, hour, minute, second).millisecondsSinceEpoch;

void main() {
  test('time in up to the window end is present', () {
    final event = buildEvent();
    expect(resolvePunctualityStatus(event, at(6, 0)), PunctualityStatus.present);
    expect(resolvePunctualityStatus(event, at(6, 30)), PunctualityStatus.present);
    expect(resolvePunctualityStatus(event, at(7, 0)), PunctualityStatus.present);
    expect(resolvePunctualityStatus(event, at(7, 0, second: 59)), PunctualityStatus.present);
  });

  test('time in after the window end is late', () {
    final event = buildEvent();
    expect(resolvePunctualityStatus(event, at(7, 1)), PunctualityStatus.late);
    expect(resolvePunctualityStatus(event, at(7, 30)), PunctualityStatus.late);
    expect(resolvePunctualityStatus(event, at(12, 0)), PunctualityStatus.late);
  });

  test('falls back to the scheduled event time without a window end', () {
    final event = buildEvent(timeInWindowStart: null, timeInWindowEnd: null);
    expect(resolvePunctualityStatus(event, at(8, 0)), PunctualityStatus.present);
    expect(resolvePunctualityStatus(event, at(8, 1)), PunctualityStatus.late);
  });

  test('honours a configured grace period', () {
    final event = buildEvent(lateGraceMinutes: 5);
    expect(resolvePunctualityStatus(event, at(7, 5)), PunctualityStatus.present);
    expect(resolvePunctualityStatus(event, at(7, 6)), PunctualityStatus.late);
  });

  test('uses the window end date for multi-day windows', () {
    final event = buildEvent(timeInWindowEnd: '01:00', timeInWindowEndDate: '2026-09-16');
    expect(
      resolvePunctualityStatus(event, at(0, 59, day: 16)),
      PunctualityStatus.present,
    );
    expect(resolvePunctualityStatus(event, at(1, 1, day: 16)), PunctualityStatus.late);
  });
}
