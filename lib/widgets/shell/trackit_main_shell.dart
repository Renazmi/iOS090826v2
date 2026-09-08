import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_branding.dart';
import '../../config/mobile_nav_config.dart';
import '../../models/trackit_role.dart';
import '../../services/app_state.dart';
import '../../services/qr_camera_registry.dart';
import '../../utils/trackit_responsive.dart';
import '../common/trackit_app_background.dart';
import 'trackit_bottom_nav.dart';

class TrackitMainShell extends StatelessWidget {
  const TrackitMainShell({
    super.key,
    required this.role,
    required this.navigationShell,
  });

  final TrackitRole role;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final layout = context.layout;
    final location = GoRouterState.of(context).matchedLocation;
    final headerHeight = layout.headerTotalHeight;
    final scanIndex = MobileNavConfig.scanBranchIndex(role);
    final scanTabActive = navigationShell.currentIndex == scanIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      QrCameraRegistry.instance.setScanTabActive(scanTabActive);
    });

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          TrackitAppBackground(
            child: Padding(
              padding: EdgeInsets.only(top: headerHeight),
              child: navigationShell,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: layout.headerLogoBarHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(layout.pageHorizontalPadding, 4, layout.pageHorizontalPadding, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Hero(
                      tag: 'trackit-logo',
                      child: Image.asset(
                        AppBranding.logoForDarkMode(app.isDarkMode),
                        height: layout.headerLogoHeight,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TrackitBottomNav(
              role: role,
              currentLocation: location,
              onSideTap: (dest) {
                final index = MobileNavConfig.branchIndexFor(dest, role);
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              onScanTap: () {
                app.attendanceFlow.clearPendingTimeIn();
                final scanBranch = MobileNavConfig.scanBranchIndex(role);
                if (navigationShell.currentIndex == scanBranch) {
                  QrCameraRegistry.instance.reactivateScanTab();
                  return;
                }
                navigationShell.goBranch(scanBranch);
              },
            ),
          ),
        ],
      ),
    );
  }
}
