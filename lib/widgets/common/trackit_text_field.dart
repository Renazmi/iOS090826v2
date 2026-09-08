import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';

enum TrackitFieldVariant { light, dark }

class TrackitTextField extends StatelessWidget {
  const TrackitTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.suffix,
    this.readOnly = false,
    this.variant = TrackitFieldVariant.light,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? suffix;
  final bool readOnly;
  final TrackitFieldVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = variant == TrackitFieldVariant.dark;
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.85) : AppTheme.textSecondary;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.surface;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.2) : AppTheme.border;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final hintColor = isDark ? Colors.white.withValues(alpha: 0.45) : AppTheme.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          enableInteractiveSelection: !readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: [
            ...?inputFormatters,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          cursorColor: isDark ? Colors.white : AppTheme.red,
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            hintStyle: TextStyle(color: hintColor),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.7) : AppTheme.red,
                width: 1.5,
              ),
            ),
            suffixIcon: suffix,
            suffixIconColor: isDark ? Colors.white70 : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
