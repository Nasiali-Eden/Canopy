// lib/Culture/Heritage/Create/create_entry_provider.dart
//
// State for the six-step creator (ARCHIVE_HANDOFF §3.2). Autosaves at every
// step: the entry lives in cultural_entries with visibility 'draft' (so the
// public Heritage queries never see it) and the chosen level parked in
// intended_visibility. Uploaded media ride along on the draft as
// draft_media until publish writes real cultural_media docs. A draft can be
// resumed from the Archive, published, or discarded.

import 'dart:async';
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
    String? communityId,
    String? communityName,
    bool? communityUnknown,
    String? localityNotes,
    bool clearCommunity = false,
  }) {
    return LocalityModel(
      countryId: countryId ?? this.countryId,
      regionId: regionId,
      countyId: countyId,
      communityId: clearCommunity ? null : (communityId ?? this.communityId),
      communityName: clearCommunity ? null : (communityName ?? this.communityName),
      communityUnknown: communityUnknown ?? this.communityUnknown,
      subGroupId: subGroupId,
      localityNotes: localityNotes ?? this.localityNotes,
    );
  }

  Map<String, dynamic> toMap() => {
        'country_id': countryId,
        'region_id': regionId,
        'county_id': countyId,
        'community_id': communityId,
        'community_name': communityName,
        'community_unknown': communityUnknown,
        'sub_group_id': subGroupId,
        'locality_notes': localityNotes,
      };

  factory LocalityModel.fromMap(Map<String, dynamic>? m) => m == null
      ? const LocalityModel()
      : LocalityModel(
          countryId: m['country_id'] as String? ?? 'country_kenya',
          regionId: m['region_id'] as String?,
          countyId: m['county_id'] as String?,
          communityId: m['community_id'] as String?,
          communityName: m['community_name'] as String?,
          communityUnknown: m['community_unknown'] as bool? ?? false,
          subGroupId: m['sub_group_id'] as String?,
          localityNotes: m['locality_notes'] as String?,
        );
}

class CreateEntryProvider extends ChangeNotifier {
  final String orgId;
  CreateEntryProvider({required this.orgId, String? draftId}) : _draftId = draftId;

  final _db = FirebaseFirestore.instance;
  String? _draftId;
  Timer? _debounce;
  bool _loadingDraft = false;
  DateTime? _savedAt;
  bool _saveFailed = false;

  int _currentStep = 0;
  String? _contentType;
  LocalityModel _locality = const LocalityModel();
  double? _mapLat, _mapLng; // where this is; required before leaving the place step
  String _title = '', _titleEnglish = '', _titleSwahili = '', _primaryLanguage = '';
  String _description = '';
  Map<String, dynamic> _typeData = {};
  List<MediaUploadItem> _media = [];
  String _visibility = 'public';
  String? _visibilityReason;
  bool _seekingContributors = false;
  bool _consent = false;
  bool _submitting = false;
  String? _submitError;

  String? get draftId => _draftId;
  bool get loadingDraft => _loadingDraft;
  DateTime? get savedAt => _savedAt;
  bool get saveFailed => _saveFailed;
  bool get hasContent => _contentType != null || _title.trim().isNotEmpty || _media.isNotEmpty;
  int get currentStep => _currentStep;
  String? get selectedContentType => _contentType;
  LocalityModel get locality => _locality;
  ({double lat, double lng})? get mapPoint => _mapLat == null || _mapLng == null ? null : (lat: _mapLat!, lng: _mapLng!);

  void setMapPoint(double lat, double lng) {
    _mapLat = lat;
    _mapLng = lng;
    _changed();
  }
  String get title => _title;
  String get titleEnglish => _titleEnglish;
  String get titleSwahili => _titleSwahili;
  String get primaryLanguage => _primaryLanguage;
  String get description => _description;
  Map<String, dynamic> get typeData => Map.unmodifiable(_typeData);
  List<MediaUploadItem> get mediaFiles => List.unmodifiable(_media);
  String get visibility => _visibility;
  String? get visibilityReason => _visibilityReason;
  bool get isSeekingContributors => _seekingContributors;
  bool get consentChecked => _consent;
  bool get isSubmitting => _submitting;
  String? get submitError => _submitError;
  bool get hasUploadingFiles => _media.any((m) => m.uploadState == MediaUploadState.uploading);
  List<MediaUploadItem> get uncredited =>
      _media.where((m) => m.uploadState == MediaUploadState.uploaded && (m.credit ?? '').trim().isEmpty).toList();
  bool get isPersonType => _contentType == 'person';

