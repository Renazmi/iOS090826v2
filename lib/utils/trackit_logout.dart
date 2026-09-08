import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';

/// Shows a confirmation dialog, clears the session, then closes the app.
Future<void> confirmLogoutAndExit(
  BuildContext context, {
  required Future<void> Function() onLogout,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: Text(
          kIsWeb
              ? 'Are you sure you want to log out? You will return to the login screen.'
              : 'Are you sure you want to log out? TrackIT will close and you will need to open the app again to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  await onLogout();
  if (!context.mounted) return;

  if (kIsWeb) {
    context.go('/login');
    return;
  }

  SystemNavigator.pop();
}
