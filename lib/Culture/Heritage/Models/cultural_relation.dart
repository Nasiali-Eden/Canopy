import 'package:cloud_firestore/cloud_firestore.dart';

/// CulturalRelation — relationship/connection between two cultural entries
class CulturalRelation {
  final String id;
  final String fromEntryId;
  final String toEntryId;
  final String
      relationshipType; // e.g., 'inspired_by', 'related_to', 'influenced', etc.
  final String status; // 'suggested', 'confirmed', 'rejected'
  final String source; // 'ai', 'community_member', 'org'
  final String? suggestedByName; // Name if community member suggested
  final String? confirmedByName; // Council member name if confirmed
  final DateTime? confirmedAt;
  final String? endorsingOrgId; // For suggested relations
  final bool orgEndorsed; // Whether the org has endorsed this suggestion
  final DateTime createdAt;

  CulturalRelation({
    required this.id,
    required this.fromEntryId,
    required this.toEntryId,
    required this.relationshipType,
    required this.status,
    required this.source,
    this.suggestedByName,
    this.confirmedByName,
    this.confirmedAt,
    this.endorsingOrgId,
    this.orgEndorsed = false,
    required this.createdAt,
  });

  factory CulturalRelation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CulturalRelation(
      id: doc.id,
      fromEntryId: data['from_entry_id'] as String? ?? '',
      toEntryId: data['to_entry_id'] as String? ?? '',
      relationshipType: data['relationship_type'] as String? ?? '',
      status: data['status'] as String? ?? 'suggested',
      source: data['source'] as String? ?? 'ai',
      suggestedByName: data['suggested_by_name'] as String?,
      confirmedByName: data['confirmed_by_name'] as String?,
      confirmedAt: (data['confirmed_at'] as Timestamp?)?.toDate(),
      endorsingOrgId: data['endorsing_org_id'] as String?,
      orgEndorsed: data['org_endorsed'] as bool? ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'from_entry_id': fromEntryId,
      'to_entry_id': toEntryId,
      'relationship_type': relationshipType,
      'status': status,
      'source': source,
      'suggested_by_name': suggestedByName,
      'confirmed_by_name': confirmedByName,
      'confirmed_at':
          confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'endorsing_org_id': endorsingOrgId,
      'org_endorsed': orgEndorsed,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  CulturalRelation copyWith({
    String? id,
    String? fromEntryId,
    String? toEntryId,
    String? relationshipType,
    String? status,
    String? source,
    String? suggestedByName,
    String? confirmedByName,
    DateTime? confirmedAt,
    String? endorsingOrgId,
    bool? orgEndorsed,
    DateTime? createdAt,
  }) {
    return CulturalRelation(
      id: id ?? this.id,
      fromEntryId: fromEntryId ?? this.fromEntryId,
      toEntryId: toEntryId ?? this.toEntryId,
      relationshipType: relationshipType ?? this.relationshipType,
      status: status ?? this.status,
      source: source ?? this.source,
      suggestedByName: suggestedByName ?? this.suggestedByName,
      confirmedByName: confirmedByName ?? this.confirmedByName,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      endorsingOrgId: endorsingOrgId ?? this.endorsingOrgId,
      orgEndorsed: orgEndorsed ?? this.orgEndorsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
