import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../models/officer.dart';
import '../../models/organization.dart';
import '../../services/app_state.dart';
import '../../utils/profile_photo_picker.dart';
import '../../widgets/common/trackit_decorations.dart';
import '../../widgets/common/trackit_page_layout.dart';
import '../../widgets/common/trackit_scaffold.dart';

const _positionOrder = [
  'President',
  'Vice President',
  'Secretary',
  'Treasurer',
  'Auditor',
  'P.R.O.',
  'Member',
];

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  int? _selectedOrgId;

  List<Organization> _featuredOrgs(List<Organization> orgs) {
    const featuredKeys = ['elite', 'obra', 'asp'];
    final featured = <Organization>[];
    for (final key in featuredKeys) {
      final match = orgs.where((org) => _orgKey(org.name) == key);
      if (match.isNotEmpty) featured.add(match.first);
    }
    if (featured.isNotEmpty) return featured;
    return orgs;
  }

  String _orgKey(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.contains('elite')) return 'elite';
    if (normalized.contains('obra')) return 'obra';
    if (normalized == 'asp' || normalized.startsWith('asp ') || normalized.contains('alliance')) {
      return 'asp';
    }
    return normalized;
  }

  List<Officer> _officersForOrg(AppState app, int orgId) {
    final officers = app.officerAuth.officers.where((o) => o.organizationId == orgId).toList();
    officers.sort((a, b) {
      final rankA = _positionOrder.indexOf(a.position);
      final rankB = _positionOrder.indexOf(b.position);
      final safeA = rankA >= 0 ? rankA : _positionOrder.length;
      final safeB = rankB >= 0 ? rankB : _positionOrder.length;
      final rankDiff = safeA.compareTo(safeB);
      if (rankDiff != 0) return rankDiff;
      return a.name.compareTo(b.name);
    });
    return officers;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colors = context.trackit;
    final orgs = _featuredOrgs(app.organizations.organizations);
    final selectedOrg = _selectedOrgId == null
        ? null
        : orgs.where((org) => org.id == _selectedOrgId).firstOrNull;
    final members = selectedOrg == null ? const <Officer>[] : _officersForOrg(app, selectedOrg.id);

    return TrackitPageLayout(
      title: 'Organizations',
      subtitle: 'Browse orgs and view their members.',
      heroTrailing: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
      ),
      onRefresh: () => app.refreshDashboards(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select an organization',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap ELITE, Obra, or ASP to view members.',
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (orgs.isEmpty)
            TrackitSurfaceCard(
              child: Text(
                'No organizations available yet.',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: orgs.map((org) {
                final memberCount = _officersForOrg(app, org.id).length;
                final selected = _selectedOrgId == org.id;
                return _OrgPickerChip(
                  org: org,
                  memberCount: memberCount,
                  selected: selected,
                  onTap: () => setState(() => _selectedOrgId = org.id),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          if (selectedOrg == null)
            TrackitSurfaceCard(
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose an organization above to see its members.',
                      style: TextStyle(color: colors.textSecondary, height: 1.45),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TrackitSectionHeader(
              title: '${selectedOrg.name} members (${members.length})',
            ),
            if (members.isEmpty)
              TrackitSurfaceCard(
                child: Text(
                  'No members listed for ${selectedOrg.name} yet.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              )
            else
              ...members.map(
                (officer) => TrackitSurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrackitProfileAvatar(
                        imageUrl: officer.profilePictureUrl,
                        fallbackLetter: officer.name.isNotEmpty ? officer.name[0] : '?',
                        size: 52,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              officer.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              officer.position,
                              style: TextStyle(color: colors.textSecondary),
                            ),
                            if (officer.section.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${officer.yearLevel} · ${officer.section}',
                                style: TextStyle(color: colors.textMuted, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textMuted.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OrgPickerChip extends StatelessWidget {
  const _OrgPickerChip({
    required this.org,
    required this.memberCount,
    required this.selected,
    required this.onTap,
  });

  final Organization org;
  final int memberCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;

    return Material(
      color: selected
          ? AppTheme.red.withValues(alpha: colors.isDark ? 0.22 : 0.08)
          : colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.red.withValues(alpha: 0.55) : colors.border,
            ),
            boxShadow: selected ? null : colors.softShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: selected ? AppTheme.headerGradient : null,
                  color: selected ? null : colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: org.logoUrl != null && org.logoUrl!.startsWith('assets/')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          org.logoUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _OrgInitial(name: org.name, selected: selected),
                        ),
                      )
                    : _OrgInitial(name: org.name, selected: selected),
              ),
              const SizedBox(height: 8),
              Text(
                org.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? AppTheme.red : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$memberCount member${memberCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgInitial extends StatelessWidget {
  const _OrgInitial({required this.name, required this.selected});

  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        color: selected ? Colors.white : AppTheme.red,
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
