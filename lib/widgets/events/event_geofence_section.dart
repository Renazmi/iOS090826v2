import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/app_theme.dart';
import '../../config/event_constants.dart';
import '../../models/geofence_coordinate.dart';

class EventGeofenceState {
  const EventGeofenceState({
    required this.enabled,
    required this.geofenceType,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.placeName,
    required this.polygon,
    required this.preset,
  });

  final bool enabled;
  final GeofenceType geofenceType;
  final double? latitude;
  final double? longitude;
  final double radiusMeters;
  final String placeName;
  final List<GeofenceCoordinate>? polygon;
  final GeofencePresetId? preset;

  factory EventGeofenceState.dctDefault() {
    final center = DctGeofence.center;
    return EventGeofenceState(
      enabled: true,
      geofenceType: GeofenceType.polygon,
      latitude: center.lat,
      longitude: center.lng,
      radiusMeters: 100,
      placeName: 'DCT',
      polygon: DctGeofence.polygon.map((p) => p.copyWith()).toList(),
      preset: GeofencePresetId.dct,
    );
  }

  factory EventGeofenceState.manualCircle({
    double? latitude,
    double? longitude,
    double radiusMeters = 100,
    String placeName = '',
  }) {
    final pin = latitude != null && longitude != null
        ? GeofenceCoordinate(lat: latitude, lng: longitude)
        : DctGeofence.manualDefault;
    return EventGeofenceState(
      enabled: true,
      geofenceType: GeofenceType.circle,
      latitude: pin.lat,
      longitude: pin.lng,
      radiusMeters: radiusMeters,
      placeName: placeName,
      polygon: null,
      preset: null,
    );
  }

  EventGeofenceState copyWith({
    bool? enabled,
    GeofenceType? geofenceType,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? placeName,
    List<GeofenceCoordinate>? polygon,
    GeofencePresetId? preset,
    bool clearPolygon = false,
    bool clearPreset = false,
  }) {
    return EventGeofenceState(
      enabled: enabled ?? this.enabled,
      geofenceType: geofenceType ?? this.geofenceType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      placeName: placeName ?? this.placeName,
      polygon: clearPolygon ? null : (polygon ?? this.polygon),
      preset: clearPreset ? null : (preset ?? this.preset),
    );
  }
}

class EventGeofenceSection extends StatelessWidget {
  const EventGeofenceSection({
    super.key,
    required this.state,
    required this.onChanged,
    this.onApplyDctWhere,
  });

  final EventGeofenceState state;
  final ValueChanged<EventGeofenceState> onChanged;
  final VoidCallback? onApplyDctWhere;

  Future<void> _useMyLocation(BuildContext context) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to set a custom event area.')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    onChanged(
      EventGeofenceState.manualCircle(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: state.radiusMeters,
        placeName: 'Current location',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDct = state.preset == GeofencePresetId.dct && state.geofenceType == GeofenceType.polygon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Location check',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Attendees must be inside the selected area to time in or time out when location check is enabled.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        _ModeChip(
          label: 'DCT campus boundary',
          selected: isDct,
          onTap: () {
            onChanged(EventGeofenceState.dctDefault());
            onApplyDctWhere?.call();
          },
        ),
        const SizedBox(height: 8),
        _ModeChip(
          label: 'Custom pin + radius',
          selected: !isDct,
          onTap: () => onChanged(
            EventGeofenceState.manualCircle(radiusMeters: state.radiusMeters),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isDct ? 'Using DCT predefined campus polygon.' : 'Using a circular check-in area.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
              ),
              if (!isDct) ...[
                const SizedBox(height: 8),
                if (state.latitude != null && state.longitude != null)
                  Text(
                    'Pin: ${state.latitude!.toStringAsFixed(5)}, ${state.longitude!.toStringAsFixed(5)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Radius', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: state.radiusMeters.clamp(10, 500),
                        min: 10,
                        max: 500,
                        divisions: 49,
                        label: '${state.radiusMeters.round()} m',
                        activeColor: AppTheme.red,
                        onChanged: (value) => onChanged(state.copyWith(radiusMeters: value)),
                      ),
                    ),
                    Text('${state.radiusMeters.round()} m', style: const TextStyle(color: Colors.white)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _useMyLocation(context),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Use my location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.red.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.red.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppTheme.red : Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: selected ? 0.95 : 0.75),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
