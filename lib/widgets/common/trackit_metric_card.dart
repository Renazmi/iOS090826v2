import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import 'trackit_decorations.dart';

class TrackitMetricCard extends StatelessWidget {
  const TrackitMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accentColor = AppTheme.red,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return TrackitSurfaceCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.18),
                  accentColor.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact 2-column metric grid for dashboards.
class TrackitMetricGrid extends StatelessWidget {
  const TrackitMetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final width = (maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children.map((child) => SizedBox(width: width, child: child)).toList(),
        );
      },
    );
  }
}

class TrackitCompactMetric extends StatelessWidget {
  const TrackitCompactMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accentColor = AppTheme.red,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: colors.softShadow,
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
