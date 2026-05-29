import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/tree_species.dart';
import 'package:impact_trail/models/environmental/enums/tree_status.dart';
import 'package:impact_trail/models/environmental/models/tree_update.dart';

class TreePlantingLocation {
  final double lat;
  final double lng;
  final double? accuracyMeters;
  final String area;
  final String? zoneId;

  const TreePlantingLocation({
    required this.lat,
    required this.lng,
    this.accuracyMeters,
    required this.area,
    this.zoneId,
  });

  factory TreePlantingLocation.fromMap(Map<String, dynamic> map) {
    return TreePlantingLocation(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      area: (map['area'] as String?) ?? '',
      zoneId: map['zoneId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'accuracyMeters': accuracyMeters,
        'area': area,
        'zoneId': zoneId,
      };

  TreePlantingLocation copyWith({
    double? lat,
    double? lng,
    double? accuracyMeters,
    String? area,
    String? zoneId,
  }) {
    return TreePlantingLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      area: area ?? this.area,
      zoneId: zoneId ?? this.zoneId,
    );
  }
}

class TreePlanting {
  final DateTime? plantedAt;
  final String plantedBy;
  final TreePlantingLocation location;

  const TreePlanting({
    this.plantedAt,
    required this.plantedBy,
    required this.location,
  });

