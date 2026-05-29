import 'dart:io';

import 'package:uuid/uuid.dart';

enum MediaUploadState { pending, uploading, uploaded, failed }

class MediaUploadItem {
  final String localId;
  final File file;
  final String mediaType; // 'image' or 'audio'
  final String mediaRole;
  final String? caption;
  final bool isPrimary;
  final MediaUploadState uploadState;
  final String? storageUrl;
  final String? storagePath;
  final String? errorMessage;
  final int? durationSeconds;
  final String? language;

  const MediaUploadItem({
    required this.localId,
    required this.file,
    required this.mediaType,
    required this.mediaRole,
    this.caption,
    this.isPrimary = false,
    this.uploadState = MediaUploadState.pending,
    this.storageUrl,
    this.storagePath,
    this.errorMessage,
    this.durationSeconds,
    this.language,
  });

  static String generateId() => const Uuid().v4();

  MediaUploadItem copyWith({
    String? localId,
    File? file,
    String? mediaType,
    String? mediaRole,
    String? caption,
    bool? isPrimary,
    MediaUploadState? uploadState,
    String? storageUrl,
    String? storagePath,
    String? errorMessage,
    int? durationSeconds,
    String? language,
  }) {
    return MediaUploadItem(
      localId: localId ?? this.localId,
      file: file ?? this.file,
      mediaType: mediaType ?? this.mediaType,
      mediaRole: mediaRole ?? this.mediaRole,
      caption: caption ?? this.caption,
      isPrimary: isPrimary ?? this.isPrimary,
      uploadState: uploadState ?? this.uploadState,
      storageUrl: storageUrl ?? this.storageUrl,
      storagePath: storagePath ?? this.storagePath,
      errorMessage: errorMessage ?? this.errorMessage,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      language: language ?? this.language,
    );
  }
}
