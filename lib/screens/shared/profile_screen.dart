import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/trackit_role.dart';
import '../../services/app_state.dart';
import '../../services/student_registration_verification_service.dart';
import '../../utils/login_credentials_storage.dart';
import '../../utils/profile_photo_picker.dart';
import '../../utils/settings_validation.dart';
import '../../utils/trackit_confirm_dialog.dart';
import '../../utils/trackit_logout.dart';
import '../../widgets/common/about_trackit_dialog.dart';
import '../../widgets/common/trackit_decorations.dart';
import '../../widgets/common/trackit_page_layout.dart';
import '../../widgets/common/trackit_scaffold.dart';
import '../../widgets/common/trackit_text_field.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final role = app.roles.currentRole;

    if (role == TrackitRole.officer) {
      return const _OfficerSettingsBody();
    }

    return const _StudentSettingsBody();
  }
}

class _StudentSettingsBody extends StatefulWidget {
  const _StudentSettingsBody();

  @override
  State<_StudentSettingsBody> createState() => _StudentSettingsBodyState();
}

class _StudentSettingsBodyState extends State<_StudentSettingsBody> {
  final _studentIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newGmailController = TextEditingController();
  final _gmailLinkPasswordController = TextEditingController();
  final _gmailVerificationController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _registrationVerification = StudentRegistrationVerificationService();

