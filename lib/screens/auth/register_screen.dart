import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../services/app_state.dart';
import '../../services/student_registration_verification_service.dart';
import '../../utils/profile_photo_picker.dart';
import '../../utils/settings_validation.dart';
import '../../utils/trackit_responsive.dart';
import '../../widgets/auth/auth_legal_footer.dart';
import '../../widgets/auth/login_auth_field.dart';
import '../../widgets/auth/registration_selfie_capture_screen.dart';
import '../../widgets/auth/splash_login_background.dart';
import '../../widgets/auth/trackit_diamond_logo.dart';

enum _RegisterStep { enterId, confirmId, accountDetails, verifyGmail, profilePhoto }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialVerificationCode,
  });

  final String? initialVerificationCode;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _registrationVerification = StudentRegistrationVerificationService();

  _RegisterStep _step = _RegisterStep.enterId;
  final _studentIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gmailController = TextEditingController();

  String? _pendingVerificationCode;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  bool _gmailVerified = false;
  String? _lookupError;
  String? _formError;
  String? _photoError;
  String? _success;
  String? _verificationMessage;
  String _resolvedStudentName = '';
  String? _profilePhotoPreview;

  @override
  void initState() {
    super.initState();
    final initialCode = widget.initialVerificationCode?.trim();
    if (initialCode != null && initialCode.isNotEmpty) {
      _pendingVerificationCode = initialCode;
      _verificationMessage =
          'Gmail verification link opened. Complete the steps below, then tap "I verified in Gmail".';
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _gmailController.dispose();
    super.dispose();
  }

  Future<void> _verifyStudentId(AppState app) async {
    setState(() {
      _lookupError = null;
      _formError = null;
      _success = null;
      _loading = true;
    });

    final studentId = app.studentAuth.normalizeStudentId(_studentIdController.text);
    final idError = SettingsValidation.validateRegistrationStudentId(studentId);
    if (idError != null) {
      setState(() {
        _loading = false;
        _lookupError = idError;
        _step = _RegisterStep.enterId;
      });
      return;
    }

    if (app.studentAuth.hasRegisteredAccount(studentId)) {
      setState(() {
        _loading = false;
        _resolvedStudentName = '';
        _lookupError =
            'This Student ID already has a TrackIT account. Please log in instead.';
        _step = _RegisterStep.enterId;
      });
      return;
    }

    final enrolledAny = await app.sections.fetchStudentByIdAny(studentId);
    if (!mounted) return;
    if (enrolledAny != null && !enrolledAny.isActive) {
      setState(() {
        _loading = false;
        _resolvedStudentName = '';
        _lookupError =
            'This Student ID has been deactivated. Contact your administrator.';
        _step = _RegisterStep.enterId;
      });
      return;
    }

    final enrolled = enrolledAny != null && enrolledAny.isActive ? enrolledAny : null;
    if (enrolled == null) {
      setState(() {
        _loading = false;
        _resolvedStudentName = '';
        _lookupError = 'Student ID not found in the system.';
        _step = _RegisterStep.enterId;
      });
      return;
    }

    setState(() {
      _loading = false;
      _resolvedStudentName = enrolled.name;
      _lookupError = null;
      _step = _RegisterStep.confirmId;
    });
  }

  void _continueConfirmation() {
    setState(() {
      _step = _RegisterStep.accountDetails;
      _formError = null;
      _gmailVerified = false;
      _pendingVerificationCode = null;
      _verificationMessage = null;
      _profilePhotoPreview = null;
      _photoError = null;
      _fullNameController.text = _resolvedStudentName;
    });
  }

  void _cancelConfirmation() {
    setState(() {
      _step = _RegisterStep.enterId;
      _resolvedStudentName = '';
      _lookupError = null;
      _fullNameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _phoneController.clear();
      _gmailController.clear();
      _pendingVerificationCode = null;
      _profilePhotoPreview = null;
      _gmailVerified = false;
    });
  }

  Future<void> _continueToGmailVerification() async {
    setState(() {
      _loading = true;
      _formError = null;
      _success = null;
    });

    if (_step != _RegisterStep.accountDetails) {
      setState(() {
        _loading = false;
        _formError = 'Complete Student ID verification first.';
      });
      return;
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (password != confirmPassword) {
      setState(() {
        _loading = false;
        _formError = 'Passwords do not match.';
      });
      return;
    }

    final validationError = SettingsValidation.validateStudentRegistration(
      fullName: _fullNameController.text.trim(),
      gmail: _gmailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: password,
      confirmPassword: confirmPassword,
    );
    if (validationError != null) {
      setState(() {
        _loading = false;
        _formError = validationError;
      });
      return;
    }

    final sent = await _registrationVerification.sendGmailVerification(
      email: _gmailController.text.trim(),
      password: password,
    );

    if (!mounted) return;

    if (!sent.success) {
      setState(() {
        _loading = false;
        _formError = sent.error ?? 'Could not send Gmail verification email.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _step = _RegisterStep.verifyGmail;
      _gmailVerified = false;
      _verificationMessage =
          'Open Gmail, tap the Google verification link, then return here and tap "I verified in Gmail".';
    });
  }

  Future<void> _confirmGmailVerifiedInApp() async {
    setState(() {
      _loading = true;
      _formError = null;
    });

    final result = await _registrationVerification.confirmGmailVerified(
      email: _gmailController.text.trim(),
      password: _passwordController.text,
      oobCode: _pendingVerificationCode,
    );

    if (!mounted) return;

    if (!result.valid) {
      setState(() {
        _loading = false;
        _formError = result.error ?? 'Gmail verification not confirmed yet.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _gmailVerified = true;
      _pendingVerificationCode = null;
      _step = _RegisterStep.profilePhoto;
      _verificationMessage =
          'Gmail verified. Upload a photo or take a selfie to finish registration.';
    });
  }

  Future<void> _resendGmailVerification() async {
    setState(() {
      _loading = true;
      _formError = null;
    });

    final sent = await _registrationVerification.sendGmailVerification(
      email: _gmailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (!sent.success) {
        _formError = sent.error ?? 'Could not resend verification email.';
        return;
      }
      _verificationMessage =
          'Verification email resent to ${_maskGmail(_gmailController.text.trim())}. '
          'Open Gmail, tap Verify, then return and tap "I verified in Gmail".';
    });
  }

  Future<void> _pickFacePhoto({required bool fromCamera}) async {
    setState(() => _photoError = null);
    try {
      if (fromCamera) {
        final dataUrl = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => const RegistrationSelfieCaptureScreen(),
            fullscreenDialog: true,
          ),
        );
        if (!mounted) return;
        if (dataUrl == null) return;
        setState(() => _profilePhotoPreview = dataUrl);
        return;
      }

      final dataUrl = await pickRegistrationFacePhotoDataUrl(fromCamera: false);
      if (!mounted) return;
      if (dataUrl == null) return;
      setState(() => _profilePhotoPreview = dataUrl);
    } on ProfilePhotoException catch (error) {
      if (!mounted) return;
      setState(() => _photoError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _photoError = 'Could not read the image.');
    }
  }

  Future<void> _submitRegistration(AppState app) async {
    setState(() {
      _loading = true;
      _formError = null;
      _photoError = null;
      _success = null;
    });

    if (_step != _RegisterStep.profilePhoto || !_gmailVerified) {
      setState(() {
        _loading = false;
        _formError = 'Verify your Gmail before creating your account.';
      });
      return;
    }

    final studentId = app.studentAuth.normalizeStudentId(_studentIdController.text);
    if (app.studentAuth.hasRegisteredAccount(studentId)) {
      setState(() {
        _loading = false;
        _formError =
            'This Student ID already has a TrackIT account. Please log in instead.';
      });
      return;
    }

    final enrolled = await app.sections.fetchStudentById(studentId);
    if (enrolled == null) {
      setState(() {
        _loading = false;
        _formError = 'Student ID not found in the system.';
      });
      return;
    }

    if (_fullNameController.text.trim().toLowerCase() != enrolled.name.trim().toLowerCase()) {
      setState(() {
        _loading = false;
        _formError = 'Full name must match the name on file for this Student ID.';
      });
      return;
    }

    if (_profilePhotoPreview == null) {
      setState(() {
        _loading = false;
        _photoError = 'Add a photo of your face. Selfies or front-camera photos work best.';
      });
      return;
    }

    final result = await app.studentAuth.createStudentAccount(
      studentId: studentId,
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      gmail: _gmailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      profilePictureUrl: _profilePhotoPreview!,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _loading = false;
        _formError = result.error ??
            'Could not create account. Check your details (ID or Gmail may already exist).';
      });
      return;
    }

    const successMessage =
        'Account created successfully! You can now sign in with your Student ID or Gmail.';

    setState(() {
      _loading = false;
      _success = successMessage;
    });

    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final loginUri = Uri(
      path: '/login',
      queryParameters: {
        'studentId': studentId,
        'gmail': _gmailController.text.trim().toLowerCase(),
        'success': successMessage,
      },
    );
    context.go(loginUri.toString());
  }

  String _maskGmail(String email) {
    final trimmed = email.trim();
    final at = trimmed.indexOf('@');
    if (at <= 0) return '***';
    final local = trimmed.substring(0, at);
    final domain = trimmed.substring(at + 1);
    final visible = local.substring(0, local.length.clamp(0, 2));
    return '$visible***@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final viewPadding = layout.viewPadding;
    final app = context.read<AppState>();
    final fieldGap = layout.isShortHeight ? 14.0 : 18.0;
    final buttonHeight = layout.loginButtonHeight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SplashLoginBackground(
        glowReveal: 1,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.loginHorizontalPadding,
                  8,
                  layout.loginHorizontalPadding,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/login'),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    layout.loginHorizontalPadding,
                    0,
                    layout.loginHorizontalPadding,
                    viewPadding.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            TrackitDiamondLogo(size: layout.scaled(52)),
                            const SizedBox(height: 12),
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your Student ID to begin registration.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: layout.isShortHeight ? 22 : 28),
                      if (_step == _RegisterStep.enterId) ...[
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
                        if (_lookupError != null) ...[
                          const SizedBox(height: 10),
                          _FieldError(message: _lookupError!),
                        ],
                        SizedBox(height: layout.isShortHeight ? 20 : 28),
                        _PrimaryButton(
                          label: 'Verify Student ID',
                          height: buttonHeight,
                          loading: false,
                          onPressed: () => _verifyStudentId(app),
                        ),
                      ],
                      if (_step == _RegisterStep.confirmId) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.loginFieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2C2C2E)),
                          ),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 14,
                                height: 1.45,
                              ),
                              children: [
                                const TextSpan(text: 'The Student ID belongs to: '),
                                TextSpan(
                                  text: _resolvedStudentName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _OutlineButton(
                                label: 'Cancel',
                                height: buttonHeight,
                                onPressed: _cancelConfirmation,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PrimaryButton(
                                label: 'Continue',
                                height: buttonHeight,
                                loading: false,
                                onPressed: _continueConfirmation,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_step == _RegisterStep.accountDetails) ...[
                        LoginAuthField(
                          label: 'Student ID',
                          controller: _studentIdController,
                          hint: 'Student ID',
                          prefixIcon: Icons.person_outline_rounded,
                          readOnly: true,
                        ),
                        SizedBox(height: fieldGap),
                        LoginAuthField(
                          label: 'Full Name',
                          controller: _fullNameController,
                          hint: 'Full Name',
                          prefixIcon: Icons.person_outline_rounded,
                          readOnly: true,
                        ),
                        SizedBox(height: fieldGap),
                        LoginAuthField(
                          label: 'Password',
                          controller: _passwordController,
                          hint: 'Password (min 8 characters)',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 21,
                            ),
                          ),
                        ),
                        SizedBox(height: fieldGap),
                        LoginAuthField(
                          label: 'Confirm Password',
                          controller: _confirmPasswordController,
                          hint: 'Confirm Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirmPassword,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 21,
                            ),
                          ),
                        ),
                        SizedBox(height: fieldGap),
                        LoginAuthField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          hint: 'Phone Number (e.g. 09171234567)',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: fieldGap),
                        LoginAuthField(
                          label: 'Gmail Address',
                          controller: _gmailController,
                          hint: 'Gmail Address (@gmail.com)',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        if (_formError != null) ...[
                          const SizedBox(height: 12),
                          _FieldError(message: _formError!),
                        ],
                        SizedBox(height: layout.isShortHeight ? 20 : 28),
                        _PrimaryButton(
                          label: 'Verify Gmail',
                          height: buttonHeight,
                          loading: _loading,
                          onPressed: _continueToGmailVerification,
                        ),
                      ],
                      if (_step == _RegisterStep.verifyGmail) ...[
                        Text(
                          'A verification email was sent to ${_maskGmail(_gmailController.text.trim())}. '
                          'Open Gmail, tap the Google verification link, then return here and tap the button below.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.45,
                            fontSize: 14,
                          ),
                        ),
                        if (_verificationMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _verificationMessage!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (_formError != null) ...[
                          const SizedBox(height: 12),
                          _FieldError(message: _formError!),
                        ],
                        SizedBox(height: layout.isShortHeight ? 20 : 28),
                        _PrimaryButton(
                          label: 'I verified in Gmail',
                          height: buttonHeight,
                          loading: _loading,
                          onPressed: _confirmGmailVerifiedInApp,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading ? null : _resendGmailVerification,
                          child: Text(
                            _loading ? 'Sending...' : 'Resend verification email',
                            style: TextStyle(color: AppTheme.loginRed.withValues(alpha: 0.95)),
                          ),
                        ),
                      ],
                      if (_step == _RegisterStep.profilePhoto) ...[
                        Text(
                          'Add a clear photo of your face. Take a selfie with the in-app camera (front or back) or upload from your gallery.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.45,
                            fontSize: 14,
                          ),
                        ),
                        if (_verificationMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _verificationMessage!,
                            style: TextStyle(
                              color: AppTheme.green.withValues(alpha: 0.9),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Center(
                          child: ClipOval(
                            child: _profilePhotoPreview != null
                                ? Image.memory(
                                    base64Decode(_profilePhotoPreview!.split(',').last),
                                    width: 148,
                                    height: 148,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 148,
                                    height: 148,
                                    color: AppTheme.loginFieldBg,
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Face photo preview',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PrimaryButton(
                          label: 'Take selfie',
                          height: buttonHeight,
                          loading: false,
                          onPressed: _loading ? () {} : () => _pickFacePhoto(fromCamera: true),
                        ),
                        const SizedBox(height: 10),
                        _OutlineButton(
                          label: _profilePhotoPreview == null
                              ? 'Upload photo'
                              : 'Choose a different photo',
                          height: buttonHeight,
                          onPressed: _loading ? () {} : () => _pickFacePhoto(fromCamera: false),
                        ),
                        if (_photoError != null) ...[
                          const SizedBox(height: 12),
                          _FieldError(message: _photoError!),
                        ],
                        if (_formError != null) ...[
                          const SizedBox(height: 12),
                          _FieldError(message: _formError!),
                        ],
                        if (_success != null) ...[
                          const SizedBox(height: 12),
                          _SuccessMessage(message: _success!),
                        ],
                        SizedBox(height: layout.isShortHeight ? 20 : 28),
                        _PrimaryButton(
                          label: 'Create Student Account',
                          height: buttonHeight,
                          loading: _loading,
                          onPressed: () => _submitRegistration(app),
                        ),
                      ],
                      if (_step == _RegisterStep.accountDetails) ...[
                        const SizedBox(height: 20),
                        Text(
                          'By creating an account, you agree to our Terms of Use and acknowledge our Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.50),
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  color: AppTheme.loginRed,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const AuthLegalFooter(showConsent: false, dark: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.height,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final double height;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.loginRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.loginRed.withValues(alpha: 0.45),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.height,
    required this.onPressed,
  });

  final String label;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppTheme.loginRed.withValues(alpha: 0.95),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.green.withValues(alpha: 0.45)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF86EFAC),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}
