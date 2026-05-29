// One handoff creates two Firestore documents:
// 1. organisations/{orgId}/collectionHandoffs/{handoffId}  ← this model
// 2. marketplace_transactions/{transactionId}              ← top-level collection
// Both reference each other via linkedTransactionId.
// Write both in a Firestore batch — never write one without the other.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/material_category.dart';
import 'package:impact_trail/models/environmental/enums/payment_method.dart';

class HandoffMaterial {
  final MaterialCategory category;
  final String type;
  final String? grade;
  final double weightKg;
  final double? impactScore;

  const HandoffMaterial({
    required this.category,
    required this.type,
    this.grade,
    required this.weightKg,
    this.impactScore,
  });

  factory HandoffMaterial.fromMap(Map<String, dynamic> map) {
    return HandoffMaterial(
      category: MaterialCategory.fromFirestoreKey(
        (map['category'] as String?) ?? 'plastics',
      ),
      type: (map['type'] as String?) ?? '',
      grade: map['grade'] as String?,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      impactScore: (map['impactScore'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category.firestoreKey,
        'type': type,
        'grade': grade,
        'weightKg': weightKg,
        'impactScore': impactScore,
      };

  HandoffMaterial copyWith({
    MaterialCategory? category,
    String? type,
    String? grade,
    double? weightKg,
    double? impactScore,
  }) {
    return HandoffMaterial(
      category: category ?? this.category,
      type: type ?? this.type,
      grade: grade ?? this.grade,
      weightKg: weightKg ?? this.weightKg,
      impactScore: impactScore ?? this.impactScore,
    );
  }
}

class HandoffFinancials {
  final double pricePerKg;
  final double totalPaidKes;
  final int impactPointsAwarded;
  final bool softPlasticBonus;
  final PaymentMethod paymentMethod;
  final String? mpesaTxRef;
  final DateTime? paidAt;

  const HandoffFinancials({
    required this.pricePerKg,
    required this.totalPaidKes,
    required this.impactPointsAwarded,
    required this.softPlasticBonus,
    required this.paymentMethod,
    this.mpesaTxRef,
    this.paidAt,
  });

  factory HandoffFinancials.fromMap(Map<String, dynamic> map) {
    return HandoffFinancials(
      pricePerKg: (map['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      totalPaidKes: (map['totalPaidKes'] as num?)?.toDouble() ?? 0.0,
      impactPointsAwarded:
          (map['impactPointsAwarded'] as num?)?.toInt() ?? 0,
      softPlasticBonus: (map['softPlasticBonus'] as bool?) ?? false,
      paymentMethod: PaymentMethod.fromFirestoreKey(
        (map['paymentMethod'] as String?) ?? 'mpesa',
      ),
      mpesaTxRef: map['mpesaTxRef'] as String?,
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'pricePerKg': pricePerKg,
        'totalPaidKes': totalPaidKes,
        'impactPointsAwarded': impactPointsAwarded,
        'softPlasticBonus': softPlasticBonus,
        'paymentMethod': paymentMethod.firestoreKey,
        'mpesaTxRef': mpesaTxRef,
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      };

  HandoffFinancials copyWith({
    double? pricePerKg,
    double? totalPaidKes,
    int? impactPointsAwarded,
    bool? softPlasticBonus,
    PaymentMethod? paymentMethod,
    String? mpesaTxRef,
    DateTime? paidAt,
  }) {
    return HandoffFinancials(
      pricePerKg: pricePerKg ?? this.pricePerKg,
      totalPaidKes: totalPaidKes ?? this.totalPaidKes,
      impactPointsAwarded: impactPointsAwarded ?? this.impactPointsAwarded,
      softPlasticBonus: softPlasticBonus ?? this.softPlasticBonus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      mpesaTxRef: mpesaTxRef ?? this.mpesaTxRef,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

class HandoffLocation {
  final double lat;
  final double lng;
  final String label;
  final String? siteMarkerId;

  const HandoffLocation({
    required this.lat,
    required this.lng,
    required this.label,
    this.siteMarkerId,
  });

  factory HandoffLocation.fromMap(Map<String, dynamic> map) {
    return HandoffLocation(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      label: (map['label'] as String?) ?? '',
      siteMarkerId: map['siteMarkerId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'label': label,
        'siteMarkerId': siteMarkerId,
      };

  HandoffLocation copyWith({
    double? lat,
    double? lng,
    String? label,
    String? siteMarkerId,
  }) {
    return HandoffLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      label: label ?? this.label,
      siteMarkerId: siteMarkerId ?? this.siteMarkerId,
    );
  }
}

class CollectionHandoff {
  final String handoffId;
  final String orgId;
  final String collectorUid;
  final HandoffMaterial material;
  final HandoffFinancials financials;
  final HandoffLocation location;
  final String? zoneId;
  final String? linkedOrderId;
  final String? linkedTransactionId;
  final DateTime? loggedAt;
  final String loggedBy;

  const CollectionHandoff({
    required this.handoffId,
    required this.orgId,
    required this.collectorUid,
    required this.material,
    required this.financials,
    required this.location,
    this.zoneId,
    this.linkedOrderId,
    this.linkedTransactionId,
    this.loggedAt,
    required this.loggedBy,
  });

  factory CollectionHandoff.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CollectionHandoff(
      handoffId: doc.id,
      orgId: (data['orgId'] as String?) ?? '',
      collectorUid: (data['collectorUid'] as String?) ?? '',
      material: HandoffMaterial.fromMap(
        (data['material'] as Map<String, dynamic>?) ?? {},
      ),
      financials: HandoffFinancials.fromMap(
        (data['financials'] as Map<String, dynamic>?) ?? {},
      ),
      location: HandoffLocation.fromMap(
        (data['location'] as Map<String, dynamic>?) ?? {},
      ),
      zoneId: data['zoneId'] as String?,
      linkedOrderId: data['linkedOrderId'] as String?,
      linkedTransactionId: data['linkedTransactionId'] as String?,
      loggedAt: (data['loggedAt'] as Timestamp?)?.toDate(),
      loggedBy: (data['loggedBy'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orgId': orgId,
        'collectorUid': collectorUid,
        'material': material.toMap(),
        'financials': financials.toMap(),
        'location': location.toMap(),
        'zoneId': zoneId,
        'linkedOrderId': linkedOrderId,
        'linkedTransactionId': linkedTransactionId,
        'loggedAt': loggedAt != null ? Timestamp.fromDate(loggedAt!) : null,
        'loggedBy': loggedBy,
      };

  CollectionHandoff copyWith({
    String? handoffId,
    String? orgId,
    String? collectorUid,
    HandoffMaterial? material,
    HandoffFinancials? financials,
    HandoffLocation? location,
    String? zoneId,
    String? linkedOrderId,
    String? linkedTransactionId,
    DateTime? loggedAt,
    String? loggedBy,
  }) {
    return CollectionHandoff(
      handoffId: handoffId ?? this.handoffId,
      orgId: orgId ?? this.orgId,
      collectorUid: collectorUid ?? this.collectorUid,
      material: material ?? this.material,
      financials: financials ?? this.financials,
      location: location ?? this.location,
      zoneId: zoneId ?? this.zoneId,
      linkedOrderId: linkedOrderId ?? this.linkedOrderId,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      loggedAt: loggedAt ?? this.loggedAt,
      loggedBy: loggedBy ?? this.loggedBy,
    );
  }
}
