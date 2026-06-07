import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'media_upload_item.dart';

class LocalityModel {
  final String countryId;
  final String? regionId;
  final String? countyId;
  final String? communityId;
  final String? communityName;
  final bool communityUnknown;
  final String? subGroupId;
  final String? localityNotes;

  const LocalityModel({
    this.countryId = 'country_kenya',
    this.regionId,
    this.countyId,
    this.communityId,
    this.communityName,
    this.communityUnknown = false,
    this.subGroupId,
    this.localityNotes,
  });

  LocalityModel copyWith({
    String? countryId,
    String? regionId,
    String? countyId,
    String? communityId,
    String? communityName,
    bool? communityUnknown,
    String? subGroupId,
    String? localityNotes,
  }) {
    return LocalityModel(
      countryId: countryId ?? this.countryId,
      regionId: regionId ?? this.regionId,
      countyId: countyId ?? this.countyId,
      communityId: communityId ?? this.communityId,
      communityName: communityName ?? this.communityName,
      communityUnknown: communityUnknown ?? this.communityUnknown,
      subGroupId: subGroupId ?? this.subGroupId,
      localityNotes: localityNotes ?? this.localityNotes,
    );
  }

  Map<String, dynamic> toMap() => {
        'country_id': countryId,
        'region_id': regionId,
        'county_id': countyId,
        'community_id': communityId,
        'community_unknown': communityUnknown,
        'sub_group_id': subGroupId,
        'locality_notes': localityNotes,
      };
}

class CreateEntryProvider extends ChangeNotifier {
  final String orgId;

  CreateEntryProvider({required this.orgId});

  int _currentStep = 0;
  String? _selectedContentType;
  LocalityModel _locality = const LocalityModel();
  String _title = '';
  String _titleSwahili = '';
  String _titleEnglish = '';
  String _primaryLanguage = '';
  String _description = '';
  String _descriptionSwahili = '';
  String _descriptionEnglish = '';
  Map<String, dynamic> _typeData = {};
  List<MediaUploadItem> _mediaFiles = [];
  String _visibility = 'public';
  String? _visibilityReason;
  bool _isSeekingContributors = false;
  bool _consentChecked = false;
  bool _isSubmitting = false;
  String? _submitError;

  int get currentStep => _currentStep;
  String? get selectedContentType => _selectedContentType;
  LocalityModel get locality => _locality;
  String get title => _title;
  String get titleSwahili => _titleSwahili;
  String get titleEnglish => _titleEnglish;
  String get primaryLanguage => _primaryLanguage;
  String get description => _description;
  String get descriptionSwahili => _descriptionSwahili;
  String get descriptionEnglish => _descriptionEnglish;
  Map<String, dynamic> get typeData => Map.unmodifiable(_typeData);
  List<MediaUploadItem> get mediaFiles => List.unmodifiable(_mediaFiles);
  String get visibility => _visibility;
  String? get visibilityReason => _visibilityReason;
  bool get isSeekingContributors => _isSeekingContributors;
  bool get consentChecked => _consentChecked;
  bool get isSubmitting => _isSubmitting;
  String? get submitError => _submitError;

  bool get hasUploadingFiles =>
      _mediaFiles.any((m) => m.uploadState == MediaUploadState.uploading);

  void setContentType(String type) {
    _selectedContentType = type;
    _typeData = {};
    notifyListeners();
  }

  void setCommunity(String? id, String? name) {
    _locality = _locality.copyWith(communityId: id, communityName: name, communityUnknown: false);
    notifyListeners();
  }

  void setCommunityUnknown(bool value) {
    _locality = _locality.copyWith(
      communityUnknown: value,
      communityId: value ? null : _locality.communityId,
      communityName: value ? null : _locality.communityName,
    );
    notifyListeners();
  }

  void setLocalityNotes(String v) {
    _locality = _locality.copyWith(localityNotes: v.isEmpty ? null : v);
    notifyListeners();
  }

