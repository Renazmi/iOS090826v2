import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/firestore_collections.dart';
import '../config/storage_keys.dart';
import '../data/seed_data.dart';
import '../models/event_item.dart';
import '../models/officer.dart';
import '../models/student_account.dart';
import '../services/events_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/storage_service.dart';
import '../utils/attendance_punctuality.dart';
import '../utils/event_qr_code.dart';
import '../utils/event_time_windows.dart';
import '../utils/student_id.dart';

class AttendanceResult {
  const AttendanceResult.ok([this.message]) : ok = true;
  const AttendanceResult.fail(this.message) : ok = false;

  final bool ok;
  final String? message;
}

class OfficerAttendanceRecord {
  OfficerAttendanceRecord({
    required this.eventId,
    required this.officerId,
    required this.officerName,
    required this.section,
    required this.timedInAt,
    this.timedOutAt,
    this.imageUrl,
    this.timedOutImageUrl,
    this.punctualityStatus,
    this.liveCheckIn,
  });

  final int eventId;
  final int officerId;
  final String officerName;
  final String section;
  final int timedInAt;
  int? timedOutAt;
  String? imageUrl;
  String? timedOutImageUrl;

  /// Present or Late, stamped from the time-in window end. Never editable by hand.
  final PunctualityStatus? punctualityStatus;
  final bool? liveCheckIn;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'officerId': officerId,
        'officerName': officerName,
        'section': section,
        'timedInAt': timedInAt,
        if (timedOutAt != null) 'timedOutAt': timedOutAt,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (timedOutImageUrl != null) 'timedOutImageUrl': timedOutImageUrl,
        if (punctualityStatus != null)
          'punctualityStatus': punctualityToJson(punctualityStatus!),
        if (liveCheckIn != null) 'liveCheckIn': liveCheckIn,
      };

  static OfficerAttendanceRecord fromJson(Map<String, dynamic> json) {
    return OfficerAttendanceRecord(
      eventId: json['eventId'] as int,
      officerId: json['officerId'] as int,
      officerName: '${json['officerName'] ?? ''}',
      section: '${json['section'] ?? ''}',
      timedInAt: json['timedInAt'] as int,
      timedOutAt: json['timedOutAt'] as int?,
      imageUrl: json['imageUrl'] as String?,
      timedOutImageUrl: json['timedOutImageUrl'] as String?,
      punctualityStatus: parseStoredPunctuality(json['punctualityStatus']),
      liveCheckIn: json['liveCheckIn'] as bool?,
    );
  }
}

class AttendeeAttendanceRecord {
  AttendeeAttendanceRecord({
    required this.eventId,
    required this.section,
    required this.name,
    required this.studentId,
    required this.timedInAt,
    this.timedOutAt,
    this.imageUrl,
    this.timedOutImageUrl,
    this.punctualityStatus,
  });

  final int eventId;
  final String section;
  final String name;
  final String studentId;
  final int timedInAt;
  int? timedOutAt;
  String? imageUrl;
  String? timedOutImageUrl;

  /// Present or Late, stamped from the time-in window end. Never editable by hand.
  final PunctualityStatus? punctualityStatus;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'section': section,
        'name': name,
        'studentId': studentId,
        'timedInAt': timedInAt,
        if (timedOutAt != null) 'timedOutAt': timedOutAt,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (timedOutImageUrl != null) 'timedOutImageUrl': timedOutImageUrl,
        if (punctualityStatus != null)
          'punctualityStatus': punctualityToJson(punctualityStatus!),
      };

  static AttendeeAttendanceRecord fromJson(Map<String, dynamic> json) {
    return AttendeeAttendanceRecord(
      eventId: json['eventId'] as int,
      section: '${json['section'] ?? ''}',
      name: '${json['name'] ?? ''}',
      studentId: '${json['studentId'] ?? ''}',
      timedInAt: json['timedInAt'] as int,
      timedOutAt: json['timedOutAt'] as int?,
      imageUrl: json['imageUrl'] as String?,
      timedOutImageUrl: json['timedOutImageUrl'] as String?,
      punctualityStatus: parseStoredPunctuality(json['punctualityStatus']),
    );
  }
}