  bool _showPasswordSection = false;
  bool _showGmailLinkSection = false;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _linkingGmail = false;
  bool _gmailVerificationSent = false;
  String? _profileError;
  String? _profileSuccess;
  String? _passwordError;
  String? _passwordSuccess;
  String? _photoError;
  String? _photoSuccess;
  String? _gmailLinkError;
  String? _gmailLinkSuccess;
  String? _displayPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadStudentFields();
  }

  void _loadStudentFields() {
    final student = context.read<AppState>().auth.currentStudent;
    if (student == null) return;
    _studentIdController.text = student.studentId;
    _nameController.text = student.fullName;
    _phoneController.text = student.phone;
    _displayPhotoUrl = student.profilePictureUrl;
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _newGmailController.dispose();
    _gmailLinkPasswordController.dispose();
    _gmailVerificationController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSavePhoto(AppState app) async {
    setState(() {
      _photoError = null;
      _photoSuccess = null;
    });

    try {
      final dataUrl = await pickProfilePhotoDataUrl();
      if (dataUrl == null || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Update profile photo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrackitProfileAvatar(
                  imageUrl: dataUrl,
                  fallbackLetter: _nameController.text,
                  size: 96,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to replace your profile photo with this image?',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Use this photo'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;

      final previousPhoto = _displayPhotoUrl;
      setState(() => _displayPhotoUrl = dataUrl);

      final result = await app.studentAuth.setCurrentStudentProfilePicture(dataUrl);
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _displayPhotoUrl = previousPhoto;
          _photoError = result.error;
        });
        return;
      }

      await app.auth.refreshStudentSession();
      app.notifyAuthChanged();
      setState(() {
        if (result.warning != null) {
          _photoError = result.warning;
        } else {
          _photoSuccess = 'Profile photo updated. TrackIT admin can see it now.';
        }
      });
    } on ProfilePhotoException catch (e) {
      if (mounted) setState(() => _photoError = e.message);
    } catch (_) {
      if (mounted) setState(() => _photoError = 'Could not pick image.');
    }
  }

  Future<void> _removePhoto(AppState app) async {
    setState(() {
      _photoError = null;
      _photoSuccess = null;
    });

    final confirmed = await confirmTrackitAction(
      context,
      title: 'Remove profile photo',
      message: 'Are you sure you want to remove your profile photo?',
      confirmLabel: 'Remove photo',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final previousPhoto = _displayPhotoUrl;
    setState(() => _displayPhotoUrl = null);

    final result = await app.studentAuth.clearCurrentStudentProfilePicture();
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _displayPhotoUrl = previousPhoto;
        _photoError = result.error;
      });
      return;
    }

    await app.auth.refreshStudentSession();
    app.notifyAuthChanged();
    setState(() {
      if (result.warning != null) {
        _photoError = result.warning;
      } else {
        _photoSuccess = 'Profile photo removed.';
      }
    });
  }

  Future<void> _saveProfile(AppState app) async {
    setState(() {
      _profileError = null;
      _profileSuccess = null;
    });

    final student = app.auth.currentStudent;
    final validationError = SettingsValidation.validateStudentProfile(
      fullName: _nameController.text,
      gmail: student?.gmail ?? '',
      phone: _phoneController.text,
    );
    if (validationError != null) {
      setState(() => _profileError = validationError);
      return;
    }

    final confirmed = await confirmTrackitAction(
      context,
      title: 'Save profile',
      message: 'Your name and phone number will be updated.',
      confirmLabel: 'Save profile',
    );
    if (!confirmed || !mounted) return;

    setState(() => _savingProfile = true);

    final result = await app.studentAuth.updateCurrentStudentProfile(
      fullName: _nameController.text,
      phone: _phoneController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _savingProfile = false;
        _profileError = result.error;
      });
      return;
    }

    await app.auth.refreshStudentSession();
    app.notifyAuthChanged();
    _loadStudentFields();

    setState(() {
      _savingProfile = false;
      if (result.warning != null) {
        _profileError = result.warning;
      } else {
        _profileSuccess = 'Profile updated. TrackIT admin can see your name and phone now.';
      }
    });
  }

  Future<void> _savePassword(AppState app) async {
    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
    });

    final validationError = SettingsValidation.validateStudentPasswordChange(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (validationError != null) {
      setState(() => _passwordError = validationError);
      return;
    }

    final confirmed = await confirmTrackitAction(
      context,
      title: 'Update password',
      message: 'You will need to use your new password the next time you sign in.',
      confirmLabel: 'Update password',
    );
    if (!confirmed || !mounted) return;

    setState(() => _savingPassword = true);

    final student = app.auth.currentStudent;
    if (student == null) {
      setState(() {
        _savingPassword = false;
        _passwordError = 'You are not signed in.';
      });
      return;
    }

    final result = await app.studentAuth.changeStudentPassword(
      student.studentId,
      _currentPasswordController.text,
      _newPasswordController.text,
      _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _savingPassword = false;
        _passwordError = result.error;
      });
      return;
    }

    final newPassword = _newPasswordController.text;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    await updateRememberedPassword(
      app.storage,
      newPassword: newPassword,
      loginId: student.studentId,
      alternateLoginId: student.gmail,
    );

    setState(() {
      _savingPassword = false;
      _showPasswordSection = false;
      if (result.warning != null) {
        _passwordError = result.warning;
      } else {
        _passwordSuccess = 'Password updated. Use it the next time you sign in.';
      }
    });
  }

  Future<void> _sendGmailVerification(AppState app) async {
    setState(() {
      _gmailLinkError = null;
      _gmailLinkSuccess = null;
    });

    final gmail = _newGmailController.text.trim().toLowerCase();
    if (!SettingsValidation.isValidGmailAddress(gmail)) {
      setState(() => _gmailLinkError = 'Enter a valid Gmail address (@gmail.com).');
      return;
    }

    final current = app.auth.currentStudent;
    if (current != null && current.gmail.trim().toLowerCase() == gmail) {
      setState(() => _gmailLinkError = 'This Gmail is already linked to your account.');
      return;
    }

    final password = _gmailLinkPasswordController.text;
    if (password.isEmpty) {
      setState(() => _gmailLinkError = 'Enter your current password to verify Gmail linking.');
      return;
    }

    if (app.studentAuth.verifyStudentLogin(current?.studentId ?? '', password) == null) {
      setState(() => _gmailLinkError = 'Current password is incorrect.');
      return;
    }

    setState(() => _linkingGmail = true);

    final result = await _registrationVerification.sendGmailVerification(
      email: gmail,
      password: password,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _linkingGmail = false;
        _gmailLinkError = result.error;
      });
      return;
    }

    setState(() {
      _linkingGmail = false;
      _gmailVerificationSent = true;
      _gmailLinkSuccess =
          'Verification email sent to ${_maskGmail(gmail)}. Open the link, then paste it below.';
    });
  }

  Future<void> _confirmGmailLink(AppState app) async {
    setState(() {
      _gmailLinkError = null;
      _gmailLinkSuccess = null;
    });

    final gmail = _newGmailController.text.trim().toLowerCase();
    final code = _gmailVerificationController.text.trim();
    if (code.isEmpty) {
      setState(() => _gmailLinkError = 'Paste the verification link or code from your Gmail.');
      return;
    }

    setState(() => _linkingGmail = true);

    final verification = await _registrationVerification.verifyGmailLink(
      code: code,
      expectedEmail: gmail,
    );

    if (!verification.valid) {
      if (!mounted) return;
      setState(() {
        _linkingGmail = false;
        _gmailLinkError = verification.error;
      });
      return;
    }

    final result = await app.studentAuth.updateCurrentStudentProfile(gmail: gmail);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _linkingGmail = false;
        _gmailLinkError = result.error;
      });
      return;
    }

    await app.auth.refreshStudentSession();
    app.notifyAuthChanged();

    _newGmailController.clear();
    _gmailLinkPasswordController.clear();
    _gmailVerificationController.clear();

    setState(() {
      _linkingGmail = false;
      _gmailVerificationSent = false;
      _showGmailLinkSection = false;
      _gmailLinkSuccess = result.warning ??
          'Gmail linked and saved. TrackIT admin can see it with your Student ID.';
    });
  }

  String _maskGmail(String gmail) {
    final at = gmail.indexOf('@');
    if (at <= 1) return gmail;
    return '${gmail.substring(0, 2)}***${gmail.substring(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final student = app.auth.currentStudent;
    final linkedGmail = student?.gmail.trim() ?? '';
    final hasLinkedGmail = SettingsValidation.isValidGmailAddress(linkedGmail);
    final photoUrl = _displayPhotoUrl ?? student?.profilePictureUrl;

    return TrackitPageLayout(
      title: 'Settings',
      subtitle: '',
      showHero: false,
      topPadding: 8,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TrackitSectionHeader(title: 'Profile'),
          if (student != null)
            TrackitProfileCard(
              name: student.fullName,
              subtitle: 'Student ID: ${student.studentId}',
              roleLabel: app.roles.roleLabel,
              imageUrl: photoUrl,
            ),
          _ProfilePhotoSection(
            imageUrl: photoUrl,
            fallbackLetter: student?.fullName ?? '',
            error: _photoError,
            success: _photoSuccess,
            onChangePhoto: () => _pickAndSavePhoto(app),
            onRemovePhoto: photoUrl != null && photoUrl.isNotEmpty
                ? () => _removePhoto(app)
                : null,
          ),
          TrackitSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrackitTextField(
                  label: 'Login username (Student ID)',
                  controller: _studentIdController,
                  readOnly: true,
                ),
                const SizedBox(height: 14),
                TrackitTextField(label: 'Full name', controller: _nameController),
                const SizedBox(height: 14),
                TrackitTextField(
                  label: 'Phone number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                _SettingsFeedback(error: _profileError, success: _profileSuccess),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _savingProfile ? null : () => _saveProfile(app),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _savingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save profile', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const TrackitSectionHeader(title: 'Gmail linking'),
          TrackitSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasLinkedGmail) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Linked',
                          style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(linkedGmail, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else
                  Text(
                    'No Gmail is linked yet. Link your Gmail for account recovery and to stay in sync with the web app.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _showGmailLinkSection = !_showGmailLinkSection;
                    _gmailLinkError = null;
                    _gmailLinkSuccess = null;
                    if (!_showGmailLinkSection) {
                      _gmailVerificationSent = false;
                      _newGmailController.clear();
                      _gmailLinkPasswordController.clear();
                      _gmailVerificationController.clear();
                    }
                  }),
                  icon: Icon(_showGmailLinkSection ? Icons.expand_less : Icons.link),
                  label: Text(hasLinkedGmail ? 'Change linked Gmail' : 'Link Gmail'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.red,
                    side: BorderSide(color: AppTheme.red.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                if (_showGmailLinkSection) ...[
                  const SizedBox(height: 14),
                  TrackitTextField(
                    label: hasLinkedGmail ? 'New Gmail' : 'Gmail',
                    controller: _newGmailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  TrackitTextField(
                    label: 'Current password',
                    controller: _gmailLinkPasswordController,
                    obscureText: true,
                  ),
                  if (!_gmailVerificationSent) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _linkingGmail ? null : () => _sendGmailVerification(app),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _linkingGmail
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Send verification email'),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    TrackitTextField(
                      label: 'Verification link or code',
                      controller: _gmailVerificationController,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _linkingGmail
                                ? null
                                : () => setState(() {
                                      _gmailVerificationSent = false;
                                      _gmailVerificationController.clear();
                                    }),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _linkingGmail ? null : () => _confirmGmailLink(app),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _linkingGmail
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Confirm link'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                _SettingsFeedback(error: _gmailLinkError, success: _gmailLinkSuccess),
              ],
            ),
          ),
          const TrackitSectionHeader(title: 'Login & security'),
          _ChangePasswordSection(
            expanded: _showPasswordSection,
            onToggle: () => setState(() => _showPasswordSection = !_showPasswordSection),
            currentPasswordController: _currentPasswordController,
            newPasswordController: _newPasswordController,
            confirmPasswordController: _confirmPasswordController,
            error: _passwordError,
            success: _passwordSuccess,
            saving: _savingPassword,
            onSave: () => _savePassword(app),
            showPasswordRules: true,
          ),
          const TrackitSectionHeader(title: 'Preferences'),
          TrackitAppearanceCard(isDarkMode: app.isDarkMode, onChanged: app.setDarkMode),
          const SizedBox(height: 4),
          _LogoutSection(app: app),
        ],
      ),
    );
  }
}

