import 'package:flutter/material.dart';

/// Layout helpers tuned for common Android phones (e.g. Redmi Note 8 Pro, 1080×2340).
class TrackitLayoutMetrics {
  TrackitLayoutMetrics._(this._context);

  final BuildContext _context;

  static TrackitLayoutMetrics of(BuildContext context) => TrackitLayoutMetrics._(context);

  MediaQueryData get _mq => MediaQuery.of(_context);

  Size get screenSize => _mq.size;

  double get screenWidth => screenSize.width;

  double get screenHeight => screenSize.height;

  EdgeInsets get viewPadding => _mq.viewPadding;

  EdgeInsets get viewInsets => _mq.viewInsets;

  /// Narrow phones (< 360 logical px) or split-screen windows.
  bool get isCompactWidth => screenWidth < 360;

  /// Short viewports (keyboard open, small devices, landscape).
  bool get isShortHeight => screenHeight < 640;

  double get pageHorizontalPadding => isCompactWidth ? 12 : 16;

  static const barHeight = 74.0;
  static const fabLift = 28.0;

  double get bottomNavHeight => barHeight + fabLift + viewPadding.bottom;

  /// Space below scroll content so the overlaid bottom nav never hides controls.
  double get scrollBottomPadding => bottomNavHeight + 12;

  double get headerLogoBarHeight => isCompactWidth ? 40 : 44;

  double get headerTotalHeight => viewPadding.top + headerLogoBarHeight;

  double get headerLogoHeight => isCompactWidth ? 26 : 30;

  /// Scale a design-token size down slightly on narrow screens.
  double scaled(double value) {
    if (screenWidth >= 400) return value;
    return value * (screenWidth / 400).clamp(0.88, 1.0);
  }

  /// QR preview height that leaves room for header, nav, and feedback cards.
  double get scannerViewportHeight {
    final reserved = headerTotalHeight + bottomNavHeight + 72;
    final available = screenHeight - reserved;
    return available.clamp(220.0, screenHeight * 0.48);
  }

  /// Square scan frame sized to the viewport width.
  double get scannerFrameSize {
    final maxByWidth = screenWidth - pageHorizontalPadding * 2 - 40;
    final maxByHeight = scannerViewportHeight - 48;
    return maxByWidth.clamp(180.0, 260.0).clamp(0, maxByHeight);
  }

  double get loginHorizontalPadding => isCompactWidth ? 20 : 32;

  double get loginButtonHeight => isShortHeight ? 48 : 52;
}

extension TrackitResponsiveContext on BuildContext {
  TrackitLayoutMetrics get layout => TrackitLayoutMetrics.of(this);
}

/// Clamps system text scaling so large accessibility settings do not break layouts.
MediaQueryData clampTrackitTextScale(MediaQueryData data) {
  final scale = data.textScaler.scale(1.0).clamp(0.85, 1.15);
  return data.copyWith(textScaler: TextScaler.linear(scale));
}
