import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/app_theme.dart';
import '../../services/events_service.dart';
import '../../utils/event_qr_code.dart';

Future<void> showEventQrDialog(
  BuildContext context, {
  required int eventId,
  required String title,
  required EventsService events,
}) {
  final payload = EventQrCode.qrPayload(eventId);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Share this QR code or event code for attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: QrImageView(data: payload, size: 220, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              SelectableText(payload, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go('/officer/events/publish?edit=$eventId');
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
                  child: const Text('Edit event details'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go('/officer/events');
                  },
                  child: const Text('Go to event list'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
