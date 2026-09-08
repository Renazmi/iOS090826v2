import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../config/about_trackit_content.dart';
import '../../config/app_theme.dart';
import 'trackit_decorations.dart';

Future<void> showAboutTrackitDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.88,
            maxWidth: 520,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AboutHeader(onClose: () => Navigator.of(dialogContext).pop()),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: const _AboutBody(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.red.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/trackit-logo.png',
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.track_changes, color: AppTheme.red),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About TrackIT',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  AboutTrackitContent.tagline,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: 'Close About TrackIT',
          ),
        ],
      ),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(label: 'Version ${AboutTrackitContent.version}'),
            _Badge(
              label: 'Updated ${AboutTrackitContent.updated}',
              muted: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('What is TrackIT?'),
        const SizedBox(height: 8),
        Text(AboutTrackitContent.overview, style: _bodyStyle(context)),
        const SizedBox(height: 10),
        Text(AboutTrackitContent.purpose, style: _bodyStyle(context)),
        const SizedBox(height: 20),
        const _SectionTitle('Core Modules'),
        const SizedBox(height: 10),
        for (final feature in AboutTrackitContent.features) ...[
          _FeatureTile(feature: feature),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        const _SectionTitle('Built For'),
        const SizedBox(height: 10),
        for (final item in AboutTrackitContent.audience) ...[
          _AudienceTile(audience: item),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const _SectionTitle('Technology Stack'),
        const SizedBox(height: 8),
        Text(AboutTrackitContent.techStackIntro, style: _bodyStyle(context)),
        const SizedBox(height: 12),
        for (final platform in AboutTrackitContent.techStackPlatforms) ...[
          Text(platform.platform, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          Text(platform.description, style: _bodyStyle(context)),
          const SizedBox(height: 10),
          for (final group in platform.groups) ...[
            _TechStackGroup(group: group),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        const _SectionTitle('Development Team'),
        const SizedBox(height: 10),
        for (final member in AboutTrackitContent.developmentTeam) ...[
          _TeamMemberTile(member: member),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const _SectionTitle('Project Adviser'),
        const SizedBox(height: 10),
        _TeamMemberTile(member: AboutTrackitContent.projectAdviser),
        const SizedBox(height: 8),
      ],
    );
  }

  TextStyle? _bodyStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45, fontSize: 13.5);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: muted
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppTheme.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: muted ? Theme.of(context).hintColor : AppTheme.red,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});

  final AboutFeature feature;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(feature.icon, size: 18, color: AppTheme.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feature.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(
                feature.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AudienceTile extends StatelessWidget {
  const _AudienceTile({required this.audience});

  final AboutAudience audience;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(audience.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 2),
        Text(
          audience.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _TechStackGroup extends StatelessWidget {
  const _TechStackGroup({required this.group});

  final AboutTechStackGroup group;

  @override
  Widget build(BuildContext context) {
    return TrackitSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: group.items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          item.iconAsset,
                          width: 16,
                          height: 16,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 6),
                        Text(item.name, style: const TextStyle(fontSize: 11.5)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.member, this.highlighted = false});

  final AboutTeamMember member;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    final roleColor = highlighted ? AppTheme.red : const Color(0xFF475569);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.red.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? AppTheme.red.withValues(alpha: 0.28) : const Color(0xFFDCE3EC),
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
          _AboutMemberAvatar(
            photoAsset: member.photoAsset,
            initial: initial,
            highlighted: highlighted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: highlighted
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

class _AboutMemberAvatar extends StatelessWidget {
  const _AboutMemberAvatar({
    required this.photoAsset,
    required this.initial,
    required this.highlighted,
  });

  final String? photoAsset;
  final String initial;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? AppTheme.red.withValues(alpha: 0.35) : const Color(0xFFDCE3EC),
          width: 1.2,
        ),
        color: highlighted ? AppTheme.red.withValues(alpha: 0.08) : Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoAsset != null
          ? Image.asset(
              photoAsset!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: highlighted ? AppTheme.headerGradient : null,
        color: highlighted ? null : AppTheme.red.withValues(alpha: 0.12),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: highlighted ? Colors.white : AppTheme.red,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    );
  }
}
