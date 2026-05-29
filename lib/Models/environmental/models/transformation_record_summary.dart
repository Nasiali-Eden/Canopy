// Partial read of transformation_records/{transformationId}.
// Only fields needed by the Verified screen pipeline cards.
// Full document schema is defined in the verification system models.

import 'package:cloud_firestore/cloud_firestore.dart';

class TransformationStage {
  final bool confirmed;
  final DateTime? confirmedAt;

  const TransformationStage({
    required this.confirmed,
    this.confirmedAt,
  });

  factory TransformationStage.fromMap(Map<String, dynamic> map) {
    return TransformationStage(
      confirmed: (map['confirmed'] as bool?) ?? false,
      confirmedAt: (map['confirmedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'confirmed': confirmed,
        'confirmedAt':
            confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      };

  TransformationStage copyWith({
    bool? confirmed,
    DateTime? confirmedAt,
  }) {
    return TransformationStage(
      confirmed: confirmed ?? this.confirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}

class TransformationStage3 extends TransformationStage {
  final DateTime? followUpDueAt;
  final bool? siteHeld;
  final String? siteFailureReason;

  const TransformationStage3({
    required super.confirmed,
    super.confirmedAt,
    this.followUpDueAt,
    this.siteHeld,
    this.siteFailureReason,
  });

  factory TransformationStage3.fromMap(Map<String, dynamic> map) {
    return TransformationStage3(
      confirmed: (map['confirmed'] as bool?) ?? false,
      confirmedAt: (map['confirmedAt'] as Timestamp?)?.toDate(),
      followUpDueAt: (map['followUpDueAt'] as Timestamp?)?.toDate(),
      siteHeld: map['siteHeld'] as bool?,
      siteFailureReason: map['siteFailureReason'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'followUpDueAt': followUpDueAt != null
            ? Timestamp.fromDate(followUpDueAt!)
            : null,
        'siteHeld': siteHeld,
        'siteFailureReason': siteFailureReason,
      };

  @override
  TransformationStage3 copyWith({
    bool? confirmed,
    DateTime? confirmedAt,
    DateTime? followUpDueAt,
    bool? siteHeld,
    String? siteFailureReason,
  }) {
    return TransformationStage3(
      confirmed: confirmed ?? this.confirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      followUpDueAt: followUpDueAt ?? this.followUpDueAt,
      siteHeld: siteHeld ?? this.siteHeld,
      siteFailureReason: siteFailureReason ?? this.siteFailureReason,
    );
  }
}

class TransformationRecordSummary {
  final String transformationId;
  final String category;
  final String locationArea;
  final String? siteLabel;
  final DateTime? interventionDate;
  final TransformationStage stage1;
  final TransformationStage stage2;
  final TransformationStage3 stage3;
  final bool creditIssued;
  final String? creditId;

  const TransformationRecordSummary({
    required this.transformationId,
    required this.category,
    required this.locationArea,
    this.siteLabel,
    this.interventionDate,
    required this.stage1,
    required this.stage2,
    required this.stage3,
    required this.creditIssued,
    this.creditId,
  });

  factory TransformationRecordSummary.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final locationData =
        (data['location'] as Map<String, dynamic>?) ?? {};
    return TransformationRecordSummary(
      transformationId: doc.id,
      category: (data['category'] as String?) ?? '',
      locationArea: (locationData['area'] as String?) ?? '',
      siteLabel: locationData['siteLabel'] as String?,
      interventionDate: (data['interventionDate'] as Timestamp?)?.toDate(),
      stage1: TransformationStage.fromMap(
        (data['stage1'] as Map<String, dynamic>?) ?? {},
      ),
      stage2: TransformationStage.fromMap(
        (data['stage2'] as Map<String, dynamic>?) ?? {},
      ),
      stage3: TransformationStage3.fromMap(
        (data['stage3'] as Map<String, dynamic>?) ?? {},
      ),
      creditIssued: (data['creditIssued'] as bool?) ?? false,
      creditId: data['creditId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'category': category,
        'location': {
          'area': locationArea,
          'siteLabel': siteLabel,
        },
        'interventionDate': interventionDate != null
            ? Timestamp.fromDate(interventionDate!)
            : null,
        'stage1': stage1.toMap(),
        'stage2': stage2.toMap(),
        'stage3': stage3.toMap(),
        'creditIssued': creditIssued,
        'creditId': creditId,
      };

  TransformationRecordSummary copyWith({
    String? transformationId,
    String? category,
    String? locationArea,
    String? siteLabel,
    DateTime? interventionDate,
    TransformationStage? stage1,
    TransformationStage? stage2,
    TransformationStage3? stage3,
    bool? creditIssued,
    String? creditId,
  }) {
    return TransformationRecordSummary(
      transformationId: transformationId ?? this.transformationId,
      category: category ?? this.category,
      locationArea: locationArea ?? this.locationArea,
      siteLabel: siteLabel ?? this.siteLabel,
      interventionDate: interventionDate ?? this.interventionDate,
      stage1: stage1 ?? this.stage1,
      stage2: stage2 ?? this.stage2,
      stage3: stage3 ?? this.stage3,
      creditIssued: creditIssued ?? this.creditIssued,
      creditId: creditId ?? this.creditId,
    );
  }
}