/// Attendance records with local persistence and Firestore sync.
class AttendanceService {
  AttendanceService(this._events, this._storage);

  final EventsService _events;
  final StorageService _storage;

  final List<OfficerAttendanceRecord> _officerRecords = [];
  final List<AttendeeAttendanceRecord> _attendeeRecords = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _officersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendeesSub;
  VoidCallback? _onChanged;
  final Set<String> _pendingOfficerWrites = {};
  final Set<String> _pendingAttendeeWrites = {};
  static const int _firestoreMaxRecordBytes = 900000;
  bool _reconcilingEventCounts = false;

  void setOnChanged(VoidCallback? callback) => _onChanged = callback;

  Future<void> initialize() async {
    _loadFromStorage();
    await FirestoreSyncService.instance.initialize();
    await _startFirestoreSync();
  }

  void dispose() {
    _officersSub?.cancel();
    _attendeesSub?.cancel();
  }

  bool canTimeInNow(EventItem event) {
    if (event.cancelled || _events.effectiveStatus(event) != EventStatus.current) return false;
    return EventTimeWindows.isTimeInOpen(event.whenDate, event.timeInWindowStart);
  }

  bool canTimeOutNow(EventItem event) {
    if (event.cancelled || _events.effectiveStatus(event) != EventStatus.current) return false;
    return EventTimeWindows.isWithinConfiguredWindow(
      event.whenDate,
      event.timeOutWindowStart,
      event.timeOutWindowEnd,
      endDate: event.timeOutWindowEndDate,
    );
  }

  String? getTimeInWindowMessage(EventItem event) =>
      EventTimeWindows.getTimeInOpensMessage(event.whenDate, event.timeInWindowStart);

  /// Present when the time in landed at or before the time-in window end,
  /// Late afterwards. Derived from the stored stamp so it cannot be edited.
  PunctualityStatus punctualityStatusFor(EventItem event, int timedInAt) =>
      resolvePunctualityStatus(event, timedInAt);

  String punctualityLabelFor(PunctualityStatus? status) =>
      punctualityLabel(status ?? PunctualityStatus.present);

  String? getTimeOutWindowMessage(EventItem event) => EventTimeWindows.getConfiguredWindowBlockMessage(
        event.whenDate,
        event.timeOutWindowStart,
        event.timeOutWindowEnd,
        'time out',
        endDate: event.timeOutWindowEndDate,
      );

  void _loadFromStorage() {
    for (final json in _storage.readJsonList(StorageKeys.attendanceOfficers)) {
      _officerRecords.add(OfficerAttendanceRecord.fromJson(json));
    }
    for (final json in _storage.readJsonList(StorageKeys.attendanceAttendees)) {
      _attendeeRecords.add(AttendeeAttendanceRecord.fromJson(json));
    }
  }

  Future<void> _persist() async {
    await _storage.writeJsonList(
      StorageKeys.attendanceOfficers,
      _officerRecords.map((record) => record.toJson()).toList(),
    );
    await _storage.writeJsonList(
      StorageKeys.attendanceAttendees,
      _attendeeRecords.map((record) => record.toJson()).toList(),
    );
    _onChanged?.call();
  }

  String _normalizeStudentId(String studentId) => normalizeStudentId(studentId);

  String _officerDocId(int eventId, int officerId) => '${eventId}_o_$officerId';

  String _attendeeDocId(int eventId, String studentId) =>
      '${eventId}_s_${_normalizeStudentId(studentId)}';

