import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../utils/attendance_selfie_picker.dart';
import '../common/trackit_scanner_viewport.dart';

/// In-app selfie capture for student registration — front/back camera with preview.
class RegistrationSelfieCaptureScreen extends StatefulWidget {
  const RegistrationSelfieCaptureScreen({super.key});

  @override
  State<RegistrationSelfieCaptureScreen> createState() =>
      _RegistrationSelfieCaptureScreenState();
}

class _RegistrationSelfieCaptureScreenState extends State<RegistrationSelfieCaptureScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const [];

  Uint8List? _previewBytes;
  String? _previewDataUrl;
  String? _errorMessage;
  bool _processing = false;
  bool _cameraReady = false;
  CameraLensDirection _lens = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    unawaited(_disposeCamera());
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _cameraReady = false;
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

  Future<void> _initCamera() async {
    if (_previewDataUrl != null) return;

    await _disposeCamera();
    if (!mounted) return;

    setState(() {
      _cameraReady = false;
      _errorMessage = null;
    });

    try {
      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
      }
      final description = _cameraForLens(_lens);
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

      _cameraController = controller;
      setState(() => _cameraReady = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _cameraErrorMessage(error));
    }
  }

  String _cameraErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission') || message.contains('authorized')) {
      return 'Camera permission is required. Allow camera access in settings, then tap Retry.';
    }
    return 'Could not start the camera. Tap Retry to try again.';
  }

  String get _alternateCameraLabel =>
      _lens == CameraLensDirection.front ? 'back' : 'front';

  Future<void> _flipCamera() async {
    if (_previewDataUrl != null || _processing) return;
    setState(() {
      _lens = _lens == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });
    await _initCamera();
  }

  Future<void> _retake() async {
    setState(() {
      _previewBytes = null;
      _previewDataUrl = null;
    });
    await _initCamera();
  }

  Future<void> _capture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _processing) return;

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      final dataUrl = encodeAttendanceSelfieDataUrl(bytes);

      await _disposeCamera();
      if (!mounted) return;

      setState(() {
        _processing = false;
        _previewBytes = bytes;
        _previewDataUrl = dataUrl;
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
        _errorMessage = 'Could not capture the photo. Try again.';
      });
    }
  }

  void _usePhoto() {
    final dataUrl = _previewDataUrl;
    if (dataUrl == null) return;
    Navigator.of(context).pop(dataUrl);
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height * 0.42;

    return Scaffold(
      backgroundColor: AppTheme.blackSoft,
      appBar: AppBar(
        backgroundColor: AppTheme.blackSoft,
        foregroundColor: Colors.white,
        title: const Text('Take a selfie'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Position your face in the frame. You can switch between the front and back camera.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _previewBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.memory(
                          _previewBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : TrackitScannerViewport(
                        height: viewportHeight,
                        hint: null,
                        overlayLabel: _cameraReady ? 'Face the camera' : 'Starting camera…',
                        scanner: _cameraReady && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : Center(
                                child: _errorMessage != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      )
                                    : const CircularProgressIndicator(color: AppTheme.loginRed),
                              ),
                      ),
              ),
              if (_errorMessage != null && _previewBytes == null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _initCamera,
                  child: const Text('Retry camera'),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_processing || (_previewBytes == null && !_cameraReady))
                          ? null
                          : (_previewBytes != null ? _retake : _flipCamera),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: Icon(
                        _previewBytes != null
                            ? Icons.refresh_rounded
                            : Icons.cameraswitch_rounded,
                      ),
                      label: Text(
                        _previewBytes != null
                            ? 'Retake'
                            : 'Switch to $_alternateCameraLabel camera',
                      ),
                    ),
                  ),
                  if (_previewBytes == null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_processing || !_cameraReady) ? null : _capture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(_processing ? 'Capturing…' : 'Capture'),
                      ),
                    ),
                  ],
                ],
              ),
              if (_previewBytes != null) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _usePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.loginRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('USE THIS PHOTO'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
