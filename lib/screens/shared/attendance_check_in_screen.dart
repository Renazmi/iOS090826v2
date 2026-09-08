import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../models/event_item.dart';
import '../../models/officer.dart';
import '../../services/app_state.dart';
import '../../services/attendance_service.dart';
import '../../utils/attendance_selfie_picker.dart';
import '../../utils/event_qr_code.dart';
import '../../utils/trackit_responsive.dart';
import '../../widgets/common/trackit_app_background.dart';
import '../../widgets/common/trackit_decorations.dart';
import '../../widgets/common/trackit_scanner_viewport.dart';

enum AttendanceCheckInMode { timeIn, timeOut }

enum _AttendanceStep { qr, selfie }

/// QR → geofence verify → selfie → cancel/submit. Matches the web attendance modal flow.
class AttendanceCheckInScreen extends StatefulWidget {
  const AttendanceCheckInScreen({
    super.key,
    required this.event,
    required this.mode,
    this.verifiedQrPayload,
  });

  final EventItem event;
  final AttendanceCheckInMode mode;
  final String? verifiedQrPayload;

  @override
  State<AttendanceCheckInScreen> createState() => _AttendanceCheckInScreenState();
}

class _AttendanceCheckInScreenState extends State<AttendanceCheckInScreen> {
  final _qrController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  CameraController? _selfieCameraController;
  List<CameraDescription> _availableCameras = const [];
  final _manualQrController = TextEditingController();

