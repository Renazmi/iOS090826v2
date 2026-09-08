import 'dart:math' as math;

import '../models/geofence_coordinate.dart';

const _earthRadiusM = 6371000;

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Haversine distance between two coordinates in meters.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusM * math.asin(math.sqrt(a));
}

bool isWithinGeofence(
  double centerLat,
  double centerLng,
  double radiusMeters,
  double pointLat,
  double pointLng,
) {
  if (radiusMeters <= 0) return false;
  return distanceMeters(centerLat, centerLng, pointLat, pointLng) <= radiusMeters;
}

/// Ray-casting point-in-polygon test.
bool isPointInPolygon(double pointLat, double pointLng, List<GeofenceCoordinate> polygon) {
  if (polygon.length < 3) return false;

  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final yi = polygon[i].lat;
    final xi = polygon[i].lng;
    final yj = polygon[j].lat;
    final xj = polygon[j].lng;

    final intersects =
        yi > pointLat != yj > pointLat &&
        pointLng < ((xj - xi) * (pointLat - yi)) / (yj - yi) + xi;

    if (intersects) inside = !inside;
  }
  return inside;
}