  void setCountryId(String countryId) {
    _locality = _locality.copyWith(
      countryId: countryId,
      // Reset community when country changes
      communityId: null,
      communityName: null,
      communityUnknown: false,
    );
    notifyListeners();
  }

  void setTitle(String v) {
    _title = v;
    notifyListeners();
  }

  void setTitleSwahili(String v) {
    _titleSwahili = v;
    notifyListeners();
  }

  void setTitleEnglish(String v) {
    _titleEnglish = v;
    notifyListeners();
  }

  void setPrimaryLanguage(String v) {
    _primaryLanguage = v;
    notifyListeners();
  }

  void setDescription(String v) {
    _description = v;
    notifyListeners();
  }

  void setDescriptionSwahili(String v) {
    _descriptionSwahili = v;
    notifyListeners();
  }

  void setDescriptionEnglish(String v) {
    _descriptionEnglish = v;
    notifyListeners();
  }

  void setTypeDataField(String key, dynamic value) {
    _typeData = {..._typeData, key: value};
    notifyListeners();
  }

  void setVisibility(String v) {
    _visibility = v;
    if (v == 'public' || v == 'community_only') _visibilityReason = null;
    notifyListeners();
  }

  void setVisibilityReason(String? v) {
    _visibilityReason = v?.isEmpty == true ? null : v;
    notifyListeners();
  }

  void setIsSeekingContributors(bool v) {
    _isSeekingContributors = v;
    notifyListeners();
  }

  void setConsentChecked(bool v) {
    _consentChecked = v;
    notifyListeners();
  }

  void goToStep(int step) {
    _currentStep = step.clamp(0, 5);
    notifyListeners();
  }

