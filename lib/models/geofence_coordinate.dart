class GeofenceCoordinate {
  const GeofenceCoordinate({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory GeofenceCoordinate.fromJson(Map<String, dynamic> json) {
    return GeofenceCoordinate(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  GeofenceCoordinate copyWith({double? lat, double? lng}) {
    return GeofenceCoordinate(lat: lat ?? this.lat, lng: lng ?? this.lng);
  }
}

enum GeofenceType { circle, polygon }

enum GeofencePresetId { dct }

enum EventScope { ccs, school }
