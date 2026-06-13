// lib/Culture/Heritage/Services/heritage_data_service.dart
//
// Phase 1 — the data backbone for the community-facing Heritage experience.
//
// Reads the CANONICAL entries collection `cultural_entries` (the collection the
// Create flow writes to and the Archive/Profile read). The legacy
// `heritage_entries` collection has no writer and is being retired; all
// community-facing reads go through this service.
//
// Backend ⇄ frontend parity: every stream reflects exactly what Firestore holds.
// There are no fallbacks, no sample data. Empty streams surface as empty lists
// and the UI shows an elegant empty state.
//
// ── Firestore schema this service relies on (written by CreateEntryProvider) ──
//   cultural_entries/{id}:
//     content_type   : String   (taxonomy KEY, e.g. 'oral_tradition')
//     org_id         : String
//     created_by_uid : String
//     title          : String
//     description     : String
//     visibility     : String   ('public' | 'community' | 'restricted' | 'sealed')
//     locality       : Map      { country_id, region_id, county_id,
//                                  community_id, community_name?, community_unknown,
//                                  sub_group_id, locality_notes }
//     cover_image_url: String?
//     tags           : List<String>
//     comment_count  : int
//     relation_count : int
//     view_count     : int
//     type_data      : Map      (per-content_type rich fields)
//     has_active_dispute : bool
//     is_seeking_contributors : bool
//     created_at / updated_at / last_activity_at : Timestamp
//
//   heritage_hierarchy/{nodeId}: bg_image_url (per-node background, e.g.
//     'country_kenya')
//
// ⚠ COMPOSITE INDEXES (apply in the Firebase console — this run does NOT touch
//   security rules or indexes):
//     • cultural_entries: locality.country_id ASC, visibility ASC,
//       last_activity_at DESC
//     • cultural_entries: locality.country_id ASC, content_type ASC,
//       visibility ASC, last_activity_at DESC
//     • cultural_entries: locality.country_id ASC, locality.community_id ASC,
//       visibility ASC, last_activity_at DESC
//   (Firestore will also surface the exact index link in a console error the
//   first time each query runs.)

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'heritage_content_types.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// A country in the cultural archive (sourced from the bundled registry
/// `assets/cultural/countries/_index.json`; the live country grid combines this
/// with whether any public entries exist).
class HeritageCountry {
  final String id; // e.g. 'country_kenya'
  final String name;
  final String nameNative;
  final String flagEmoji;
  final String isoCode;
  final String continent;
  final bool isLive;
  final int communityCount;

  const HeritageCountry({
    required this.id,
    required this.name,
    required this.nameNative,
    required this.flagEmoji,
    required this.isoCode,
    required this.continent,
    required this.isLive,
    required this.communityCount,
  });

  factory HeritageCountry.fromJson(Map<String, dynamic> j) => HeritageCountry(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        nameNative: j['name_native'] as String? ?? (j['name'] as String? ?? ''),
        flagEmoji: j['flag_emoji'] as String? ?? '',
        isoCode: j['iso_code'] as String? ?? '',
        continent: j['continent'] as String? ?? '',
        isLive: j['is_live'] as bool? ?? false,
        communityCount: (j['community_count'] as num?)?.toInt() ?? 0,
      );
}

/// Read-model for a `cultural_entries` document. Mirrors the real written
/// schema (distinct from the older `CulturalEntry` model used by the org-side
/// archive, which reads a slightly different field set).
class HeritageItem {
  final String id;
  final String contentType; // taxonomy key
  final String orgId;
  final String title;
  final String description;
  final String visibility;
  final String? coverImageUrl;
  final List<String> tags;

  final String countryId;
  final String? communityId;
  final String? communityName;
  final String? subGroupId;

  final int commentCount;
  final int relationCount;
  final int viewCount;
  final bool hasActiveDispute;
  final bool isSeekingContributors;

  final Map<String, dynamic> typeData;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;

  const HeritageItem({
    required this.id,
    required this.contentType,
    required this.orgId,
    required this.title,
    required this.description,
    required this.visibility,
    required this.coverImageUrl,
    required this.tags,
    required this.countryId,
    required this.communityId,
    required this.communityName,
    required this.subGroupId,
    required this.commentCount,
    required this.relationCount,
    required this.viewCount,
    required this.hasActiveDispute,
    required this.isSeekingContributors,
    required this.typeData,
    required this.lastActivityAt,
    required this.createdAt,
  });

