import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/event_item.dart';
import '../../models/announcement_item.dart';
import '../../services/app_state.dart';
import '../../services/chat_service.dart';
import '../../widgets/common/trackit_decorations.dart';
import '../../widgets/common/trackit_event_tile.dart';
import '../../widgets/common/trackit_page_layout.dart';
import '../../widgets/common/trackit_scaffold.dart';

class OfficerDashboardScreen extends StatelessWidget {
  const OfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final data = app.dashboard.buildOfficerDashboard();

    if (data == null) {
      return TrackitPageLayout(
        title: 'Dashboard',
        subtitle: 'Loading your officer dashboard…',
        showHero: false,
        topPadding: 8,
        body: TrackitEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load dashboard',
          message:
              'Your session is active as ${app.roles.displayName}, but officer profile data is still loading. Pull down to refresh or log in again.',
        ),
        onRefresh: () async {
          await app.auth.initialize();
          app.notifyAuthChanged();
        },
      );
    }

    return TrackitPageLayout(
      title: 'Dashboard',
      subtitle: '',
      showHero: false,
      topPadding: 8,
      onRefresh: () => app.refreshDashboards(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: TrackitSectionHeader(title: 'Campus events')),
              TextButton(
                onPressed: () => context.go('/officer/events'),
                child: const Text('View all'),
              ),
            ],
          ),
          if (data.campusEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('No scheduled events.', style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...data.campusEvents.map((event) {
              final status = app.events.effectiveStatus(event);
              final badge = switch (status) {
                EventStatus.current => 'Ongoing',
                EventStatus.upcoming => 'Upcoming',
                EventStatus.previous => 'Ended',
              };
              final color = switch (status) {
                EventStatus.current => AppTheme.green,
                EventStatus.upcoming => AppTheme.blue,
                EventStatus.previous => AppTheme.textMuted,
              };
              return TrackitEventTile(event: event, badgeLabel: badge, badgeColor: color);
            }),
          if (data.eventsToday.isNotEmpty) ...[
            const SizedBox(height: 8),
            TrackitSurfaceCard(
              accentColor: AppTheme.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's schedule",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ...data.eventsToday.map(
                    (ev) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ev.whenTime.isEmpty
                            ? ev.title
                            : '${ev.title} · ${_formatTime(ev.whenTime)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              const Expanded(child: TrackitSectionHeader(title: 'Mentions & announcements')),
              TextButton(
                onPressed: () => context.go('/officer/message'),
                child: const Text('View all'),
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final announcementRows = app.announcements.recent(limit: 4);
              final mentionRows = app.chat.dashboardMessagesForOfficer(
                data.officer.id,
                officerName: data.officer.name,
                limit: 4,
              ).where((m) => !m.isAnnouncement).toList();

              if (announcementRows.isEmpty && mentionRows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No mentions or announcements yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return TrackitSurfaceCard(
                child: Column(
                  children: [
                    ...announcementRows.map((a) => _announcementRow(context, a)),
                    ...mentionRows.map((m) => _messageRow(context, m)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _announcementRow(BuildContext context, AnnouncementItem announcement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  announcement.senderName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
              ),
              Text(
                announcement.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.blue,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            announcement.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _messageRow(BuildContext context, ChatMessage message) {
    final label = message.isAnnouncement ? 'Announcement' : 'Mentioned you';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message.senderName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: message.isAnnouncement ? AppTheme.blue : AppTheme.red,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;
    final date = DateTime(1970, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.jm().format(date);
  }
}
