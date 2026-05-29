import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/verification_tier.dart';

enum EnvironmentalOrgType {
  recycler,
  upcycler,
  processor,
  wasteCollector,
  conservationBody,
  urbanGreening,
  waterwayClearance,
  multi;

  String get firestoreKey {
    switch (this) {
      case EnvironmentalOrgType.recycler:
        return 'recycler';
      case EnvironmentalOrgType.upcycler:
        return 'upcycler';
      case EnvironmentalOrgType.processor:
        return 'processor';
      case EnvironmentalOrgType.wasteCollector:
        return 'wasteCollector';
      case EnvironmentalOrgType.conservationBody:
        return 'conservationBody';
      case EnvironmentalOrgType.urbanGreening:
        return 'urbanGreening';
      case EnvironmentalOrgType.waterwayClearance:
        return 'waterwayClearance';
      case EnvironmentalOrgType.multi:
        return 'multi';
    }
  }

  String get displayLabel {
    switch (this) {
      case EnvironmentalOrgType.recycler:
        return 'Recycler';
      case EnvironmentalOrgType.upcycler:
        return 'Upcycler';
      case EnvironmentalOrgType.processor:
        return 'Processor';
      case EnvironmentalOrgType.wasteCollector:
        return 'Waste Collector';
      case EnvironmentalOrgType.conservationBody:
        return 'Conservation Body';
      case EnvironmentalOrgType.urbanGreening:
        return 'Urban Greening';
      case EnvironmentalOrgType.waterwayClearance:
        return 'Waterway Clearance';
      case EnvironmentalOrgType.multi:
        return 'Multi-activity';
    }
  }

  static EnvironmentalOrgType fromFirestoreKey(String key) {
    return EnvironmentalOrgType.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => EnvironmentalOrgType.recycler,
    );
  }
}

enum OrgSellerRole {
  collector,
  processor,
  maker;

  String get firestoreKey {
    switch (this) {
      case OrgSellerRole.collector:
        return 'collector';
      case OrgSellerRole.processor:
        return 'processor';
      case OrgSellerRole.maker:
        return 'maker';
    }
  }

  static OrgSellerRole fromFirestoreKey(String key) {
    return OrgSellerRole.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => OrgSellerRole.collector,
    );
  }
}

class OrgCapabilityFlags {
  final bool isEnvironmentalOps;
  final bool isMarketplaceSeller;
  final OrgSellerRole? sellerRole;
  final bool hasCollectionZones;
  final bool hasTrees;
  final bool hasFleetCollectors;

  const OrgCapabilityFlags({
    required this.isEnvironmentalOps,
    required this.isMarketplaceSeller,
    this.sellerRole,
    required this.hasCollectionZones,
    required this.hasTrees,
    required this.hasFleetCollectors,
  });

