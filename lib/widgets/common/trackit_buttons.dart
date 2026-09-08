import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

class TrackitPrimaryButton extends StatelessWidget {
  const TrackitPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.useGradient = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label);

    if (useGradient) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.scanFabGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.red.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Center(child: child),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}

class TrackitOutlineButton extends StatelessWidget {
  const TrackitOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.onDark = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark
        ? (selected ? Colors.white : Colors.white.withValues(alpha: 0.75))
        : (selected ? AppTheme.red : AppTheme.textPrimary);
    final bg = onDark
        ? (selected ? Colors.white.withValues(alpha: 0.18) : Colors.transparent)
        : (selected ? AppTheme.red.withValues(alpha: 0.08) : AppTheme.surface);
    final border = onDark
        ? (selected ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.25))
        : (selected ? AppTheme.red : AppTheme.border);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border, width: selected ? 1.5 : 1),
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Pill segmented control for login role toggle.
class TrackitSegmentedToggle extends StatelessWidget {
  const TrackitSegmentedToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.onDark = true,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onDark ? Colors.black.withValues(alpha: 0.25) : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onDark ? Colors.white.withValues(alpha: 0.15) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? (onDark ? Colors.white.withValues(alpha: 0.16) : AppTheme.red.withValues(alpha: 0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: selectedIndex == i && onDark
                        ? Border.all(color: Colors.white.withValues(alpha: 0.25))
                        : null,
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: onDark
                          ? (selectedIndex == i ? Colors.white : Colors.white.withValues(alpha: 0.65))
                          : (selectedIndex == i ? AppTheme.red : AppTheme.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TrackitTextLinkButton extends StatelessWidget {
  const TrackitTextLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.light = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: light ? Colors.white.withValues(alpha: 0.85) : AppTheme.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
