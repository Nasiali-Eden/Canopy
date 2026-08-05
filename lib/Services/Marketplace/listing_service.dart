// lib/Services/Marketplace/listing_service.dart
//
// Reads and writes /listings — the one marketplace collection.
//
// Query strategy, deliberately chosen to avoid a composite-index wall:
//
// Firestore serves equality-only queries from automatic single-field indexes.
// The Heritage service already relies on this (see its header note) and it is
// the right constraint here too, because the location switch multiplies the
// filter space: 4 geo tiers × 2 sides × 2 intents × 10 categories would need an
// unmaintainable number of composite indexes if all of it were pushed server-
// side.
//
// So: ONE equality predicate goes to Firestore — the geo tier, which is the
// most selective and the one that actually bounds document count. Everything
// else (side, intent, category, badge, search text) filters client-side over
// the already-bounded result, and ordering is client-side too.
//
// The single exception is `status`, which is combined with geo. That pair is
// declared in COMPOSITE_INDEXES below — two indexes total, not two hundred.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Models/marketplace/canopy_listing.dart';

/// Composite indexes this service requires. Add these in the Firebase console
/// (or firestore.indexes.json) before shipping:
///
///   listings: geo_county_id ASC, status ASC, createdAt DESC
///   listings: geo_country_id ASC, status ASC, createdAt DESC
///
/// Region and area tiers reuse the county index shape; if they are promoted to
/// server-side ordering later, mirror the same two fields.
const kListingCompositeIndexes = [
  'listings(geo_county_id, status, createdAt desc)',
  'listings(geo_country_id, status, createdAt desc)',
];

class ListingQuery {
  final LocationFilter location;
  final ListingSide? side;
  final ListingIntent? intent;
  final ListingCategory? category;
  final bool onlyCircularBadge;
  final bool onlyWithDna;
  final String searchText;
  final String? sellerId;
  final String? orgId;
  final ListingStatus status;

  const ListingQuery({
    this.location = LocationFilter.everywhere,
    this.side,
    this.intent,
    this.category,
    this.onlyCircularBadge = false,
    this.onlyWithDna = false,
    this.searchText = '',
    this.sellerId,
    this.orgId,
    this.status = ListingStatus.active,
  });

  ListingQuery copyWith({
    LocationFilter? location,
    Object? side = _sentinel,
    Object? intent = _sentinel,
    Object? category = _sentinel,
    bool? onlyCircularBadge,
    bool? onlyWithDna,
    String? searchText,
    String? sellerId,
    String? orgId,
    ListingStatus? status,
  }) {
    return ListingQuery(
      location: location ?? this.location,
      side: side == _sentinel ? this.side : side as ListingSide?,
      intent: intent == _sentinel ? this.intent : intent as ListingIntent?,
      category:
          category == _sentinel ? this.category : category as ListingCategory?,
      onlyCircularBadge: onlyCircularBadge ?? this.onlyCircularBadge,
      onlyWithDna: onlyWithDna ?? this.onlyWithDna,
      searchText: searchText ?? this.searchText,
      sellerId: sellerId ?? this.sellerId,
      orgId: orgId ?? this.orgId,
      status: status ?? this.status,
    );
  }

  bool get hasActiveFilters =>
      side != null ||
      intent != null ||
      category != null ||
      onlyCircularBadge ||
      onlyWithDna ||
      searchText.isNotEmpty;
}

const _sentinel = Object();

class ListingService {
  ListingService._();
  static final ListingService instance = ListingService._();

