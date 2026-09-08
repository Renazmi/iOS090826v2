import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/auth_legal_content.dart';

/// Footer with Terms, Privacy, and Development Team links.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({
    super.key,
    this.showConsent = true,
    this.dark = true,
  });

  final bool showConsent;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final muted = dark ? Colors.white.withValues(alpha: 0.72) : AppTheme.textMuted;
    final consentColor = dark ? Colors.white.withValues(alpha: 0.82) : const Color(0xFF5C6B7F);
    final copyColor = dark ? Colors.white.withValues(alpha: 0.9) : AppTheme.textPrimary;
    final borderColor = dark ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          if (showConsent) ...[
            Text(
              AuthLegalContent.consentText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: consentColor),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            '© $year TrackIT. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: copyColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              _LegalLink(
                label: 'Terms of Use',
                color: muted,
                onTap: () => _openDocument(context, AuthLegalDocumentId.terms),
              ),
              Text('·', style: TextStyle(color: muted.withValues(alpha: 0.65), fontSize: 11)),
              _LegalLink(
                label: 'Privacy Policy',
                color: muted,
                onTap: () => _openDocument(context, AuthLegalDocumentId.privacy),
              ),
              Text('·', style: TextStyle(color: muted.withValues(alpha: 0.65), fontSize: 11)),
              _LegalLink(
                label: 'Development Team',
                color: muted,
                onTap: () => showDevelopmentTeamDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDocument(BuildContext context, AuthLegalDocumentId id) {
    showAuthLegalDocumentDialog(context, AuthLegalContent.documents[id]!);
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}

Future<void> showAuthLegalDocumentDialog(BuildContext context, AuthLegalDocument document) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
            maxWidth: 520,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last updated: ${document.updated}',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final section in document.sections) ...[
                        Text(
                          section.heading,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          section.body,
                          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                                fontSize: 13.5,
                              ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showDevelopmentTeamDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
            maxWidth: 520,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Development Team',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'TrackIT mobile & web application',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Development Team',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      for (final member in AuthLegalContent.developmentTeam)
                        _TeamMemberTile(member: member),
                      const SizedBox(height: 20),
                      const Text(
                        'Project Adviser',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      _TeamMemberTile(
                        member: AuthLegalContent.projectAdviser,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.member, this.highlight = false});

  final DevelopmentTeamMember member;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final roleColor = highlight ? AppTheme.red : const Color(0xFF475569);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.red.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? AppTheme.red.withValues(alpha: 0.28) : const Color(0xFFDCE3EC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MemberAvatar(member: member, highlight: highlight),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: highlight
                        ? AppTheme.red.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member.role,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: roleColor,
                      letterSpacing: 0.15,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, required this.highlight});

  final DevelopmentTeamMember member;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    final photo = member.photoAsset;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? AppTheme.red.withValues(alpha: 0.35) : const Color(0xFFDCE3EC),
          width: 1.2,
        ),
        color: highlight ? AppTheme.red.withValues(alpha: 0.08) : Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null
          ? Image.asset(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialFallback(initial),
            )
          : _initialFallback(initial),
    );
  }

  Widget _initialFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: highlight ? AppTheme.red : AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }
}
