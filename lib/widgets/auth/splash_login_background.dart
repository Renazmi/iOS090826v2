import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Login backdrop — solid black during splash loading, then gradient + arc rise from below.
class SplashLoginBackground extends StatelessWidget {
  const SplashLoginBackground({
    super.key,
    required this.child,
    this.glowReveal = 1,
  });

  /// 0 = loading (plain black). 1 = full gradient + bottom circle visible.
  final double glowReveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reveal = glowReveal.clamp(0.0, 1.0);
    final slideY = (1 - reveal) * MediaQuery.sizeOf(context).height * 0.55;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF000000)),
        RepaintBoundary(
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(0, slideY),
              child: Opacity(
                opacity: reveal,
                child: const CustomPaint(
                  painter: TrackitLoginGlowPainter(),
                  isComplex: true,
                  willChange: false,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class TrackitLoginGlowPainter extends CustomPainter {
  const TrackitLoginGlowPainter();

  static const _redBright = Color(0xFFEF2B2B);
  static const _redDeep = Color(0xFF6E1212);
  static const _capDark = Color(0xFF040101);
  static const _capBlack = Color(0xFF010000);

  ({Offset center, double radius, double horizonY}) _sphere(Size size) {
    final radius = size.width * 0.78;
    final center = Offset(size.width * 0.5, size.height + radius * 0.68);
    final horizonY = center.dy - radius;
    return (center: center, radius: radius, horizonY: horizonY);
  }

  Path _capClip(
    Size size,
    Offset sphereCenter,
    double sphereRadius,
    double horizonY,
  ) {
    return Path()
      ..moveTo(0, horizonY)
      ..arcTo(
        Rect.fromCircle(center: sphereCenter, radius: sphereRadius),
        3.1415926535,
        3.1415926535,
        false,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sphere = _sphere(size);
    final capClip = _capClip(size, sphere.center, sphere.radius, sphere.horizonY);

    _paintBaseGradient(canvas, size);
    _paintBackGlow(canvas, sphere.center, sphere.radius, capClip);
    _paintBackRimLight(canvas, sphere.center, sphere.radius);
    _paintArcBloom(canvas, sphere.center, sphere.radius);
    _paintArcRim(canvas, sphere.center, sphere.radius);
  }

  void _paintBaseGradient(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, size.height),
          const [
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0xFF050203),
            Color(0xFF0A0405),
            Color(0xFF120707),
            Color(0xFF1A0909),
            Color(0xFF240C0C),
            Color(0xFF301010),
          ],
          const [0.0, 0.38, 0.52, 0.64, 0.74, 0.84, 0.92, 1.0],
        ),
    );
  }

  void _paintBackGlow(
    Canvas canvas,
    Offset sphereCenter,
    double sphereRadius,
    Path capClip,
  ) {
    canvas.save();
    canvas.clipPath(capClip);

    canvas.drawCircle(
      sphereCenter,
      sphereRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          sphereCenter,
          sphereRadius,
          [
            _redDeep.withValues(alpha: 0.28),
            _redDeep.withValues(alpha: 0.16),
            _capDark.withValues(alpha: 0.72),
            Colors.transparent,
          ],
          const [0.0, 0.32, 0.62, 1.0],
        ),
    );

    canvas.drawCircle(
      sphereCenter,
      sphereRadius * 0.72,
      Paint()
        ..shader = ui.Gradient.radial(
          sphereCenter,
          sphereRadius * 0.72,
          [
            _capBlack.withValues(alpha: 0.82),
            _capDark.withValues(alpha: 0.55),
            Colors.transparent,
          ],
          const [0.0, 0.50, 1.0],
        ),
    );

    canvas.drawRect(
      capClip.getBounds(),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(sphereCenter.dx, sphereCenter.dy - sphereRadius),
          Offset(sphereCenter.dx, sphereCenter.dy + sphereRadius),
          [
            _capBlack.withValues(alpha: 0.35),
            _capBlack.withValues(alpha: 0.72),
            _capDark.withValues(alpha: 0.88),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    canvas.restore();
  }

  void _paintBackRimLight(Canvas canvas, Offset sphereCenter, double sphereRadius) {
    final arcRect = Rect.fromCircle(center: sphereCenter, radius: sphereRadius);
    const start = 3.1415926535;
    const sweep = 3.1415926535;

    for (final layer in [
      (w: 28.0, blur: 36.0, alpha: 0.10),
      (w: 18.0, blur: 22.0, alpha: 0.16),
      (w: 10.0, blur: 12.0, alpha: 0.24),
    ]) {
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.w
          ..color = _redBright.withValues(alpha: layer.alpha)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, layer.blur),
      );
    }
  }

  void _paintArcBloom(Canvas canvas, Offset sphereCenter, double sphereRadius) {
    final arcRect = Rect.fromCircle(center: sphereCenter, radius: sphereRadius);
    const start = 3.1415926535;
    const sweep = 3.1415926535;

    for (final layer in [
      (w: 16.0, blur: 22.0, alpha: 0.08),
      (w: 10.0, blur: 13.0, alpha: 0.14),
      (w: 5.0, blur: 7.0, alpha: 0.22),
    ]) {
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.w
          ..color = _redBright.withValues(alpha: layer.alpha)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, layer.blur),
      );
    }
  }

  void _paintArcRim(Canvas canvas, Offset sphereCenter, double sphereRadius) {
    final arcRect = Rect.fromCircle(center: sphereCenter, radius: sphereRadius);
    const start = 3.1415926535;
    const sweep = 3.1415926535;

    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _redBright,
    );

    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55
        ..color = Colors.white.withValues(alpha: 0.30),
    );
  }

  @override
  bool shouldRepaint(covariant TrackitLoginGlowPainter oldDelegate) => false;
}