class _OfficerSettingsBody extends StatefulWidget {
  const _OfficerSettingsBody();

  @override
  State<_OfficerSettingsBody> createState() => _OfficerSettingsBodyState();
}

class _OfficerSettingsBodyState extends State<_OfficerSettingsBody> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPasswordSection = false;
  bool _savingProfile = false;
  bool _savingPassword = false;
  String? _profileError;
  String? _profileSuccess;
  String? _passwordError;
  String? _passwordSuccess;
  String? _photoError;
  String? _photoSuccess;

  @override
  void initState() {
    super.initState();
    _loadOfficerFields();
  }

  void _loadOfficerFields() {
    final officer = context.read<AppState>().auth.currentOfficer;
    if (officer == null) return;
    _nameController.text = officer.name;
    _emailController.text = officer.email;
    _phoneController.text = officer.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSavePhoto(AppState app) async {
    setState(() {
      _photoError = null;
      _photoSuccess = null;
    });

    try {
      final dataUrl = await pickProfilePhotoDataUrl();
      if (dataUrl == null || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Update profile photo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrackitProfileAvatar(
                  imageUrl: dataUrl,
                  fallbackLetter: _nameController.text,
                  size: 96,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to replace your profile photo with this image?',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Use this photo'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;

      final officer = app.auth.currentOfficer;
      if (officer == null) {
        setState(() => _photoError = 'You are not signed in.');
        return;
      }

      final result = await app.officerAuth.setOfficerProfilePicture(officer.id, dataUrl);
      if (!mounted) return;

      if (!result.success) {
        setState(() => _photoError = result.error);
        return;
      }

      await app.auth.refreshOfficerSession();
      app.notifyAuthChanged();
      setState(() => _photoSuccess = 'Profile photo updated.');
    } on ProfilePhotoException catch (e) {
      if (mounted) setState(() => _photoError = e.message);
    } catch (_) {
      if (mounted) setState(() => _photoError = 'Could not pick image.');
    }
  }

  Future<void> _removePhoto(AppState app) async {
    setState(() {
      _photoError = null;
      _photoSuccess = null;
    });

    final confirmed = await confirmTrackitAction(
      context,
      title: 'Remove profile photo',
      message: 'Are you sure you want to remove your profile photo?',
      confirmLabel: 'Remove photo',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final officer = app.auth.currentOfficer;
    if (officer == null) {
      setState(() => _photoError = 'You are not signed in.');
      return;
    }

    final result = await app.officerAuth.clearOfficerProfilePicture(officer.id);
    if (!mounted) return;

    if (!result.success) {
      setState(() => _photoError = result.error);
      return;
    }

    await app.auth.refreshOfficerSession();
    app.notifyAuthChanged();
    setState(() => _photoSuccess = 'Profile photo removed.');
  }

  Future<void> _saveProfile(AppState app) async {
    setState(() {
      _profileError = null;
      _profileSuccess = null;
    });

    final validationError = SettingsValidation.validateOfficerProfile(
      fullName: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
    );
    if (validationError != null) {
      setState(() => _profileError = validationError);
      return;
    }

    final confirmed = await confirmTrackitAction(
      context,
      title: 'Save profile',
      message: 'Your name, email, and phone number will be updated.',
      confirmLabel: 'Save profile',
    );
    if (!confirmed || !mounted) return;

    setState(() => _savingProfile = true);

    final officer = app.auth.currentOfficer;
    if (officer == null) {
      setState(() {
        _savingProfile = false;
        _profileError = 'You are not signed in.';
      });
      return;
    }

    final result = await app.officerAuth.updateOfficerAccount(
      officer.id,
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _savingProfile = false;
        _profileError = result.error;
      });
      return;
    }

    await app.auth.refreshOfficerSession();
    app.notifyAuthChanged();
    _loadOfficerFields();

    setState(() {
      _savingProfile = false;
      _profileSuccess = 'Profile updated.';
    });
  }

  Future<void> _savePassword(AppState app) async {
    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
    });

    final validationError = SettingsValidation.validateOfficerPasswordChange(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (validationError != null) {
      setState(() => _passwordError = validationError);
      return;
    }

    final confirmed = await confirmTrackitAction(
      context,
      title: 'Update password',
      message: 'You will need to use your new password the next time you sign in.',
      confirmLabel: 'Update password',
    );
    if (!confirmed || !mounted) return;

    setState(() => _savingPassword = true);

    final officer = app.auth.currentOfficer;
    if (officer == null) {
      setState(() {
        _savingPassword = false;
        _passwordError = 'You are not signed in.';
      });
      return;
    }

    final result = await app.officerAuth.changeOfficerPassword(
      officer.id,
      _currentPasswordController.text,
      _newPasswordController.text,
      _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _savingPassword = false;
        _passwordError = result.error;
      });
      return;
    }

    final newPassword = _newPasswordController.text;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    await updateRememberedPassword(
      app.storage,
      newPassword: newPassword,
      loginId: officer.email,
    );

    setState(() {
      _savingPassword = false;
      _showPasswordSection = false;
      _passwordSuccess = 'Password updated. Use it the next time you sign in.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final officer = app.auth.currentOfficer;
    final org = officer != null ? app.organizations.getById(officer.organizationId) : null;

    return TrackitPageLayout(
      title: 'Settings',
      subtitle: '',
      showHero: false,
      topPadding: 8,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TrackitSectionHeader(title: 'Profile'),
          if (officer != null)
            TrackitProfileCard(
              name: officer.name,
              subtitle: officer.position,
              roleLabel: app.roles.roleLabel,
              imageUrl: officer.profilePictureUrl,
            ),
          _ProfilePhotoSection(
            imageUrl: officer?.profilePictureUrl,
            fallbackLetter: officer?.name ?? '',
            error: _photoError,
            success: _photoSuccess,
            onChangePhoto: () => _pickAndSavePhoto(app),
            onRemovePhoto: officer?.profilePictureUrl != null &&
                    officer!.profilePictureUrl!.isNotEmpty
                ? () => _removePhoto(app)
                : null,
          ),
          TrackitSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrackitTextField(label: 'Full name', controller: _nameController),
                const SizedBox(height: 14),
                TrackitTextField(
                  label: 'Gmail / username',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TrackitTextField(
                  label: 'Phone number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                Text(
                  'Position: ${officer?.position ?? '—'} · Organization: ${org?.name ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                _SettingsFeedback(error: _profileError, success: _profileSuccess),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _savingProfile ? null : () => _saveProfile(app),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _savingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save profile', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const TrackitSectionHeader(title: 'Login & security'),
          _ChangePasswordSection(
            expanded: _showPasswordSection,
            onToggle: () => setState(() => _showPasswordSection = !_showPasswordSection),
            currentPasswordController: _currentPasswordController,
            newPasswordController: _newPasswordController,
            confirmPasswordController: _confirmPasswordController,
            error: _passwordError,
            success: _passwordSuccess,
            saving: _savingPassword,
            onSave: () => _savePassword(app),
            showPasswordRules: true,
          ),
          const TrackitSectionHeader(title: 'Preferences'),
          TrackitAppearanceCard(isDarkMode: app.isDarkMode, onChanged: app.setDarkMode),
          const SizedBox(height: 4),
          const TrackitSectionHeader(title: 'About'),
          TrackitAboutCard(onTap: () => showAboutTrackitDialog(context)),
          const SizedBox(height: 4),
          _LogoutSection(app: app),
        ],
      ),
    );
  }
}

