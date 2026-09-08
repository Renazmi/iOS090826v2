import 'package:flutter/material.dart';

import 'trackit_colors.dart';

/// TrackIT design tokens — mirrors web tokens with mobile-first extensions.
abstract final class AppTheme {
  static const red = Color(0xFFE53935);
  static const redDark = Color(0xFFC62828);
  static const redDeep = Color(0xFF7B1515);
  static const loginRed = Color(0xFFC62828);
  static const loginBg = Color(0xFF000000);
  static const loginFieldBg = Color(0xFF1E1E1E);
  static const loginSilver = Color(0xFFB8B8B8);
  static const black = Color(0xFF0A0A0A);
  static const blackSoft = Color(0xFF141414);
  static const bg = Color(0xFFF4F6F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF5C6B7F);
  static const textMuted = Color(0xFF8B97A8);
  static const border = Color(0xFFDDE3EC);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFD97706);
  static const blue = Color(0xFF2563EB);

  /// Login screen — red at top fading to black.
  static const authGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE53935),
      Color(0xFF9B1C1C),
      Color(0xFF1A1A1A),
      Color(0xFF0A0A0A),
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [red, redDark],
  );

  static const scanFabGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF5350), redDark],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: textPrimary.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: textPrimary.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      extensions: const [TrackitColors.light],
      colorScheme: ColorScheme.fromSeed(
        seedColor: red,
        primary: red,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.6),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, color: textMuted),
      ),
    );
  }

  static ThemeData dark() {
    const primaryText = Color(0xFFF5F5F5);
    const secondaryText = Color(0xFFB8B8B8);
    const mutedText = Color(0xFF8A8A8A);
    const darkSurface = Color(0xFF141010);
    const darkBorder = Color(0xFF3A2020);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: const [TrackitColors.dark],
      colorScheme: ColorScheme.fromSeed(
        seedColor: red,
        brightness: Brightness.dark,
        primary: red,
        onPrimary: Colors.white,
        surface: darkSurface,
        onSurface: primaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: darkBorder.withValues(alpha: 0.6),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: loginFieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkBorder.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
        labelStyle: const TextStyle(color: secondaryText, fontSize: 13),
        hintStyle: const TextStyle(color: mutedText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: primaryText,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: secondaryText, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, color: mutedText),
      ),
    );
  }
}
