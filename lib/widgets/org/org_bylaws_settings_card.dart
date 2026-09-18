import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/organization.dart';
import '../../services/app_state.dart';
import '../common/trackit_decorations.dart';
import 'org_bylaws_sheet.dart';

/// Settings by-laws card shared by officer and attendee so both platforms
/// render the same layout, copy, and constitution viewer.
class OrgBylawsSettingsCard extends StatelessWidget {
  const OrgBylawsSettingsCard({super.key});

  static bool isFeaturedOrg(Organization org) {
    final key = org.name.trim().toLowerCase();
    return key.contains('elite') ||
        key.contains('obra') ||
        key.contains('asp') ||
        key.contains('alliance');
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context
        .watch<AppState>()
        .organizations
        .organizations
        .where(isFeaturedOrg);

    return TrackitSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Organization by-laws',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Open constitutions for ELITE, Obra, and ASP without selecting an org first.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 8),
          ...orgs.map(
            (org) => Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showOrgBylawsSheet(context, org),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text('${org.name} by-laws'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