  factory OrgCapabilityFlags.fromMap(Map<String, dynamic> map) {
    final sellerRoleKey = map['sellerRole'] as String?;
    return OrgCapabilityFlags(
      isEnvironmentalOps: (map['isEnvironmentalOps'] as bool?) ?? false,
      isMarketplaceSeller: (map['isMarketplaceSeller'] as bool?) ?? false,
      sellerRole: sellerRoleKey != null
          ? OrgSellerRole.fromFirestoreKey(sellerRoleKey)
          : null,
      hasCollectionZones: (map['hasCollectionZones'] as bool?) ?? false,
      hasTrees: (map['hasTrees'] as bool?) ?? false,
      hasFleetCollectors: (map['hasFleetCollectors'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'isEnvironmentalOps': isEnvironmentalOps,
        'isMarketplaceSeller': isMarketplaceSeller,
        'sellerRole': sellerRole?.firestoreKey,
        'hasCollectionZones': hasCollectionZones,
        'hasTrees': hasTrees,
        'hasFleetCollectors': hasFleetCollectors,
      };

  OrgCapabilityFlags copyWith({
    bool? isEnvironmentalOps,
    bool? isMarketplaceSeller,
    OrgSellerRole? sellerRole,
    bool? hasCollectionZones,
    bool? hasTrees,
    bool? hasFleetCollectors,
  }) {
    return OrgCapabilityFlags(
      isEnvironmentalOps: isEnvironmentalOps ?? this.isEnvironmentalOps,
      isMarketplaceSeller: isMarketplaceSeller ?? this.isMarketplaceSeller,
      sellerRole: sellerRole ?? this.sellerRole,
      hasCollectionZones: hasCollectionZones ?? this.hasCollectionZones,
      hasTrees: hasTrees ?? this.hasTrees,
      hasFleetCollectors: hasFleetCollectors ?? this.hasFleetCollectors,
    );
  }
}

// impactRecord is read-only system data.
// Never write to this block from the app.
// Maintained by Cloud Functions only.
class OrgImpactRecord {
  final int eventsRun;
  final int sitesCleaned;
  final int treesPlanted;
  final int treesConfirmed90Day;
  final double plasticDivertedKg;
  final int transformationConfirmations;
  final DateTime? lastUpdated;

  const OrgImpactRecord({
    required this.eventsRun,
    required this.sitesCleaned,
    required this.treesPlanted,
    required this.treesConfirmed90Day,
    required this.plasticDivertedKg,
    required this.transformationConfirmations,
    this.lastUpdated,
  });

  factory OrgImpactRecord.fromMap(Map<String, dynamic> map) {
    return OrgImpactRecord(
      eventsRun: (map['eventsRun'] as num?)?.toInt() ?? 0,
      sitesCleaned: (map['sitesCleaned'] as num?)?.toInt() ?? 0,
      treesPlanted: (map['treesPlanted'] as num?)?.toInt() ?? 0,
      treesConfirmed90Day: (map['treesConfirmed90Day'] as num?)?.toInt() ?? 0,
      plasticDivertedKg: (map['plasticDivertedKg'] as num?)?.toDouble() ?? 0.0,
      transformationConfirmations:
          (map['transformationConfirmations'] as num?)?.toInt() ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'eventsRun': eventsRun,
        'sitesCleaned': sitesCleaned,
        'treesPlanted': treesPlanted,
        'treesConfirmed90Day': treesConfirmed90Day,
        'plasticDivertedKg': plasticDivertedKg,
        'transformationConfirmations': transformationConfirmations,
        'lastUpdated':
            lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      };

  OrgImpactRecord copyWith({
    int? eventsRun,
    int? sitesCleaned,
    int? treesPlanted,
    int? treesConfirmed90Day,
    double? plasticDivertedKg,
    int? transformationConfirmations,
    DateTime? lastUpdated,
  }) {
    return OrgImpactRecord(
      eventsRun: eventsRun ?? this.eventsRun,
      sitesCleaned: sitesCleaned ?? this.sitesCleaned,
      treesPlanted: treesPlanted ?? this.treesPlanted,
      treesConfirmed90Day: treesConfirmed90Day ?? this.treesConfirmed90Day,
      plasticDivertedKg: plasticDivertedKg ?? this.plasticDivertedKg,
      transformationConfirmations:
          transformationConfirmations ?? this.transformationConfirmations,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class OrgEnvSummary {
  final String orgId;
  final String orgName;
  final EnvironmentalOrgType orgType;
  final VerificationTier verificationTier;
  final OrgCapabilityFlags capabilityFlags;
  final OrgImpactRecord impactRecord;

  const OrgEnvSummary({
    required this.orgId,
    required this.orgName,
    required this.orgType,
    required this.verificationTier,
    required this.capabilityFlags,
    required this.impactRecord,
  });

  factory OrgEnvSummary.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final capsData = (data['capabilityFlags'] as Map<String, dynamic>?) ?? {};
    final impactData = (data['impactRecord'] as Map<String, dynamic>?) ?? {};
    return OrgEnvSummary(
      orgId: doc.id,
      orgName: (data['orgName'] as String?) ?? '',
      orgType: EnvironmentalOrgType.fromFirestoreKey(
        (data['orgType'] as String?) ?? 'recycler',
      ),
      verificationTier: VerificationTier.fromFirestoreKey(
        (data['verificationTier'] as String?) ?? 'registered',
      ),
      capabilityFlags: OrgCapabilityFlags.fromMap(capsData),
      impactRecord: OrgImpactRecord.fromMap(impactData),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orgName': orgName,
        'orgType': orgType.firestoreKey,
        'verificationTier': verificationTier.firestoreKey,
        'capabilityFlags': capabilityFlags.toMap(),
        'impactRecord': impactRecord.toMap(),
      };

  OrgEnvSummary copyWith({
    String? orgId,
    String? orgName,
    EnvironmentalOrgType? orgType,
    VerificationTier? verificationTier,
    OrgCapabilityFlags? capabilityFlags,
    OrgImpactRecord? impactRecord,
  }) {
    return OrgEnvSummary(
      orgId: orgId ?? this.orgId,
      orgName: orgName ?? this.orgName,
      orgType: orgType ?? this.orgType,
      verificationTier: verificationTier ?? this.verificationTier,
      capabilityFlags: capabilityFlags ?? this.capabilityFlags,
      impactRecord: impactRecord ?? this.impactRecord,
    );
  }
}
