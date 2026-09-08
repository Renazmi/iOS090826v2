import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/event_item.dart';
import '../../services/app_state.dart';
import '../../widgets/common/trackit_event_tile.dart';
import '../../widgets/common/trackit_page_layout.dart';
import '../../widgets/common/trackit_scaffold.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final data = app.dashboard.buildStudentDashboard();

    if (data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.red),
      );
    }

    return TrackitPageLayout(
      title: 'Dashboard',
      subtitle:
          'Welcome, ${data.student.fullName}. Browse ongoing and upcoming campus events.',
      heroTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              DateFormat.yMMMMEEEEd().format(DateTime.now()),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: TrackitSectionHeader(title: 'Campus events'),
              ),
              TextButton(
                onPressed: () => context.go('/student/events'),
                child: const Text('View all'),
              ),
            ],
          ),
          _eventGroup(context, 'Ongoing', data.ongoingEvents, 'Ongoing', AppTheme.green),
          _eventGroup(context, 'Upcoming', data.upcomingEvents, 'Upcoming', AppTheme.blue),
        ],
      ),
    );
  }

  Widget _eventGroup(
    BuildContext context,
    String title,
    List<EventItem> events,
    String badge,
    Color badgeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              title == 'Ongoing'
                  ? 'No events are happening right now.'
                  : 'No upcoming events scheduled.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...events.map(
            (event) => TrackitEventTile(
              event: event,
              badgeLabel: badge,
              badgeColor: badgeColor,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
