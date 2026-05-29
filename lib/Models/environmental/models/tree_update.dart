import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/tree_update_status.dart';

class TreeUpdatePhoto {
  final String url;
  final String storagePath;
  final DateTime? capturedAt;
  final double gpsLat;
  final double gpsLng;
  final double? gpsAccuracyMeters;

  const TreeUpdatePhoto({
    required this.url,
    required this.storagePath,
    this.capturedAt,
    required this.gpsLat,
    required this.gpsLng,
    this.gpsAccuracyMeters,
  });

  factory TreeUpdatePhoto.fromMap(Map<String, dynamic> map) {
    return TreeUpdatePhoto(
      url: (map['url'] as String?) ?? '',
      storagePath: (map['storagePath'] as String?) ?? '',
      capturedAt: (map['capturedAt'] as Timestamp?)?.toDate(),
      gpsLat: (map['gpsLat'] as num?)?.toDouble() ?? 0.0,
      gpsLng: (map['gpsLng'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracyMeters: (map['gpsAccuracyMeters'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        'storagePath': storagePath,
        'capturedAt':
            capturedAt != null ? Timestamp.fromDate(capturedAt!) : null,
        'gpsLat': gpsLat,
        'gpsLng': gpsLng,
        'gpsAccuracyMeters': gpsAccuracyMeters,
      };

  TreeUpdatePhoto copyWith({
    String? url,
    String? storagePath,
    DateTime? capturedAt,
    double? gpsLat,
    double? gpsLng,
    double? gpsAccuracyMeters,
  }) {
    return TreeUpdatePhoto(
      url: url ?? this.url,
      storagePath: storagePath ?? this.storagePath,
      capturedAt: capturedAt ?? this.capturedAt,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
    );
  }
}

class TreeUpdateValidation {
  final bool gpsProximityPassed;
  final double? distanceFromPlantingMeters;
  final String? autoStatusSet;

  const TreeUpdateValidation({
    required this.gpsProximityPassed,
    this.distanceFromPlantingMeters,
    this.autoStatusSet,
  });

  factory TreeUpdateValidation.fromMap(Map<String, dynamic> map) {
    return TreeUpdateValidation(
      gpsProximityPassed: (map['gpsProximityPassed'] as bool?) ?? false,
      distanceFromPlantingMeters:
          (map['distanceFromPlantingMeters'] as num?)?.toDouble(),
      autoStatusSet: map['autoStatusSet'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'gpsProximityPassed': gpsProximityPassed,
        'distanceFromPlantingMeters': distanceFromPlantingMeters,
        'autoStatusSet': autoStatusSet,
      };

  TreeUpdateValidation copyWith({
    bool? gpsProximityPassed,
    double? distanceFromPlantingMeters,
    String? autoStatusSet,
  }) {
    return TreeUpdateValidation(
      gpsProximityPassed: gpsProximityPassed ?? this.gpsProximityPassed,
      distanceFromPlantingMeters:
          distanceFromPlantingMeters ?? this.distanceFromPlantingMeters,
      autoStatusSet: autoStatusSet ?? this.autoStatusSet,
    );
  }
}

class TreeUpdate {
  final String updateId;
  final DateTime? submittedAt;
  final String submittedBy;
  final TreeUpdatePhoto photo;
  final TreeUpdateStatus statusAtUpdate;
  final String? healthNotes;
  final TreeUpdateValidation validationResult;

  const TreeUpdate({
    required this.updateId,
    this.submittedAt,
    required this.submittedBy,
    required this.photo,
    required this.statusAtUpdate,
    this.healthNotes,
    required this.validationResult,
  });

  factory TreeUpdate.fromMap(Map<String, dynamic> map) {
    return TreeUpdate(
      updateId: (map['updateId'] as String?) ?? '',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate(),
      submittedBy: (map['submittedBy'] as String?) ?? '',
      photo: TreeUpdatePhoto.fromMap(
        (map['photo'] as Map<String, dynamic>?) ?? {},
      ),
      statusAtUpdate: TreeUpdateStatus.fromFirestoreKey(
        (map['statusAtUpdate'] as String?) ?? 'alive',
      ),
      healthNotes: map['healthNotes'] as String?,
      validationResult: TreeUpdateValidation.fromMap(
        (map['validationResult'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'updateId': updateId,
        'submittedAt':
            submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
        'submittedBy': submittedBy,
        'photo': photo.toMap(),
        'statusAtUpdate': statusAtUpdate.firestoreKey,
        'healthNotes': healthNotes,
        'validationResult': validationResult.toMap(),
      };

  TreeUpdate copyWith({
    String? updateId,
    DateTime? submittedAt,
    String? submittedBy,
    TreeUpdatePhoto? photo,
    TreeUpdateStatus? statusAtUpdate,
    String? healthNotes,
    TreeUpdateValidation? validationResult,
  }) {
    return TreeUpdate(
      updateId: updateId ?? this.updateId,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      photo: photo ?? this.photo,
      statusAtUpdate: statusAtUpdate ?? this.statusAtUpdate,
      healthNotes: healthNotes ?? this.healthNotes,
      validationResult: validationResult ?? this.validationResult,
    );
  }
}
