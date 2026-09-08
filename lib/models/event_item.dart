import 'geofence_coordinate.dart';

enum EventStatus { upcoming, current, previous }

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.whenDate,
    required this.whenTime,
    required this.where,
    required this.assignAll,
    required this.assignedOfficerIds,
    required this.officersAttended,
    required this.attendeesScanned,
    required this.officersTimedIn,
    required this.officersTimedOut,
    required this.attendeesTimedIn,
    required this.attendeesTimedOut,
    required this.status,
    required this.createdAt,
    this.eventScope = EventScope.school,
    this.description,
    this.imageUrl,
    this.cancelled = false,
    this.expireQrWhenEventDone = true,
    this.timeInWindowStart,
    this.timeInWindowEnd,
    this.timeInWindowEndDate,
    this.timeOutWindowStart,
    this.timeOutWindowEnd,
    this.timeOutWindowEndDate,
    this.geofenceEnabled = false,
    this.geofenceLatitude,
    this.geofenceLongitude,
    this.geofenceRadiusMeters,
    this.geofencePlaceName,
    this.geofenceType,
    this.geofencePolygon,
    this.geofencePreset,
  });

  final int id;
  final String title;
  final EventScope eventScope;
  final String? description;
  final String whenDate;
  final String whenTime;
  final String where;
  final bool assignAll;
  final List<int> assignedOfficerIds;
  final int officersAttended;
  final int attendeesScanned;
  final int officersTimedIn;
  final int officersTimedOut;
  final int attendeesTimedIn;
  final int attendeesTimedOut;
  final EventStatus status;
  final int createdAt;
  final String? imageUrl;
  final bool cancelled;
  final bool expireQrWhenEventDone;
  final String? timeInWindowStart;
  final String? timeInWindowEnd;
  final String? timeInWindowEndDate;
  final String? timeOutWindowStart;
  final String? timeOutWindowEnd;
  final String? timeOutWindowEndDate;
  final bool geofenceEnabled;
  final double? geofenceLatitude;
  final double? geofenceLongitude;
  final double? geofenceRadiusMeters;
  final String? geofencePlaceName;
  final GeofenceType? geofenceType;
  final List<GeofenceCoordinate>? geofencePolygon;
  final GeofencePresetId? geofencePreset;

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'] as int,
      title: '${json['title'] ?? ''}',
      eventScope: _parseScope('${json['eventScope'] ?? 'school'}'),
      description: json['description'] as String?,
      whenDate: '${json['whenDate'] ?? ''}',
      whenTime: '${json['whenTime'] ?? ''}',
      where: '${json['where'] ?? ''}',
      assignAll: json['assignAll'] as bool? ?? true,
      assignedOfficerIds: (json['assignedOfficerIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      officersAttended: json['officersAttended'] as int? ?? 0,
      attendeesScanned: json['attendeesScanned'] as int? ?? 0,
      officersTimedIn: json['officersTimedIn'] as int? ?? 0,
      officersTimedOut: json['officersTimedOut'] as int? ?? 0,
      attendeesTimedIn: json['attendeesTimedIn'] as int? ?? 0,
      attendeesTimedOut: json['attendeesTimedOut'] as int? ?? 0,
      status: _parseStatus('${json['status'] ?? 'upcoming'}'),
      createdAt: json['createdAt'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String?,
      cancelled: json['cancelled'] as bool? ?? false,
      expireQrWhenEventDone: json['expireQrWhenEventDone'] as bool? ?? true,
      timeInWindowStart: json['timeInWindowStart'] as String?,
      timeInWindowEnd: json['timeInWindowEnd'] as String?,
      timeInWindowEndDate: json['timeInWindowEndDate'] as String?,
      timeOutWindowStart: json['timeOutWindowStart'] as String?,
      timeOutWindowEnd: json['timeOutWindowEnd'] as String?,
      timeOutWindowEndDate: json['timeOutWindowEndDate'] as String?,
      geofenceEnabled: json['geofenceEnabled'] as bool? ?? false,
      geofenceLatitude: (json['geofenceLatitude'] as num?)?.toDouble(),
      geofenceLongitude: (json['geofenceLongitude'] as num?)?.toDouble(),
      geofenceRadiusMeters: (json['geofenceRadiusMeters'] as num?)?.toDouble(),
      geofencePlaceName: json['geofencePlaceName'] as String?,
      geofenceType: _parseGeofenceType(json['geofenceType'] as String?),
      geofencePolygon: (json['geofencePolygon'] as List<dynamic>?)
          ?.map((e) => GeofenceCoordinate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      geofencePreset: _parseGeofencePreset(json['geofencePreset'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'eventScope': eventScope.name,
        if (description != null) 'description': description,
        'whenDate': whenDate,
        'whenTime': whenTime,
        'where': where,
        'assignAll': assignAll,
        'assignedOfficerIds': assignedOfficerIds,
        'officersAttended': officersAttended,
        'attendeesScanned': attendeesScanned,
        'officersTimedIn': officersTimedIn,
        'officersTimedOut': officersTimedOut,
        'attendeesTimedIn': attendeesTimedIn,
        'attendeesTimedOut': attendeesTimedOut,
        'status': status.name,
        'createdAt': createdAt,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'cancelled': cancelled,
        'expireQrWhenEventDone': expireQrWhenEventDone,
        if (timeInWindowStart != null) 'timeInWindowStart': timeInWindowStart,
        if (timeInWindowEnd != null) 'timeInWindowEnd': timeInWindowEnd,
        if (timeInWindowEndDate != null) 'timeInWindowEndDate': timeInWindowEndDate,
        if (timeOutWindowStart != null) 'timeOutWindowStart': timeOutWindowStart,
        if (timeOutWindowEnd != null) 'timeOutWindowEnd': timeOutWindowEnd,
        if (timeOutWindowEndDate != null) 'timeOutWindowEndDate': timeOutWindowEndDate,
        'geofenceEnabled': geofenceEnabled,
        if (geofenceLatitude != null) 'geofenceLatitude': geofenceLatitude,
        if (geofenceLongitude != null) 'geofenceLongitude': geofenceLongitude,
        if (geofenceRadiusMeters != null) 'geofenceRadiusMeters': geofenceRadiusMeters,
        if (geofencePlaceName != null) 'geofencePlaceName': geofencePlaceName,
        if (geofenceType != null) 'geofenceType': geofenceType!.name,
        if (geofencePolygon != null)
          'geofencePolygon': geofencePolygon!.map((p) => p.toJson()).toList(),
        if (geofencePreset != null) 'geofencePreset': geofencePreset!.name,
      };

  static EventStatus _parseStatus(String raw) {
    switch (raw) {
      case 'current':
        return EventStatus.current;
      case 'previous':
        return EventStatus.previous;
      default:
        return EventStatus.upcoming;
    }
  }

  static EventScope _parseScope(String raw) {
    return raw == 'ccs' ? EventScope.ccs : EventScope.school;
  }

  static GeofenceType? _parseGeofenceType(String? raw) {
    if (raw == 'polygon') return GeofenceType.polygon;
    if (raw == 'circle') return GeofenceType.circle;
    return null;
  }

  static GeofencePresetId? _parseGeofencePreset(String? raw) {
    if (raw == 'dct') return GeofencePresetId.dct;
    return null;
  }

  EventItem copyWith({
    String? title,
    EventScope? eventScope,
    String? description,
    String? whenDate,
    String? whenTime,
    String? where,
    bool? assignAll,
    List<int>? assignedOfficerIds,
    EventStatus? status,
    bool? cancelled,
    int? createdAt,
    int? officersTimedIn,
    int? officersTimedOut,
    int? attendeesTimedIn,
    int? attendeesTimedOut,
    int? officersAttended,
    int? attendeesScanned,
    bool? expireQrWhenEventDone,
    String? timeInWindowStart,
    String? timeInWindowEnd,
    String? timeInWindowEndDate,
    String? timeOutWindowStart,
    String? timeOutWindowEnd,
    String? timeOutWindowEndDate,
    String? imageUrl,
    bool clearImageUrl = false,
    bool? geofenceEnabled,
    GeofenceType? geofenceType,
    double? geofenceLatitude,
    double? geofenceLongitude,
    double? geofenceRadiusMeters,
    String? geofencePlaceName,
    List<GeofenceCoordinate>? geofencePolygon,
    GeofencePresetId? geofencePreset,
    bool clearGeofencePolygon = false,
    bool clearGeofencePreset = false,
  }) {
    return EventItem(
      id: id,
      title: title ?? this.title,
      eventScope: eventScope ?? this.eventScope,
      description: description ?? this.description,
      whenDate: whenDate ?? this.whenDate,
      whenTime: whenTime ?? this.whenTime,
      where: where ?? this.where,
      assignAll: assignAll ?? this.assignAll,
      assignedOfficerIds: assignedOfficerIds ?? this.assignedOfficerIds,
      officersAttended: officersAttended ?? this.officersAttended,
      attendeesScanned: attendeesScanned ?? this.attendeesScanned,
      officersTimedIn: officersTimedIn ?? this.officersTimedIn,
      officersTimedOut: officersTimedOut ?? this.officersTimedOut,
      attendeesTimedIn: attendeesTimedIn ?? this.attendeesTimedIn,
      attendeesTimedOut: attendeesTimedOut ?? this.attendeesTimedOut,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      cancelled: cancelled ?? this.cancelled,
      expireQrWhenEventDone: expireQrWhenEventDone ?? this.expireQrWhenEventDone,
      timeInWindowStart: timeInWindowStart ?? this.timeInWindowStart,
      timeInWindowEnd: timeInWindowEnd ?? this.timeInWindowEnd,
      timeInWindowEndDate: timeInWindowEndDate ?? this.timeInWindowEndDate,
      timeOutWindowStart: timeOutWindowStart ?? this.timeOutWindowStart,
      timeOutWindowEnd: timeOutWindowEnd ?? this.timeOutWindowEnd,
      timeOutWindowEndDate: timeOutWindowEndDate ?? this.timeOutWindowEndDate,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      geofenceLatitude: geofenceLatitude ?? this.geofenceLatitude,
      geofenceLongitude: geofenceLongitude ?? this.geofenceLongitude,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      geofencePlaceName: geofencePlaceName ?? this.geofencePlaceName,
      geofenceType: geofenceType ?? this.geofenceType,
      geofencePolygon: clearGeofencePolygon ? null : (geofencePolygon ?? this.geofencePolygon),
      geofencePreset: clearGeofencePreset ? null : (geofencePreset ?? this.geofencePreset),
    );
  }
}
