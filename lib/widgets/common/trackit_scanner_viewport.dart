import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';

/// Themed camera preview frame for QR scanning and in-app selfie preview.
class TrackitScannerViewport extends StatelessWidget {
  const TrackitScannerViewport({
    super.key,
    required this.height,
    required this.scanner,
    this.hint,
    this.overlayLabel,
  });

  final double height;
  final Widget scanner;
  final String? hint;
  final String? overlayLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;
    final frameInset = height * 0.12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null) ...[
          Text(
            hint!,
            style: TextStyle(color: colors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: colors.isDark ? Colors.black : AppTheme.blackSoft,
                  child: scanner,
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colors.isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppTheme.border,
                      ),
                    ),
                    child: Stack(
                      children: [
                        _ScannerDimOverlay(
                          isDark: colors.isDark,
                          frameInset: frameInset,
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(frameInset),
                            child: _ScannerCorners(isDark: colors.isDark),
                          ),
                        ),
                        if (overlayLabel != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: colors.isDark ? 0.62 : 0.48),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  overlayLabel!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerDimOverlay extends StatelessWidget {
  const _ScannerDimOverlay({
    required this.isDark,
    required this.frameInset,
  });

  final bool isDark;
  final double frameInset;

  @override
  Widget build(BuildContext context) {
    final scrim = isDark ? Colors.black.withValues(alpha: 0.58) : Colors.black.withValues(alpha: 0.34);

    return CustomPaint(
      painter: _DimOverlayPainter(
        scrimColor: scrim,
        frameInset: frameInset,
        cornerRadius: 18,
      ),
      size: Size.infinite,
    );
  }
}

class _DimOverlayPainter extends CustomPainter {
  _DimOverlayPainter({
    required this.scrimColor,
    required this.frameInset,
    required this.cornerRadius,
  });

  final Color scrimColor;
  final double frameInset;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(frameInset, frameInset, size.width - frameInset * 2, size.height - frameInset * 2),
          Radius.circular(cornerRadius),
        ),
      );
    final overlay = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(overlay, Paint()..color = scrimColor);
  }

  @override
  bool shouldRepaint(covariant _DimOverlayPainter oldDelegate) {
    return oldDelegate.scrimColor != scrimColor ||
        oldDelegate.frameInset != frameInset ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

class _ScannerCorners extends StatelessWidget {
  const _ScannerCorners({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const stroke = 4.0;
    const length = 28.0;
    final color = isDark ? AppTheme.red : AppTheme.redDark;

    Widget corner({required Alignment alignment, required bool flipX, required bool flipY}) {
      return Align(
        alignment: alignment,
        child: SizedBox(
          width: length,
          height: length,
          child: CustomPaint(
            painter: _CornerPainter(
              color: color,
              strokeWidth: stroke,
              flipX: flipX,
              flipY: flipY,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(alignment: Alignment.topLeft, flipX: false, flipY: false),
        corner(alignment: Alignment.topRight, flipX: true, flipY: false),
        corner(alignment: Alignment.bottomLeft, flipX: false, flipY: true),
        corner(alignment: Alignment.bottomRight, flipX: true, flipY: true),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.flipX,
    required this.flipY,
  });

  final Color color;
  final double strokeWidth;
  final bool flipX;
  final bool flipY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (!flipX && !flipY) {
      path.moveTo(0, size.height * 0.45);
      path.lineTo(0, 0);
      path.lineTo(size.width * 0.45, 0);
    } else if (flipX && !flipY) {
      path.moveTo(size.width, size.height * 0.45);
      path.lineTo(size.width, 0);
      path.lineTo(size.width * 0.55, 0);
    } else if (!flipX && flipY) {
      path.moveTo(0, size.height * 0.55);
      path.lineTo(0, size.height);
      path.lineTo(size.width * 0.45, size.height);
    } else {
      path.moveTo(size.width, size.height * 0.55);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width * 0.55, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => false;
}
