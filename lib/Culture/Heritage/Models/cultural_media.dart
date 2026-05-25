import 'package:cloud_firestore/cloud_firestore.dart';

/// CulturalMedia — image or audio media attached to archive entries
class CulturalMedia {
  final String id;
  final String orgId;
  final String entryId; // Primary entry this media belongs to
  final List<String> attachedEntryIds; // Can be attached to multiple entries
  final String mediaType; // 'image', 'audio'
  final String fileName;
  final String fileUrl;
  final String? caption;
  final String? languageCode; // For audio files
  final String
      mediaRole; // 'hero_image', 'process', 'artefact', 'context', etc.
  final int? durationSeconds; // For audio files
  final DateTime uploadedAt;
  final String uploadedBy;

  CulturalMedia({
    required this.id,
    required this.orgId,
    required this.entryId,
    this.attachedEntryIds = const [],
    required this.mediaType,
    required this.fileName,
    required this.fileUrl,
    this.caption,
    this.languageCode,
    required this.mediaRole,
    this.durationSeconds,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  factory CulturalMedia.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CulturalMedia(
      id: doc.id,
      orgId: data['org_id'] as String? ?? '',
      entryId: data['entry_id'] as String? ?? '',
      attachedEntryIds:
          List<String>.from(data['attached_entry_ids'] as List? ?? []),
      mediaType: data['media_type'] as String? ?? 'image',
      fileName: data['file_name'] as String? ?? '',
      fileUrl: data['file_url'] as String? ?? '',
      caption: data['caption'] as String?,
      languageCode: data['language_code'] as String?,
      mediaRole: data['media_role'] as String? ?? 'hero_image',
      durationSeconds: data['duration_seconds'] as int?,
      uploadedAt:
          (data['uploaded_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadedBy: data['uploaded_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'org_id': orgId,
      'entry_id': entryId,
      'attached_entry_ids': attachedEntryIds,
      'media_type': mediaType,
      'file_name': fileName,
      'file_url': fileUrl,
      'caption': caption,
      'language_code': languageCode,
      'media_role': mediaRole,
      'duration_seconds': durationSeconds,
      'uploaded_at': Timestamp.fromDate(uploadedAt),
      'uploaded_by': uploadedBy,
    };
  }

  CulturalMedia copyWith({
    String? id,
    String? orgId,
    String? entryId,
    List<String>? attachedEntryIds,
    String? mediaType,
    String? fileName,
    String? fileUrl,
    String? caption,
    String? languageCode,
    String? mediaRole,
    int? durationSeconds,
    DateTime? uploadedAt,
    String? uploadedBy,
  }) {
    return CulturalMedia(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      entryId: entryId ?? this.entryId,
      attachedEntryIds: attachedEntryIds ?? this.attachedEntryIds,
      mediaType: mediaType ?? this.mediaType,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      caption: caption ?? this.caption,
      languageCode: languageCode ?? this.languageCode,
      mediaRole: mediaRole ?? this.mediaRole,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }

  String get durationString {
    if (durationSeconds == null) return '';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
