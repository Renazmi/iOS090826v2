import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../services/app_state.dart';

/// Confirms logout, clears the authenticated session, then opens the login screen.
Future<void> confirmLogoutAndExit(
  BuildContext context, {
  required AppState app,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out? You will return to the login screen.',
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

  final router = GoRouter.of(context);
  await app.auth.logout();
  app.notifyAuthChanged();
  router.go('/login');
}
