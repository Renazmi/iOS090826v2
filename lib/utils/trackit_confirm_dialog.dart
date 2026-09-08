import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Generic confirmation dialog for sensitive settings actions.
Future<bool> confirmTrackitAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? AppTheme.red : AppTheme.red,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
