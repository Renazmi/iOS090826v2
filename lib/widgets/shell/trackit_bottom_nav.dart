import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../config/mobile_nav_config.dart';
import '../../models/trackit_role.dart';
import '../../utils/trackit_responsive.dart';

/// Curved bottom bar with elevated center QR button — modern docked nav.
class TrackitBottomNav extends StatelessWidget {
  const TrackitBottomNav({
    super.key,
    required this.role,
    required this.currentLocation,
    required this.onSideTap,
    required this.onScanTap,
  });

  final TrackitRole role;
  final String currentLocation;
  final ValueChanged<MobileNavDestination> onSideTap;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final colors = context.trackit;
    const barHeight = TrackitLayoutMetrics.barHeight;
    const fabLift = TrackitLayoutMetrics.fabLift;
    const fabSize = 60.0;
    final sideItems = MobileNavConfig.sideDestinations(role);
    final leftItems = sideItems.sublist(0, 2);
    final rightItems = sideItems.sublist(2, 4);
    final activeId = MobileNavConfig.activeSideId(currentLocation, role);
    final scanActive = MobileNavConfig.isScanActive(currentLocation);
    final bottomPad = layout.viewPadding.bottom;

    return SizedBox(
      height: barHeight + fabLift + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                height: barHeight + bottomPad,
                decoration: BoxDecoration(
                  color: colors.navSurface.withValues(alpha: colors.isDark ? 0.92 : 1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.black.withValues(alpha: colors.isDark ? 0.55 : 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, -6),
                    ),
                  ],
                  border: Border(
                    top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: leftItems
                                .map(
                                  (item) => _NavIconButton(
                                    destination: item,
                                    selected: activeId == item.id,
                                    onTap: () => onSideTap(item),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        SizedBox(width: fabSize + 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: rightItems
                                .map(
                                  (item) => _NavIconButton(
                                    destination: item,
                                    selected: activeId == item.id,
                                    onTap: () => onSideTap(item),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: barHeight - fabLift + bottomPad - 6,
            child: _ScanFab(active: scanActive, size: fabSize, onTap: onScanTap),
          ),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final MobileNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;
    final color = selected ? AppTheme.red : colors.textMuted;

    return Material(
      color: selected ? AppTheme.red.withValues(alpha: colors.isDark ? 0.18 : 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? (destination.activeIcon ?? destination.icon) : destination.icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab({required this.active, required this.size, required this.onTap});

  final bool active;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = (size * 0.47).clamp(24.0, 28.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.scanFabGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.red.withValues(alpha: active ? 0.45 : 0.32),
            blurRadius: active ? 20 : 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
