import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/credit_type.dart';

enum CreditQuantityUnit {
  kg,
  tonne,
  tree,
  meter;

  String get firestoreKey {
    switch (this) {
      case CreditQuantityUnit.kg:
        return 'kg';
      case CreditQuantityUnit.tonne:
        return 'tonne';
      case CreditQuantityUnit.tree:
        return 'tree';
      case CreditQuantityUnit.meter:
        return 'meter';
    }
  }

  static CreditQuantityUnit fromFirestoreKey(String key) {
    return CreditQuantityUnit.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => CreditQuantityUnit.kg,
    );
  }
}

enum CreditTradingStatus {
  held,
  listed,
  sold,
  retired;

  String get firestoreKey {
    switch (this) {
      case CreditTradingStatus.held:
        return 'held';
      case CreditTradingStatus.listed:
        return 'listed';
      case CreditTradingStatus.sold:
        return 'sold';
      case CreditTradingStatus.retired:
        return 'retired';
    }
  }

  String get displayLabel {
    switch (this) {
      case CreditTradingStatus.held:
        return 'Held';
      case CreditTradingStatus.listed:
        return 'Listed';
      case CreditTradingStatus.sold:
        return 'Sold';
      case CreditTradingStatus.retired:
        return 'Retired';
    }
  }

  static CreditTradingStatus fromFirestoreKey(String key) {
    return CreditTradingStatus.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => CreditTradingStatus.held,
    );
  }
}

class CreditOnChainAnchor {
  final String txHash;
  final DateTime? anchoredAt;
  final String blockchainExplorerUrl;

  const CreditOnChainAnchor({
    required this.txHash,
    this.anchoredAt,
    required this.blockchainExplorerUrl,
  });

