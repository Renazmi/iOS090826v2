import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../data/seed_data.dart';
import '../../models/event_item.dart';
import '../../services/app_state.dart';
import '../../utils/open_attendance_check_in.dart';
import '../../widgets/common/trackit_event_tile.dart';
import '../../widgets/common/trackit_page_layout.dart';
import '../../widgets/common/trackit_scaffold.dart';
import '../../widgets/events/event_qr_dialog.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  int? _busyEventId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final events = app.events.activeEvents();

    final canManageEvents = app.roles.isOfficer && app.permissions.canManageEvents();

    return TrackitPageLayout(
      title: 'Events',
      subtitle: '',
      showHero: false,
      topPadding: 8,
      onRefresh: () => app.refreshDashboards(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canManageEvents)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => context.go('/officer/events/publish'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Publish event'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
          const TrackitSectionHeader(title: 'Event list'),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No ongoing or upcoming events.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...events.map(
              (event) => TrackitEventTile(
                event: event,
                badgeLabel: _badgeFor(app.events.effectiveStatus(event)),
                badgeColor: _badgeColor(app.events.effectiveStatus(event)),
                useRawDateTime: true,
                attendanceLines: _attendanceLines(app, event),
                showAttendanceActions: _canRecordAttendance(app),
                canTimeIn: _canTimeIn(app, event),
                canTimeOut: _canTimeOut(app, event),
                attendanceBusy: _busyEventId == event.id,
                onTimeIn: () => _handleTimeIn(app, event),
                onTimeOut: () => _handleTimeOut(app, event),
                onEdit: canManageEvents && !event.cancelled
                    ? () => context.go('/officer/events/publish?edit=${event.id}')
                    : null,
                onShowQr: canManageEvents && !event.cancelled
                    ? () => showEventQrDialog(
                          context,
                          eventId: event.id,
                          title: event.title,
                          events: app.events,
                        )
                    : null,
                onReschedule: canManageEvents && !event.cancelled
                    ? () => _rescheduleEvent(app, event)
                    : null,
                onCancel: canManageEvents && !event.cancelled
                    ? () => _cancelEvent(app, event)
                    : null,
                onDelete: canManageEvents && !isProtectedEventId(event.id)
                    ? () => _deleteEvent(app, event)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  bool _canRecordAttendance(AppState app) =>
      app.roles.isStudent || app.roles.isOfficer;

  bool _hasTimedIn(AppState app, EventItem event) => _myRecord(app, event) != null;

  bool _hasTimedOut(AppState app, EventItem event) {
    final record = _myRecord(app, event);
    return record?.timedOutAt != null;
  }

  bool _canTimeIn(AppState app, EventItem event) {
    if (event.cancelled) return false;
    if (app.events.effectiveStatus(event) != EventStatus.current) return false;
    return !_hasTimedIn(app, event) && app.attendance.canTimeInNow(event);
  }

  bool _canTimeOut(AppState app, EventItem event) {
    if (event.cancelled) return false;
    if (app.events.effectiveStatus(event) != EventStatus.current) return false;
    return _hasTimedIn(app, event) && !_hasTimedOut(app, event) && app.attendance.canTimeOutNow(event);
  }

  Future<void> _handleTimeIn(AppState app, EventItem event) async {
    if (!_canTimeIn(app, event)) return;
    await openAttendanceCheckIn(
      context,
      app: app,
      event: event,
      mode: AttendanceCheckInMode.timeIn,
    );
  }

  Future<void> _handleTimeOut(AppState app, EventItem event) async {
    if (!_canTimeOut(app, event)) return;
    await openAttendanceCheckIn(
      context,
      app: app,
      event: event,
      mode: AttendanceCheckInMode.timeOut,
    );
  }

  Future<void> _deleteEvent(AppState app, EventItem event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Permanently delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.events.removeEvent(event.id);
    await app.refreshDashboards();
    if (mounted) _showFeedback('Event deleted.', isError: false);
  }

  Future<void> _cancelEvent(AppState app, EventItem event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel event?'),
        content: Text('Mark "${event.title}" as cancelled? It will move off the active list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.events.cancelEvent(event.id);
    await app.refreshDashboards();
    if (mounted) _showFeedback('Event cancelled.', isError: false);
  }

  Future<void> _rescheduleEvent(AppState app, EventItem event) async {
    var selectedDate = DateTime.tryParse('${event.whenDate}T12:00:00') ?? DateTime.now();
    var selectedTime = _parseTimeOfDay(event.whenTime) ?? const TimeOfDay(hour: 9, minute: 0);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reschedule event'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 2),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(context)),
                    trailing: const Icon(Icons.schedule_outlined),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: selectedTime);
                      if (picked != null) setDialogState(() => selectedTime = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    final whenDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final whenTime =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
    try {
      await app.events.rescheduleEvent(eventId: event.id, whenDate: whenDate, whenTime: whenTime);
      await app.refreshDashboards();
      if (mounted) _showFeedback('Event rescheduled.', isError: false);
    } catch (error) {
      if (mounted) {
        _showFeedback(
          error is ArgumentError ? '${error.message}' : 'Could not reschedule event.',
          isError: true,
        );
      }
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  void _showFeedback(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.redDark : AppTheme.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<String> _attendanceLines(AppState app, EventItem event) {
    final lines = <String>[];
    final canManageEvents = app.roles.isOfficer && app.permissions.canManageEvents();

    if (canManageEvents) {
      lines
        ..add('Officers timed in: ${app.attendance.countOfficersTimedIn(event.id)}')
        ..add('Officers timed out: ${app.attendance.countOfficersTimedOut(event.id)}')
        ..add('Students timed in: ${app.attendance.countAttendeesTimedIn(event.id)}')
        ..add('Students timed out: ${app.attendance.countAttendeesTimedOut(event.id)}');
    }

    if (!_canRecordAttendance(app)) return lines;

    final timedIn = _myTimedInLabel(app, event);
    if (timedIn != null) {
      lines.add('Timed in: $timedIn');
    } else {
      lines.add('Not timed in yet');
    }
    final timedOut = _myTimedOutLabel(app, event);
    if (timedOut != null) {
      lines.add('Timed out: $timedOut');
    }
    return lines;
  }

  String? _myTimedInLabel(AppState app, EventItem event) {
    final record = _myRecord(app, event);
    if (record == null) return null;
    return _formatAttendanceTime(record.timedInAt);
  }

  String? _myTimedOutLabel(AppState app, EventItem event) {
    final record = _myRecord(app, event);
    if (record?.timedOutAt == null) return null;
    return _formatAttendanceTime(record!.timedOutAt!);
  }

  ({int timedInAt, int? timedOutAt})? _myRecord(AppState app, EventItem event) {
    if (app.roles.isStudent) {
      final studentId = app.auth.currentStudent?.studentId;
      if (studentId == null) return null;
      final record = app.attendance.getStudentRecord(event.id, studentId);
      if (record == null) return null;
      return (timedInAt: record.timedInAt, timedOutAt: record.timedOutAt);
    }
    if (app.roles.isOfficer) {
      final officerId = app.auth.currentOfficer?.id;
      if (officerId == null) return null;
      final record = app.attendance.getOfficerRecord(event.id, officerId);
      if (record == null) return null;
      return (timedInAt: record.timedInAt, timedOutAt: record.timedOutAt);
    }
    return null;
  }

  String _formatAttendanceTime(int ms) {
    return DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  String _badgeFor(EventStatus status) => switch (status) {
        EventStatus.current => 'Ongoing',
        EventStatus.upcoming => 'Upcoming',
        EventStatus.previous => 'Done',
      };

  Color _badgeColor(EventStatus status) => switch (status) {
        EventStatus.current => AppTheme.green,
        EventStatus.upcoming => AppTheme.blue,
        EventStatus.previous => AppTheme.textMuted,
      };
}
