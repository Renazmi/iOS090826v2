import 'package:flutter/material.dart';

import '../models/event_item.dart';
import '../screens/shared/attendance_check_in_screen.dart';
import '../services/app_state.dart';

export '../screens/shared/attendance_check_in_screen.dart' show AttendanceCheckInMode;

/// Opens the unified attendance flow: QR → geofence → selfie → cancel/submit.
Future<bool?> openAttendanceCheckIn(
  BuildContext context, {
  required AppState app,
  required EventItem event,
  required AttendanceCheckInMode mode,
  String? verifiedQrPayload,
}) {
  return Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AttendanceCheckInScreen(
        event: event,
        mode: mode,
        verifiedQrPayload: verifiedQrPayload,
      ),
    ),
  );
}