  factory TreePlanting.fromMap(Map<String, dynamic> map) {
    return TreePlanting(
      plantedAt: (map['plantedAt'] as Timestamp?)?.toDate(),
      plantedBy: (map['plantedBy'] as String?) ?? '',
      location: TreePlantingLocation.fromMap(
        (map['location'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'plantedAt':
            plantedAt != null ? Timestamp.fromDate(plantedAt!) : null,
        'plantedBy': plantedBy,
        'location': location.toMap(),
      };

  TreePlanting copyWith({
    DateTime? plantedAt,
    String? plantedBy,
    TreePlantingLocation? location,
  }) {
    return TreePlanting(
      plantedAt: plantedAt ?? this.plantedAt,
      plantedBy: plantedBy ?? this.plantedBy,
      location: location ?? this.location,
    );
  }
}

class TreeSurvival {
  final bool survivalConfirmed90Day;
  final DateTime? survivalConfirmedAt;
  final bool creditEligible;

  const TreeSurvival({
    required this.survivalConfirmed90Day,
    this.survivalConfirmedAt,
    required this.creditEligible,
  });

  factory TreeSurvival.fromMap(Map<String, dynamic> map) {
    return TreeSurvival(
      survivalConfirmed90Day:
          (map['survivalConfirmed90Day'] as bool?) ?? false,
      survivalConfirmedAt:
          (map['survivalConfirmedAt'] as Timestamp?)?.toDate(),
      creditEligible: (map['creditEligible'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'survivalConfirmed90Day': survivalConfirmed90Day,
        'survivalConfirmedAt': survivalConfirmedAt != null
            ? Timestamp.fromDate(survivalConfirmedAt!)
            : null,
        'creditEligible': creditEligible,
      };

  TreeSurvival copyWith({
    bool? survivalConfirmed90Day,
    DateTime? survivalConfirmedAt,
    bool? creditEligible,
  }) {
    return TreeSurvival(
      survivalConfirmed90Day:
          survivalConfirmed90Day ?? this.survivalConfirmed90Day,
      survivalConfirmedAt: survivalConfirmedAt ?? this.survivalConfirmedAt,
      creditEligible: creditEligible ?? this.creditEligible,
    );
  }
}

class TreeUpdateSchedule {
  final DateTime? nextUpdateDueAt;
  final int updateIntervalDays;
  final int overdueThresholdDays;
  final int criticalThresholdDays;

  const TreeUpdateSchedule({
    this.nextUpdateDueAt,
    required this.updateIntervalDays,
    required this.overdueThresholdDays,
    required this.criticalThresholdDays,
  });

  factory TreeUpdateSchedule.fromMap(Map<String, dynamic> map) {
    return TreeUpdateSchedule(
      nextUpdateDueAt: (map['nextUpdateDueAt'] as Timestamp?)?.toDate(),
      updateIntervalDays:
          (map['updateIntervalDays'] as num?)?.toInt() ?? 30,
      overdueThresholdDays:
          (map['overdueThresholdDays'] as num?)?.toInt() ?? 30,
      criticalThresholdDays:
          (map['criticalThresholdDays'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toMap() => {
        'nextUpdateDueAt': nextUpdateDueAt != null
            ? Timestamp.fromDate(nextUpdateDueAt!)
            : null,
        'updateIntervalDays': updateIntervalDays,
        'overdueThresholdDays': overdueThresholdDays,
        'criticalThresholdDays': criticalThresholdDays,
      };

  TreeUpdateSchedule copyWith({
    DateTime? nextUpdateDueAt,
    int? updateIntervalDays,
    int? overdueThresholdDays,
    int? criticalThresholdDays,
  }) {
    return TreeUpdateSchedule(
      nextUpdateDueAt: nextUpdateDueAt ?? this.nextUpdateDueAt,
      updateIntervalDays: updateIntervalDays ?? this.updateIntervalDays,
      overdueThresholdDays: overdueThresholdDays ?? this.overdueThresholdDays,
      criticalThresholdDays:
          criticalThresholdDays ?? this.criticalThresholdDays,
    );
  }
}

class TreeRecord {
  final String treeId;
  final String treeRef;
  final String orgId;
  final TreeSpecies species;
  final String commonName;
  final TreePlanting planting;
  final TreeSurvival survival;
  final TreeStatus status;
  final DateTime? statusUpdatedAt;
  final String statusUpdatedBy;
  final TreeUpdateSchedule updateSchedule;
  final List<TreeUpdate> monthlyUpdates;
  final int updateCount;
  final DateTime? lastUpdateAt;
  final String? notes;
  final DateTime? createdAt;

  const TreeRecord({
    required this.treeId,
    required this.treeRef,
    required this.orgId,
    required this.species,
    required this.commonName,
    required this.planting,
    required this.survival,
    required this.status,
    this.statusUpdatedAt,
    required this.statusUpdatedBy,
    required this.updateSchedule,
    required this.monthlyUpdates,
    required this.updateCount,
    this.lastUpdateAt,
    this.notes,
    this.createdAt,
  });

  bool get isOverdue {
    if (updateSchedule.nextUpdateDueAt == null) return false;
    return DateTime.now().isAfter(updateSchedule.nextUpdateDueAt!);
  }

  factory TreeRecord.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TreeRecord(
      treeId: doc.id,
      treeRef: (data['treeRef'] as String?) ?? '',
      orgId: (data['orgId'] as String?) ?? '',
      species: TreeSpecies.fromFirestoreKey(
        (data['species'] as String?) ?? 'other',
      ),
      commonName: (data['commonName'] as String?) ?? '',
      planting: TreePlanting.fromMap(
        (data['planting'] as Map<String, dynamic>?) ?? {},
      ),
      survival: TreeSurvival.fromMap(
        (data['survival'] as Map<String, dynamic>?) ?? {},
      ),
      status: TreeStatus.fromFirestoreKey(
        (data['status'] as String?) ?? 'unconfirmed',
      ),
      statusUpdatedAt: (data['statusUpdatedAt'] as Timestamp?)?.toDate(),
      statusUpdatedBy: (data['statusUpdatedBy'] as String?) ?? '',
      updateSchedule: TreeUpdateSchedule.fromMap(
        (data['updateSchedule'] as Map<String, dynamic>?) ?? {},
      ),
      monthlyUpdates: (data['monthlyUpdates'] as List?)
              ?.map((e) => TreeUpdate.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      updateCount: (data['updateCount'] as num?)?.toInt() ?? 0,
      lastUpdateAt: (data['lastUpdateAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'treeRef': treeRef,
        'orgId': orgId,
        'species': species.firestoreKey,
        'commonName': commonName,
        'planting': planting.toMap(),
        'survival': survival.toMap(),
        'status': status.firestoreKey,
        'statusUpdatedAt': statusUpdatedAt != null
            ? Timestamp.fromDate(statusUpdatedAt!)
            : null,
        'statusUpdatedBy': statusUpdatedBy,
        'updateSchedule': updateSchedule.toMap(),
        'monthlyUpdates': monthlyUpdates.map((e) => e.toMap()).toList(),
        'updateCount': updateCount,
        'lastUpdateAt':
            lastUpdateAt != null ? Timestamp.fromDate(lastUpdateAt!) : null,
        'notes': notes,
        'createdAt':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      };

  TreeRecord copyWith({
    String? treeId,
    String? treeRef,
    String? orgId,
    TreeSpecies? species,
    String? commonName,
    TreePlanting? planting,
    TreeSurvival? survival,
    TreeStatus? status,
    DateTime? statusUpdatedAt,
    String? statusUpdatedBy,
    TreeUpdateSchedule? updateSchedule,
    List<TreeUpdate>? monthlyUpdates,
    int? updateCount,
    DateTime? lastUpdateAt,
    String? notes,
    DateTime? createdAt,
  }) {
    return TreeRecord(
      treeId: treeId ?? this.treeId,
      treeRef: treeRef ?? this.treeRef,
      orgId: orgId ?? this.orgId,
      species: species ?? this.species,
      commonName: commonName ?? this.commonName,
      planting: planting ?? this.planting,
      survival: survival ?? this.survival,
      status: status ?? this.status,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusUpdatedBy: statusUpdatedBy ?? this.statusUpdatedBy,
      updateSchedule: updateSchedule ?? this.updateSchedule,
      monthlyUpdates: monthlyUpdates ?? this.monthlyUpdates,
      updateCount: updateCount ?? this.updateCount,
      lastUpdateAt: lastUpdateAt ?? this.lastUpdateAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
