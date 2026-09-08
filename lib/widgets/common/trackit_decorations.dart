import 'dart:ui';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../utils/trackit_responsive.dart';

/// Full-screen red-to-black gradient used on the login screen.
class TrackitAuthBackground extends StatelessWidget {
  const TrackitAuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.authGradient),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              size: 220,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: _GlowOrb(
              size: 160,
              color: AppTheme.red.withValues(alpha: 0.15),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Frosted glass panel for login and overlays.
class TrackitGlassCard extends StatelessWidget {
  const TrackitGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Elevated white card with soft shadow — default in-app surface.
class TrackitSurfaceCard extends StatelessWidget {
  const TrackitSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: colors.cardShadow,
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: accentColor != null
                ? Border(left: BorderSide(color: accentColor!, width: 4))
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Page hero block with gradient strip for in-app screens.
class TrackitPageHero extends StatelessWidget {
  const TrackitPageHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final horizontal = context.layout.pageHorizontalPadding;
    return Container(
      margin: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.red.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Empty-state panel with icon.
class TrackitEmptyState extends StatelessWidget {
  const TrackitEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return TrackitSurfaceCard(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.red, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
