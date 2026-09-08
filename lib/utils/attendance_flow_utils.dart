import '../models/event_item.dart';
import '../services/app_state.dart';
import 'open_attendance_check_in.dart';

AttendanceCheckInMode? resolveAttendanceMode(AppState app, EventItem event) {
  if (_canTimeIn(app, event)) return AttendanceCheckInMode.timeIn;
  if (_canTimeOut(app, event)) return AttendanceCheckInMode.timeOut;
  return null;
}

String? attendanceModeError(AppState app, EventItem event) {
  if (event.cancelled) return 'This event was cancelled.';
  final status = app.events.effectiveStatus(event);
  if (status == EventStatus.upcoming) {
    return 'This event has not started yet.';
  }
  if (status == EventStatus.previous && event.expireQrWhenEventDone) {
    return 'This event has ended.';
  }
  if (resolveAttendanceMode(app, event) != null) return null;
  if (_hasTimedOut(app, event)) return 'You already timed out for this event.';
  if (_hasTimedIn(app, event)) {
    return 'You cannot time out for this event yet.';
  }
  return 'Time in is not available for this event right now.';
}

bool _canTimeIn(AppState app, EventItem event) {
  if (event.cancelled) return false;
  if (app.events.effectiveStatus(event) != EventStatus.current) return false;
  return !_hasTimedIn(app, event) && app.attendance.canTimeInNow(event);
}

bool _canTimeOut(AppState app, EventItem event) {
  if (event.cancelled) return false;
  if (app.events.effectiveStatus(event) != EventStatus.current) return false;
  return _hasTimedIn(app, event) &&
      !_hasTimedOut(app, event) &&
      app.attendance.canTimeOutNow(event);
}

bool _hasTimedIn(AppState app, EventItem event) => _myRecord(app, event) != null;

bool _hasTimedOut(AppState app, EventItem event) {
  final record = _myRecord(app, event);
  return record?.timedOutAt != null;
}

dynamic _myRecord(AppState app, EventItem event) {
  if (app.roles.isOfficer) {
    final officerId = app.auth.currentOfficer?.id;
    if (officerId == null) return null;
    return app.attendance.getOfficerRecord(event.id, officerId);
  }
  final studentId = app.auth.currentStudent?.studentId;
  if (studentId == null) return null;
  return app.attendance.getStudentRecord(event.id, studentId);
}
