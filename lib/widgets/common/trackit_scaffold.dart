import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../utils/profile_photo_picker.dart';
import '../../utils/trackit_logout.dart';
import 'trackit_decorations.dart';

class TrackitDashboardScaffold extends StatelessWidget {
  const TrackitDashboardScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.auth,
    required this.body,
  });

  final String title;
  final String subtitle;
  final AuthService auth;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        title: Row(
          children: [
            Image.asset('assets/images/trackit-logo.png', height: 28),
            const SizedBox(width: 10),
            const Text('TrackIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => confirmLogoutAndExit(
              context,
              onLogout: () => context.read<AppState>().auth.logout(),
            ),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.red,
        onRefresh: () async {},
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: TrackitPageHero(title: title, subtitle: subtitle)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(child: body),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackitSectionHeader extends StatelessWidget {
  const TrackitSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class TrackitRoleChip extends StatelessWidget {
  const TrackitRoleChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.red.withValues(alpha: 0.14),
            AppTheme.redDark.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.red.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.redDark,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class TrackitInfoCard extends StatelessWidget {
  const TrackitInfoCard({
    super.key,
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return TrackitSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppTheme.red, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: const BoxDecoration(
                      color: AppTheme.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(lines[i], style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TrackitProfileCard extends StatelessWidget {
  const TrackitProfileCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.roleLabel,
    this.avatarLetter,
    this.imageUrl,
  });

  final String name;
  final String subtitle;
  final String roleLabel;
  final String? avatarLetter;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final letter = avatarLetter ?? (name.isNotEmpty ? name[0].toUpperCase() : '?');

    return TrackitSurfaceCard(
      accentColor: AppTheme.red,
      child: Row(
        children: [
          TrackitProfileAvatar(
            imageUrl: imageUrl,
            fallbackLetter: letter,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TrackitRoleChip(label: roleLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrackitActionButton extends StatelessWidget {
  const TrackitActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.red,
          side: BorderSide(color: AppTheme.red.withValues(alpha: 0.35)),
          backgroundColor: AppTheme.red.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
