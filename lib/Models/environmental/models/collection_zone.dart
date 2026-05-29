import 'package:cloud_firestore/cloud_firestore.dart';

class ZonePolygon {
  final List<GeoPoint> coordinates;
  final GeoPoint centroid;
  final double? areaEstimateSqm;

  const ZonePolygon({
    required this.coordinates,
    required this.centroid,
    this.areaEstimateSqm,
  });

  factory ZonePolygon.fromMap(Map<String, dynamic> map) {
    final centroidData = map['centroid'];
    final GeoPoint centroid;
    if (centroidData is GeoPoint) {
      centroid = centroidData;
    } else if (centroidData is Map<String, dynamic>) {
      centroid = GeoPoint(
        (centroidData['lat'] as num?)?.toDouble() ?? 0.0,
        (centroidData['lng'] as num?)?.toDouble() ?? 0.0,
      );
    } else {
      centroid = const GeoPoint(0, 0);
    }
    return ZonePolygon(
      coordinates:
          (map['coordinates'] as List?)?.cast<GeoPoint>() ?? const [],
      centroid: centroid,
      areaEstimateSqm: (map['areaEstimateSqm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'coordinates': coordinates,
        'centroid': centroid,
        'areaEstimateSqm': areaEstimateSqm,
      };

  ZonePolygon copyWith({
    List<GeoPoint>? coordinates,
    GeoPoint? centroid,
    double? areaEstimateSqm,
  }) {
    return ZonePolygon(
      coordinates: coordinates ?? this.coordinates,
      centroid: centroid ?? this.centroid,
      areaEstimateSqm: areaEstimateSqm ?? this.areaEstimateSqm,
    );
  }
}

class ZoneSchedule {
  final List<String> days;
  final String startTime;
  final String endTime;
  final String timezone;

  const ZoneSchedule({
    required this.days,
    required this.startTime,
    required this.endTime,
    required this.timezone,
  });

  factory ZoneSchedule.fromMap(Map<String, dynamic> map) {
    return ZoneSchedule(
      days: (map['days'] as List?)?.cast<String>() ?? const [],
      startTime: (map['startTime'] as String?) ?? '',
      endTime: (map['endTime'] as String?) ?? '',
      timezone: (map['timezone'] as String?) ?? 'Africa/Nairobi',
    );
  }

  Map<String, dynamic> toMap() => {
        'days': days,
        'startTime': startTime,
        'endTime': endTime,
        'timezone': timezone,
      };

  ZoneSchedule copyWith({
    List<String>? days,
    String? startTime,
    String? endTime,
    String? timezone,
  }) {
    return ZoneSchedule(
      days: days ?? this.days,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      timezone: timezone ?? this.timezone,
    );
  }
}

class ZoneStats {
  final int totalCollectionsLogged;
  final double totalKgVerified;
  final DateTime? lastCollectionAt;
  final DateTime? firstCollectionAt;
  final int activeMonths;

  const ZoneStats({
    required this.totalCollectionsLogged,
    required this.totalKgVerified,
    this.lastCollectionAt,
    this.firstCollectionAt,
    required this.activeMonths,
  });

  factory ZoneStats.fromMap(Map<String, dynamic> map) {
    return ZoneStats(
      totalCollectionsLogged:
          (map['totalCollectionsLogged'] as num?)?.toInt() ?? 0,
      totalKgVerified: (map['totalKgVerified'] as num?)?.toDouble() ?? 0.0,
      lastCollectionAt: (map['lastCollectionAt'] as Timestamp?)?.toDate(),
      firstCollectionAt: (map['firstCollectionAt'] as Timestamp?)?.toDate(),
      activeMonths: (map['activeMonths'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'totalCollectionsLogged': totalCollectionsLogged,
        'totalKgVerified': totalKgVerified,
        'lastCollectionAt': lastCollectionAt != null
            ? Timestamp.fromDate(lastCollectionAt!)
            : null,
        'firstCollectionAt': firstCollectionAt != null
            ? Timestamp.fromDate(firstCollectionAt!)
            : null,
        'activeMonths': activeMonths,
      };

  ZoneStats copyWith({
    int? totalCollectionsLogged,
    double? totalKgVerified,
    DateTime? lastCollectionAt,
    DateTime? firstCollectionAt,
    int? activeMonths,
  }) {
    return ZoneStats(
      totalCollectionsLogged:
          totalCollectionsLogged ?? this.totalCollectionsLogged,
      totalKgVerified: totalKgVerified ?? this.totalKgVerified,
      lastCollectionAt: lastCollectionAt ?? this.lastCollectionAt,
      firstCollectionAt: firstCollectionAt ?? this.firstCollectionAt,
      activeMonths: activeMonths ?? this.activeMonths,
    );
  }
}

class ZoneCreditEligibility {
  final int monthsActive;
  final bool thresholdMet;
  final double plasticCreditEligibleKg;

  const ZoneCreditEligibility({
    required this.monthsActive,
    required this.thresholdMet,
    required this.plasticCreditEligibleKg,
  });

  factory ZoneCreditEligibility.fromMap(Map<String, dynamic> map) {
    return ZoneCreditEligibility(
      monthsActive: (map['monthsActive'] as num?)?.toInt() ?? 0,
      thresholdMet: (map['thresholdMet'] as bool?) ?? false,
      plasticCreditEligibleKg:
          (map['plasticCreditEligibleKg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'monthsActive': monthsActive,
        'thresholdMet': thresholdMet,
        'plasticCreditEligibleKg': plasticCreditEligibleKg,
      };

  ZoneCreditEligibility copyWith({
    int? monthsActive,
    bool? thresholdMet,
    double? plasticCreditEligibleKg,
  }) {
    return ZoneCreditEligibility(
      monthsActive: monthsActive ?? this.monthsActive,
      thresholdMet: thresholdMet ?? this.thresholdMet,
      plasticCreditEligibleKg:
          plasticCreditEligibleKg ?? this.plasticCreditEligibleKg,
    );
  }
}

class CollectionZone {
  final String zoneId;
  final String orgId;
  final String label;
  final ZonePolygon polygon;
  final ZoneSchedule schedule;
  final List<String> materialTypes;
  final List<String> linkedOrderIds;
  final bool isActive;
  final String? color;
  final ZoneStats stats;
  final ZoneCreditEligibility creditEligibility;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const CollectionZone({
    required this.zoneId,
    required this.orgId,
    required this.label,
    required this.polygon,
    required this.schedule,
    required this.materialTypes,
    required this.linkedOrderIds,
    required this.isActive,
    this.color,
    required this.stats,
    required this.creditEligibility,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  factory CollectionZone.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CollectionZone(
      zoneId: doc.id,
      orgId: (data['orgId'] as String?) ?? '',
      label: (data['label'] as String?) ?? '',
      polygon: ZonePolygon.fromMap(
        (data['polygon'] as Map<String, dynamic>?) ?? {},
      ),
      schedule: ZoneSchedule.fromMap(
        (data['schedule'] as Map<String, dynamic>?) ?? {},
      ),
      materialTypes:
          (data['materialTypes'] as List?)?.cast<String>() ?? const [],
      linkedOrderIds:
          (data['linkedOrderIds'] as List?)?.cast<String>() ?? const [],
      isActive: (data['isActive'] as bool?) ?? false,
      color: data['color'] as String?,
      stats: ZoneStats.fromMap(
        (data['stats'] as Map<String, dynamic>?) ?? {},
      ),
      creditEligibility: ZoneCreditEligibility.fromMap(
        (data['creditEligibility'] as Map<String, dynamic>?) ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: (data['createdBy'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orgId': orgId,
        'label': label,
        'polygon': polygon.toMap(),
        'schedule': schedule.toMap(),
        'materialTypes': materialTypes,
        'linkedOrderIds': linkedOrderIds,
        'isActive': isActive,
        'color': color,
        'stats': stats.toMap(),
        'creditEligibility': creditEligibility.toMap(),
        'createdAt':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'updatedAt':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'createdBy': createdBy,
      };

  CollectionZone copyWith({
    String? zoneId,
    String? orgId,
    String? label,
    ZonePolygon? polygon,
    ZoneSchedule? schedule,
    List<String>? materialTypes,
    List<String>? linkedOrderIds,
    bool? isActive,
    String? color,
    ZoneStats? stats,
    ZoneCreditEligibility? creditEligibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CollectionZone(
      zoneId: zoneId ?? this.zoneId,
      orgId: orgId ?? this.orgId,
      label: label ?? this.label,
      polygon: polygon ?? this.polygon,
      schedule: schedule ?? this.schedule,
      materialTypes: materialTypes ?? this.materialTypes,
      linkedOrderIds: linkedOrderIds ?? this.linkedOrderIds,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
      stats: stats ?? this.stats,
      creditEligibility: creditEligibility ?? this.creditEligibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