  static const collectionPath = 'listings';

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collectionPath);

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// Live listings matching [query]. Geo is applied server-side; everything
  /// else client-side. See the file header for why.
  Stream<List<CanopyListing>> watch(ListingQuery query, {int limit = 200}) {
    Query<Map<String, dynamic>> q = _col;

    final field = query.location.field;
    final value = query.location.value;
    if (field != null && value != null) {
      q = q.where(field, isEqualTo: value);
    }

    // Seller / org scoping is also an equality predicate and is mutually
    // exclusive with geo in practice (a shop page is not location-filtered),
    // so this never stacks into a composite requirement.
    if (query.sellerId != null && query.sellerId!.isNotEmpty) {
      q = q.where('postedByUid', isEqualTo: query.sellerId);
    } else if (query.orgId != null && query.orgId!.isNotEmpty) {
      q = q.where('orgId', isEqualTo: query.orgId);
    }

    return q.limit(limit).snapshots().map((snap) {
      final all = snap.docs.map(CanopyListing.fromFirestore).toList();
      return _applyClientFilters(all, query);
    }).handleError((Object e, StackTrace st) {
      debugPrint('[ListingService] watch failed: $e');
    });
  }

  /// One-shot variant for screens that do not need live updates.
  Future<List<CanopyListing>> fetch(ListingQuery query,
      {int limit = 200}) async {
    Query<Map<String, dynamic>> q = _col;
    final field = query.location.field;
    final value = query.location.value;
    if (field != null && value != null) {
      q = q.where(field, isEqualTo: value);
    }
    try {
      final snap = await q.limit(limit).get();
      return _applyClientFilters(
          snap.docs.map(CanopyListing.fromFirestore).toList(), query);
    } catch (e) {
      debugPrint('[ListingService] fetch failed: $e');
      return const [];
    }
  }

  Future<CanopyListing?> byId(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return CanopyListing.fromFirestore(doc);
    } catch (e) {
      debugPrint('[ListingService] byId failed: $e');
      return null;
    }
  }

  Stream<CanopyListing?> watchById(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? CanopyListing.fromFirestore(d) : null);

  /// Everything a member has posted, both sides, both intents.
  Stream<List<CanopyListing>> watchByMember(String uid) => _col
      .where('postedByUid', isEqualTo: uid)
      .snapshots()
      .map((s) => _sort(s.docs.map(CanopyListing.fromFirestore).toList()));

  Stream<List<CanopyListing>> watchByOrg(String orgId) => _col
      .where('orgId', isEqualTo: orgId)
      .snapshots()
      .map((s) => _sort(s.docs.map(CanopyListing.fromFirestore).toList()));

  List<CanopyListing> _applyClientFilters(
      List<CanopyListing> all, ListingQuery query) {
    final text = query.searchText.trim().toLowerCase();

    final filtered = all.where((l) {
      if (l.status != query.status) return false;
      if (query.side != null && l.side != query.side) return false;
      if (query.intent != null && l.intent != query.intent) return false;
      if (query.category != null && l.category != query.category) return false;
      if (query.onlyCircularBadge &&
          l.circularBadge != CircularBadgeTier.verified) return false;
      if (query.onlyWithDna && !l.hasDna) return false;
      // Seeking listings that have passed their date are noise.
      if (l.isSeeking && l.isExpired) return false;
      if (text.isNotEmpty) {
        final haystack = [
          l.title,
          l.tagline,
          l.story,
          l.seller.shopName,
          l.orgName ?? '',
          l.location.label,
          ...l.tags,
          ...l.materials.map((m) => m.label),
        ].join(' ').toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      return true;
    }).toList();

    return _sort(filtered);
  }

  /// Featured first, then newest. Seeking listings are NOT pushed down — a buy
  /// order for material in your county is at least as useful as a new artisan
  /// piece, and burying it is what made the buy side invisible before.
  List<CanopyListing> _sort(List<CanopyListing> list) {
    list.sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<String> create(CanopyListing listing) async {
    final ref = _col.doc();
    await ref.set({
      ...listing.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, Map<String, dynamic> patch) =>
      _col.doc(id).set(
        {...patch, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  Future<void> setStatus(String id, ListingStatus status) =>
      update(id, {'status': status.name});

  Future<void> incrementView(String id) =>
      _col.doc(id).update({'viewCount': FieldValue.increment(1)}).catchError(
          (Object e) => debugPrint('[ListingService] view bump failed: $e'));

  // ── Responses to seeking listings ─────────────────────────────────────────

  Stream<List<ListingResponse>> watchResponses(String listingId) => _col
      .doc(listingId)
      .collection('responses')
      .snapshots()
      .map((s) => s.docs
          .map((d) => ListingResponse.fromFirestore(listingId, d))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Future<void> respond(ListingResponse response) async {
    final batch = _db.batch();
    final ref = _col
        .doc(response.listingId)
        .collection('responses')
        .doc(response.responderUid); // one live response per member
    batch.set(ref, response.toFirestore());
    batch.set(
      _col.doc(response.listingId),
      {
        'responseCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ── Aggregates for the marketplace header strip ───────────────────────────

  /// Counts within the active location scope, used by the market header:
  /// "142 listed · 38 wanted · in Kiambu".
  Future<MarketplaceTotals> totals(LocationFilter location) async {
    try {
      Query<Map<String, dynamic>> q = _col;
      final field = location.field;
      final value = location.value;
      if (field != null && value != null) {
        q = q.where(field, isEqualTo: value);
      }
      final snap = await q.limit(500).get();
      final all = snap.docs
          .map(CanopyListing.fromFirestore)
          .where((l) => l.isActive)
          .toList();
      return MarketplaceTotals(
        offering: all.where((l) => l.isOffering).length,
        seeking: all.where((l) => l.isSeeking && !l.isExpired).length,
        supply: all.where((l) => l.isSupply).length,
        creative: all.where((l) => l.isCreative).length,
        kgDiverted:
            all.fold<double>(0, (sum, l) => sum + l.impact.kgDiverted),
        collectorsCredited: all
            .expand((l) => l.creditedCollectors)
            .toSet()
            .length,
      );
    } catch (e) {
      debugPrint('[ListingService] totals failed: $e');
      return const MarketplaceTotals();
    }
  }
}

class MarketplaceTotals {
  final int offering;
  final int seeking;
  final int supply;
  final int creative;
  final double kgDiverted;
  final int collectorsCredited;

  const MarketplaceTotals({
    this.offering = 0,
    this.seeking = 0,
    this.supply = 0,
    this.creative = 0,
    this.kgDiverted = 0,
    this.collectorsCredited = 0,
  });

  int get total => offering + seeking;
  bool get isEmpty => total == 0;
}
