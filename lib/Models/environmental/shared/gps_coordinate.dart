import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

enum GpsCoordinateSource {
  deviceGps,
  manual,
  mapTap;

  String get firestoreKey {
    switch (this) {
      case GpsCoordinateSource.deviceGps:
        return 'device_gps';
      case GpsCoordinateSource.manual:
        return 'manual';
      case GpsCoordinateSource.mapTap:
        return 'map_tap';
    }
  }

  static GpsCoordinateSource fromFirestoreKey(String key) {
    return GpsCoordinateSource.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => GpsCoordinateSource.deviceGps,
    );
  }
}

// source == manual is permitted for display-only coordinates only.
// GPS evidence for verification, tree updates, and handoffs must
// use source == deviceGps. Enforce this in the UI layer — never
// accept manual coordinates for evidence-bearing documents.
class GpsCoordinate {
  final double lat;
  final double lng;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final GpsCoordinateSource source;

  const GpsCoordinate({
    required this.lat,
    required this.lng,
    this.accuracyMeters,
    this.capturedAt,
    required this.source,
  });

  factory GpsCoordinate.fromMap(Map<String, dynamic> map) {
    return GpsCoordinate(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      capturedAt: (map['capturedAt'] as Timestamp?)?.toDate(),
      source: GpsCoordinateSource.fromFirestoreKey(
        (map['source'] as String?) ?? 'device_gps',
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'accuracyMeters': accuracyMeters,
        'capturedAt':
            capturedAt != null ? Timestamp.fromDate(capturedAt!) : null,
        'source': source.firestoreKey,
      };

  GpsCoordinate copyWith({
    double? lat,
    double? lng,
    double? accuracyMeters,
    DateTime? capturedAt,
    GpsCoordinateSource? source,
  }) {
    return GpsCoordinate(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      capturedAt: capturedAt ?? this.capturedAt,
      source: source ?? this.source,
    );
  }

  // Haversine formula — returns distance in meters
  // Used for tree update GPS proximity validation
  double distanceTo(GpsCoordinate other) {
    const double earthRadiusMeters = 6371000;
    final double lat1 = lat * pi / 180;
    final double lat2 = other.lat * pi / 180;
    final double dLat = (other.lat - lat) * pi / 180;
    final double dLng = (other.lng - lng) * pi / 180;
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }
}
