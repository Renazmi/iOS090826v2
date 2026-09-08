import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/event_constants.dart';
import '../../models/event_item.dart';
import '../../models/geofence_coordinate.dart';
import '../../services/app_state.dart';
import '../../services/events_service.dart';
import '../../utils/trackit_responsive.dart';
import '../../widgets/common/trackit_app_background.dart';
import '../../widgets/events/event_geofence_section.dart';
import '../../widgets/events/event_qr_dialog.dart';

class EventPublishScreen extends StatefulWidget {
  const EventPublishScreen({super.key, this.editEventId});

  final int? editEventId;

  @override
  State<EventPublishScreen> createState() => _EventPublishScreenState();
}

class _EventPublishScreenState extends State<EventPublishScreen> {
  final _titleController = TextEditingController();
  final _whereController = TextEditingController(text: EventConstants.dctDefaultWhere);

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  TimeOfDay? _timeInWindowStart;
  TimeOfDay? _timeInWindowEnd;
  TimeOfDay? _timeOutWindowStart;
  TimeOfDay? _timeOutWindowEnd;

  EventScope _eventScope = EventScope.school;
  bool _assignAll = false;
  final Set<int> _selectedOfficerIds = {};
  bool _expireQrWhenEventDone = true;
  String? _imageUrl;
  EventGeofenceState _geofence = EventGeofenceState.dctDefault();

  bool _loading = false;
  String? _error;
  bool _initialized = false;

  bool get _isEditing => widget.editEventId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final app = context.read<AppState>();
    if (!app.permissions.canManageEvents()) {
      if (mounted) context.go('/officer/events');
      return;
    }

    if (_isEditing) {
      final event = app.events.getById(widget.editEventId!);
      if (event == null) {
        if (mounted) context.go('/officer/events');
        return;
      }
      _applyEvent(event);
    }

