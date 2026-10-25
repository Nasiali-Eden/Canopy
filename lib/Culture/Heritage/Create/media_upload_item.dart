import 'dart:io';

import 'package:uuid/uuid.dart';

enum MediaUploadState { pending, uploading, uploaded, failed }

/// One image or audio file in the creator. [file] is null for media that
/// came back with a resumed draft (already uploaded — only [storageUrl]).
class MediaUploadItem {
  final String localId;
  final File? file;
  final String mediaType; // 'image' or 'audio'
  final String mediaRole;
  final String? caption;

  /// Who made the photo / recording. Required before publishing.
  final String? credit;
  final bool isPrimary;
  final MediaUploadState uploadState;
  final double progress; // 0–1 while uploading
  final String? storageUrl;
  final String? storagePath;
  final String? errorMessage;
  final int? durationSeconds;
  final String? language;

  const MediaUploadItem({
    required this.localId,
    this.file,
    required this.mediaType,
    required this.mediaRole,
    this.caption,
    this.credit,
    this.isPrimary = false,
    this.uploadState = MediaUploadState.pending,
    this.progress = 0,
    this.storageUrl,
    this.storagePath,
    this.errorMessage,
    this.durationSeconds,
    this.language,
  });

  static String generateId() => const Uuid().v4();

  String get filename => (file?.path ?? storagePath ?? '').split('/').last;

  Map<String, dynamic> toDraftMap() => {
        'local_id': localId,
        'media_type': mediaType,
        'media_role': mediaRole,
        'caption': caption,
        'credit': credit,
        'is_primary': isPrimary,
        'storage_url': storageUrl,
        'storage_path': storagePath,
        'duration_seconds': durationSeconds,
        'language': language,
      };

  factory MediaUploadItem.fromDraftMap(Map<String, dynamic> m) => MediaUploadItem(
        localId: m['local_id'] as String? ?? generateId(),
        mediaType: m['media_type'] as String? ?? 'image',
        mediaRole: m['media_role'] as String? ?? 'illustration',
        caption: m['caption'] as String?,
        credit: m['credit'] as String?,
        isPrimary: m['is_primary'] as bool? ?? false,
        uploadState: MediaUploadState.uploaded,
        progress: 1,
        storageUrl: m['storage_url'] as String?,
        storagePath: m['storage_path'] as String?,
        durationSeconds: (m['duration_seconds'] as num?)?.toInt(),
        language: m['language'] as String?,
      );

  MediaUploadItem copyWith({
    String? mediaRole,
    String? caption,
    String? credit,
    bool? isPrimary,
    MediaUploadState? uploadState,
    double? progress,
    String? storageUrl,
    String? storagePath,
    String? errorMessage,
  }) {
    return MediaUploadItem(
      localId: localId,
      file: file,
      mediaType: mediaType,
      mediaRole: mediaRole ?? this.mediaRole,
      caption: caption ?? this.caption,
      credit: credit ?? this.credit,
      isPrimary: isPrimary ?? this.isPrimary,
      uploadState: uploadState ?? this.uploadState,
      progress: progress ?? this.progress,
      storageUrl: storageUrl ?? this.storageUrl,
      storagePath: storagePath ?? this.storagePath,
      errorMessage: errorMessage,
      durationSeconds: durationSeconds,
      language: language,
    );
  }
}
