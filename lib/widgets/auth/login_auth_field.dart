import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';

class LoginAuthField extends StatelessWidget {
  const LoginAuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.suffix,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? suffix;
  final bool readOnly;

  static const _labelColor = Color(0xFFAEAEAE);
  static const _hintColor = Color(0xFF8E8E93);
  static const _borderColor = Color(0xFF2C2C2E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: [
            ...?inputFormatters,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          cursorColor: AppTheme.loginRed,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.loginFieldBg,
            hintText: hint,
            hintStyle: const TextStyle(
              color: _hintColor,
              fontWeight: FontWeight.w400,
              fontSize: 15,
            ),
            prefixIcon: Icon(prefixIcon, color: _hintColor, size: 21),
            suffixIcon: suffix,
            suffixIconColor: _hintColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.loginRed.withValues(alpha: 0.65),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
