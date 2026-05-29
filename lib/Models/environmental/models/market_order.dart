import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/material_category.dart';
import 'package:impact_trail/models/environmental/enums/material_order_status.dart';

enum MarketOrderType {
  buy,
  sell;

  String get firestoreKey {
    switch (this) {
      case MarketOrderType.buy:
        return 'buy';
      case MarketOrderType.sell:
        return 'sell';
    }
  }

  static MarketOrderType fromFirestoreKey(String key) {
    return MarketOrderType.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => MarketOrderType.buy,
    );
  }
}

class MarketOrderMaterial {
  final MaterialCategory category;
  final String type;
  final String? grade;
  final String? conditionNotes;

  const MarketOrderMaterial({
    required this.category,
    required this.type,
    this.grade,
    this.conditionNotes,
  });

  factory MarketOrderMaterial.fromMap(Map<String, dynamic> map) {
    return MarketOrderMaterial(
      category: MaterialCategory.fromFirestoreKey(
        (map['category'] as String?) ?? 'plastics',
      ),
      type: (map['type'] as String?) ?? '',
      grade: map['grade'] as String?,
      conditionNotes: map['conditionNotes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category.firestoreKey,
        'type': type,
        'grade': grade,
        'conditionNotes': conditionNotes,
      };

  MarketOrderMaterial copyWith({
    MaterialCategory? category,
    String? type,
    String? grade,
    String? conditionNotes,
  }) {
    return MarketOrderMaterial(
      category: category ?? this.category,
      type: type ?? this.type,
      grade: grade ?? this.grade,
      conditionNotes: conditionNotes ?? this.conditionNotes,
    );
  }
}

class MarketOrderPricing {
  final double pricePerKg;
  final String currency;
  final bool negotiable;

  const MarketOrderPricing({
    required this.pricePerKg,
    required this.currency,
    required this.negotiable,
  });

  factory MarketOrderPricing.fromMap(Map<String, dynamic> map) {
    return MarketOrderPricing(
      pricePerKg: (map['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? 'KES',
      negotiable: (map['negotiable'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'pricePerKg': pricePerKg,
        'currency': currency,
        'negotiable': negotiable,
      };

  MarketOrderPricing copyWith({
    double? pricePerKg,
    String? currency,
    bool? negotiable,
  }) {
    return MarketOrderPricing(
      pricePerKg: pricePerKg ?? this.pricePerKg,
      currency: currency ?? this.currency,
      negotiable: negotiable ?? this.negotiable,
    );
  }
}

class MarketOrderQuantity {
  final double minimumKg;
  final double maximumKg;
  final double filledKg;

  const MarketOrderQuantity({
    required this.minimumKg,
    required this.maximumKg,
    required this.filledKg,
  });

  factory MarketOrderQuantity.fromMap(Map<String, dynamic> map) {
    return MarketOrderQuantity(
      minimumKg: (map['minimumKg'] as num?)?.toDouble() ?? 0.0,
      maximumKg: (map['maximumKg'] as num?)?.toDouble() ?? 0.0,
      filledKg: (map['filledKg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'minimumKg': minimumKg,
        'maximumKg': maximumKg,
        'filledKg': filledKg,
      };

  MarketOrderQuantity copyWith({
    double? minimumKg,
    double? maximumKg,
    double? filledKg,
  }) {
    return MarketOrderQuantity(
      minimumKg: minimumKg ?? this.minimumKg,
      maximumKg: maximumKg ?? this.maximumKg,
      filledKg: filledKg ?? this.filledKg,
    );
  }
}

class MarketOrderZone {
  final List<String> zoneIds;
  final List<String> zoneLabels;
  final bool acceptsDelivery;
  final bool willCollect;

  const MarketOrderZone({
    required this.zoneIds,
    required this.zoneLabels,
    required this.acceptsDelivery,
    required this.willCollect,
  });

  factory MarketOrderZone.fromMap(Map<String, dynamic> map) {
    return MarketOrderZone(
      zoneIds:
          (map['zoneIds'] as List?)?.cast<String>() ?? const [],
      zoneLabels:
          (map['zoneLabels'] as List?)?.cast<String>() ?? const [],
      acceptsDelivery: (map['acceptsDelivery'] as bool?) ?? false,
      willCollect: (map['willCollect'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'zoneIds': zoneIds,
        'zoneLabels': zoneLabels,
        'acceptsDelivery': acceptsDelivery,
        'willCollect': willCollect,
      };

  MarketOrderZone copyWith({
    List<String>? zoneIds,
    List<String>? zoneLabels,
    bool? acceptsDelivery,
    bool? willCollect,
  }) {
    return MarketOrderZone(
      zoneIds: zoneIds ?? this.zoneIds,
      zoneLabels: zoneLabels ?? this.zoneLabels,
      acceptsDelivery: acceptsDelivery ?? this.acceptsDelivery,
      willCollect: willCollect ?? this.willCollect,
    );
  }
}

class MarketOrderResponses {
  final int count;
  final List<String> respondentUids;

  const MarketOrderResponses({
    required this.count,
    required this.respondentUids,
  });

  factory MarketOrderResponses.fromMap(Map<String, dynamic> map) {
    return MarketOrderResponses(
      count: (map['count'] as num?)?.toInt() ?? 0,
      respondentUids:
          (map['respondentUids'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'count': count,
        'respondentUids': respondentUids,
      };

  MarketOrderResponses copyWith({
    int? count,
    List<String>? respondentUids,
  }) {
    return MarketOrderResponses(
      count: count ?? this.count,
      respondentUids: respondentUids ?? this.respondentUids,
    );
  }
}

class MarketOrder {
  final String orderId;
  final String orgId;
  final MarketOrderType orderType;
  final MarketOrderMaterial material;
  final MarketOrderPricing pricing;
  final MarketOrderQuantity quantity;
  final MarketOrderZone zone;
  final MarketOrderResponses responses;
  final MaterialOrderStatus status;
  final String? notes;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const MarketOrder({
    required this.orderId,
    required this.orgId,
    required this.orderType,
    required this.material,
    required this.pricing,
    required this.quantity,
    required this.zone,
    required this.responses,
    required this.status,
    this.notes,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  double get fillFraction =>
      quantity.maximumKg > 0 ? quantity.filledKg / quantity.maximumKg : 0.0;

  factory MarketOrder.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MarketOrder(
      orderId: doc.id,
      orgId: (data['orgId'] as String?) ?? '',
      orderType: MarketOrderType.fromFirestoreKey(
        (data['orderType'] as String?) ?? 'buy',
      ),
      material: MarketOrderMaterial.fromMap(
        (data['material'] as Map<String, dynamic>?) ?? {},
      ),
      pricing: MarketOrderPricing.fromMap(
        (data['pricing'] as Map<String, dynamic>?) ?? {},
      ),
      quantity: MarketOrderQuantity.fromMap(
        (data['quantity'] as Map<String, dynamic>?) ?? {},
      ),
      zone: MarketOrderZone.fromMap(
        (data['zone'] as Map<String, dynamic>?) ?? {},
      ),
      responses: MarketOrderResponses.fromMap(
        (data['responses'] as Map<String, dynamic>?) ?? {},
      ),
      status: MaterialOrderStatus.fromFirestoreKey(
        (data['status'] as String?) ?? 'draft',
      ),
      notes: data['notes'] as String?,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: (data['createdBy'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orgId': orgId,
        'orderType': orderType.firestoreKey,
        'material': material.toMap(),
        'pricing': pricing.toMap(),
        'quantity': quantity.toMap(),
        'zone': zone.toMap(),
        'responses': responses.toMap(),
        'status': status.firestoreKey,
        'notes': notes,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'createdAt':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'updatedAt':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'createdBy': createdBy,
      };

  MarketOrder copyWith({
    String? orderId,
    String? orgId,
    MarketOrderType? orderType,
    MarketOrderMaterial? material,
    MarketOrderPricing? pricing,
    MarketOrderQuantity? quantity,
    MarketOrderZone? zone,
    MarketOrderResponses? responses,
    MaterialOrderStatus? status,
    String? notes,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return MarketOrder(
      orderId: orderId ?? this.orderId,
      orgId: orgId ?? this.orgId,
      orderType: orderType ?? this.orderType,
      material: material ?? this.material,
      pricing: pricing ?? this.pricing,
      quantity: quantity ?? this.quantity,
      zone: zone ?? this.zone,
      responses: responses ?? this.responses,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