class _ProfilePhotoSection extends StatelessWidget {
  const _ProfilePhotoSection({
    required this.imageUrl,
    required this.fallbackLetter,
    required this.onChangePhoto,
    this.onRemovePhoto,
    this.error,
    this.success,
  });

  final String? imageUrl;
  final String fallbackLetter;
  final VoidCallback onChangePhoto;
  final VoidCallback? onRemovePhoto;
  final String? error;
  final String? success;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TrackitSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TrackitProfileAvatar(
                  imageUrl: imageUrl,
                  fallbackLetter: fallbackLetter,
                  size: 72,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onChangePhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Change photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.red,
                          side: BorderSide(color: AppTheme.red.withValues(alpha: 0.35)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      if (onRemovePhoto != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: onRemovePhoto,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.red,
                            side: BorderSide(color: AppTheme.red.withValues(alpha: 0.25)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            _SettingsFeedback(error: error, success: success),
          ],
        ),
      ),
    );
  }
}

class _SettingsFeedback extends StatelessWidget {
  const _SettingsFeedback({this.error, this.success});

  final String? error;
  final String? success;

  @override
  Widget build(BuildContext context) {
    if (error == null && success == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        error ?? success!,
        style: TextStyle(
          color: error != null ? AppTheme.red : AppTheme.green,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ChangePasswordSection extends StatefulWidget {
  const _ChangePasswordSection({
    required this.expanded,
    required this.onToggle,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.error,
    required this.success,
    required this.saving,
    required this.onSave,
    this.showPasswordRules = false,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final String? error;
  final String? success;
  final bool saving;
  final VoidCallback onSave;
  final bool showPasswordRules;

  @override
  State<_ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<_ChangePasswordSection> {
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    widget.newPasswordController.addListener(_onFieldChanged);
    widget.confirmPasswordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    widget.newPasswordController.removeListener(_onFieldChanged);
    widget.confirmPasswordController.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final newPassword = widget.newPasswordController.text;
    final confirmPassword = widget.confirmPasswordController.text;
    final rules = SettingsValidation.passwordRuleChecks(newPassword);
    final passwordsMatch =
        confirmPassword.isNotEmpty && newPassword == confirmPassword;

    return TrackitSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: widget.onToggle,
            icon: Icon(widget.expanded ? Icons.expand_less : Icons.lock_outline),
            label: Text(widget.expanded ? 'Hide password form' : 'Change password'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.red,
              side: BorderSide(color: AppTheme.red.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (widget.expanded) ...[
            const SizedBox(height: 16),
            TrackitTextField(
              label: 'Current password',
              controller: widget.currentPasswordController,
              obscureText: _obscureCurrent,
              suffix: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            const SizedBox(height: 14),
            TrackitTextField(
              label: 'New password',
              controller: widget.newPasswordController,
              obscureText: _obscureNew,
              suffix: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            if (widget.showPasswordRules && newPassword.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PasswordRequirementsList(rules: rules),
            ] else if (newPassword.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                newPassword.length >= SettingsValidation.minPasswordLength
                    ? 'Password length requirement met.'
                    : 'Password must be at least ${SettingsValidation.minPasswordLength} characters.',
                style: TextStyle(
                  fontSize: 12,
                  color: newPassword.length >= SettingsValidation.minPasswordLength
                      ? AppTheme.green
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TrackitTextField(
              label: 'Confirm new password',
              controller: widget.confirmPasswordController,
              obscureText: _obscureConfirm,
              suffix: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            if (confirmPassword.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                passwordsMatch ? 'Passwords match.' : 'Passwords do not match.',
                style: TextStyle(
                  fontSize: 12,
                  color: passwordsMatch ? AppTheme.green : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            _SettingsFeedback(error: widget.error, success: widget.success),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: widget.saving ? null : widget.onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: widget.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update password', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasswordRequirementsList extends StatelessWidget {
  const _PasswordRequirementsList({required this.rules});

  final List<PasswordRuleCheck> rules;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password requirements',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  rule.met ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: rule.met ? AppTheme.green : Theme.of(context).hintColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: rule.met ? AppTheme.green : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LogoutSection extends StatelessWidget {
  const _LogoutSection({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return TrackitLogoutCard(
      onLogout: () => confirmLogoutAndExit(
        context,
        onLogout: () async {
          await app.auth.logout();
          app.notifyAuthChanged();
        },
      ),
    );
  }
}

class TrackitAppearanceCard extends StatelessWidget {
  const TrackitAppearanceCard({
    super.key,
    required this.isDarkMode,
    required this.onChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TrackitSurfaceCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: isDarkMode ? 0.5 : 0.08),
                  const Color(0xFFC62828).withValues(alpha: isDarkMode ? 0.45 : 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDarkMode ? Colors.white : const Color(0xFFC62828),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark mode', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  isDarkMode ? 'Black & red gradient theme' : 'Light theme',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDarkMode,
            activeTrackColor: const Color(0xFFC62828).withValues(alpha: 0.55),
            activeThumbColor: const Color(0xFFC62828),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class TrackitAboutCard extends StatelessWidget {
  const TrackitAboutCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TrackitSurfaceCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: AppTheme.red, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About TrackIT', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Version, modules, team, and technology stack',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TrackitLogoutCard extends StatelessWidget {
  const TrackitLogoutCard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return TrackitSurfaceCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppTheme.red, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Log out', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Sign out of your TrackIT account',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
