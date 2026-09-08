import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/trackit_colors.dart';
import '../../services/app_state.dart';
import '../auth/splash_login_background.dart';

/// In-app backdrop — light gray in light mode, black + red glow like login in dark mode.
class TrackitAppBackground extends StatelessWidget {
  const TrackitAppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Rebuild when theme toggles (web sometimes misses Theme-only updates).
    context.watch<AppState>();
    final colors = context.trackit;

    if (!colors.isDark) {
      return ColoredBox(color: colors.bg, child: child);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF000000)),
        const RepaintBoundary(
          child: CustomPaint(
            painter: TrackitLoginGlowPainter(),
            isComplex: true,
            willChange: false,
          ),
        ),
        child,
      ],
    );
  }
}