  bool canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _selectedContentType != null;
      case 1:
        return true;
      case 2:
        return _title.trim().isNotEmpty;
      case 3:
        return _description.trim().length >= 50 &&
            (_typeData['subcategory'] as String?)?.isNotEmpty == true;
      case 4:
        return true;
      case 5:
        return _consentChecked;
      default:
        return false;
    }
  }

  Future<void> addMediaFile(File file, String mediaType, String defaultRole) async {
    final localId = MediaUploadItem.generateId();
    final isFirstOfType = !_mediaFiles.any((m) => m.mediaType == mediaType);

    final item = MediaUploadItem(
      localId: localId,
      file: file,
      mediaType: mediaType,
      mediaRole: defaultRole,
      uploadState: MediaUploadState.uploading,
      isPrimary: isFirstOfType,
    );

    _mediaFiles = [..._mediaFiles, item];
    notifyListeners();

    try {
      final filename = '${const Uuid().v4()}_${file.path.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      final storagePath = 'cultural_media/$orgId/pending/$filename';
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      _mediaFiles = _mediaFiles.map((m) {
        if (m.localId != localId) return m;
        return m.copyWith(
          uploadState: MediaUploadState.uploaded,
          storageUrl: url,
          storagePath: storagePath,
        );
      }).toList();
    } catch (e) {
      _mediaFiles = _mediaFiles.map((m) {
        if (m.localId != localId) return m;
        return m.copyWith(
          uploadState: MediaUploadState.failed,
          errorMessage: e.toString(),
        );
      }).toList();
    }

    notifyListeners();
  }

  void removeMediaFile(String localId) {
    final removed = _mediaFiles.firstWhere((m) => m.localId == localId, orElse: () => _mediaFiles.first);
    _mediaFiles = _mediaFiles.where((m) => m.localId != localId).toList();
    if (removed.isPrimary && _mediaFiles.isNotEmpty) {
      final sameType = _mediaFiles.where((m) => m.mediaType == removed.mediaType).toList();
      if (sameType.isNotEmpty) {
        final first = sameType.first;
        _mediaFiles = _mediaFiles.map((m) {
          if (m.localId == first.localId) return m.copyWith(isPrimary: true);
          return m;
        }).toList();
      }
    }
    notifyListeners();
  }

  void setMediaPrimary(String localId) {
    final targetType = _mediaFiles.firstWhere((m) => m.localId == localId).mediaType;
    _mediaFiles = _mediaFiles.map((m) {
      if (m.mediaType != targetType) return m;
      return m.copyWith(isPrimary: m.localId == localId);
    }).toList();
    notifyListeners();
  }

  void setMediaRole(String localId, String role) {
    _mediaFiles = _mediaFiles.map((m) {
      if (m.localId != localId) return m;
      return m.copyWith(mediaRole: role);
    }).toList();
    notifyListeners();
  }

  void setMediaCaption(String localId, String caption) {
    _mediaFiles = _mediaFiles.map((m) {
      if (m.localId != localId) return m;
      return m.copyWith(caption: caption.isEmpty ? null : caption);
    }).toList();
    notifyListeners();
  }

  Future<void> submit() async {
    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final entryRef = FirebaseFirestore.instance.collection('cultural_entries').doc();
      final entryId = entryRef.id;
      final now = Timestamp.now();

      final batch = FirebaseFirestore.instance.batch();

      String? coverImageUrl;
      String? coverImageMediaId;

      final uploadedMedia = _mediaFiles.where((m) => m.uploadState == MediaUploadState.uploaded && m.storageUrl != null).toList();

      for (final item in uploadedMedia) {
        final mediaRef = FirebaseFirestore.instance.collection('cultural_media').doc();
        if (item.isPrimary && item.mediaType == 'image') {
          coverImageUrl = item.storageUrl;
          coverImageMediaId = mediaRef.id;
        }

        batch.set(mediaRef, {
          'entry_id': entryId,
          'org_id': orgId,
          'uploaded_by_uid': uid,
          'media_type': item.mediaType,
          'mime_type': item.mediaType == 'image' ? 'image/jpeg' : 'audio/mpeg',
          'media_role': item.mediaRole,
          'storage_url': item.storageUrl,
          'storage_path': item.storagePath,
          'thumbnail_url': null,
          'filename': item.file.path.split('/').last,
          'file_size_bytes': item.file.lengthSync(),
          'duration_seconds': item.durationSeconds,
          'width_px': null,
          'height_px': null,
          'caption': item.caption,
          'caption_english': null,
          'language': item.language,
          'is_primary': item.isPrimary,
          'subject_notes': null,
          'consent_on_file': _consentChecked,
          'location_lat': null,
          'location_lng': null,
          'recorded_date': null,
          'visibility': 'inherits_from_entry',
          'created_at': now,
          'updated_at': null,
        });
      }

      batch.set(entryRef, {
        'content_type': _selectedContentType,
        'org_id': orgId,
        'created_by_uid': uid,
        'title': _title.trim(),
        'title_swahili': _titleSwahili.trim().isEmpty ? null : _titleSwahili.trim(),
        'title_english': _titleEnglish.trim().isEmpty ? null : _titleEnglish.trim(),
        'locality': _locality.toMap(),
        'primary_language': _primaryLanguage.trim().isEmpty ? null : _primaryLanguage.trim(),
        'languages_present': null,
        'description': _description.trim(),
        'description_swahili': _descriptionSwahili.trim().isEmpty ? null : _descriptionSwahili.trim(),
        'description_english': _descriptionEnglish.trim().isEmpty ? null : _descriptionEnglish.trim(),
        'visibility': _visibility,
        'visibility_reason': _visibilityReason,
        'tags': const <String>[],
        'is_seeking_contributors': _isSeekingContributors,
        'is_endangered': false,
        'is_contested': false,
        'has_active_dispute': false,
        'version_count': 1,
        'on_chain_ref': null,
        'cover_image_url': coverImageUrl,
        'cover_image_media_id': coverImageMediaId,
        'media_count': uploadedMedia.length,
        'relation_count': 0,
        'comment_count': 0,
        'view_count': 0,
        'created_at': now,
        'updated_at': now,
        'last_activity_at': now,
        'type_data': _typeData,
      });

      await batch.commit();

      _isSubmitting = false;
      _submitError = null;
      notifyListeners();
    } catch (e) {
      _isSubmitting = false;
      _submitError = e.toString();
      notifyListeners();
    }
  }
}
