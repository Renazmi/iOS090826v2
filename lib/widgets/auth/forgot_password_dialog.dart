import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../services/account_recovery_service.dart';
import 'login_auth_field.dart';

enum _ForgotStep { studentId, confirmStudent, gmail, emailSent, verify, reset, done }

/// Password recovery for students (Student ID) and staff (Gmail) — mirrors Angular logic.
Future<String?> showForgotPasswordDialog(
  BuildContext context, {
  required AccountRecoveryService accountRecovery,
  String initialGmail = '',
  String initialStudentId = '',
  String initialOobCode = '',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _ForgotPasswordDialog(
        accountRecovery: accountRecovery,
        initialGmail: initialGmail,
        initialStudentId: initialStudentId,
        initialOobCode: initialOobCode,
      );
    },
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.accountRecovery,
    required this.initialGmail,
    required this.initialStudentId,
    required this.initialOobCode,
  });

  final AccountRecoveryService accountRecovery;
  final String initialGmail;
  final String initialStudentId;
  final String initialOobCode;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late bool _studentFlow;
  late _ForgotStep _step;

  final _studentIdController = TextEditingController();
  final _gmailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _sendingCode = false;
  String? _error;
  String? _success;
  String? _codeMessage;
  String _displayName = '';
  String _maskedEmail = '';
  String _recoveryGmail = '';
  String _loginIdAfterReset = '';

  @override
  void initState() {
    super.initState();
    final initialGmail = widget.initialGmail.trim();
    _studentFlow = false;
    _step = widget.initialOobCode.trim().isNotEmpty
        ? _ForgotStep.verify
        : _ForgotStep.gmail;
    _studentIdController.text = widget.initialStudentId.trim();
    _gmailController.text = initialGmail;
    _codeController.text = widget.initialOobCode.trim();
    _codeController.addListener(_onFieldChanged);
    _newPasswordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
    if (_codeController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bootstrapFromLink();
      });
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _codeController.removeListener(_onFieldChanged);
    _newPasswordController.removeListener(_onFieldChanged);
    _confirmPasswordController.removeListener(_onFieldChanged);
    _studentIdController.dispose();
    _gmailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _activeRecoveryGmail =>
      _recoveryGmail.isNotEmpty ? _recoveryGmail : _gmailController.text.trim().toLowerCase();

  void _verifyStudentId() {
    setState(() {
      _error = null;
      _success = null;
    });

    final lookup = widget.accountRecovery.lookupStudentByIdForRecovery(
      _studentIdController.text,
    );

    if (!lookup.success) {
      setState(() => _error = lookup.error);
      return;
    }

    if (!lookup.hasRecoveryContact) {
      setState(() => _error = lookup.error);
      return;
    }

    setState(() {
      _displayName = lookup.studentName ?? '';
      _maskedEmail = lookup.maskedGmail ?? '';
      _recoveryGmail = lookup.recoveryEmail ?? '';
      _step = _ForgotStep.confirmStudent;
    });
  }

  Future<void> _submitStudentSendCode() async {
    setState(() {
      _error = null;
      _success = null;
      _sendingCode = true;
    });

    final result = await widget.accountRecovery.sendRecoveryCodeForStudentId(
      _studentIdController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _sendingCode = false;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _sendingCode = false;
      _maskedEmail = result.maskedEmail ?? _maskedEmail;
      _codeMessage =
          'Open Gmail on Android or Mail/Gmail on iPhone and tap the reset link. TrackIT will open so you can set a new password. You can also paste the link here.';
      _step = _ForgotStep.emailSent;
    });
  }

  Future<void> _submitGmailSendCode() async {
    setState(() {
      _error = null;
      _success = null;
      _sendingCode = true;
    });

    final gmail = _gmailController.text.trim().isNotEmpty
        ? _gmailController.text
        : _recoveryGmail;

    final lookup = await widget.accountRecovery.lookupAccount(gmail);
    if (!lookup.success) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = lookup.error;
      });
      return;
    }

    _displayName = lookup.displayName ?? '';
    _maskedEmail = lookup.maskedEmail ?? '';
    _recoveryGmail = lookup.email ?? '';

    final result = await widget.accountRecovery.sendRecoveryCode(gmail);

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _sendingCode = false;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _sendingCode = false;
      _maskedEmail = result.maskedEmail ?? _maskedEmail;
      _codeMessage =
          'Open Gmail on Android or Mail/Gmail on iPhone and tap the reset link. TrackIT will open so you can set a new password. You can also paste the link here.';
      _step = _ForgotStep.emailSent;
    });
  }

  Future<void> _bootstrapFromLink() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final resolved = await widget.accountRecovery.resolveRecoveryFromLink(_codeController.text);
    if (!mounted) return;

    if (!resolved.success) {
      setState(() {
        _submitting = false;
        _error = resolved.error;
        _step = _ForgotStep.verify;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _studentFlow = resolved.kind == RecoveryAccountKind.student;
      _recoveryGmail = resolved.email ?? '';
      _displayName = resolved.displayName ?? '';
      _maskedEmail = resolved.maskedEmail ?? '';
      if (resolved.studentId != null && resolved.studentId!.isNotEmpty) {
        _studentIdController.text = resolved.studentId!;
      }
      _step = _ForgotStep.reset;
    });
  }

  Future<void> _submitVerify() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final result = await widget.accountRecovery.verifyRecoveryCode(
      _activeRecoveryGmail,
      _codeController.text,
    );

    if (!mounted) return;

    if (!result.valid) {
      setState(() {
        _submitting = false;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _step = _ForgotStep.reset;
    });
  }

  Future<void> _submitReset() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final result = await widget.accountRecovery.resetPassword(
      _activeRecoveryGmail,
      _codeController.text,
      _newPasswordController.text,
      _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _submitting = false;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _step = _ForgotStep.done;
      _success = 'Your password has been reset. You can now sign in with your new password.';
      _loginIdAfterReset = _studentFlow
          ? (_studentIdController.text.trim().isNotEmpty
              ? _studentIdController.text.trim()
              : result.loginId ?? '')
          : (result.loginId ?? _gmailController.text.trim());
    });
  }

  void _finish() {
    Navigator.of(context).pop(
      _loginIdAfterReset.isNotEmpty ? _loginIdAfterReset : _studentIdController.text.trim(),
    );
  }

  Future<void> _resendCode() async {
    await _submitGmailSendCode();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.loginFieldBg,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _studentFlow ? 'Reset password' : 'Forgot password',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step == _ForgotStep.studentId) ...[
                      Text(
                        'Enter your Student ID. We will verify it against the admin student list and send password reset instructions to the Gmail linked to your account.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      LoginAuthField(
                        label: 'Student ID',
                        controller: _studentIdController,
                        hint: 'Student ID',
                        prefixIcon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 12,
                      ),
                    ],
                    if (_step == _ForgotStep.confirmStudent) ...[
                      Text.rich(
                        TextSpan(
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                          children: [
                            const TextSpan(text: 'The Student ID belongs to: '),
                            TextSpan(
                              text: _displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const TextSpan(text: '. Password reset instructions will be sent to '),
                            TextSpan(
                              text: _maskedEmail,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ],
                    if (_step == _ForgotStep.gmail) ...[
                      Text(
                        'Enter the Gmail address on your TrackIT account. If it is registered, a time-limited reset link will be sent there.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      LoginAuthField(
                        label: 'Gmail address',
                        controller: _gmailController,
                        hint: 'you@gmail.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                    if (_step == _ForgotStep.emailSent) ...[
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                          children: [
                            const TextSpan(text: 'A password reset email was sent to '),
                            TextSpan(
                              text: _maskedEmail,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _codeMessage ??
                            'Open the reset link in your email. TrackIT will open so you can set a new password, then sign in here.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Android: Gmail → reset link → TrackIT → new password\n'
                        'iPhone: Mail/Gmail → reset link → TrackIT → new password',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (_step == _ForgotStep.verify) ...[
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                          children: [
                            if (_displayName.isNotEmpty) ...[
                              const TextSpan(text: 'Account found for '),
                              TextSpan(
                                text: _displayName,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const TextSpan(text: '. Paste the reset link sent to '),
                            ] else
                              const TextSpan(text: 'Paste the reset link sent to '),
                            TextSpan(
                              text: _maskedEmail,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      if (_codeMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _codeMessage!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      LoginAuthField(
                        label: 'Reset link or code',
                        controller: _codeController,
                        hint: 'Paste link from email',
                        prefixIcon: Icons.mark_email_read_outlined,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _sendingCode ? null : _resendCode,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.loginRed.withValues(alpha: 0.95),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(_sendingCode ? 'Sending...' : 'Resend email'),
                        ),
                      ),
                    ],
                    if (_step == _ForgotStep.reset) ...[
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                          children: [
                            const TextSpan(text: 'Identity verified. Create a new password'),
                            if (_displayName.isNotEmpty) ...[
                              const TextSpan(text: ' for '),
                              TextSpan(
                                text: _displayName,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LoginAuthField(
                        label: 'New password',
                        controller: _newPasswordController,
                        hint: 'Min 8 characters',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureNew,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          icon: Icon(
                            _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white54,
                            size: 21,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LoginAuthField(
                        label: 'Confirm password',
                        controller: _confirmPasswordController,
                        hint: 'Re-enter new password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white54,
                            size: 21,
                          ),
                        ),
                      ),
                    ],
                    if (_step == _ForgotStep.done) ...[
                      Text(
                        _success ?? '',
                        style: TextStyle(
                          color: AppTheme.green.withValues(alpha: 0.95),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: AppTheme.loginRed.withValues(alpha: 0.95), fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_step == _ForgotStep.studentId) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _studentIdController.text.trim().isEmpty ? null : _verifyStudentId,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Verify Student ID'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.confirmStudent) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _step = _ForgotStep.studentId;
                          _error = null;
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _sendingCode ? null : _submitStudentSendCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(_sendingCode ? 'Sending...' : 'Send reset email'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.gmail) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _sendingCode || _gmailController.text.trim().isEmpty
                            ? null
                            : _submitGmailSendCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(_sendingCode ? 'Sending...' : 'Send reset email'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.emailSent) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _finish,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back to login'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => setState(() {
                          _error = null;
                          _step = _ForgotStep.verify;
                        }),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('I have the reset link'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.verify) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _step = _ForgotStep.gmail;
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting || _codeController.text.trim().length < 10
                            ? null
                            : _submitVerify,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Verify link'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.reset) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => setState(() => _step = _ForgotStep.verify),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ||
                                _newPasswordController.text.length < 8 ||
                                _confirmPasswordController.text.length < 8
                            ? null
                            : _submitReset,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Reset password'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.done)
                    Expanded(
                      child: FilledButton(
                        onPressed: _finish,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back to login'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
