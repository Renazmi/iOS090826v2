import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Semantic colors that adapt between light and dark in-app themes.
@immutable
class TrackitColors extends ThemeExtension<TrackitColors> {
  const TrackitColors({
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.navSurface,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color navSurface;
  final bool isDark;

  static const light = TrackitColors(
    bg: AppTheme.bg,
    surface: AppTheme.surface,
    surfaceMuted: AppTheme.surfaceMuted,
    textPrimary: AppTheme.textPrimary,
    textSecondary: AppTheme.textSecondary,
    textMuted: AppTheme.textMuted,
    border: AppTheme.border,
    navSurface: AppTheme.surface,
    isDark: false,
  );

  static const dark = TrackitColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF141010),
    surfaceMuted: Color(0xFF1C1212),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB8B8B8),
    textMuted: Color(0xFF8A8A8A),
    border: Color(0xFF3A2020),
    navSurface: Color(0xFF0E0A0A),
    isDark: true,
  );

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: (isDark ? Colors.black : AppTheme.textPrimary).withValues(alpha: isDark ? 0.45 : 0.06),
          blurRadius: isDark ? 24 : 20,
          offset: const Offset(0, 8),
        ),
      ];

  List<BoxShadow> get softShadow => [
        BoxShadow(
          color: (isDark ? Colors.black : AppTheme.textPrimary).withValues(alpha: isDark ? 0.35 : 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  @override
  TrackitColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? navSurface,
    bool? isDark,
  }) {
    return TrackitColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      navSurface: navSurface ?? this.navSurface,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  TrackitColors lerp(ThemeExtension<TrackitColors>? other, double t) {
    if (other is! TrackitColors) return this;
    return TrackitColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension TrackitColorsContext on BuildContext {
  TrackitColors get trackit =>
      Theme.of(this).extension<TrackitColors>() ?? TrackitColors.light;
}
