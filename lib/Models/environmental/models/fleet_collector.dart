import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/fleet_collector_status.dart';

class FleetCollectorProfile {
  final String displayName;
  final String? photoUrl;
  final String? phoneNumber;

  const FleetCollectorProfile({
    required this.displayName,
    this.photoUrl,
    this.phoneNumber,
  });

  factory FleetCollectorProfile.fromMap(Map<String, dynamic> map) {
    return FleetCollectorProfile(
      displayName: (map['displayName'] as String?) ?? '',
      photoUrl: map['photoUrl'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
      };

  FleetCollectorProfile copyWith({
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
  }) {
    return FleetCollectorProfile(
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class FleetAssignment {
  final List<String> assignedZoneIds;
  final List<String> assignedZoneLabels;
  final String? primaryZoneId;

  const FleetAssignment({
    required this.assignedZoneIds,
    required this.assignedZoneLabels,
    this.primaryZoneId,
  });

  factory FleetAssignment.fromMap(Map<String, dynamic> map) {
    return FleetAssignment(
      assignedZoneIds:
          (map['assignedZoneIds'] as List?)?.cast<String>() ?? const [],
      assignedZoneLabels:
          (map['assignedZoneLabels'] as List?)?.cast<String>() ?? const [],
      primaryZoneId: map['primaryZoneId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'assignedZoneIds': assignedZoneIds,
        'assignedZoneLabels': assignedZoneLabels,
        'primaryZoneId': primaryZoneId,
      };

  FleetAssignment copyWith({
    List<String>? assignedZoneIds,
    List<String>? assignedZoneLabels,
    String? primaryZoneId,
  }) {
    return FleetAssignment(
      assignedZoneIds: assignedZoneIds ?? this.assignedZoneIds,
      assignedZoneLabels: assignedZoneLabels ?? this.assignedZoneLabels,
      primaryZoneId: primaryZoneId ?? this.primaryZoneId,
    );
  }
}

// Route sharing is always collector-controlled opt-in.
// The org cannot set routeSharing.enabled = true.
// Only the collector's own device can write this field.
class FleetRouteSharing {
  final bool enabled;
  final String? currentRouteGeoJsonUrl;
  final DateTime? lastRouteSharedAt;

  const FleetRouteSharing({
    required this.enabled,
    this.currentRouteGeoJsonUrl,
    this.lastRouteSharedAt,
  });

  factory FleetRouteSharing.fromMap(Map<String, dynamic> map) {
    return FleetRouteSharing(
      enabled: (map['enabled'] as bool?) ?? false,
      currentRouteGeoJsonUrl: map['currentRouteGeoJsonUrl'] as String?,
      lastRouteSharedAt: (map['lastRouteSharedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'currentRouteGeoJsonUrl': currentRouteGeoJsonUrl,
        'lastRouteSharedAt': lastRouteSharedAt != null
            ? Timestamp.fromDate(lastRouteSharedAt!)
            : null,
      };

  FleetRouteSharing copyWith({
    bool? enabled,
    String? currentRouteGeoJsonUrl,
    DateTime? lastRouteSharedAt,
  }) {
    return FleetRouteSharing(
      enabled: enabled ?? this.enabled,
      currentRouteGeoJsonUrl:
          currentRouteGeoJsonUrl ?? this.currentRouteGeoJsonUrl,
      lastRouteSharedAt: lastRouteSharedAt ?? this.lastRouteSharedAt,
    );
  }
}

class FleetStats {
  final double thisMonthKg;
  final int thisMonthTransactions;
  final double thisMonthEarningsKes;
  final DateTime? lastDeliveryAt;
  final double? lastDeliveryKg;
  final double totalKgAllTime;
  final int totalTransactionsAllTime;
  final double totalEarningsKesAllTime;
  final double royaltiesReceivedKesAllTime;

  const FleetStats({
    required this.thisMonthKg,
    required this.thisMonthTransactions,
    required this.thisMonthEarningsKes,
    this.lastDeliveryAt,
    this.lastDeliveryKg,
    required this.totalKgAllTime,
    required this.totalTransactionsAllTime,
    required this.totalEarningsKesAllTime,
    required this.royaltiesReceivedKesAllTime,
  });

  factory FleetStats.fromMap(Map<String, dynamic> map) {
    return FleetStats(
      thisMonthKg: (map['thisMonthKg'] as num?)?.toDouble() ?? 0.0,
      thisMonthTransactions:
          (map['thisMonthTransactions'] as num?)?.toInt() ?? 0,
      thisMonthEarningsKes:
          (map['thisMonthEarningsKes'] as num?)?.toDouble() ?? 0.0,
      lastDeliveryAt: (map['lastDeliveryAt'] as Timestamp?)?.toDate(),
      lastDeliveryKg: (map['lastDeliveryKg'] as num?)?.toDouble(),
      totalKgAllTime: (map['totalKgAllTime'] as num?)?.toDouble() ?? 0.0,
      totalTransactionsAllTime:
          (map['totalTransactionsAllTime'] as num?)?.toInt() ?? 0,
      totalEarningsKesAllTime:
          (map['totalEarningsKesAllTime'] as num?)?.toDouble() ?? 0.0,
      royaltiesReceivedKesAllTime:
          (map['royaltiesReceivedKesAllTime'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'thisMonthKg': thisMonthKg,
        'thisMonthTransactions': thisMonthTransactions,
        'thisMonthEarningsKes': thisMonthEarningsKes,
        'lastDeliveryAt':
            lastDeliveryAt != null ? Timestamp.fromDate(lastDeliveryAt!) : null,
        'lastDeliveryKg': lastDeliveryKg,
        'totalKgAllTime': totalKgAllTime,
        'totalTransactionsAllTime': totalTransactionsAllTime,
        'totalEarningsKesAllTime': totalEarningsKesAllTime,
        'royaltiesReceivedKesAllTime': royaltiesReceivedKesAllTime,
      };

  FleetStats copyWith({
    double? thisMonthKg,
    int? thisMonthTransactions,
    double? thisMonthEarningsKes,
    DateTime? lastDeliveryAt,
    double? lastDeliveryKg,
    double? totalKgAllTime,
    int? totalTransactionsAllTime,
    double? totalEarningsKesAllTime,
    double? royaltiesReceivedKesAllTime,
  }) {
    return FleetStats(
      thisMonthKg: thisMonthKg ?? this.thisMonthKg,
      thisMonthTransactions:
          thisMonthTransactions ?? this.thisMonthTransactions,
      thisMonthEarningsKes: thisMonthEarningsKes ?? this.thisMonthEarningsKes,
      lastDeliveryAt: lastDeliveryAt ?? this.lastDeliveryAt,
      lastDeliveryKg: lastDeliveryKg ?? this.lastDeliveryKg,
      totalKgAllTime: totalKgAllTime ?? this.totalKgAllTime,
      totalTransactionsAllTime:
          totalTransactionsAllTime ?? this.totalTransactionsAllTime,
      totalEarningsKesAllTime:
          totalEarningsKesAllTime ?? this.totalEarningsKesAllTime,
      royaltiesReceivedKesAllTime:
          royaltiesReceivedKesAllTime ?? this.royaltiesReceivedKesAllTime,
    );
  }
}

class FleetCollector {
  final String fleetMemberId;
  final String orgId;
  final String collectorUid;
  final FleetCollectorProfile profile;
  final FleetAssignment assignment;
  final FleetCollectorStatus status;
  final DateTime? statusUpdatedAt;
  final String statusUpdatedBy;
  final FleetRouteSharing routeSharing;
  final FleetStats stats;
  final DateTime? joinedFleetAt;
  final String? invitedBy;
  final String? notes;

  const FleetCollector({
    required this.fleetMemberId,
    required this.orgId,
    required this.collectorUid,
    required this.profile,
    required this.assignment,
    required this.status,
    this.statusUpdatedAt,
    required this.statusUpdatedBy,
    required this.routeSharing,
    required this.stats,
    this.joinedFleetAt,
    this.invitedBy,
    this.notes,
  });

  factory FleetCollector.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FleetCollector(
      fleetMemberId: doc.id,
      orgId: (data['orgId'] as String?) ?? '',
      collectorUid: (data['collectorUid'] as String?) ?? '',
      profile: FleetCollectorProfile.fromMap(
        (data['profile'] as Map<String, dynamic>?) ?? {},
      ),
      assignment: FleetAssignment.fromMap(
        (data['assignment'] as Map<String, dynamic>?) ?? {},
      ),
      status: FleetCollectorStatus.fromFirestoreKey(
        (data['status'] as String?) ?? 'inactive',
      ),
      statusUpdatedAt: (data['statusUpdatedAt'] as Timestamp?)?.toDate(),
      statusUpdatedBy: (data['statusUpdatedBy'] as String?) ?? '',
      routeSharing: FleetRouteSharing.fromMap(
        (data['routeSharing'] as Map<String, dynamic>?) ?? {},
      ),
      stats: FleetStats.fromMap(
        (data['stats'] as Map<String, dynamic>?) ?? {},
      ),
      joinedFleetAt: (data['joinedFleetAt'] as Timestamp?)?.toDate(),
      invitedBy: data['invitedBy'] as String?,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orgId': orgId,
        'collectorUid': collectorUid,
        'profile': profile.toMap(),
        'assignment': assignment.toMap(),
        'status': status.firestoreKey,
        'statusUpdatedAt': statusUpdatedAt != null
            ? Timestamp.fromDate(statusUpdatedAt!)
            : null,
        'statusUpdatedBy': statusUpdatedBy,
        'routeSharing': routeSharing.toMap(),
        'stats': stats.toMap(),
        'joinedFleetAt':
            joinedFleetAt != null ? Timestamp.fromDate(joinedFleetAt!) : null,
        'invitedBy': invitedBy,
        'notes': notes,
      };

  FleetCollector copyWith({
    String? fleetMemberId,
    String? orgId,
    String? collectorUid,
    FleetCollectorProfile? profile,
    FleetAssignment? assignment,
    FleetCollectorStatus? status,
    DateTime? statusUpdatedAt,
    String? statusUpdatedBy,
    FleetRouteSharing? routeSharing,
    FleetStats? stats,
    DateTime? joinedFleetAt,
    String? invitedBy,
    String? notes,
  }) {
    return FleetCollector(
      fleetMemberId: fleetMemberId ?? this.fleetMemberId,
      orgId: orgId ?? this.orgId,
      collectorUid: collectorUid ?? this.collectorUid,
      profile: profile ?? this.profile,
      assignment: assignment ?? this.assignment,
      status: status ?? this.status,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusUpdatedBy: statusUpdatedBy ?? this.statusUpdatedBy,
      routeSharing: routeSharing ?? this.routeSharing,
      stats: stats ?? this.stats,
      joinedFleetAt: joinedFleetAt ?? this.joinedFleetAt,
      invitedBy: invitedBy ?? this.invitedBy,
      notes: notes ?? this.notes,
    );
  }
}
