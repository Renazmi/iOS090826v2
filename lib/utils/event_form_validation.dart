import '../config/event_constants.dart';
import '../models/geofence_coordinate.dart';
import 'event_time_windows.dart';

/// Payload for publishing or updating an event — mirrors Angular publish form output.
class EventPublishPayload {
  const EventPublishPayload({
    required this.title,
    required this.whenDate,
    required this.whenTime,
    required this.where,
    this.eventScope = EventScope.school,
    this.description,
    this.assignAll = false,
    this.assignedOfficerIds = const [],
    this.imageUrl,
    this.expireQrWhenEventDone = true,
    this.timeInWindowStart,
    this.timeInWindowEnd,
    this.timeOutWindowStart,
    this.timeOutWindowEnd,
    this.geofenceEnabled = true,
    this.geofenceType = GeofenceType.polygon,
    this.geofenceLatitude,
    this.geofenceLongitude,
    this.geofenceRadiusMeters = 100,
    this.geofencePlaceName,
    this.geofencePolygon,
    this.geofencePreset,
  });

  final String title;
  final String whenDate;
  final String whenTime;
  final String where;
  final EventScope eventScope;
  final String? description;
  final bool assignAll;
  final List<int> assignedOfficerIds;
  final String? imageUrl;
  final bool expireQrWhenEventDone;
  final String? timeInWindowStart;
  final String? timeInWindowEnd;
  final String? timeOutWindowStart;
  final String? timeOutWindowEnd;
  final bool geofenceEnabled;
  final GeofenceType geofenceType;
  final double? geofenceLatitude;
  final double? geofenceLongitude;
  final double geofenceRadiusMeters;
  final String? geofencePlaceName;
  final List<GeofenceCoordinate>? geofencePolygon;
  final GeofencePresetId? geofencePreset;
}

class EventFormValidation {
  static String? validate(EventPublishPayload payload) {
    final title = payload.title.trim();
    final whenDate = payload.whenDate.trim();
    final whenTime = payload.whenTime.trim();
    var where = payload.where.trim();

    if (where.isEmpty &&
        (payload.eventScope == EventScope.ccs ||
            payload.geofencePreset == GeofencePresetId.dct ||
            payload.geofencePlaceName == 'DCT')) {
      where = EventConstants.dctDefaultWhere;
    }

    final missing = <String>[];
    if (title.isEmpty) missing.add('title');
    if (whenDate.isEmpty) missing.add('date');
    if (whenTime.isEmpty) missing.add('time');
    if (where.isEmpty) missing.add('location');

    if (missing.length == 4) {
      return 'Please fill in event title, date, time, and location.';
    }
    if (missing.isNotEmpty) {
      return 'Please fill in event ${missing.join(', ')}.';
    }

    if (!_isValidDateInput(whenDate)) {
      return 'Enter a valid date with a 4-digit year.';
    }

    if (!payload.assignAll && payload.assignedOfficerIds.isEmpty) {
      return 'Select at least one officer, or choose Select all.';
    }

    if (payload.geofenceEnabled) {
      if (payload.geofenceType == GeofenceType.polygon) {
        final polygon = payload.geofencePolygon;
        if (polygon == null || polygon.length < 3) {
          return 'Set the event area using the manual location picker.';
        }
      } else if (payload.geofenceLatitude == null || payload.geofenceLongitude == null) {
        return 'Set the event location on the map when location check is enabled.';
      }
    }

    final timeInError = EventTimeWindows.getTimeWindowValidationError(
      payload.timeInWindowStart,
      payload.timeInWindowEnd,
      'Time-in window',
    );
    if (timeInError != null) return timeInError;

    final timeOutError = EventTimeWindows.getTimeWindowValidationError(
      payload.timeOutWindowStart,
      payload.timeOutWindowEnd,
      'Time-out window',
    );
    if (timeOutError != null) return timeOutError;

    return null;
  }

  static bool _isValidDateInput(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    if (year < 1000 || year > 9999) return false;
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    return DateTime(year, month, day).month == month && DateTime(year, month, day).day == day;
  }

  /// Mirrors Angular `geofencePayload()`.
  static ({
    bool geofenceEnabled,
    GeofenceType? geofenceType,
    double? geofenceLatitude,
    double? geofenceLongitude,
    double? geofenceRadiusMeters,
    String? geofencePlaceName,
    List<GeofenceCoordinate>? geofencePolygon,
    GeofencePresetId? geofencePreset,
  }) geofenceFields(EventPublishPayload payload) {
    if (!payload.geofenceEnabled) {
      return (
        geofenceEnabled: false,
        geofenceType: null,
        geofenceLatitude: null,
        geofenceLongitude: null,
        geofenceRadiusMeters: null,
        geofencePlaceName: null,
        geofencePolygon: null,
        geofencePreset: null,
      );
    }

    if (payload.geofenceType == GeofenceType.polygon &&
        payload.geofencePolygon != null &&
        payload.geofencePolygon!.length >= 3) {
      return (
        geofenceEnabled: true,
        geofenceType: GeofenceType.polygon,
        geofenceLatitude: payload.geofenceLatitude,
        geofenceLongitude: payload.geofenceLongitude,
        geofenceRadiusMeters: null,
        geofencePlaceName: payload.geofencePlaceName?.trim().isNotEmpty == true
            ? payload.geofencePlaceName!.trim()
            : null,
        geofencePolygon: payload.geofencePolygon!.map((p) => p.copyWith()).toList(),
        geofencePreset: payload.geofencePreset,
      );
    }

    return (
      geofenceEnabled: true,
      geofenceType: GeofenceType.circle,
      geofenceLatitude: payload.geofenceLatitude,
      geofenceLongitude: payload.geofenceLongitude,
      geofenceRadiusMeters: payload.geofenceRadiusMeters,
      geofencePlaceName: payload.geofencePlaceName?.trim().isNotEmpty == true
          ? payload.geofencePlaceName!.trim()
          : null,
      geofencePolygon: null,
      geofencePreset: null,
    );
  }
}

GeofenceCoordinate get defaultDctCenter => DctGeofence.center;

List<GeofenceCoordinate> get defaultDctPolygon =>
    DctGeofence.polygon.map((p) => p.copyWith()).toList();