    setState(() => _initialized = true);
  }

  void _applyEvent(EventItem event) {
    _titleController.text = event.title;
    _whereController.text = event.where;
    _eventScope = event.eventScope;
    _assignAll = event.assignAll;
    _selectedOfficerIds
      ..clear()
      ..addAll(event.assignedOfficerIds);
    _expireQrWhenEventDone = event.expireQrWhenEventDone;
    _imageUrl = event.imageUrl;
    _selectedDate = DateTime.tryParse('${event.whenDate}T12:00:00');
    _selectedTime = _parseTime(event.whenTime);
    _timeInWindowStart = event.timeInWindowStart != null ? _parseTime(event.timeInWindowStart!) : null;
    _timeInWindowEnd = event.timeInWindowEnd != null ? _parseTime(event.timeInWindowEnd!) : null;
    _timeOutWindowStart = event.timeOutWindowStart != null ? _parseTime(event.timeOutWindowStart!) : null;
    _timeOutWindowEnd = event.timeOutWindowEnd != null ? _parseTime(event.timeOutWindowEnd!) : null;

    if (event.geofenceEnabled) {
      if (event.geofenceType == GeofenceType.polygon &&
          event.geofencePolygon != null &&
          event.geofencePolygon!.length >= 3) {
        _geofence = EventGeofenceState(
          enabled: true,
          geofenceType: GeofenceType.polygon,
          latitude: event.geofenceLatitude,
          longitude: event.geofenceLongitude,
          radiusMeters: event.geofenceRadiusMeters ?? 100,
          placeName: event.geofencePlaceName ?? 'DCT',
          polygon: event.geofencePolygon!.map((p) => p.copyWith()).toList(),
          preset: event.geofencePreset,
        );
      } else {
        _geofence = EventGeofenceState.manualCircle(
          latitude: event.geofenceLatitude,
          longitude: event.geofenceLongitude,
          radiusMeters: event.geofenceRadiusMeters ?? 100,
          placeName: event.geofencePlaceName ?? '',
        );
      }
    } else {
      _geofence = EventGeofenceState.dctDefault();
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _whereController.dispose();
    super.dispose();
  }

  String? get _dateLabel =>
      _selectedDate == null ? null : DateFormat('yyyy-MM-dd').format(_selectedDate!);

  String? _timeLabel(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  EventPublishPayload _buildPayload() {
    return EventPublishPayload(
      title: _titleController.text,
      whenDate: _dateLabel ?? '',
      whenTime: _timeLabel(_selectedTime) ?? '',
      where: _whereController.text,
      eventScope: _eventScope,
      assignAll: _assignAll,
      assignedOfficerIds: _selectedOfficerIds.toList(),
      imageUrl: _imageUrl,
      expireQrWhenEventDone: _expireQrWhenEventDone,
      timeInWindowStart: _timeLabel(_timeInWindowStart),
      timeInWindowEnd: _timeLabel(_timeInWindowEnd),
      timeOutWindowStart: _timeLabel(_timeOutWindowStart),
      timeOutWindowEnd: _timeLabel(_timeOutWindowEnd),
      geofenceEnabled: _geofence.enabled,
      geofenceType: _geofence.geofenceType,
      geofenceLatitude: _geofence.latitude,
      geofenceLongitude: _geofence.longitude,
      geofenceRadiusMeters: _geofence.radiusMeters,
      geofencePlaceName: _geofence.placeName,
      geofencePolygon: _geofence.polygon,
      geofencePreset: _geofence.preset,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({
    bool forEventTime = false,
    bool forTimeInStart = false,
    bool forTimeInEnd = false,
    bool forTimeOutStart = false,
    bool forTimeOutEnd = false,
  }) async {
    final initial = forTimeInStart
        ? (_timeInWindowStart ?? const TimeOfDay(hour: 8, minute: 0))
        : forTimeInEnd
            ? (_timeInWindowEnd ?? const TimeOfDay(hour: 9, minute: 0))
            : forTimeOutStart
                ? (_timeOutWindowStart ?? const TimeOfDay(hour: 16, minute: 0))
                : forTimeOutEnd
                    ? (_timeOutWindowEnd ?? const TimeOfDay(hour: 18, minute: 0))
                    : (_selectedTime ?? const TimeOfDay(hour: 9, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (forTimeInStart) {
        _timeInWindowStart = picked;
      } else if (forTimeInEnd) {
        _timeInWindowEnd = picked;
      } else if (forTimeOutStart) {
        _timeOutWindowStart = picked;
      } else if (forTimeOutEnd) {
        _timeOutWindowEnd = picked;
      } else if (forEventTime) {
        _selectedTime = picked;
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? 'image/jpeg';
    setState(() => _imageUrl = 'data:$mime;base64,${base64Encode(bytes)}');
  }

  Future<void> _submit(AppState app) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await app.events.updateEvent(widget.editEventId!, _buildPayload());
        await app.refreshDashboards();
        if (!mounted) return;
        setState(() => _loading = false);
        context.go('/officer/events');
      } else {
        final event = await app.events.publishEvent(_buildPayload());
        await app.refreshDashboards();
        if (!mounted) return;
        await showEventQrDialog(
          context,
          eventId: event.id,
          title: event.title,
          events: app.events,
        );
        if (!mounted) return;
        context.go('/officer/events');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ArgumentError ? '${error.message}' : 'Could not save the event.';
      });
    }
  }

  Future<void> _confirmDelete(AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text('This permanently removes the event and cannot be undone.'),
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
    if (confirmed != true || !mounted) return;
    await app.events.removeEvent(widget.editEventId!);
    await app.refreshDashboards();
    if (!mounted) return;
    context.go('/officer/events');
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.red)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/officer/events'),
        ),
        title: Text(
          _isEditing ? 'Edit event' : 'Publish event',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _loading ? null : () => _confirmDelete(context.read<AppState>()),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              tooltip: 'Delete event',
            ),
        ],
      ),
      body: TrackitAppBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              layout.pageHorizontalPadding,
              8,
              layout.pageHorizontalPadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing
                      ? 'Update event details, officer assignments, and QR settings.'
                      : 'Create a new event and generate a QR code for attendance.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72), height: 1.4),
                ),
                const SizedBox(height: 20),
                _FieldLabel('Event title'),
                _FormField(controller: _titleController, hint: 'e.g. General Assembly'),
                const SizedBox(height: 16),
                _FieldLabel('Event type'),
                _ScopeSelector(
                  value: _eventScope,
                  onChanged: (scope) {
                    setState(() {
                      _eventScope = scope;
                      if (scope == EventScope.ccs) {
                        _whereController.text = EventConstants.dctDefaultWhere;
                        _geofence = EventGeofenceState.dctDefault();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                _FieldLabel('Date'),
                _PickerField(
                  value: _dateLabel ?? 'Select date',
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                _FieldLabel('Time'),
                _PickerField(
                  value: _timeLabel(_selectedTime) ?? 'Select time',
                  icon: Icons.schedule_outlined,
                  onTap: () => _pickTime(forEventTime: true),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Where'),
                _FormField(controller: _whereController, hint: EventConstants.dctDefaultWhere),
                const SizedBox(height: 16),
                EventGeofenceSection(
                  state: _geofence,
                  onChanged: (value) => setState(() => _geofence = value),
                  onApplyDctWhere: () => _whereController.text = EventConstants.dctDefaultWhere,
                ),
                const SizedBox(height: 16),
                _FieldLabel('Event image (optional)'),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Choose image'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                    if (_imageUrl != null) ...[
                      const SizedBox(width: 8),
                      TextButton(onPressed: () => setState(() => _imageUrl = null), child: const Text('Remove')),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel('Assign officers'),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Select all officers', style: TextStyle(color: Colors.white)),
                  value: _assignAll,
                  activeColor: AppTheme.red,
                  onChanged: (value) => setState(() => _assignAll = value),
                ),
                if (!_assignAll)
                  ...defaultEventOfficers.map(
                    (officer) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(officer.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text('Officer #${officer.id}', style: TextStyle(color: Colors.white.withValues(alpha: 0.55))),
                      value: _selectedOfficerIds.contains(officer.id),
                      activeColor: AppTheme.red,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedOfficerIds.add(officer.id);
                          } else {
                            _selectedOfficerIds.remove(officer.id);
                          }
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expire QR when event is done', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'QR codes stop working after the event ends.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                  ),
                  value: _expireQrWhenEventDone,
                  activeColor: AppTheme.red,
                  onChanged: (value) => setState(() => _expireQrWhenEventDone = value),
                ),
                const SizedBox(height: 8),
                _FieldLabel('Time-in window (optional)'),
                Text(
                  'Time in is only allowed between start and end on the event date.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        value: _timeLabel(_timeInWindowStart) ?? 'Time-in start',
                        icon: Icons.access_time,
                        onTap: () => _pickTime(forTimeInStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerField(
                        value: _timeLabel(_timeInWindowEnd) ?? 'Time-in end',
                        icon: Icons.access_time_filled,
                        onTap: () => _pickTime(forTimeInEnd: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _FieldLabel('Time-out window (optional)'),
                Text(
                  'Time out is only allowed between start and end on the event date.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        value: _timeLabel(_timeOutWindowStart) ?? 'Time-out start',
                        icon: Icons.access_time,
                        onTap: () => _pickTime(forTimeOutStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerField(
                        value: _timeLabel(_timeOutWindowEnd) ?? 'Time-out end',
                        icon: Icons.access_time_filled,
                        onTap: () => _pickTime(forTimeOutEnd: true),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: layout.loginButtonHeight,
                  child: FilledButton(
                    onPressed: _loading ? null : () => _submit(context.read<AppState>()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isEditing ? 'Save changes' : 'Publish event',
                            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => showEventQrDialog(
                      context,
                      eventId: widget.editEventId!,
                      title: _titleController.text.trim(),
                      events: context.read<AppState>().events,
                    ),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('View event QR code'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({required this.value, required this.onChanged});

  final EventScope value;
  final ValueChanged<EventScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: EventScope.values.map((scope) {
        return RadioListTile<EventScope>(
          contentPadding: EdgeInsets.zero,
          title: Text(EventConstants.scopeLabel(scope), style: const TextStyle(color: Colors.white)),
          value: scope,
          groupValue: value,
          activeColor: AppTheme.red,
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.controller, required this.hint, this.maxLines = 1});

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.value, required this.icon, required this.onTap});

  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: value.contains('Select') || value.contains('Window') ? 0.45 : 0.92),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.45)),
            ],
          ),
        ),
      ),
    );
  }
}
