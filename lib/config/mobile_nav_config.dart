import 'package:flutter/material.dart';

import '../models/trackit_role.dart';

/// Bottom navigation destinations (4 tabs + center QR FAB).
class MobileNavDestination {
  const MobileNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.routeSuffix,
    this.activeIcon,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  /// Path segment after `/student` or `/officer`.
  final String routeSuffix;

  String routeFor(TrackitRole role) {
    final prefix = role == TrackitRole.officer ? '/officer' : '/student';
    return '$prefix/$routeSuffix';
  }
}

abstract final class MobileNavConfig {
  static const scanDestination = MobileNavDestination(
    id: 'scan',
    label: 'Scan QR',
    icon: Icons.add,
    routeSuffix: 'scan',
  );

  static const studentSideDestinations = [
    MobileNavDestination(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      routeSuffix: 'dashboard',
    ),
    MobileNavDestination(
      id: 'events',
      label: 'Events',
      icon: Icons.event_outlined,
      activeIcon: Icons.event,
      routeSuffix: 'events',
    ),
    MobileNavDestination(
      id: 'organizations',
      label: 'Org',
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment,
      routeSuffix: 'organizations',
    ),
    MobileNavDestination(
      id: 'profile',
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      routeSuffix: 'profile',
    ),
  ];

  static const officerSideDestinations = [
    MobileNavDestination(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      routeSuffix: 'dashboard',
    ),
    MobileNavDestination(
      id: 'events',
      label: 'Events',
      icon: Icons.event_outlined,
      activeIcon: Icons.event,
      routeSuffix: 'events',
    ),
    MobileNavDestination(
      id: 'message',
      label: 'Message',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      routeSuffix: 'message',
    ),
    MobileNavDestination(
      id: 'profile',
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      routeSuffix: 'profile',
    ),
  ];

  static List<MobileNavDestination> sideDestinations(TrackitRole role) {
    return role == TrackitRole.officer
        ? officerSideDestinations
        : studentSideDestinations;
  }

  static int branchIndexFor(MobileNavDestination dest, TrackitRole role) {
    final items = sideDestinations(role);
    return items.indexWhere((item) => item.id == dest.id);
  }

  static int scanBranchIndex(TrackitRole role) => sideDestinations(role).length;

  static String? activeSideId(String location, TrackitRole role) {
    if (location.contains('/scan')) return scanDestination.id;
    for (final dest in sideDestinations(role)) {
      if (location == dest.routeFor(role)) return dest.id;
    }
    return null;
  }

  static bool isScanActive(String location) => location.contains('/scan');
}
