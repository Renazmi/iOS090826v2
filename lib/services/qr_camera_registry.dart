import 'package:mobile_scanner/mobile_scanner.dart';

/// Coordinates QR camera visibility when the scan tab is shown or hidden.
class QrCameraRegistry {
  QrCameraRegistry._();

  static final QrCameraRegistry instance = QrCameraRegistry._();

  MobileScannerController? _controller;
  void Function(bool visible)? _onVisibilityChanged;
  void Function()? _onReset;
  bool _scanTabActive = false;

  bool get scanTabActive => _scanTabActive;

  void attach(
    MobileScannerController controller, {
    void Function(bool visible)? onVisibilityChanged,
    void Function()? onReset,
  }) {
    _controller = controller;
    _onVisibilityChanged = onVisibilityChanged;
    _onReset = onReset;
    if (_scanTabActive) {
      _onVisibilityChanged?.call(true);
    }
  }

  void detach(MobileScannerController controller) {
    if (!identical(_controller, controller)) return;
    _controller = null;
    _onVisibilityChanged = null;
    _onReset = null;
  }

  void setScanTabActive(bool active) {
    if (_scanTabActive == active) return;
    _scanTabActive = active;
    _onVisibilityChanged?.call(active);
  }

  /// Re-opens the scanner when the center FAB is tapped while already on scan.
  void reactivateScanTab() {
    if (!_scanTabActive) return;
    _onReset?.call();
  }
}
