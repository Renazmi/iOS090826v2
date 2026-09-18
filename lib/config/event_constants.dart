import '../models/geofence_coordinate.dart';

/// Mirrors Angular `DCT_DEFAULT_WHERE` and predefined geofence defaults.
abstract final class EventConstants {
  static const dctDefaultWhere = 'Dominican College of Tarlac (DCT)';

  static const eventScopeLabels = {
    EventScope.ccs: 'CCS Department',
    EventScope.school: 'School Event',
  };

  static String scopeLabel(EventScope? scope) =>
      eventScopeLabels[scope ?? EventScope.school]!;
}

/// DCT campus boundary — mirrors `predefined-locations.ts`.
abstract final class DctGeofence {
  static const southLat = 15.3321;
  static const northLat = 15.3326;
  static const westLng = 120.589199;
  static const eastLng = 120.5904;

  static const polygon = [
    GeofenceCoordinate(lat: southLat, lng: westLng),
    GeofenceCoordinate(lat: northLat, lng: westLng),
    GeofenceCoordinate(lat: northLat, lng: eastLng),
    GeofenceCoordinate(lat: southLat, lng: eastLng),
  ];

  static GeofenceCoordinate get center => GeofenceCoordinate(
        lat: (southLat + northLat) / 2,
        lng: (westLng + eastLng) / 2,
      );

  static const manualDefault = GeofenceCoordinate(lat: 15.33235, lng: 120.5898);
}