  factory HeritageItem.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    final locality = (data['locality'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return HeritageItem(
      id: doc.id,
      contentType: data['content_type'] as String? ?? '',
      orgId: data['org_id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      visibility: data['visibility'] as String? ?? 'public',
      coverImageUrl: data['cover_image_url'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? const []),
      countryId: locality['country_id'] as String? ?? '',
      communityId: locality['community_id'] as String?,
      communityName: locality['community_name'] as String?,
      subGroupId: locality['sub_group_id'] as String?,
      commentCount: (data['comment_count'] as num?)?.toInt() ?? 0,
      relationCount: (data['relation_count'] as num?)?.toInt() ?? 0,
      viewCount: (data['view_count'] as num?)?.toInt() ?? 0,
      hasActiveDispute: data['has_active_dispute'] as bool? ?? false,
      isSeekingContributors: data['is_seeking_contributors'] as bool? ?? false,
      typeData: (data['type_data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      lastActivityAt: (data['last_activity_at'] as Timestamp?)?.toDate() ??
          (data['created_at'] as Timestamp?)?.toDate(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  /// The display name for this item's content type (e.g. 'Stories').
  String get contentTypeLabel =>
      HeritageContentTypes.byKey(contentType)?.label ?? contentType;
}

/// A content category present in a country, with how many public entries it has.
class CategoryCount {
  final HeritageContentType type;
  final int count;
  const CategoryCount({required this.type, required this.count});
}

/// A community that actually has public entries in a country (parity-safe:
/// derived from entries, so no empty/invented communities appear).
class CommunitySummary {
  final String id;
  final String name;
  final int entryCount;
  const CommunitySummary(
      {required this.id, required this.name, required this.entryCount});
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class HeritageDataService {
  HeritageDataService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String entriesCollection = 'cultural_entries';
  static const String hierarchyCollection = 'heritage_hierarchy';

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection(entriesCollection);

  // ── Countries ──────────────────────────────────────────────────────────────

  List<HeritageCountry>? _countryCache;

  /// Loads the bundled country registry. Cached for the session.
  Future<List<HeritageCountry>> loadCountries() async {
    if (_countryCache != null) return _countryCache!;
    try {
      final raw =
          await rootBundle.loadString('assets/cultural/countries/_index.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = (decoded['countries'] as List? ?? const [])
          .map((e) => HeritageCountry.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList();
      _countryCache = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Per-node background image url (e.g. nodeId 'country_kenya'). Null when the
  /// org hasn't uploaded one yet — callers render a gradient (never an emoji or
  /// static asset).
  Stream<String?> streamNodeBg(String nodeId) {
    return _db
        .collection(hierarchyCollection)
        .doc(nodeId)
        .snapshots()
        .map((d) => (d.data())?['bg_image_url'] as String?);
  }

  /// True when a country has at least one public entry (drives Live/Soon).
  Stream<bool> streamCountryHasEntries(String countryId) {
    return _publicForCountry(countryId)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty);
  }

  // ── Entries ──────────────────────────────────────────────────────────────

  Query<Map<String, dynamic>> _publicForCountry(String countryId) {
    return _entries
        .where('locality.country_id', isEqualTo: countryId)
        .where('visibility', isEqualTo: 'public');
  }

  /// All public entries for a country, optionally filtered by content type and
  /// community, newest activity first.
  Stream<List<HeritageItem>> streamItems({
    required String countryId,
    String? contentType,
    String? communityId,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = _publicForCountry(countryId);
    if (contentType != null) {
      q = q.where('content_type', isEqualTo: contentType);
    }
    if (communityId != null) {
      q = q.where('locality.community_id', isEqualTo: communityId);
    }
    q = q.orderBy('last_activity_at', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(
        (s) => s.docs.map((d) => HeritageItem.fromDoc(d)).toList());
  }

  /// A single entry, live.
  Stream<HeritageItem?> streamItem(String id) {
    return _entries
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? HeritageItem.fromDoc(d) : null);
  }

  Future<HeritageItem?> getItem(String id) async {
    final d = await _entries.doc(id).get();
    return d.exists ? HeritageItem.fromDoc(d) : null;
  }

  /// Featured = most recently active public entries across all countries.
  /// Replaces the old hardcoded `_staticFeatured`.
  Stream<List<HeritageItem>> streamFeatured({int limit = 8}) {
    return _entries
        .where('visibility', isEqualTo: 'public')
        .orderBy('last_activity_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => HeritageItem.fromDoc(d)).toList());
  }

  // ── Aggregations (computed client-side; Firestore has no DISTINCT/GROUP) ────

  /// The content categories that have ≥1 public entry in a country, with counts,
  /// returned in the canonical taxonomy order. Categories with zero entries are
  /// omitted (Q1: a category card only appears when present).
  Stream<List<CategoryCount>> streamCategoriesForCountry(String countryId) {
    return _publicForCountry(countryId).snapshots().map((snap) {
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final ct = doc.data()['content_type'] as String? ?? '';
        if (ct.isEmpty) continue;
        counts[ct] = (counts[ct] ?? 0) + 1;
      }
      final result = <CategoryCount>[];
      for (final type in HeritageContentTypes.ordered) {
        final c = counts[type.key];
        if (c != null && c > 0) {
          result.add(CategoryCount(type: type, count: c));
        }
      }
      return result;
    });
  }

  /// Communities that actually have public entries in a country (parity-safe).
  Stream<List<CommunitySummary>> streamCommunitiesForCountry(String countryId) {
    return _publicForCountry(countryId).snapshots().map((snap) {
      final byId = <String, CommunitySummary>{};
      for (final doc in snap.docs) {
        final loc = (doc.data()['locality'] as Map?)?.cast<String, dynamic>() ??
            const {};
        final id = loc['community_id'] as String?;
        if (id == null || id.isEmpty) continue;
        final name = (loc['community_name'] as String?)?.trim();
        final existing = byId[id];
        byId[id] = CommunitySummary(
          id: id,
          name: (name != null && name.isNotEmpty)
              ? name
              : (existing?.name ?? id),
          entryCount: (existing?.entryCount ?? 0) + 1,
        );
      }
      final list = byId.values.toList()
        ..sort((a, b) => b.entryCount.compareTo(a.entryCount));
      return list;
    });
  }
}
