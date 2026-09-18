import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/trackit_role.dart';
import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../utils/login_credentials_storage.dart';
import '../../utils/trackit_responsive.dart';
import '../../widgets/auth/auth_legal_footer.dart';
import '../../widgets/auth/forgot_password_dialog.dart';
import '../../widgets/auth/login_auth_field.dart';
import '../../widgets/auth/splash_login_background.dart';
import '../../widgets/auth/trackit_splash_logo_animation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialStudentId,
    this.initialGmail,
    this.initialSuccessMessage,
    this.initialResetCode,
  });

  final String? initialStudentId;
  final String? initialGmail;
  final String? initialSuccessMessage;
  final String? initialResetCode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  /// Same phase ratios as before — shorter total time for a snappier intro.
  static const _sequenceDuration = Duration(milliseconds: 4200);
  static const _loadingPhaseEnd = 2000 / 5800;
  static const _logoShiftEnd = _loadingPhaseEnd + 0.14;
  static const _wordmarkStart = _loadingPhaseEnd + 0.05;
  static const _wordmarkEnd = _loadingPhaseEnd + 0.26;
  static const _formRevealStart = 0.78;

  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _loading = false;
  String? _error;
  String? _success;
  bool _formLayerVisible = false;
  bool _ringActive = true;

  late final AnimationController _sequenceController;
  late final AnimationController _ringController;
  late final Animation<double> _logoAppear;
  late final Animation<double> _logoShift;
  late final Animation<double> _wordmarkSlide;
  late final Animation<double> _ringFade;
  late final Animation<double> _headerLift;
  late final Animation<double> _backgroundReveal;
  late final Animation<double> _subtitleReveal;
  late final Animation<double> _formReveal;
  late final Listenable _headerListenable;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    final initialId = widget.initialStudentId?.trim();
    final initialGmail = widget.initialGmail?.trim();
    if (initialGmail != null && initialGmail.isNotEmpty) {
      _loginIdController.text = initialGmail;
    } else if (initialId != null && initialId.isNotEmpty) {
      _loginIdController.text = initialId;
    }
    final initialSuccess = widget.initialSuccessMessage?.trim();
    if (initialSuccess != null && initialSuccess.isNotEmpty) {
      _success = initialSuccess;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreRememberedLogin();
      _openResetFromLinkIfNeeded();
    });

    _sequenceController = AnimationController(
      vsync: this,
      duration: _sequenceDuration,
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();

    _headerListenable = Listenable.merge([_sequenceController, _ringController]);

    _logoAppear = CurvedAnimation(
      parent: _sequenceController,
      curve: const Interval(0.0, 0.10, curve: Curves.easeOutCubic),
    );

    _ringFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: Interval(_loadingPhaseEnd - 0.07, _loadingPhaseEnd, curve: Curves.easeInOut),
      ),
    );

    _logoShift = CurvedAnimation(
      parent: _sequenceController,
      curve: Interval(_loadingPhaseEnd, _logoShiftEnd, curve: Curves.easeInOutCubic),
    );

    _wordmarkSlide = CurvedAnimation(
      parent: _sequenceController,
      curve: Interval(_wordmarkStart, _wordmarkEnd, curve: Curves.easeOutCubic),
    );

    _headerLift = CurvedAnimation(
      parent: _sequenceController,
      curve: const Interval(0.60, 0.80, curve: Curves.easeInOutCubic),
    );

    _backgroundReveal = CurvedAnimation(
      parent: _sequenceController,
      curve: const Interval(0.58, 1.0, curve: Curves.easeInOutCubic),
    );

    _subtitleReveal = CurvedAnimation(
      parent: _sequenceController,
      curve: const Interval(0.72, 0.88, curve: Curves.easeOutCubic),
    );

    _formReveal = CurvedAnimation(
      parent: _sequenceController,
      curve: const Interval(_formRevealStart, 1.0, curve: Curves.easeOutCubic),
    );

    _sequenceController.addListener(_onSequenceTick);
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (mounted) _sequenceController.forward();
    });
  }

  void _onSequenceTick() {
    final value = _sequenceController.value;

    if (_ringActive && value >= _loadingPhaseEnd) {
      _ringActive = false;
      _ringController.stop(canceled: false);
    }

    if (!_formLayerVisible && value >= _formRevealStart) {
      setState(() => _formLayerVisible = true);
    }
  }

  @override
  void dispose() {
    _sequenceController.removeListener(_onSequenceTick);
    _sequenceController.dispose();
    _ringController.dispose();
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _restoreRememberedLogin() {
    if (!mounted) return;
    if (widget.initialStudentId?.trim().isNotEmpty == true) return;

    final app = context.read<AppState>();
    final saved = loadRememberedLogin(app.storage);
    if (saved == null) return;

    setState(() {
      _loginIdController.text = saved.loginId;
      _passwordController.text = saved.password;
      _rememberMe = true;
    });
  }

  Future<void> _persistRememberMe(
    AppState app,
    String loginId,
    String password,
    TrackitRole role,
  ) async {
    if (!_rememberMe) {
      await clearRememberedLogin(app.storage);
      return;
    }

    await saveRememberedLogin(
      app.storage,
      SavedLoginCredentials(
        loginId: loginId,
        password: password,
        accountKind: role == TrackitRole.officer ? 'staff' : 'student',
        verifiedLoginId: loginId,
      ),
    );
  }

  Future<void> _submit(AppState app) async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final loginId = _loginIdController.text.trim();
    final password = _passwordController.text;

    if (loginId.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Enter your credentials to continue.';
      });
      return;
    }

    if (!loginId.contains('@') && RegExp(r'\D').hasMatch(loginId)) {
      setState(() {
        _loading = false;
        _error = 'Student ID must contain numbers only.';
      });
      return;
    }

    AuthResult result;
    if (loginId.contains('@')) {
      result = await app.auth.loginStudent(loginId, password);
      // A deactivated student must not fall through to the officer login.
      if (!result.isSuccess && !result.needsProfileCompletion && !result.deactivated) {
        result = await app.auth.loginOfficer(loginId, password);
      }
    } else {
      result = await app.auth.loginStudent(loginId, password);
    }

    if (!mounted) return;

    if (result.needsProfileCompletion) {
      setState(() {
        _loading = false;
        _error =
            'Profile completion is required. Please finish your profile on the web app first.';
      });
      return;
    }

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.error ??
            (loginId.contains('@')
                ? 'Invalid Gmail or password.'
                : 'Invalid Student ID or password.');
      });
      return;
    }

    final role = result.session!.role;
    await _persistRememberMe(app, loginId, password, role);
    app.notifyAuthChanged();
    if (!mounted) return;
    context.go(role == TrackitRole.officer ? '/officer/dashboard' : '/student/dashboard');

    if (mounted) setState(() => _loading = false);
  }

  void _openResetFromLinkIfNeeded() {
    final code = widget.initialResetCode?.trim();
    if (code == null || code.isEmpty || !mounted) return;
    final app = context.read<AppState>();
    _openForgotPassword(app, initialOobCode: code);
  }

  Future<void> _openForgotPassword(AppState app, {String initialOobCode = ''}) async {
    final loginId = _loginIdController.text.trim();
    final initialGmail = loginId.contains('@') ? loginId : '';

    final resetLoginId = await showForgotPasswordDialog(
      context,
      accountRecovery: app.accountRecovery,
      initialGmail: initialGmail,
      initialStudentId: '',
      initialOobCode: initialOobCode,
    );

    if (resetLoginId != null && resetLoginId.isNotEmpty && mounted) {
      _loginIdController.text = resetLoginId;
      _passwordController.clear();
    }
  }

  void _goToRegister() {
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final viewPadding = layout.viewPadding;
    final topInset = viewPadding.top;
    final bottomInset = viewPadding.bottom;
    final horizontalPad = layout.loginHorizontalPadding;
    final fieldGap = layout.isShortHeight ? 14.0 : 20.0;
    final buttonHeight = layout.loginButtonHeight;
    final app = context.read<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Keep the splash header fixed; only the form area adjusts for the keyboard.
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final splashLogoSize = layout.scaled(96);
          final finalTop = topInset + (layout.isShortHeight ? 44 : 54);
          final splashBlockHeight = splashLogoSize * 1.46;
          final splashTop = (height - splashBlockHeight) / 2;
          final settledHeaderLogoSize = layout.scaled(58);

          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _backgroundReveal,
                builder: (context, _) {
                  return SplashLoginBackground(
                    glowReveal: _backgroundReveal.value,
                    child: const SizedBox.expand(),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _headerListenable,
                builder: (context, _) {
                  final headerLogoSize =
                      lerpDouble(splashLogoSize, settledHeaderLogoSize, _headerLift.value)!;
                  final wordmarkSize =
                      lerpDouble(layout.scaled(38), layout.scaled(31), _headerLift.value)!;
                  final headerTop = lerpDouble(splashTop, finalTop, _headerLift.value)!;
                  final showRing = _ringActive;
                  final ringOpacity = showRing ? _ringFade.value : 0.0;

                  return Positioned(
                    left: 0,
                    right: 0,
                    top: headerTop,
                    child: RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: TrackitSplashLogoAnimation(
                              logoSize: headerLogoSize,
                              wordmarkSize: wordmarkSize,
                              logoAppear: _logoAppear.value,
                              logoShift: _logoShift.value,
                              wordmarkSlide: _wordmarkSlide.value,
                              ringOpacity: ringOpacity,
                              ringRotationTurns: _ringController.value,
                            ),
                          ),
                          Opacity(
                            opacity: _subtitleReveal.value,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  width: 40,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: AppTheme.loginRed,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Sign in to continue',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_formLayerVisible)
                AnimatedBuilder(
                  animation: _sequenceController,
                  builder: (context, _) {
                    final lift = _headerLift.value;
                    final headerLogoSize =
                        lerpDouble(splashLogoSize, settledHeaderLogoSize, lift)!;
                    final headerBlockHeight =
                        headerLogoSize + (layout.isShortHeight ? 48 : 56);
                    final headerTop = lerpDouble(splashTop, finalTop, lift)!;
                    final formTop = headerTop + headerBlockHeight + 8;
                    final keyboardInset = layout.viewInsets.bottom;

                    return Positioned(
                      left: 0,
                      right: 0,
                      top: formTop,
                      bottom: keyboardInset,
                      child: Opacity(
                        opacity: _formReveal.value,
                        child: Transform.translate(
                          offset: Offset(0, 28 * (1 - _formReveal.value)),
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: keyboardInset > 0
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              horizontalPad,
                              0,
                              horizontalPad,
                              24 + bottomInset,
                            ),
                            child: RepaintBoundary(
                              child: _LoginFormContent(
                                loginIdController: _loginIdController,
                                passwordController: _passwordController,
                                obscurePassword: _obscurePassword,
                                rememberMe: _rememberMe,
                                error: _error,
                                success: _success,
                                loading: _loading,
                                fieldGap: fieldGap,
                                buttonHeight: buttonHeight,
                                isShortHeight: layout.isShortHeight,
                                onToggleObscure: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                onRememberMeChanged: (value) => setState(() => _rememberMe = value),
                                onSubmit: () => _submit(app),
                                onForgotPassword: () => _openForgotPassword(app),
                                onSignUp: _goToRegister,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Static login form subtree — built once when the form layer mounts.
class _LoginFormContent extends StatelessWidget {
  const _LoginFormContent({
    required this.loginIdController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.error,
    this.success,
    required this.loading,
    required this.fieldGap,
    required this.buttonHeight,
    required this.isShortHeight,
    required this.onToggleObscure,
    required this.onRememberMeChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onSignUp,
  });

  final TextEditingController loginIdController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final String? error;
  final String? success;
  final bool loading;
  final double fieldGap;
  final double buttonHeight;
  final bool isShortHeight;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoginAuthField(
          label: 'Student ID or Gmail',
          controller: loginIdController,
          hint: 'Enter Student ID or Gmail address',
          prefixIcon: Icons.person_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: fieldGap),
        LoginAuthField(
          label: 'Password',
          controller: passwordController,
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          suffix: IconButton(
            onPressed: onToggleObscure,
            icon: Icon(
              obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 21,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              height: 28,
              child: Checkbox(
                value: rememberMe,
                onChanged: loading ? null : (value) => onRememberMeChanged(value ?? false),
                activeColor: AppTheme.loginRed,
                checkColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            GestureDetector(
              onTap: loading ? null : () => onRememberMeChanged(!rememberMe),
              child: Text(
                'Remember me',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.65),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
        if (success != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.45)),
            ),
            child: Text(
              success!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF86EFAC),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.loginRed.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        SizedBox(height: isShortHeight ? 18 : 24),
        SizedBox(
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
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
                : const Text(
                    'LOGIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              GestureDetector(
                onTap: onSignUp,
                child: const Text(
                  'Sign up',
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
        const AuthLegalFooter(showConsent: true, dark: true),
      ],
    );
  }
}