  _AttendanceStep _step = _AttendanceStep.qr;
  String? _lastScan;
  String? _verifiedQrPayload;
  double? _verifiedLatitude;
  double? _verifiedLongitude;
  String? _selfiePreview;
  Uint8List? _selfiePreviewBytes;
  String? _errorMessage;
  bool _processing = false;
  bool _submitting = false;
  bool _selfieCameraReady = false;
  CameraLensDirection _selfieLens = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final preset = widget.verifiedQrPayload?.trim();
      if (preset != null && preset.isNotEmpty) {
        await _verifyQr(preset);
        return;
      }
      await _startQrCamera();
    });
  }

  @override
  void dispose() {
    _qrController.dispose();
    unawaited(_disposeSelfieCamera());
    _manualQrController.dispose();
    super.dispose();
  }

  Future<void> _disposeSelfieCamera() async {
    final controller = _selfieCameraController;
    _selfieCameraController = null;
    _selfieCameraReady = false;
    if (controller != null) {
      await controller.dispose();
    }
  }

  CameraDescription? _cameraForLens(CameraLensDirection lens) {
    for (final camera in _availableCameras) {
      if (camera.lensDirection == lens) return camera;
    }
    return _availableCameras.isEmpty ? null : _availableCameras.first;
  }

  Future<void> _initSelfieCamera() async {
    if (_step != _AttendanceStep.selfie || _selfiePreview != null) return;

    await _disposeSelfieCamera();
    if (!mounted) return;

    setState(() {
      _selfieCameraReady = false;
      _errorMessage = null;
    });

    try {
      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
      }
      final description = _cameraForLens(_selfieLens);
      if (description == null) {
        throw StateError('No camera available on this device.');
      }

      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _selfieCameraController = controller;
      setState(() => _selfieCameraReady = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _cameraErrorMessage(error));
    }
  }

  Future<void> _startQrCamera() async {
    if (_step != _AttendanceStep.qr) return;
    try {
      await _disposeSelfieCamera();
      await _qrController.start();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _cameraErrorMessage(error));
    }
  }

  Future<void> _startSelfiePreview() async {
    await _initSelfieCamera();
  }

  Future<void> _stopCameras() async {
    try {
      await _qrController.stop();
      await _disposeSelfieCamera();
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

  Future<({double? lat, double? lng})> _currentLocation() async {
    if (!widget.event.geofenceEnabled) return (lat: null, lng: null);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return (lat: null, lng: null);
    }

    final position = await Geolocator.getCurrentPosition();
    return (lat: position.latitude, lng: position.longitude);
  }

  Future<void> _verifyQr(String payload) async {
    if (_processing || _verifiedQrPayload != null) return;

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final app = context.read<AppState>();
    final coords = await _currentLocation();
    final result = app.attendance.validateEventQrForEventWithLocation(
      widget.event,
      payload,
      latitude: coords.lat,
      longitude: coords.lng,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _processing = false;
        _errorMessage = result.message;
        _lastScan = null;
      });
      return;
    }

    if (app.roles.isOfficer) {
      final officer = app.auth.currentOfficer;
      if (officer != null) {
        final assignError = _validateOfficerAssignment(widget.event, officer);
        if (assignError != null) {
          setState(() {
            _processing = false;
            _errorMessage = assignError.message;
            _lastScan = null;
          });
          return;
        }
      }
    }

    await _stopCameras();
    if (!mounted) return;

    setState(() {
      _processing = false;
      _verifiedQrPayload = payload.trim();
      _verifiedLatitude = coords.lat;
      _verifiedLongitude = coords.lng;
      _step = _AttendanceStep.selfie;
      _errorMessage = null;
    });
    await _startSelfiePreview();
  }

  AttendanceResult? _validateOfficerAssignment(EventItem event, Officer officer) {
    if (!event.assignAll && !event.assignedOfficerIds.contains(officer.id)) {
      return const AttendanceResult.fail('You are not assigned to this event.');
    }
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty || value == _lastScan) return;
    _lastScan = value;
    await _verifyQr(value);
  }

  Future<void> _submitManualQr() async {
    final payload = _manualQrController.text.trim();
    if (payload.isEmpty) {
      setState(() => _errorMessage = 'Enter the event code to verify.');
      return;
    }
    await _verifyQr(payload);
  }

  Future<void> _captureSelfie() async {
    final controller = _selfieCameraController;
    if (controller == null || !controller.value.isInitialized || _processing) return;

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      final dataUrl = encodeAttendanceSelfieDataUrl(bytes);

      await _disposeSelfieCamera();
      if (!mounted) return;

      setState(() {
        _processing = false;
        _selfiePreviewBytes = bytes;
        _selfiePreview = dataUrl;
        _selfieCameraReady = false;
      });
    } on AttendanceSelfieException catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorMessage = 'Could not capture the selfie. Try again.';
      });
    }
  }

  Future<void> _submitAttendance() async {
    if (_verifiedQrPayload == null || _selfiePreview == null) {
      setState(() => _errorMessage = 'Complete QR verification and take a selfie before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final app = context.read<AppState>();
    final coords = await _currentLocation();
    final lat = coords.lat ?? _verifiedLatitude;
    final lng = coords.lng ?? _verifiedLongitude;

    final AttendanceResult result;
    if (widget.mode == AttendanceCheckInMode.timeIn) {
      result = await _recordTimeIn(app, lat, lng, _selfiePreview!);
    } else {
      result = await _recordTimeOut(app, lat, lng, _selfiePreview!);
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.ok) {
      setState(() => _errorMessage = result.message);
      return;
    }

    await app.refreshDashboards();
    if (!mounted) return;

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.mode == AttendanceCheckInMode.timeIn
              ? 'Timed in successfully.'
              : 'Timed out successfully.',
        ),
        backgroundColor: AppTheme.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<AttendanceResult> _recordTimeIn(AppState app, double? lat, double? lng, String selfie) async {
    if (app.roles.isOfficer) {
      final officer = app.auth.currentOfficer;
      if (officer == null) return const AttendanceResult.fail('Officer session not found.');
      return app.attendance.recordOfficerTimeIn(
        widget.event,
        officer,
        latitude: lat,
        longitude: lng,
        selfieDataUrl: selfie,
      );
    }
    final student = app.auth.currentStudent;
    if (student == null) return const AttendanceResult.fail('Student session not found.');
    final roster = app.sections.findStudentById(student.studentId);
    return app.attendance.recordStudentTimeIn(
      widget.event,
      student,
      section: roster?.section,
      latitude: lat,
      longitude: lng,
      selfieDataUrl: selfie,
    );
  }

  Future<AttendanceResult> _recordTimeOut(AppState app, double? lat, double? lng, String selfie) async {
    if (app.roles.isOfficer) {
      final officerId = app.auth.currentOfficer?.id;
      if (officerId == null) return const AttendanceResult.fail('Officer session not found.');
      return app.attendance.recordOfficerTimeOut(
        widget.event,
        officerId,
        latitude: lat,
        longitude: lng,
        selfieDataUrl: selfie,
      );
    }
    final studentId = app.auth.currentStudent?.studentId;
    if (studentId == null) return const AttendanceResult.fail('Student session not found.');
    return app.attendance.recordStudentTimeOut(
      widget.event,
      studentId,
      latitude: lat,
      longitude: lng,
      selfieDataUrl: selfie,
    );
  }

  void _cancel() {
    _stopCameras();
    Navigator.of(context).pop(false);
  }

  Future<void> _flipSelfieCamera() async {
    if (_selfiePreview != null || _processing) return;

    final nextLens = _selfieLens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    setState(() => _selfieLens = nextLens);
    await _initSelfieCamera();
  }

  Future<void> _retakeSelfie() async {
    setState(() {
      _selfiePreview = null;
      _selfiePreviewBytes = null;
    });
    await _initSelfieCamera();
  }

  String get _alternateSelfieCameraLabel =>
      _selfieLens == CameraLensDirection.front ? 'back' : 'front';

  String get _title =>
      widget.mode == AttendanceCheckInMode.timeIn ? 'Time in' : 'Time out';

  String get _stepLabel => _step == _AttendanceStep.qr
      ? 'Step 1 of 2 — Scan event QR code ($_title)'
      : 'Step 2 of 2 — Take a selfie ($_title)';

  Widget _buildSelfieActionBar(BuildContext context, TrackitColors colors) {
    final hasPreview = _selfiePreviewBytes != null;

    return Material(
      color: colors.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_submitting || _processing || (!hasPreview && !_selfieCameraReady))
                          ? null
                          : (hasPreview ? _retakeSelfie : _flipSelfieCamera),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                      ),
                      icon: Icon(
                        hasPreview ? Icons.refresh_rounded : Icons.cameraswitch_rounded,
                      ),
                      label: Text(
                        hasPreview
                            ? 'Retake selfie'
                            : 'Switch to $_alternateSelfieCameraLabel camera',
                      ),
                    ),
                  ),
                  if (!hasPreview) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_submitting || _processing || !_selfieCameraReady)
                            ? null
                            : _captureSelfie,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(_processing ? 'Capturing…' : 'Capture'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: (_submitting || _selfiePreview == null) ? null : _submitAttendance,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.red.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Submit ${_title.toLowerCase()}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, TrackitColors colors) {
    return TrackitSurfaceCard(
      accentColor: AppTheme.red,
      child: Text(
        message,
        style: TextStyle(
          color: colors.isDark ? const Color(0xFFFF8A80) : AppTheme.redDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSelfieCaptureSection(BuildContext context, TrackitColors colors, TrackitLayoutMetrics layout) {
    final viewportHeight = layout.scannerViewportHeight.clamp(220.0, 320.0);

    if (_selfiePreviewBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: viewportHeight,
          width: double.infinity,
          child: Image.memory(
            _selfiePreviewBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    final controller = _selfieCameraController;
    if (!_selfieCameraReady || controller == null || !controller.value.isInitialized) {
      return SizedBox(
        height: viewportHeight,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.red),
        ),
      );
    }

    return TrackitScannerViewport(
      height: viewportHeight,
      overlayLabel: 'Center your face inside the frame',
      scanner: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? viewportHeight,
            height: controller.value.previewSize?.width ?? viewportHeight,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final colors = context.trackit;
    final bottomInset = layout.viewInsets.bottom;
    final scrollBottomPadding = _step == _AttendanceStep.selfie
        ? 16.0
        : layout.viewPadding.bottom + 16;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
        foregroundColor: Colors.white,
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _submitting ? null : _cancel,
        ),
      ),
      body: TrackitAppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, scrollBottomPadding + bottomInset),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stepLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      _buildErrorCard(_errorMessage!, colors),
                      const SizedBox(height: 12),
                    ],
                    if (_step == _AttendanceStep.qr) ...[
                      TrackitScannerViewport(
                        height: layout.scannerViewportHeight,
                        hint: widget.event.geofenceEnabled
                            ? 'Scan the event QR code with the rear camera. You must be inside the event area to continue.'
                            : 'Scan the event QR code with the rear camera to continue.',
                        overlayLabel: 'Align the QR code inside the frame',
                        scanner: MobileScanner(
                          controller: _qrController,
                          fit: BoxFit.cover,
                          onDetect: _onDetect,
                        ),
                      ),
                      if (_processing)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.red),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Or enter QR code manually',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        EventQrCode.shortCode(widget.event.id),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                            ),
                      ),
                      if (widget.event.geofenceEnabled) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Enter this code if you cannot scan. You must be inside the event area.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _manualQrController,
                        style: TextStyle(color: colors.textPrimary),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Event code',
                          hintText: EventQrCode.shortCode(widget.event.id),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _processing ? null : _submitManualQr,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Verify QR code'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _cancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ] else ...[
                      TrackitSurfaceCard(
                        accentColor: AppTheme.green,
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppTheme.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.event.geofenceEnabled
                                    ? 'QR verified and inside event area — take your selfie.'
                                    : 'QR verified — take your selfie.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSelfieCaptureSection(context, colors, layout),
                    ],
                  ],
                ),
              ),
            ),
            if (_step == _AttendanceStep.selfie) _buildSelfieActionBar(context, colors),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