  Future<void> _startFirestoreSync() async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) return;

    final db = FirestoreSyncService.instance.db;
    _officersSub?.cancel();
    _attendeesSub?.cancel();

    _officersSub = db.collection(FirestoreCollections.attendanceOfficers).snapshots().listen(
      (snap) => _mergeOfficerFirestoreSnapshot(snap.docs),
      onError: (Object error) {
        debugPrint('[AttendanceService] Firestore officers listener error: $error');
      },
    );

    _attendeesSub = db.collection(FirestoreCollections.attendanceAttendees).snapshots().listen(
      (snap) => _mergeAttendeeFirestoreSnapshot(snap.docs),
      onError: (Object error) {
        debugPrint('[AttendanceService] Firestore attendees listener error: $error');
      },
    );
  }

  void _mergeOfficerFirestoreSnapshot(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return;
    final merged = <String, OfficerAttendanceRecord>{};
    for (final docSnap in docs) {
      merged[docSnap.id] = OfficerAttendanceRecord.fromJson(docSnap.data());
    }
    for (final record in _officerRecords) {
      final key = _officerDocId(record.eventId, record.officerId);
      if (!merged.containsKey(key) && _pendingOfficerWrites.contains(key)) {
        merged[key] = record;
      }
    }
    final affectedEventIds = <int>{attendanceTestEventId};
    _officerRecords
      ..clear()
      ..addAll(merged.values);
    for (final record in _officerRecords) {
      affectedEventIds.add(record.eventId);
    }
    unawaited(_syncEventCountsFromRecords(affectedEventIds.toList()));
    unawaited(_persist());
  }

  void _mergeAttendeeFirestoreSnapshot(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return;
    final merged = <String, AttendeeAttendanceRecord>{};
    for (final docSnap in docs) {
      merged[docSnap.id] = AttendeeAttendanceRecord.fromJson(docSnap.data());
    }
    for (final record in _attendeeRecords) {
      final key = _attendeeDocId(record.eventId, record.studentId);
      if (!merged.containsKey(key) && _pendingAttendeeWrites.contains(key)) {
        merged[key] = record;
      }
    }
    final affectedEventIds = <int>{attendanceTestEventId};
    _attendeeRecords
      ..clear()
      ..addAll(merged.values);
    for (final record in _attendeeRecords) {
      affectedEventIds.add(record.eventId);
    }
    unawaited(_syncEventCountsFromRecords(affectedEventIds.toList()));
    unawaited(_persist());
  }

  Map<String, dynamic> _officerJsonForFirestore(
    OfficerAttendanceRecord record, {
    required bool includeImages,
  }) {
    final json = record.toJson();
    if (!includeImages) {
      json.remove('imageUrl');
      json.remove('timedOutImageUrl');
    }
    return json;
  }

  Map<String, dynamic> _attendeeJsonForFirestore(
    AttendeeAttendanceRecord record, {
    required bool includeImages,
  }) {
    final json = record.toJson();
    if (!includeImages) {
      json.remove('imageUrl');
      json.remove('timedOutImageUrl');
    }
    return json;
  }

  int _estimateJsonBytes(Map<String, dynamic> json) {
    return jsonEncode(json).length * 2;
  }

  void _upsertOfficer(OfficerAttendanceRecord record, {bool notify = true}) {
    final index = _officerRecords.indexWhere(
      (r) => r.eventId == record.eventId && r.officerId == record.officerId,
    );
    if (index >= 0) {
      _officerRecords[index] = record;
    } else {
      _officerRecords.add(record);
    }
    if (notify) _onChanged?.call();
  }

  void _upsertAttendee(AttendeeAttendanceRecord record, {bool notify = true}) {
    final studentId = _normalizeStudentId(record.studentId);
    final index = _attendeeRecords.indexWhere(
      (r) => r.eventId == record.eventId && _normalizeStudentId(r.studentId) == studentId,
    );
    if (index >= 0) {
      _attendeeRecords[index] = record;
    } else {
      _attendeeRecords.add(record);
    }
    if (notify) _onChanged?.call();
  }

  Future<void> _writeOfficerRecord(OfficerAttendanceRecord record) async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) {
      throw Exception('Could not save attendance to the server. Check your connection and try again.');
    }
    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.attendanceOfficers)
        .doc(_officerDocId(record.eventId, record.officerId));

    final withImages = _officerJsonForFirestore(record, includeImages: true);
    if (_estimateJsonBytes(withImages) <= _firestoreMaxRecordBytes) {
      try {
        await ref.set(withImages);
        return;
      } catch (_) {
        // Fall back to core fields without selfies.
      }
    }

    await ref.set(_officerJsonForFirestore(record, includeImages: false));
  }

  Future<void> _writeAttendeeRecord(AttendeeAttendanceRecord record) async {
    await FirestoreSyncService.instance.initialize();
    if (!FirestoreSyncService.instance.isReady) {
      throw Exception('Could not save attendance to the server. Check your connection and try again.');
    }
    final ref = FirestoreSyncService.instance.db
        .collection(FirestoreCollections.attendanceAttendees)
        .doc(_attendeeDocId(record.eventId, record.studentId));

    final withImages = _attendeeJsonForFirestore(record, includeImages: true);
    if (_estimateJsonBytes(withImages) <= _firestoreMaxRecordBytes) {
      try {
        await ref.set(withImages);
        return;
      } catch (_) {
        // Fall back to core fields without selfies.
      }
    }

    await ref.set(_attendeeJsonForFirestore(record, includeImages: false));
  }

  Future<void> _saveOfficerRecord(OfficerAttendanceRecord record) async {
    final key = _officerDocId(record.eventId, record.officerId);
    _pendingOfficerWrites.add(key);
    try {
      await _writeOfficerRecord(record);
    } finally {
      _pendingOfficerWrites.remove(key);
    }
    _upsertOfficer(record);
    await _persist();
    await _syncEventAttendanceCounts(record.eventId);
  }

  Future<void> _saveAttendeeRecord(AttendeeAttendanceRecord record) async {
    final key = _attendeeDocId(record.eventId, record.studentId);
    _pendingAttendeeWrites.add(key);
    try {
      await _writeAttendeeRecord(record);
    } finally {
      _pendingAttendeeWrites.remove(key);
    }
    _upsertAttendee(record);
    await _persist();
    await _syncEventAttendanceCounts(record.eventId);
  }

  Future<void> _syncEventCountsFromRecords([List<int>? eventIds]) async {
    final ids = eventIds ??
        {
          ..._officerRecords.map((record) => record.eventId),
          ..._attendeeRecords.map((record) => record.eventId),
        }.toList();
    for (final eventId in ids) {
      await _syncEventAttendanceCounts(eventId);
    }
  }

  Future<void> _syncEventAttendanceCounts(int eventId) async {
    final officers = getOfficerRecords(eventId);
    final attendees = getAttendeeRecords(eventId);
    await _events.applyAttendanceCounts(
      eventId,
      officersTimedIn: officers.length,
      officersTimedOut: officers.where((record) => record.timedOutAt != null).length,
      attendeesTimedIn: attendees.length,
      attendeesTimedOut: attendees.where((record) => record.timedOutAt != null).length,
    );
  }

  List<OfficerAttendanceRecord> getOfficerRecords(int eventId) =>
      _officerRecords.where((r) => r.eventId == eventId).toList();

  List<AttendeeAttendanceRecord> getAttendeeRecords(int eventId) =>
      _attendeeRecords.where((r) => r.eventId == eventId).toList();

  int countOfficersTimedIn(int eventId) => getOfficerRecords(eventId).length;

  int countOfficersTimedOut(int eventId) =>
      getOfficerRecords(eventId).where((record) => record.timedOutAt != null).length;

  int countAttendeesTimedIn(int eventId) => getAttendeeRecords(eventId).length;

  int countAttendeesTimedOut(int eventId) =>
      getAttendeeRecords(eventId).where((record) => record.timedOutAt != null).length;

  /// Reconcile event tallies from Firestore-backed attendance when the events catalog refreshes.
  Future<void> reconcileEventCountsFromRecords() async {
    if (_reconcilingEventCounts) return;
    if (_officerRecords.isEmpty && _attendeeRecords.isEmpty) return;
    _reconcilingEventCounts = true;
    try {
      await _syncEventCountsFromRecords();
    } finally {
      _reconcilingEventCounts = false;
    }
  }

  /// Clear all attendance for an event locally and in Firestore.
  Future<void> resetEventAttendance(int eventId) async {
    final officerKeys =
        getOfficerRecords(eventId).map((r) => _officerDocId(r.eventId, r.officerId)).toList();
    final attendeeKeys = getAttendeeRecords(eventId)
        .map((r) => _attendeeDocId(r.eventId, r.studentId))
        .toList();

    _officerRecords.removeWhere((record) => record.eventId == eventId);
    _attendeeRecords.removeWhere((record) => record.eventId == eventId);
    for (final key in officerKeys) {
      _pendingOfficerWrites.remove(key);
    }
    for (final key in attendeeKeys) {
      _pendingAttendeeWrites.remove(key);
    }
    await _persist();

    await FirestoreSyncService.instance.initialize();
    if (FirestoreSyncService.instance.isReady) {
      final db = FirestoreSyncService.instance.db;
      for (final key in officerKeys) {
        try {
          await db.collection(FirestoreCollections.attendanceOfficers).doc(key).delete();
        } catch (_) {}
      }
      for (final key in attendeeKeys) {
        try {
          await db.collection(FirestoreCollections.attendanceAttendees).doc(key).delete();
        } catch (_) {}
      }
    }

    await _syncEventAttendanceCounts(eventId);
  }

  Future<void> resetAttendanceTestEvent() async {
    await resetEventAttendance(attendanceTestEventId);
    await _events.publishAttendanceTestEvent(force: true);
  }

  OfficerAttendanceRecord? getOfficerRecord(int eventId, int officerId) {
    for (final r in _officerRecords) {
      if (r.eventId == eventId && r.officerId == officerId) return r;
    }
    return null;
  }

  AttendeeAttendanceRecord? getStudentRecord(int eventId, String studentId) {
    final id = _normalizeStudentId(studentId);
    for (final r in _attendeeRecords) {
      if (r.eventId == eventId && _normalizeStudentId(r.studentId) == id) return r;
    }
    return null;
  }

  int? parseEventQrPayload(String payload) => EventQrCode.parsePayload(payload);

  AttendanceResult? validateEventQrForEvent(EventItem event, String payload) {
    final eventId = parseEventQrPayload(payload);
    if (eventId == null) {
      return const AttendanceResult.fail('Invalid event QR code. Scan the official event QR.');
    }
    if (eventId != event.id) {
      return const AttendanceResult.fail('This QR code is not for this event.');
    }

    if (event.cancelled) {
      return const AttendanceResult.fail('This event was cancelled.');
    }

    final status = _events.effectiveStatus(event);
    if (status == EventStatus.upcoming) {
      return const AttendanceResult.fail(
        'This event has not started yet. Time in and time out are only available for ongoing events.',
      );
    }
    if (status == EventStatus.previous && event.expireQrWhenEventDone) {
      return const AttendanceResult.fail('This event has ended. The QR code is no longer valid.');
    }

    return null;
  }

  AttendanceResult? validateEventQrForEventWithLocation(
    EventItem event,
    String payload, {
    double? latitude,
    double? longitude,
  }) {
    final qrError = validateEventQrForEvent(event, payload);
    if (qrError != null) return qrError;

    if (!event.geofenceEnabled) return null;

    if (latitude == null || longitude == null) {
      return const AttendanceResult.fail(
        'Location is required to verify this QR code. Allow location access and try again.',
      );
    }

    return _validateGeofence(event, latitude, longitude);
  }

  AttendanceResult? validateSelfie(String? selfieDataUrl) {
    if (selfieDataUrl == null || !selfieDataUrl.startsWith('data:image/')) {
      return const AttendanceResult.fail('A verification selfie is required.');
    }
    return null;
  }

  /// Unique officers who timed in today (local calendar day; resets at midnight).
  int countCheckInsToday() {
    final todayKey = _todayStr();
    final seen = <int>{};
    for (final record in _officerRecords) {
      if (_dateKeyFromTimestamp(record.timedInAt) != todayKey) continue;
      seen.add(record.officerId);
    }
    return seen.length;
  }

  String _todayStr() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String _dateKeyFromTimestamp(int timestamp) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  AttendanceResult? _validateEvent(EventItem event) {
    if (event.cancelled) {
      return const AttendanceResult.fail('This event was cancelled.');
    }
    final status = _events.effectiveStatus(event);
    if (status == EventStatus.previous) {
      if (event.expireQrWhenEventDone) {
        return const AttendanceResult.fail('This event has ended. The QR code is no longer valid.');
      }
      return const AttendanceResult.fail('This event has ended.');
    }
    if (status == EventStatus.upcoming) {
      return const AttendanceResult.fail(
        'This event has not started yet. Time in and time out are only available for ongoing events.',
      );
    }
    return null;
  }

  AttendanceResult? _validateGeofence(EventItem event, double? latitude, double? longitude) {
    if (!event.geofenceEnabled) return null;
    if (latitude == null || longitude == null) {
      return const AttendanceResult.fail(
        'Location is required to verify attendance. Allow location access and try again.',
      );
    }
    final result = _events.validateCheckInLocation(event, latitude, longitude);
    if (!result.ok) return AttendanceResult.fail(result.message);
    return null;
  }

  /// Time-in is stored independently of event assignment. Unassigned officers may still time in.
  Future<AttendanceResult> recordOfficerTimeIn(
    EventItem event,
    Officer officer, {
    double? latitude,
    double? longitude,
    String? selfieDataUrl,
  }) async {
    final blocked = _validateEvent(event);
    if (blocked != null) return blocked;
    final selfie = validateSelfie(selfieDataUrl);
    if (selfie != null) return selfie;
    final geofence = _validateGeofence(event, latitude, longitude);
    if (geofence != null) return geofence;
    final windowError = getTimeInWindowMessage(event);
    if (windowError != null) return AttendanceResult.fail(windowError);
    if (getOfficerRecord(event.id, officer.id) != null) {
      return const AttendanceResult.fail('You already timed in for this event.');
    }
    final timedInAt = DateTime.now().millisecondsSinceEpoch;
    final status = resolvePunctualityStatus(event, timedInAt);
    final record = OfficerAttendanceRecord(
      eventId: event.id,
      officerId: officer.id,
      officerName: officer.name,
      section: officer.section,
      timedInAt: timedInAt,
      imageUrl: selfieDataUrl,
      punctualityStatus: status,
      liveCheckIn: true,
    );
    try {
      await _saveOfficerRecord(record);
      return AttendanceResult.ok('Timed in — ${punctualityLabel(status)}.');
    } catch (error) {
      return AttendanceResult.fail(
        error is Exception ? error.toString().replaceFirst('Exception: ', '') : 'Could not save attendance.',
      );
    }
  }

  Future<AttendanceResult> recordOfficerTimeOut(
    EventItem event,
    int officerId, {
    double? latitude,
    double? longitude,
    String? selfieDataUrl,
  }) async {
    final blocked = _validateEvent(event);
    if (blocked != null) return blocked;
    final selfie = validateSelfie(selfieDataUrl);
    if (selfie != null) return selfie;
    final geofence = _validateGeofence(event, latitude, longitude);
    if (geofence != null) return geofence;
    final record = getOfficerRecord(event.id, officerId);
    if (record == null) {
      return const AttendanceResult.fail('Time in first before timing out.');
    }
    if (record.timedOutAt != null) {
      return const AttendanceResult.fail('You already timed out for this event.');
    }
    final windowError = getTimeOutWindowMessage(event);
    if (windowError != null) return AttendanceResult.fail(windowError);
    final updated = OfficerAttendanceRecord(
      eventId: record.eventId,
      officerId: record.officerId,
      officerName: record.officerName,
      section: record.section,
      timedInAt: record.timedInAt,
      timedOutAt: DateTime.now().millisecondsSinceEpoch,
      imageUrl: record.imageUrl,
      timedOutImageUrl: selfieDataUrl,
      punctualityStatus: record.punctualityStatus,
      liveCheckIn: record.liveCheckIn ?? true,
    );
    try {
      await _saveOfficerRecord(updated);
      return const AttendanceResult.ok();
    } catch (error) {
      return AttendanceResult.fail(
        error is Exception ? error.toString().replaceFirst('Exception: ', '') : 'Could not save attendance.',
      );
    }
  }

  Future<AttendanceResult> recordStudentTimeIn(
    EventItem event,
    StudentAccount student, {
    String? section,
    double? latitude,
    double? longitude,
    String? selfieDataUrl,
  }) async {
    final blocked = _validateEvent(event);
    if (blocked != null) return blocked;
    final selfie = validateSelfie(selfieDataUrl);
    if (selfie != null) return selfie;
    final geofence = _validateGeofence(event, latitude, longitude);
    if (geofence != null) return geofence;
    final windowError = getTimeInWindowMessage(event);
    if (windowError != null) return AttendanceResult.fail(windowError);
    if (getStudentRecord(event.id, student.studentId) != null) {
      return const AttendanceResult.fail('You already timed in for this event.');
    }
    final timedInAt = DateTime.now().millisecondsSinceEpoch;
    final status = resolvePunctualityStatus(event, timedInAt);
    final record = AttendeeAttendanceRecord(
      eventId: event.id,
      section: (section != null && section.trim().isNotEmpty) ? section.trim() : '—',
      name: student.fullName,
      studentId: _normalizeStudentId(student.studentId),
      timedInAt: timedInAt,
      imageUrl: selfieDataUrl,
      punctualityStatus: status,
    );
    try {
      await _saveAttendeeRecord(record);
      return AttendanceResult.ok('Timed in — ${punctualityLabel(status)}.');
    } catch (error) {
      return AttendanceResult.fail(
        error is Exception ? error.toString().replaceFirst('Exception: ', '') : 'Could not save attendance.',
      );
    }
  }

  Future<AttendanceResult> recordStudentTimeOut(
    EventItem event,
    String studentId, {
    double? latitude,
    double? longitude,
    String? selfieDataUrl,
  }) async {
    final blocked = _validateEvent(event);
    if (blocked != null) return blocked;
    final selfie = validateSelfie(selfieDataUrl);
    if (selfie != null) return selfie;
    final geofence = _validateGeofence(event, latitude, longitude);
    if (geofence != null) return geofence;
    final record = getStudentRecord(event.id, studentId);
    if (record == null) {
      return const AttendanceResult.fail('Time in first before timing out.');
    }
    if (record.timedOutAt != null) {
      return const AttendanceResult.fail('You already timed out for this event.');
    }
    final windowError = getTimeOutWindowMessage(event);
    if (windowError != null) return AttendanceResult.fail(windowError);
    final updated = AttendeeAttendanceRecord(
      eventId: record.eventId,
      section: record.section,
      name: record.name,
      studentId: record.studentId,
      timedInAt: record.timedInAt,
      timedOutAt: DateTime.now().millisecondsSinceEpoch,
      imageUrl: record.imageUrl,
      timedOutImageUrl: selfieDataUrl,
      punctualityStatus: record.punctualityStatus,
    );
    try {
      await _saveAttendeeRecord(updated);
      return const AttendanceResult.ok();
    } catch (error) {
      return AttendanceResult.fail(
        error is Exception ? error.toString().replaceFirst('Exception: ', '') : 'Could not save attendance.',
      );
    }
  }
}
