import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/mobile_nav_config.dart';
import '../models/trackit_role.dart';
import '../services/app_state.dart';

/// Opens the scan branch in the bottom nav shell (attendance instructions).
void openScanTab(
  BuildContext context,
  AppState app, {
  int? timeInEventId,
}) {
  final role = app.roles.currentRole;
  if (role == null) return;

  app.attendanceFlow.clearPendingTimeIn();

  final scanIndex = MobileNavConfig.scanBranchIndex(role);
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(
      scanIndex,
      initialLocation: shell.currentIndex == scanIndex,
    );
    return;
  }

  final prefix = role == TrackitRole.officer ? '/officer' : '/student';
  context.go('$prefix/scan');
}
