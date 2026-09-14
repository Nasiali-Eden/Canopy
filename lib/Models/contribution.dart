import 'package:cloud_firestore/cloud_firestore.dart';

class Contribution {
  final String id;
  final String userId;
  final String? activityId;
  final String type;
  final double? hours;
  final String? effort;
  final List<String> materials;
  final String? notes;
  final List<String> photoUrls;
  final int estimatedImpactPoints;
  final bool isVerified;
  final DateTime? createdAt;

  const Contribution({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.type,
    required this.hours,
    required this.effort,
    required this.materials,
    required this.notes,
    required this.photoUrls,
    required this.estimatedImpactPoints,
    this.isVerified = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'activityId': activityId,
      'type': type,
      'hours': hours,
      'effort': effort,
      'materials': materials,
      'notes': notes,
      'photoUrls': photoUrls,
      'estimatedImpactPoints': estimatedImpactPoints,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Contribution fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? _toDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return Contribution(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      activityId: data['activityId'] as String?,
      type: (data['type'] ?? 'Time') as String,
      hours: (data['hours'] as num?)?.toDouble(),
      effort: data['effort'] as String?,
      materials: (data['materials'] as List?)?.cast<String>() ?? const [],
      notes: data['notes'] as String?,
      photoUrls: (data['photoUrls'] as List?)?.cast<String>() ?? const [],
      estimatedImpactPoints:
          ((data['estimatedImpactPoints'] ?? data['points'] ?? 0) as num)
              .toInt(),
      isVerified: data['status'] == 'verified' &&
          data['scoringVersion'] == 1 &&
          data['deleted'] != true,
      createdAt: _toDate(data['createdAt']),
    );
  }
}