  factory CreditOnChainAnchor.fromMap(Map<String, dynamic> map) {
    return CreditOnChainAnchor(
      txHash: (map['txHash'] as String?) ?? '',
      anchoredAt: (map['anchoredAt'] as Timestamp?)?.toDate(),
      blockchainExplorerUrl: (map['blockchainExplorerUrl'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'txHash': txHash,
        'anchoredAt':
            anchoredAt != null ? Timestamp.fromDate(anchoredAt!) : null,
        'blockchainExplorerUrl': blockchainExplorerUrl,
      };

  CreditOnChainAnchor copyWith({
    String? txHash,
    DateTime? anchoredAt,
    String? blockchainExplorerUrl,
  }) {
    return CreditOnChainAnchor(
      txHash: txHash ?? this.txHash,
      anchoredAt: anchoredAt ?? this.anchoredAt,
      blockchainExplorerUrl:
          blockchainExplorerUrl ?? this.blockchainExplorerUrl,
    );
  }
}

class CreditEvidenceChain {
  final String? reportId;
  final List<String> verificationTaskIds;
  final String? transformationId;
  final List<String> collectorIds;
  final List<String> processorIds;
  final DateTime? stage3ConfirmedAt;
  final GeoPoint gpsCoordinates;
  final List<String> photoUrls;
  final CreditOnChainAnchor onChainAnchor;

  const CreditEvidenceChain({
    this.reportId,
    required this.verificationTaskIds,
    this.transformationId,
    required this.collectorIds,
    required this.processorIds,
    this.stage3ConfirmedAt,
    required this.gpsCoordinates,
    required this.photoUrls,
    required this.onChainAnchor,
  });

  factory CreditEvidenceChain.fromMap(Map<String, dynamic> map) {
    return CreditEvidenceChain(
      reportId: map['reportId'] as String?,
      verificationTaskIds:
          (map['verificationTaskIds'] as List?)?.cast<String>() ?? const [],
      transformationId: map['transformationId'] as String?,
      collectorIds:
          (map['collectorIds'] as List?)?.cast<String>() ?? const [],
      processorIds:
          (map['processorIds'] as List?)?.cast<String>() ?? const [],
      stage3ConfirmedAt: (map['stage3ConfirmedAt'] as Timestamp?)?.toDate(),
      gpsCoordinates:
          map['gpsCoordinates'] as GeoPoint? ?? const GeoPoint(0, 0),
      photoUrls: (map['photoUrls'] as List?)?.cast<String>() ?? const [],
      onChainAnchor: CreditOnChainAnchor.fromMap(
        (map['onChainAnchor'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'verificationTaskIds': verificationTaskIds,
        'transformationId': transformationId,
        'collectorIds': collectorIds,
        'processorIds': processorIds,
        'stage3ConfirmedAt': stage3ConfirmedAt != null
            ? Timestamp.fromDate(stage3ConfirmedAt!)
            : null,
        'gpsCoordinates': gpsCoordinates,
        'photoUrls': photoUrls,
        'onChainAnchor': onChainAnchor.toMap(),
      };

  CreditEvidenceChain copyWith({
    String? reportId,
    List<String>? verificationTaskIds,
    String? transformationId,
    List<String>? collectorIds,
    List<String>? processorIds,
    DateTime? stage3ConfirmedAt,
    GeoPoint? gpsCoordinates,
    List<String>? photoUrls,
    CreditOnChainAnchor? onChainAnchor,
  }) {
    return CreditEvidenceChain(
      reportId: reportId ?? this.reportId,
      verificationTaskIds: verificationTaskIds ?? this.verificationTaskIds,
      transformationId: transformationId ?? this.transformationId,
      collectorIds: collectorIds ?? this.collectorIds,
      processorIds: processorIds ?? this.processorIds,
      stage3ConfirmedAt: stage3ConfirmedAt ?? this.stage3ConfirmedAt,
      gpsCoordinates: gpsCoordinates ?? this.gpsCoordinates,
      photoUrls: photoUrls ?? this.photoUrls,
      onChainAnchor: onChainAnchor ?? this.onChainAnchor,
    );
  }
}

class CreditQuantity {
  final CreditQuantityUnit unit;
  final double amount;
  final String displayLabel;

  const CreditQuantity({
    required this.unit,
    required this.amount,
    required this.displayLabel,
  });

  factory CreditQuantity.fromMap(Map<String, dynamic> map) {
    return CreditQuantity(
      unit: CreditQuantityUnit.fromFirestoreKey(
        (map['unit'] as String?) ?? 'kg',
      ),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      displayLabel: (map['displayLabel'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'unit': unit.firestoreKey,
        'amount': amount,
        'displayLabel': displayLabel,
      };

  CreditQuantity copyWith({
    CreditQuantityUnit? unit,
    double? amount,
    String? displayLabel,
  }) {
    return CreditQuantity(
      unit: unit ?? this.unit,
      amount: amount ?? this.amount,
      displayLabel: displayLabel ?? this.displayLabel,
    );
  }
}

class CreditCertificate {
  final String serialNumber;
  final String? pdfUrl;
  final String? jsonUrl;
  final String? blockchainVerificationUrl;

  const CreditCertificate({
    required this.serialNumber,
    this.pdfUrl,
    this.jsonUrl,
    this.blockchainVerificationUrl,
  });

  factory CreditCertificate.fromMap(Map<String, dynamic> map) {
    return CreditCertificate(
      serialNumber: (map['serialNumber'] as String?) ?? '',
      pdfUrl: map['pdfUrl'] as String?,
      jsonUrl: map['jsonUrl'] as String?,
      blockchainVerificationUrl: map['blockchainVerificationUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'serialNumber': serialNumber,
        'pdfUrl': pdfUrl,
        'jsonUrl': jsonUrl,
        'blockchainVerificationUrl': blockchainVerificationUrl,
      };

  CreditCertificate copyWith({
    String? serialNumber,
    String? pdfUrl,
    String? jsonUrl,
    String? blockchainVerificationUrl,
  }) {
    return CreditCertificate(
      serialNumber: serialNumber ?? this.serialNumber,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      jsonUrl: jsonUrl ?? this.jsonUrl,
      blockchainVerificationUrl:
          blockchainVerificationUrl ?? this.blockchainVerificationUrl,
    );
  }
}

class CreditUnepAlignment {
  final String methodology;
  final String? treatyFramework;
  final String? complianceNotes;

  const CreditUnepAlignment({
    required this.methodology,
    this.treatyFramework,
    this.complianceNotes,
  });

  factory CreditUnepAlignment.fromMap(Map<String, dynamic> map) {
    return CreditUnepAlignment(
      methodology: (map['methodology'] as String?) ?? '',
      treatyFramework: map['treatyFramework'] as String?,
      complianceNotes: map['complianceNotes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'methodology': methodology,
        'treatyFramework': treatyFramework,
        'complianceNotes': complianceNotes,
      };

  CreditUnepAlignment copyWith({
    String? methodology,
    String? treatyFramework,
    String? complianceNotes,
  }) {
    return CreditUnepAlignment(
      methodology: methodology ?? this.methodology,
      treatyFramework: treatyFramework ?? this.treatyFramework,
      complianceNotes: complianceNotes ?? this.complianceNotes,
    );
  }
}

class EnvironmentalCredit {
  final String creditId;
  final CreditType creditType;
  final String issuedTo;
  final DateTime? issuedAt;
  final CreditEvidenceChain evidenceChain;
  final CreditQuantity quantity;
  final CreditCertificate certificate;
  final CreditUnepAlignment unepAlignment;
  final CreditTradingStatus tradingStatus;
  final DateTime? listedAt;
  final DateTime? soldAt;
  final String? buyerId;
  final double? salePriceKes;
  final double? salePriceUsd;
  final String? linkedBountyId;
  final DateTime? createdAt;

  const EnvironmentalCredit({
    required this.creditId,
    required this.creditType,
    required this.issuedTo,
    this.issuedAt,
    required this.evidenceChain,
    required this.quantity,
    required this.certificate,
    required this.unepAlignment,
    required this.tradingStatus,
    this.listedAt,
    this.soldAt,
    this.buyerId,
    this.salePriceKes,
    this.salePriceUsd,
    this.linkedBountyId,
    this.createdAt,
  });

  factory EnvironmentalCredit.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return EnvironmentalCredit(
      creditId: doc.id,
      creditType: CreditType.fromFirestoreKey(
        (data['creditType'] as String?) ?? 'plastic_recovery',
      ),
      issuedTo: (data['issuedTo'] as String?) ?? '',
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate(),
      evidenceChain: CreditEvidenceChain.fromMap(
        (data['evidenceChain'] as Map<String, dynamic>?) ?? {},
      ),
      quantity: CreditQuantity.fromMap(
        (data['quantity'] as Map<String, dynamic>?) ?? {},
      ),
      certificate: CreditCertificate.fromMap(
        (data['certificate'] as Map<String, dynamic>?) ?? {},
      ),
      unepAlignment: CreditUnepAlignment.fromMap(
        (data['unepAlignment'] as Map<String, dynamic>?) ?? {},
      ),
      tradingStatus: CreditTradingStatus.fromFirestoreKey(
        (data['tradingStatus'] as String?) ?? 'held',
      ),
      listedAt: (data['listedAt'] as Timestamp?)?.toDate(),
      soldAt: (data['soldAt'] as Timestamp?)?.toDate(),
      buyerId: data['buyerId'] as String?,
      salePriceKes: (data['salePriceKes'] as num?)?.toDouble(),
      salePriceUsd: (data['salePriceUsd'] as num?)?.toDouble(),
      linkedBountyId: data['linkedBountyId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'creditType': creditType.firestoreKey,
        'issuedTo': issuedTo,
        'issuedAt': issuedAt != null ? Timestamp.fromDate(issuedAt!) : null,
        'evidenceChain': evidenceChain.toMap(),
        'quantity': quantity.toMap(),
        'certificate': certificate.toMap(),
        'unepAlignment': unepAlignment.toMap(),
        'tradingStatus': tradingStatus.firestoreKey,
        'listedAt': listedAt != null ? Timestamp.fromDate(listedAt!) : null,
        'soldAt': soldAt != null ? Timestamp.fromDate(soldAt!) : null,
        'buyerId': buyerId,
        'salePriceKes': salePriceKes,
        'salePriceUsd': salePriceUsd,
        'linkedBountyId': linkedBountyId,
        'createdAt':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      };

  EnvironmentalCredit copyWith({
    String? creditId,
    CreditType? creditType,
    String? issuedTo,
    DateTime? issuedAt,
    CreditEvidenceChain? evidenceChain,
    CreditQuantity? quantity,
    CreditCertificate? certificate,
    CreditUnepAlignment? unepAlignment,
    CreditTradingStatus? tradingStatus,
    DateTime? listedAt,
    DateTime? soldAt,
    String? buyerId,
    double? salePriceKes,
    double? salePriceUsd,
    String? linkedBountyId,
    DateTime? createdAt,
  }) {
    return EnvironmentalCredit(
      creditId: creditId ?? this.creditId,
      creditType: creditType ?? this.creditType,
      issuedTo: issuedTo ?? this.issuedTo,
      issuedAt: issuedAt ?? this.issuedAt,
      evidenceChain: evidenceChain ?? this.evidenceChain,
      quantity: quantity ?? this.quantity,
      certificate: certificate ?? this.certificate,
      unepAlignment: unepAlignment ?? this.unepAlignment,
      tradingStatus: tradingStatus ?? this.tradingStatus,
      listedAt: listedAt ?? this.listedAt,
      soldAt: soldAt ?? this.soldAt,
      buyerId: buyerId ?? this.buyerId,
      salePriceKes: salePriceKes ?? this.salePriceKes,
      salePriceUsd: salePriceUsd ?? this.salePriceUsd,
      linkedBountyId: linkedBountyId ?? this.linkedBountyId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