  // ── Draft persistence ────────────────────────────────────────────────────

  Future<void> loadDraft() async {
    final id = _draftId;
    if (id == null) {
      // New entry: start from the archive's default visibility, if set.
      try {
        final org = (await _db.collection('organizations').doc(orgId).get()).data();
        final v = org?['archive_default_visibility'] as String?;
        if (v != null && v.isNotEmpty) {
          _visibility = v;
          notifyListeners();
        }
      } catch (_) {}
      return;
    }
    _loadingDraft = true;
    notifyListeners();
    try {
      final d = (await _db.collection('cultural_entries').doc(id).get()).data() ?? {};
      _contentType = d['content_type'] as String?;
      _locality = LocalityModel.fromMap((d['locality'] as Map?)?.cast<String, dynamic>());
      final mp = d['map_point'];
      if (mp is GeoPoint) {
        _mapLat = mp.latitude;
        _mapLng = mp.longitude;
      }
      _title = d['title'] as String? ?? '';
      _titleEnglish = d['title_english'] as String? ?? '';
      _titleSwahili = d['title_swahili'] as String? ?? '';
      _primaryLanguage = d['primary_language'] as String? ?? '';
      _description = d['description'] as String? ?? '';
      _typeData = Map<String, dynamic>.from((d['type_data'] as Map?) ?? {});
      _visibility = d['intended_visibility'] as String? ?? 'public';
      _visibilityReason = d['visibility_reason'] as String?;
      _seekingContributors = d['is_seeking_contributors'] as bool? ?? false;
      _consent = d['consent_on_file'] as bool? ?? false;
      _currentStep = ((d['draft_step'] as num?)?.toInt() ?? 0).clamp(0, 5);
      _media = [
        for (final m in (d['draft_media'] as List? ?? const []))
          if (m is Map) MediaUploadItem.fromDraftMap(m.cast<String, dynamic>()),
      ];
      _savedAt = (d['updated_at'] as Timestamp?)?.toDate();
    } catch (_) {
      _saveFailed = true;
    }
    _loadingDraft = false;
    notifyListeners();
  }

  Map<String, dynamic> _entryFields() {
    String? nz(String s) => s.trim().isEmpty ? null : s.trim();
    return {
      'content_type': _contentType,
      'org_id': orgId,
      'title': _title.trim(),
      'title_english': nz(_titleEnglish),
      'title_swahili': nz(_titleSwahili),
      'primary_language': nz(_primaryLanguage),
      'locality': _locality.toMap(),
      if (_mapLat != null && _mapLng != null) 'map_point': GeoPoint(_mapLat!, _mapLng!),
      'description': _description.trim(),
      'visibility_reason': _visibilityReason,
      'is_seeking_contributors': _seekingContributors,
      'consent_on_file': _consent,
      'type_data': _typeData,
      'tags': const <String>[],
    };
  }

