import 'package:cloud_firestore/cloud_firestore.dart';

/// CulturalEntry — represents an archive entry in the Heritage layer
class CulturalEntry {
  final String id;
  final String orgId;
  final String title;
  final String
      contentType; // Stories, Food, Music, Ceremony, Craft, Place, Language, Ingredients
  final String? subcategory;
  final String? description;
  final List<String> tags;
  final String visibility; // public, community, restricted, sealed
  final String? locality; // Community or region name
  final String? imageUrl; // Cover image
  final int commentCount;
  final int connectionCount;
  final bool hasActiveDispute;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  CulturalEntry({
    required this.id,
    required this.orgId,
    required this.title,
    required this.contentType,
    this.subcategory,
    this.description,
    this.tags = const [],
    required this.visibility,
    this.locality,
    this.imageUrl,
    this.commentCount = 0,
    this.connectionCount = 0,
    this.hasActiveDispute = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory CulturalEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CulturalEntry(
      id: doc.id,
      orgId: data['org_id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      contentType: data['content_type'] as String? ?? 'Stories',
      subcategory: data['subcategory'] as String?,
      description: data['description'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      visibility: data['visibility'] as String? ?? 'public',
      locality: data['locality'] as String?,
      imageUrl: data['image_url'] as String?,
      commentCount: data['comment_count'] as int? ?? 0,
      connectionCount: data['connection_count'] as int? ?? 0,
      hasActiveDispute: data['has_active_dispute'] as bool? ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['created_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'org_id': orgId,
      'title': title,
      'content_type': contentType,
      'subcategory': subcategory,
      'description': description,
      'tags': tags,
      'visibility': visibility,
      'locality': locality,
      'image_url': imageUrl,
      'comment_count': commentCount,
      'connection_count': connectionCount,
      'has_active_dispute': hasActiveDispute,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'created_by': createdBy,
    };
  }

  CulturalEntry copyWith({
    String? id,
    String? orgId,
    String? title,
    String? contentType,
    String? subcategory,
    String? description,
    List<String>? tags,
    String? visibility,
    String? locality,
    String? imageUrl,
    int? commentCount,
    int? connectionCount,
    bool? hasActiveDispute,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CulturalEntry(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      title: title ?? this.title,
      contentType: contentType ?? this.contentType,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      visibility: visibility ?? this.visibility,
      locality: locality ?? this.locality,
      imageUrl: imageUrl ?? this.imageUrl,
      commentCount: commentCount ?? this.commentCount,
      connectionCount: connectionCount ?? this.connectionCount,
      hasActiveDispute: hasActiveDispute ?? this.hasActiveDispute,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
