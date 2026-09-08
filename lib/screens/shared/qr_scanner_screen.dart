import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../services/app_state.dart';
import '../../services/qr_camera_registry.dart';
import '../../utils/attendance_flow_utils.dart';
import '../../utils/open_attendance_check_in.dart';
import '../../utils/trackit_responsive.dart';
import '../../widgets/common/trackit_decorations.dart';
import '../../widgets/common/trackit_page_layout.dart';
import '../../widgets/common/trackit_scanner_viewport.dart';

/// Center nav scan tab — live event QR scanner that opens attendance flow.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  String? _lastScan;
  String? _errorMessage;
  String? _statusMessage;
  bool _processing = false;
  bool _cameraVisible = false;

  @override
  void initState() {
    super.initState();
    QrCameraRegistry.instance.attach(
      _controller,
      onVisibilityChanged: _onScanTabVisibilityChanged,
      onReset: _resetScanner,
    );
  }

  @override
  void dispose() {
    QrCameraRegistry.instance.detach(_controller);
    _controller.dispose();
    super.dispose();
  }

  void _onScanTabVisibilityChanged(bool visible) {
    if (!mounted) return;
    setState(() => _cameraVisible = visible);
    if (visible) {
      unawaited(_startCamera());
    } else {
      unawaited(_stopCamera());
    }
  }

  Future<void> _resetScanner() async {
    if (!mounted) return;
    setState(() {
      _lastScan = null;
      _errorMessage = null;
      _statusMessage = null;
      _processing = false;
    });
    await _startCamera();
  }

  Future<void> _startCamera() async {
    if (!QrCameraRegistry.instance.scanTabActive || _processing) return;
    try {
      await _controller.start();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _cameraErrorMessage(error));
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _controller.stop();
    } catch (_) {}
  }

  String _cameraErrorMessage(Object error) {
    if (error is MobileScannerException) {
      switch (error.errorCode) {
        case MobileScannerErrorCode.permissionDenied:
          return 'Camera permission is required. Allow camera access in settings, then tap Retry.';
        default:
          return 'Could not start the camera. Tap Retry to try again.';
      }
    }
    return 'Could not start the camera. Tap Retry to try again.';
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    final payload = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (payload == null || payload.isEmpty || payload == _lastScan) return;

    final app = context.read<AppState>();
    final eventId = app.attendance.parseEventQrPayload(payload);
    if (eventId == null) {
      setState(() {
        _lastScan = payload;
        _errorMessage = 'Invalid event QR code. Scan the official TrackIT event QR.';
      });
      return;
    }

    final event = app.events.getById(eventId);
    if (event == null) {
      setState(() {
        _lastScan = payload;
        _errorMessage = 'Event #$eventId was not found.';
      });
      return;
    }

    final mode = resolveAttendanceMode(app, event);
    if (mode == null) {
      setState(() {
        _lastScan = payload;
        _errorMessage = attendanceModeError(app, event) ??
            'Time in or time out is not available for this event right now.';
      });
      return;
    }

    setState(() {
      _processing = true;
      _lastScan = payload;
      _errorMessage = null;
      _statusMessage = 'Opening ${event.title}…';
    });

    await _stopCamera();
    if (!mounted) return;

    await openAttendanceCheckIn(
      context,
      app: app,
      event: event,
      mode: mode,
      verifiedQrPayload: payload,
    );

    if (!mounted) return;
    setState(() {
      _processing = false;
      _lastScan = null;
      _statusMessage = null;
    });

    if (QrCameraRegistry.instance.scanTabActive) {
      await _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final colors = context.trackit;

    return TrackitPageLayout(
      title: 'Scan QR',
      subtitle: 'Scan an event QR code to time in or time out.',
      showHero: false,
      topPadding: 0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            TrackitSurfaceCard(
              accentColor: AppTheme.red,
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: colors.isDark ? const Color(0xFFFF8A80) : AppTheme.redDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _resetScanner,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.border),
              ),
              child: const Text('Scan again'),
            ),
            const SizedBox(height: 12),
          ],
          if (_statusMessage != null) ...[
            TrackitSurfaceCard(
              accentColor: AppTheme.blue,
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TrackitScannerViewport(
            height: layout.scannerViewportHeight,
            hint: 'Point your camera at the event QR code. Attendance opens automatically after a valid scan.',
            overlayLabel: 'Align the event QR inside the frame',
            scanner: _cameraVisible
                ? MobileScanner(
                    controller: _controller,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                  )
                : ColoredBox(
                    color: colors.isDark ? Colors.black : AppTheme.blackSoft,
                    child: Center(
                      child: Icon(Icons.qr_code_scanner_rounded, size: 48, color: colors.textMuted),
                    ),
                  ),
          ),
          if (_processing)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator(color: AppTheme.red)),
            ),
          const SizedBox(height: 16),
          TrackitSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'After scanning',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. QR is verified\n2. Geofence check runs if enabled\n3. Take your selfie\n4. Submit to record attendance',
                  style: TextStyle(color: colors.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
