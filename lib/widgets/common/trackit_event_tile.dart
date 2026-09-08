import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../config/trackit_colors.dart';
import '../../models/event_item.dart';
import '../../utils/trackit_responsive.dart';
import 'trackit_decorations.dart';

class TrackitEventTile extends StatelessWidget {
  const TrackitEventTile({
    super.key,
    required this.event,
    this.badgeLabel,
    this.badgeColor = AppTheme.blue,
    this.useRawDateTime = false,
    this.attendanceLines = const [],
    this.showAttendanceActions = false,
    this.canTimeIn = false,
    this.canTimeOut = false,
    this.onTimeIn,
    this.onTimeOut,
    this.onEdit,
    this.onDelete,
    this.onCancel,
    this.onReschedule,
    this.onShowQr,
    this.attendanceBusy = false,
  });

  final EventItem event;
  final String? badgeLabel;
  final Color badgeColor;
  final bool useRawDateTime;
  final List<String> attendanceLines;
  final bool showAttendanceActions;
  final bool canTimeIn;
  final bool canTimeOut;
  final VoidCallback? onTimeIn;
  final VoidCallback? onTimeOut;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;
  final VoidCallback? onShowQr;
  final bool attendanceBusy;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;
    final layout = context.layout;
    final stackActions = layout.isCompactWidth;
    final dateLabel = _formatShortDate(event.whenDate);
    final timeLabel = _formatTime(event.whenTime);

    return TrackitSurfaceCard(
      accentColor: badgeColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  badgeColor.withValues(alpha: 0.15),
                  badgeColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  dateLabel.split(' ').first,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  dateLabel.split(' ').length > 1 ? dateLabel.split(' ')[1] : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      const SizedBox(width: 8),
                      _Badge(label: badgeLabel!, color: badgeColor),
                    ],
                  ],
                ),
                if (event.description != null && event.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 10),
                _meta(
                  context,
                  Icons.schedule_rounded,
                  useRawDateTime ? '${event.whenDate} ${event.whenTime}'.trim() : timeLabel,
                ),
                const SizedBox(height: 4),
                _meta(context, Icons.location_on_outlined, event.where),
                if (attendanceLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...attendanceLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: line.startsWith('Timed') ? FontWeight.w600 : FontWeight.w400,
                          color: line.startsWith('Timed')
                              ? AppTheme.green
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
                if (showAttendanceActions) ...[
                  const SizedBox(height: 12),
                  if (stackActions)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._manageActionButtons(stack: true),
                        if (onEdit != null) ...[
                          _AttendanceButton(
                            label: 'Edit event',
                            icon: Icons.edit_outlined,
                            enabled: !attendanceBusy,
                            filled: false,
                            onPressed: onEdit,
                          ),
                          const SizedBox(height: 8),
                        ],
                        _AttendanceButton(
                          label: 'Time in',
                          icon: Icons.login_rounded,
                          enabled: canTimeIn && !attendanceBusy,
                          filled: true,
                          onPressed: onTimeIn,
                        ),
                        const SizedBox(height: 8),
                        _AttendanceButton(
                          label: 'Time out',
                          icon: Icons.logout_rounded,
                          enabled: canTimeOut && !attendanceBusy,
                          filled: false,
                          onPressed: onTimeOut,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._manageActionButtons(stack: false),
                        if (onEdit != null) ...[
                          _AttendanceButton(
                            label: 'Edit event',
                            icon: Icons.edit_outlined,
                            enabled: !attendanceBusy,
                            filled: false,
                            onPressed: onEdit,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: _AttendanceButton(
                                label: 'Time in',
                                icon: Icons.login_rounded,
                                enabled: canTimeIn && !attendanceBusy,
                                filled: true,
                                onPressed: onTimeIn,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AttendanceButton(
                                label: 'Time out',
                                icon: Icons.logout_rounded,
                                enabled: canTimeOut && !attendanceBusy,
                                filled: false,
                                onPressed: onTimeOut,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ] else ...[
                  ..._manageActionButtons(stack: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _manageActionButtons({required bool stack}) {
    final actions = <({String label, IconData icon, VoidCallback? onTap})>[
      (label: 'View QR', icon: Icons.qr_code_rounded, onTap: onShowQr),
      (label: 'Reschedule', icon: Icons.event_repeat_rounded, onTap: onReschedule),
      (label: 'Cancel event', icon: Icons.cancel_outlined, onTap: onCancel),
      (label: 'Delete event', icon: Icons.delete_outline_rounded, onTap: onDelete),
    ].where((item) => item.onTap != null).toList();

    if (actions.isEmpty) return const [];

    return [
      for (final action in actions) ...[
        _AttendanceButton(
          label: action.label,
          icon: action.icon,
          enabled: !attendanceBusy,
          filled: false,
          onPressed: action.onTap,
        ),
        if (stack || action != actions.last) const SizedBox(height: 8),
      ],
    ];
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    final colors = context.trackit;
    return Row(
      children: [
        Icon(icon, size: 15, color: colors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }

  static String _formatShortDate(String dateStr) {
    final date = DateTime.tryParse('${dateStr}T12:00:00');
    if (date == null) return dateStr;
    return DateFormat('MMM d').format(date);
  }

  static String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return 'All day';
    final parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;
    final date = DateTime(1970, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.jm().format(date);
  }
}

class _AttendanceButton extends StatelessWidget {
  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.trackit;
    return Material(
      color: filled
          ? (enabled ? AppTheme.red : AppTheme.red.withValues(alpha: 0.35))
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled
                  ? Colors.transparent
                  : (enabled ? AppTheme.red : colors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled
                    ? Colors.white
                    : (enabled ? AppTheme.red : colors.textMuted),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: filled
                      ? Colors.white
                      : (enabled ? AppTheme.red : colors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
