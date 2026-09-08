import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/seed_data.dart';
import '../models/event_item.dart';
import '../models/geofence_coordinate.dart';
import '../utils/event_form_validation.dart';
import '../utils/event_time_windows.dart';
import '../utils/event_qr_code.dart';
import '../utils/geofence.dart';
import 'api_service.dart';
import 'firestore_sync_service.dart';
import 'storage_service.dart';

export '../utils/event_form_validation.dart' show EventPublishPayload;

/// Mirrors `EventsService` from the Ionic web app.
class EventsService {
  EventsService(this._storage, this._api);

  final StorageService _storage;
  final ApiService _api;

  List<EventItem> _events = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _seededFirestore = false;
  void Function()? _onChanged;

  List<EventItem> get events => List.unmodifiable(_events);

  void setOnChanged(void Function()? callback) {
    _onChanged = callback;
  }

  Future<void> initialize() async {
    // Cached events paint the UI immediately; Firestore snapshot is the source of truth.
    final rows = _storage.readJsonList(StorageKeys.events);
    if (rows.isNotEmpty) {
      _events = rows.map(EventItem.fromJson).toList();
    }

    await _startListener();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _save() async {
    await _api.saveCollection(
      StorageKeys.events,
      _events.map((e) => e.toJson()).toList(),
    );
    _onChanged?.call();
  }

  Future<void> _startListener() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    await _sub?.cancel();
    _sub = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.events)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) {
        _seededFirestore = true;
        return;
      }

      _seededFirestore = true;
      _events = snap.docs
          .map((doc) => EventItem.fromJson({...doc.data(), 'id': _parseEventId(doc)}))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (getById(attendanceTestEventId) == null) {
        await publishAttendanceTestEvent();
      }
      await _api.saveCollection(
        StorageKeys.events,
        _events.map((e) => e.toJson()).toList(),
      );
      _onChanged?.call();
    });
  }

  int _parseEventId(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final dataId = doc.data()['id'];
    if (dataId is int) return dataId;
    return int.tryParse(doc.id) ?? 0;
  }

  Future<void> _seedFirestore() async {
    if (_events.isEmpty) {
      _events = buildDefaultEvents();
      await _storage.writeInt(StorageKeys.eventsCatalogVersion, eventsCatalogVersion);
    }
    await publishAttendanceTestEvent();
    final db = FirestoreSyncService.instance.db;
    for (final event in _events) {
      await db.collection(FirestoreCollections.events).doc('${event.id}').set(event.toJson());
    }
    await _api.saveCollection(
      StorageKeys.events,
      _events.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _writeEventToFirestore(EventItem event) async {
    if (!FirestoreSyncService.instance.isReady) return;
    await FirestoreSyncService.instance.db
        .collection(FirestoreCollections.events)
        .doc('${event.id}')
        .set(event.toJson());
  }

  Future<void> _deleteEventFromFirestore(int eventId) async {
    if (!FirestoreSyncService.instance.isReady) return;
    await FirestoreSyncService.instance.db
        .collection(FirestoreCollections.events)
        .doc('$eventId')
        .delete();
  }

  List<EventItem> eventsByStatus(EventStatus status) {
    final list = _events.where((e) => !e.cancelled && effectiveStatus(e) == status).toList();
    if (status == EventStatus.previous) {
      list.sort((a, b) {
        final dateCmp = b.whenDate.compareTo(a.whenDate);
        if (dateCmp != 0) return dateCmp;
        return b.whenTime.compareTo(a.whenTime);
      });
    } else {
      list.sort((a, b) {
        final dateCmp = a.whenDate.compareTo(b.whenDate);
        if (dateCmp != 0) return dateCmp;
        return a.whenTime.compareTo(b.whenTime);
      });
    }
    return list;
  }

  EventItem? getById(int id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  List<EventItem> eventsToday() {
    final today = _todayStr();
    return _events.where((e) => !e.cancelled && e.whenDate == today).toList()
      ..sort((a, b) => a.whenTime.compareTo(b.whenTime));
  }

  List<EventItem> activeEvents() {
    final events = _events
        .where((e) {
          if (e.cancelled) return false;
          final status = effectiveStatus(e);
          return status == EventStatus.current || status == EventStatus.upcoming;
        })
        .toList();
    events.sort((a, b) {
      final statusA = effectiveStatus(a);
      final statusB = effectiveStatus(b);
      int order(EventStatus s) =>
          s == EventStatus.current ? 0 : (s == EventStatus.upcoming ? 1 : 2);
      final o = order(statusA) - order(statusB);
      if (o != 0) return o;
      final dateCmp = a.whenDate.compareTo(b.whenDate);
      if (dateCmp != 0) return dateCmp;
      return a.whenTime.compareTo(b.whenTime);
    });
    return events;
  }

  List<EventItem> campusEventsPreview({int limit = 8}) {
    return activeEvents().take(limit).toList();
  }

  int countEventsToday() {
    final today = _todayStr();
    return _events.where((e) => !e.cancelled && e.whenDate == today).length;
  }

  int countCurrentEvents() {
    return _events.where((e) => !e.cancelled && effectiveStatus(e) == EventStatus.current).length;
  }

  EventStatus effectiveStatus(EventItem event) {
    if (event.id == attendanceTestEventId) {
      return _resolveAttendanceTestStatus();
    }
    final today = _todayStr();
    final dateCmp = event.whenDate.compareTo(today);
    if (dateCmp > 0) return EventStatus.upcoming;
    if (dateCmp < 0) return EventStatus.previous;
    return EventStatus.current;
  }

  EventStatus _resolveAttendanceTestStatus() {
    final start = EventTimeWindows.parseLocalDateTime(attendanceTestWhenDate, attendanceTestWindowStart);
    final end = EventTimeWindows.parseLocalDateTime(attendanceTestWindowEndDate, attendanceTestWindowEnd);
    final now = DateTime.now();
    if (start == null || end == null) return EventStatus.current;
    if (now.isBefore(start)) return EventStatus.upcoming;
    if (now.isAfter(end)) return EventStatus.previous;
    return EventStatus.current;
  }

  String _todayStr() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  EventItem _buildAttendanceTestEvent() {
    return EventItem(
      id: attendanceTestEventId,
      title: 'BETA TEST',
      description:
          'Beta test event for verifying time in and time out. Schedule: Aug 19 10:00 PM – Aug 20 11:00 PM. Geofence off for remote testing.',
      whenDate: attendanceTestWhenDate,
      whenTime: attendanceTestWindowStart,
      where: 'Dominican College of Tarlac (DCT)',
      eventScope: EventScope.school,
      assignAll: true,
      assignedOfficerIds: const [],
      officersAttended: 0,
      attendeesScanned: 0,
      officersTimedIn: 0,
      officersTimedOut: 0,
      attendeesTimedIn: 0,
      attendeesTimedOut: 0,
      status: _resolveAttendanceTestStatus(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      cancelled: false,
      expireQrWhenEventDone: true,
      timeInWindowStart: attendanceTestWindowStart,
      timeInWindowEnd: attendanceTestWindowEnd,
      timeInWindowEndDate: attendanceTestWindowEndDate,
      timeOutWindowStart: attendanceTestWindowStart,
      timeOutWindowEnd: attendanceTestWindowEnd,
      timeOutWindowEndDate: attendanceTestWindowEndDate,
      geofenceEnabled: false,
    );
  }

  bool _attendanceTestNeedsUpdate(EventItem? existing) {
    if (existing == null) return true;
    final template = _buildAttendanceTestEvent();
    final effectiveStatus = _resolveAttendanceTestStatus();
    return existing.title != template.title ||
        existing.whenDate != template.whenDate ||
        existing.whenTime != template.whenTime ||
        existing.status != effectiveStatus ||
        existing.cancelled == true ||
        existing.geofenceEnabled != false ||
        existing.timeInWindowStart != template.timeInWindowStart ||
        existing.timeInWindowEnd != template.timeInWindowEnd ||
        existing.timeInWindowEndDate != template.timeInWindowEndDate ||
        existing.timeOutWindowStart != template.timeOutWindowStart ||
        existing.timeOutWindowEnd != template.timeOutWindowEnd ||
        existing.timeOutWindowEndDate != template.timeOutWindowEndDate;
  }

  Future<void> publishAttendanceTestEvent({bool force = false}) async {
    final existing = getById(attendanceTestEventId);
    if (existing != null && !force) {
      return;
    }

    final template = _buildAttendanceTestEvent();
    final index = _events.indexWhere((event) => event.id == attendanceTestEventId);

    if (index >= 0) {
      final previous = _events[index];
      _events[index] = template.copyWith(
        createdAt: previous.createdAt,
        officersAttended: previous.officersAttended,
        attendeesScanned: previous.attendeesScanned,
        officersTimedIn: previous.officersTimedIn,
        officersTimedOut: previous.officersTimedOut,
        attendeesTimedIn: previous.attendeesTimedIn,
        attendeesTimedOut: previous.attendeesTimedOut,
        imageUrl: previous.imageUrl,
      );
    } else {
      _events.insert(0, template);
    }

    await _save();
    final saved = getById(attendanceTestEventId);
    if (saved != null) {
      await _writeEventToFirestore(saved);
    }
  }

  int _nextEventId() {
    if (_events.isEmpty) return 1;
    return _events.map((event) => event.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  bool isWithinEventGeofence(EventItem event, double latitude, double longitude) {
    if (!event.geofenceEnabled) return true;

    if (event.geofenceType == GeofenceType.polygon &&
        event.geofencePolygon != null &&
        event.geofencePolygon!.length >= 3) {
      return isPointInPolygon(latitude, longitude, event.geofencePolygon!);
    }

    if (event.geofenceLatitude == null ||
        event.geofenceLongitude == null ||
        event.geofenceRadiusMeters == null ||
        event.geofenceRadiusMeters! <= 0) {
      return false;
    }

    return isWithinGeofence(
      event.geofenceLatitude!,
      event.geofenceLongitude!,
      event.geofenceRadiusMeters!,
      latitude,
      longitude,
    );
  }

  ({bool ok, String? message}) validateCheckInLocation(
    EventItem event,
    double latitude,
    double longitude,
  ) {
    if (!event.geofenceEnabled) return (ok: true, message: null);
    if (isWithinEventGeofence(event, latitude, longitude)) {
      return (ok: true, message: null);
    }

    final areaLabel = event.geofencePreset == GeofencePresetId.dct || event.geofencePlaceName == 'DCT'
        ? 'the DCT campus boundary'
        : 'the event area';

    return (
      ok: false,
      message: 'Check-in rejected. You must be inside $areaLabel to time in or time out.',
    );
  }

  String qrPayloadForEvent(int eventId) => EventQrCode.qrPayload(eventId);

  Future<EventItem> publishEvent(EventPublishPayload payload) async {
    final error = EventFormValidation.validate(payload);
    if (error != null) throw ArgumentError(error);

    final geofence = EventFormValidation.geofenceFields(payload);
    final where = payload.where.trim();

    final event = EventItem(
      id: _nextEventId(),
      title: payload.title.trim(),
      eventScope: payload.eventScope,
      description: payload.description?.trim().isNotEmpty == true ? payload.description!.trim() : null,
      whenDate: payload.whenDate.trim(),
      whenTime: payload.whenTime.trim(),
      where: where,
      assignAll: payload.assignAll,
      assignedOfficerIds: payload.assignAll ? const [] : List<int>.from(payload.assignedOfficerIds),
      officersAttended: 0,
      attendeesScanned: 0,
      officersTimedIn: 0,
      officersTimedOut: 0,
      attendeesTimedIn: 0,
      attendeesTimedOut: 0,
      status: EventStatus.upcoming,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      imageUrl: payload.imageUrl,
      expireQrWhenEventDone: payload.expireQrWhenEventDone,
      timeInWindowStart: payload.timeInWindowStart?.trim().isNotEmpty == true
          ? payload.timeInWindowStart!.trim()
          : null,
      timeInWindowEnd: payload.timeInWindowEnd?.trim().isNotEmpty == true
          ? payload.timeInWindowEnd!.trim()
          : null,
      timeOutWindowStart: payload.timeOutWindowStart?.trim().isNotEmpty == true
          ? payload.timeOutWindowStart!.trim()
          : null,
      timeOutWindowEnd: payload.timeOutWindowEnd?.trim().isNotEmpty == true
          ? payload.timeOutWindowEnd!.trim()
          : null,
      geofenceEnabled: geofence.geofenceEnabled,
      geofenceType: geofence.geofenceType,
      geofenceLatitude: geofence.geofenceLatitude,
      geofenceLongitude: geofence.geofenceLongitude,
      geofenceRadiusMeters: geofence.geofenceRadiusMeters,
      geofencePlaceName: geofence.geofencePlaceName,
      geofencePolygon: geofence.geofencePolygon,
      geofencePreset: geofence.geofencePreset,
    );

    _events = [event, ..._events];
    await _save();
    await _writeEventToFirestore(event);
    return event;
  }

  Future<EventItem?> updateEvent(int eventId, EventPublishPayload payload) async {
    final existing = getById(eventId);
    if (existing == null) return null;

    final error = EventFormValidation.validate(payload);
    if (error != null) throw ArgumentError(error);

    final geofence = EventFormValidation.geofenceFields(payload);
    final rescheduled =
        payload.whenDate.trim() != existing.whenDate || payload.whenTime.trim() != existing.whenTime;

    final updated = existing.copyWith(
      title: payload.title.trim(),
      eventScope: payload.eventScope,
      description: payload.description?.trim().isNotEmpty == true ? payload.description!.trim() : null,
      whenDate: payload.whenDate.trim(),
      whenTime: payload.whenTime.trim(),
      where: payload.where.trim(),
      assignAll: payload.assignAll,
      assignedOfficerIds: payload.assignAll ? const [] : List<int>.from(payload.assignedOfficerIds),
      status: rescheduled ? EventStatus.upcoming : existing.status,
      imageUrl: payload.imageUrl ?? existing.imageUrl,
      expireQrWhenEventDone: payload.expireQrWhenEventDone,
      timeInWindowStart: payload.timeInWindowStart?.trim().isNotEmpty == true
          ? payload.timeInWindowStart!.trim()
          : null,
      timeInWindowEnd: payload.timeInWindowEnd?.trim().isNotEmpty == true
          ? payload.timeInWindowEnd!.trim()
          : null,
      timeOutWindowStart: payload.timeOutWindowStart?.trim().isNotEmpty == true
          ? payload.timeOutWindowStart!.trim()
          : null,
      timeOutWindowEnd: payload.timeOutWindowEnd?.trim().isNotEmpty == true
          ? payload.timeOutWindowEnd!.trim()
          : null,
      geofenceEnabled: geofence.geofenceEnabled,
      geofenceType: geofence.geofenceType,
      geofenceLatitude: geofence.geofenceLatitude,
      geofenceLongitude: geofence.geofenceLongitude,
      geofenceRadiusMeters: geofence.geofenceRadiusMeters,
      geofencePlaceName: geofence.geofencePlaceName,
      geofencePolygon: geofence.geofencePolygon,
      geofencePreset: geofence.geofencePreset,
      clearGeofencePolygon: geofence.geofencePolygon == null,
      clearGeofencePreset: geofence.geofencePreset == null,
    );

    _events = _events.map((event) => event.id == eventId ? updated : event).toList();
    await _save();
    await _writeEventToFirestore(updated);
    return updated;
  }

  Future<bool> removeEvent(int eventId) async {
    if (isProtectedEventId(eventId)) {
      return false;
    }
    final before = _events.length;
    _events = _events.where((event) => event.id != eventId).toList();
    if (_events.length == before) return false;
    await _save();
    await _deleteEventFromFirestore(eventId);
    return true;
  }

  Future<void> applyAttendanceCounts(
    int eventId, {
    required int officersTimedIn,
    required int officersTimedOut,
    required int attendeesTimedIn,
    required int attendeesTimedOut,
  }) async {
    final existing = getById(eventId);
    if (existing == null) return;
    final updated = existing.copyWith(
      officersTimedIn: officersTimedIn,
      officersTimedOut: officersTimedOut,
      attendeesTimedIn: attendeesTimedIn,
      attendeesTimedOut: attendeesTimedOut,
      officersAttended: officersTimedOut,
      attendeesScanned: attendeesTimedIn,
    );
    _events = _events.map((event) => event.id == eventId ? updated : event).toList();
    await _save();
    await _writeEventToFirestore(updated);
    _onChanged?.call();
  }

  Future<EventItem?> cancelEvent(int eventId) async {
    final existing = getById(eventId);
    if (existing == null) return null;
    final updated = existing.copyWith(cancelled: true, status: EventStatus.previous);
    _events = _events.map((event) => event.id == eventId ? updated : event).toList();
    await _save();
    await _writeEventToFirestore(updated);
    return updated;
  }

  Future<EventItem?> rescheduleEvent({
    required int eventId,
    required String whenDate,
    required String whenTime,
  }) async {
    final existing = getById(eventId);
    if (existing == null) return null;
    if (whenDate.trim().isEmpty || whenTime.trim().isEmpty) {
      throw ArgumentError('Date and time are required to reschedule.');
    }
    final updated = existing.copyWith(
      whenDate: whenDate.trim(),
      whenTime: whenTime.trim(),
      status: EventStatus.upcoming,
      cancelled: false,
    );
    _events = _events.map((event) => event.id == eventId ? updated : event).toList();
    await _save();
    await _writeEventToFirestore(updated);
    return updated;
  }

  /// Backward-compatible wrapper used by older call sites.
  Future<EventItem?> updateEventDetails({
    required int eventId,
    required String title,
    required String whenDate,
    required String whenTime,
    required String where,
    String? description,
  }) {
    return updateEvent(
      eventId,
      EventPublishPayload(
        title: title,
        whenDate: whenDate,
        whenTime: whenTime,
        where: where,
        description: description,
      ),
    );
  }
}
