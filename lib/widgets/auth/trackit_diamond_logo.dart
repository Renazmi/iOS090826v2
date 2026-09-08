import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// TrackIT mark — thick white ring with hollow split-color diamond inside.
class TrackitDiamondLogo extends StatelessWidget {
  const TrackitDiamondLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TrackitDiamondLogoPainter(),
      ),
    );
  }
}

class _TrackitDiamondLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final ringStroke = outerRadius * 0.11;
    final ringRadius = outerRadius - ringStroke / 2;

    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringStroke
        ..color = Colors.white,
    );

    final innerLimit = ringRadius - ringStroke * 0.85;
    final halfW = innerLimit * 0.46;
    final halfH = innerLimit * 0.50;
    final top = Offset(center.dx, center.dy - halfH);
    final right = Offset(center.dx + halfW, center.dy);
    final bottom = Offset(center.dx, center.dy + halfH);
    final left = Offset(center.dx - halfW, center.dy);

    final diamondStroke = ringStroke * 0.88;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = diamondStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    linePaint.color = AppTheme.loginRed;
    canvas.drawLine(top, right, linePaint);
    canvas.drawLine(top, left, linePaint);

    linePaint.color = AppTheme.loginSilver;
    canvas.drawLine(left, bottom, linePaint);
    canvas.drawLine(right, bottom, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Spinning red arc on a faint circular track — sits just outside the logo ring.
class TrackitLogoRingLoader extends StatelessWidget {
  const TrackitLogoRingLoader({
    super.key,
    required this.loaderSize,
    required this.logoSize,
    required this.rotationTurns,
    this.opacity = 1,
  });

  final double loaderSize;
  final double logoSize;
  final double rotationTurns;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.01) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: rotationTurns * 6.283185307,
          child: CustomPaint(
            size: Size(loaderSize, loaderSize),
            painter: _RingLoaderPainter(logoSize: logoSize),
            isComplex: true,
            willChange: true,
          ),
        ),
      ),
    );
  }
}

class _RingLoaderPainter extends CustomPainter {
  const _RingLoaderPainter({required this.logoSize});

  final double logoSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gap = logoSize * 0.07;
    final radius = logoSize / 2 + gap;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackStroke = (logoSize * 0.028).clamp(2.5, 4.0);
    final arcStroke = (logoSize * 0.034).clamp(3.0, 5.0);

    // Visible circular track the red segment travels along.
    canvas.drawArc(
      rect,
      0,
      6.283185307,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackStroke
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // Soft red glow behind the moving arc.
    canvas.drawArc(
      rect,
      -1.5707963268,
      1.745329252,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcStroke + 4
        ..strokeCap = StrokeCap.round
        ..color = AppTheme.loginRed.withValues(alpha: 0.22),
    );

    // Bright red loading arc (~100°) — clearly visible while rotating.
    canvas.drawArc(
      rect,
      -1.5707963268,
      1.745329252,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcStroke
        ..strokeCap = StrokeCap.round
        ..color = AppTheme.loginRed,
    );
  }

  @override
  bool shouldRepaint(covariant _RingLoaderPainter oldDelegate) =>
      oldDelegate.logoSize != logoSize;
}