  void _changed() {
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), saveDraft);
  }

  /// Writes the draft now. Nothing is created until there's a type or title.
  Future<void> saveDraft() async {
    _debounce?.cancel();
    if (!hasContent || _submitting) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final ref = _draftId == null ? _db.collection('cultural_entries').doc() : _db.collection('cultural_entries').doc(_draftId);
      final now = Timestamp.now();
      await ref.set({
        ..._entryFields(),
        'visibility': 'draft',
        'intended_visibility': _visibility,
        'draft_step': _currentStep,
        'draft_media': [for (final m in _media.where((m) => m.uploadState == MediaUploadState.uploaded)) m.toDraftMap()],
        'created_by_uid': uid,
        'updated_at': now,
        if (_draftId == null) 'created_at': now,
      }, SetOptions(merge: true));
      _draftId = ref.id;
      _savedAt = DateTime.now();
      _saveFailed = false;
    } catch (_) {
      _saveFailed = true;
    }
    notifyListeners();
  }

  Future<void> discardDraft() async {
    _debounce?.cancel();
    final id = _draftId;
    if (id == null) return;
    try {
      await _db.collection('cultural_entries').doc(id).delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  void setContentType(String type) {
    if (_contentType != type) _typeData = {};
    _contentType = type;
    _changed();
  }

  void setCommunity(String? id, String? name) {
    _locality = _locality.copyWith(communityId: id, communityName: name, communityUnknown: false);
    _changed();
  }

  void setCommunityUnknown(bool value) {
    _locality = _locality.copyWith(communityUnknown: value, clearCommunity: value);
    _changed();
  }

  void setLocalityNotes(String v) {
    _locality = _locality.copyWith(localityNotes: v);
    _changed();
  }

  void setCountryId(String countryId) {
    _locality = _locality.copyWith(countryId: countryId, communityUnknown: false, clearCommunity: true);
    _changed();
  }

  void setTitle(String v) {
    _title = v;
    _changed();
  }
  void setTitleEnglish(String v) {
    _titleEnglish = v;
    _changed();
  }
  void setTitleSwahili(String v) {
    _titleSwahili = v;
    _changed();
  }
  void setPrimaryLanguage(String v) {
    _primaryLanguage = v;
    _changed();
  }
  void setDescription(String v) {
    _description = v;
    _changed();
  }

  void setTypeDataField(String key, dynamic value) {
    _typeData = {..._typeData, key: value};
    _changed();
  }

  void setVisibility(String v) {
    _visibility = v;
    _changed();
  }

  void setVisibilityReason(String? v) {
    _visibilityReason = (v ?? '').trim().isEmpty ? null : v;
    _changed();
  }

  void setIsSeekingContributors(bool v) {
    _seekingContributors = v;
    _changed();
  }
  void setConsentChecked(bool v) {
    _consent = v;
    _changed();
  }

  void goToStep(int step) {
    _currentStep = step.clamp(0, 5);
    _changed();
  }

  /// Why the step can't be left yet, or null.
  String? blockerFor(int step) {
    switch (step) {
      case 0:
        return _contentType == null ? 'Choose what kind of knowledge this is.' : null;
      case 1:
        return (_mapLat == null || _mapLng == null) ? 'Pin where this is on the map.' : null;
      case 2:
        return _title.trim().isEmpty ? 'Give the entry a name.' : null;
      case 3:
        if (_description.trim().length < 50) return 'Describe it in a few sentences (at least 50 characters).';
        if ((_typeData['subcategory'] as String?)?.isNotEmpty != true) return 'Choose a subcategory.';
        if (isPersonType && !_consent) return 'Confirm they agreed to be documented and named.';
        return null;
      case 4:
        if (hasUploadingFiles) return 'Wait for uploads to finish.';
        if (uncredited.isNotEmpty) return 'Add a credit to every photo and recording.';
        return null;
      default:
        return null;
    }
  }

  // ── Media ────────────────────────────────────────────────────────────────

  Future<void> addMediaFile(File file, String mediaType, String defaultRole) async {
    final item = MediaUploadItem(
      localId: MediaUploadItem.generateId(),
      file: file,
      mediaType: mediaType,
      mediaRole: defaultRole,
      uploadState: MediaUploadState.uploading,
      isPrimary: !_media.any((m) => m.mediaType == mediaType),
    );
    _media = [..._media, item];
    notifyListeners();
    await _upload(item.localId);
  }

  Future<void> retryUpload(String localId) => _upload(localId);

  Future<void> _upload(String localId) async {
    final item = _media.firstWhere((m) => m.localId == localId);
    final file = item.file;
    if (file == null) return;
    _update(localId, (m) => m.copyWith(uploadState: MediaUploadState.uploading, progress: 0));
    try {
      final safe = file.path.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'cultural_media/$orgId/pending/${const Uuid().v4()}_$safe';
      final task = FirebaseStorage.instance.ref(path).putFile(file);
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) _update(localId, (m) => m.copyWith(progress: s.bytesTransferred / s.totalBytes));
      });
      final snap = await task;
      await sub.cancel();
      final url = await snap.ref.getDownloadURL();
      _update(localId, (m) => m.copyWith(uploadState: MediaUploadState.uploaded, progress: 1, storageUrl: url, storagePath: path));
      _changed();
    } catch (e) {
      _update(localId, (m) => m.copyWith(uploadState: MediaUploadState.failed, errorMessage: "Couldn't upload"));
    }
  }

  void _update(String localId, MediaUploadItem Function(MediaUploadItem) f) {
    _media = [for (final m in _media) m.localId == localId ? f(m) : m];
    notifyListeners();
  }

  void removeMediaFile(String localId) {
    final removed = _media.firstWhere((m) => m.localId == localId);
    _media = _media.where((m) => m.localId != localId).toList();
    if (removed.isPrimary) {
      final same = _media.where((m) => m.mediaType == removed.mediaType).toList();
      if (same.isNotEmpty) _media = [for (final m in _media) m.localId == same.first.localId ? m.copyWith(isPrimary: true) : m];
    }
    _changed();
  }

  void setMediaPrimary(String localId) {
    final type = _media.firstWhere((m) => m.localId == localId).mediaType;
    _media = [for (final m in _media) m.mediaType == type ? m.copyWith(isPrimary: m.localId == localId) : m];
    _changed();
  }

  void setMediaRole(String localId, String role) {
    _update(localId, (m) => m.copyWith(mediaRole: role));
    _changed();
  }
  void setMediaCaption(String localId, String caption) {
    _update(localId, (m) => m.copyWith(caption: caption));
    _changed();
  }
  void setMediaCredit(String localId, String credit) {
    _update(localId, (m) => m.copyWith(credit: credit));
    _changed();
  }

  // ── Publish ──────────────────────────────────────────────────────────────

  Future<void> submit() async {
    _debounce?.cancel();
    _submitting = true;
    _submitError = null;
    notifyListeners();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final entryRef = _draftId == null ? _db.collection('cultural_entries').doc() : _db.collection('cultural_entries').doc(_draftId);
      final now = Timestamp.now();
      final batch = _db.batch();
      String? coverUrl, coverId;
      final uploaded = _media.where((m) => m.uploadState == MediaUploadState.uploaded && m.storageUrl != null).toList();
      for (final m in uploaded) {
        final ref = _db.collection('cultural_media').doc();
        if (m.isPrimary && m.mediaType == 'image') {
          coverUrl = m.storageUrl;
          coverId = ref.id;
        }
        batch.set(ref, {
          'entry_id': entryRef.id,
          'org_id': orgId,
          'uploaded_by_uid': uid,
          'media_type': m.mediaType,
          'mime_type': m.mediaType == 'image' ? 'image/jpeg' : 'audio/mpeg',
          'media_role': m.mediaRole,
          'storage_url': m.storageUrl,
          'storage_path': m.storagePath,
          'filename': m.filename,
          'file_size_bytes': m.file?.existsSync() == true ? m.file!.lengthSync() : null,
          'duration_seconds': m.durationSeconds,
          'caption': m.caption,
          'credit': m.credit,
          'language': m.language,
          'is_primary': m.isPrimary,
          'consent_on_file': _consent,
          'visibility': 'inherits_from_entry',
          'created_at': now,
        });
      }
      batch.set(entryRef, {
        ..._entryFields(),
        'visibility': _visibility,
        'intended_visibility': FieldValue.delete(),
        'draft_step': FieldValue.delete(),
        'draft_media': FieldValue.delete(),
        'created_by_uid': uid,
        'is_endangered': _typeData['is_endangered'] == true,
        'is_contested': false,
        'has_active_dispute': false,
        'version_count': 1,
        'cover_image_url': coverUrl,
        'cover_image_media_id': coverId,
        'media_count': uploaded.length,
        'relation_count': 0,
        'comment_count': 0,
        'view_count': 0,
        if (_draftId == null) 'created_at': now,
        'published_at': now,
        'updated_at': now,
        'last_activity_at': now,
      }, SetOptions(merge: true));
      await batch.commit();
      _draftId = entryRef.id;
    } catch (e) {
      _submitError = "Couldn't add the entry. It's still saved as a draft — try again.";
    }
    _submitting = false;
    notifyListeners();
  }
}
