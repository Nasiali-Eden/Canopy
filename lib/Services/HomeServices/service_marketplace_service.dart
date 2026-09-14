// lib/Services/HomeServices/service_marketplace_service.dart
//
// Reads and writes /service_listings and /service_bookings.
//
// Query strategy is copied deliberately from ListingService
// (lib/Services/Marketplace/listing_service.dart): ONE equality predicate
// goes to Firestore — geo tier for listings, requesterUid/providerUid for
// bookings — everything else (category, status, search text) filters
// client-side over the already-bounded result. See that file's header for
// why this avoids a composite-index wall; the same reasoning applies here
// unchanged, just against two collections instead of one.
//
// This intentionally does NOT reuse EnvironmentOpsService.createMarketOrder's
// dual-write pattern (MarketOrder to `marketOrders` + a snake_case mirror to
// `market_listings`) — that split is documented in this codebase as the
// reason buy orders were invisible outside their posting org. Services has
// one collection per concept, written once, same as /listings.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Models/services/service_listing.dart';
import '../../Models/services/service_booking.dart';

/// Composite indexes this service requires (Firebase console or
/// firestore.indexes.json), mirroring kListingCompositeIndexes:
///
///   service_listings: geo_county_id ASC, status ASC, createdAt DESC
///   service_listings: geo_country_id ASC, status ASC, createdAt DESC
///   service_bookings: requesterUid ASC, createdAt DESC
///   service_bookings: providerUid ASC, createdAt DESC
const kServiceCompositeIndexes = [
  'service_listings(geo_county_id, status, createdAt desc)',
  'service_listings(geo_country_id, status, createdAt desc)',
  'service_bookings(requesterUid, createdAt desc)',
  'service_bookings(providerUid, createdAt desc)',
];

const _sentinel = Object();

class ServiceListingQuery {
  final LocationFilter location;
  final ServiceCategory? category;
  final String searchText;
  final String? providerId;
  final String? orgId;
  final ServiceListingStatus status;

  const ServiceListingQuery({
    this.location = LocationFilter.everywhere,
    this.category,
    this.searchText = '',
    this.providerId,
    this.orgId,
    this.status = ServiceListingStatus.active,
  });

  ServiceListingQuery copyWith({
    LocationFilter? location,
    Object? category = _sentinel,
    String? searchText,
    String? providerId,
    String? orgId,
    ServiceListingStatus? status,
  }) {
    return ServiceListingQuery(
      location: location ?? this.location,
      category:
          category == _sentinel ? this.category : category as ServiceCategory?,
      searchText: searchText ?? this.searchText,
      providerId: providerId ?? this.providerId,
      orgId: orgId ?? this.orgId,
      status: status ?? this.status,
    );
  }
}

class ServiceMarketplaceService {
  ServiceMarketplaceService._();
  static final ServiceMarketplaceService instance = ServiceMarketplaceService._();

  static const listingsPath = 'service_listings';
  static const bookingsPath = 'service_bookings';

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _listings =>
      _db.collection(listingsPath);
  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection(bookingsPath);

  // ── Listings: reads ─────────────────────────────────────────────────────

  Stream<List<ServiceListing>> watchListings(ServiceListingQuery query,
      {int limit = 200}) {
    Query<Map<String, dynamic>> q = _listings;
    final field = query.location.field;
    final value = query.location.value;
    if (field != null && value != null) {
      q = q.where(field, isEqualTo: value);
    }
    if (query.providerId != null && query.providerId!.isNotEmpty) {
      q = q.where('postedByUid', isEqualTo: query.providerId);
    } else if (query.orgId != null && query.orgId!.isNotEmpty) {
      q = q.where('orgId', isEqualTo: query.orgId);
    }
    return q.limit(limit).snapshots().map((snap) {
      final all = snap.docs.map(ServiceListing.fromFirestore).toList();
      return _applyClientFilters(all, query);
    }).handleError((Object e, StackTrace st) {
      debugPrint('[ServiceMarketplaceService] watchListings failed: $e');
    });
  }

  Future<List<ServiceListing>> fetchListings(ServiceListingQuery query,
      {int limit = 200}) async {
    Query<Map<String, dynamic>> q = _listings;
    final field = query.location.field;
    final value = query.location.value;
    if (field != null && value != null) {
      q = q.where(field, isEqualTo: value);
    }
    if (query.providerId != null && query.providerId!.isNotEmpty) {
      q = q.where('postedByUid', isEqualTo: query.providerId);
    } else if (query.orgId != null && query.orgId!.isNotEmpty) {
      q = q.where('orgId', isEqualTo: query.orgId);
    }
    try {
      final snap = await q.limit(limit).get();
      return _applyClientFilters(
          snap.docs.map(ServiceListing.fromFirestore).toList(), query);
    } catch (e) {
      debugPrint('[ServiceMarketplaceService] fetchListings failed: $e');
      return const [];
    }
  }

  Future<ServiceListing?> listingById(String id) async {
    try {
      final doc = await _listings.doc(id).get();
      if (!doc.exists) return null;
      return ServiceListing.fromFirestore(doc);
    } catch (e) {
      debugPrint('[ServiceMarketplaceService] listingById failed: $e');
      return null;
    }
  }

  Stream<ServiceListing?> watchListingById(String id) => _listings
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ServiceListing.fromFirestore(d) : null);

  Stream<List<ServiceListing>> watchListingsByProvider(String uid) => _listings
      .where('postedByUid', isEqualTo: uid)
      .snapshots()
      .map((s) => _sortListings(s.docs.map(ServiceListing.fromFirestore).toList()));

  List<ServiceListing> _applyClientFilters(
      List<ServiceListing> all, ServiceListingQuery query) {
    final text = query.searchText.trim().toLowerCase();
    final filtered = all.where((l) {
      if (l.status != query.status) return false;
      if (query.category != null && l.category != query.category) return false;
      if (text.isNotEmpty) {
        final haystack = [
          l.title,
          l.description,
          l.provider.shopName,
          l.orgName ?? '',
          l.location.label,
          ...l.tags,
          ...l.offeringLabels,
        ].join(' ').toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      return true;
    }).toList();
    return _sortListings(filtered);
  }

  List<ServiceListing> _sortListings(List<ServiceListing> list) {
    list.sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // ── Listings: writes ────────────────────────────────────────────────────

  Future<String> createListing(ServiceListing listing) async {
    final ref = _listings.doc();
    await ref.set({
      ...listing.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateListing(String id, Map<String, dynamic> patch) =>
      _listings.doc(id).set(
        {...patch, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  Future<void> setListingStatus(String id, ServiceListingStatus status) =>
      updateListing(id, {'status': status.name});

  Future<void> incrementListingView(String id) => _listings
      .doc(id)
      .update({'viewCount': FieldValue.increment(1)}).catchError(
          (Object e) => debugPrint('[ServiceMarketplaceService] view bump failed: $e'));

  // ── Bookings: reads ─────────────────────────────────────────────────────

  /// "My Requests" tab — jobs this member asked for, as requester.
  Stream<List<ServiceBooking>> watchMyRequests(String requesterUid) => _bookings
      .where('requesterUid', isEqualTo: requesterUid)
      .snapshots()
      .map((s) => _sortBookings(s.docs.map(ServiceBooking.fromFirestore).toList()));

  /// "Incoming Jobs" tab — jobs asked of this member, as provider.
  Stream<List<ServiceBooking>> watchIncomingJobs(String providerUid) => _bookings
      .where('providerUid', isEqualTo: providerUid)
      .snapshots()
      .map((s) => _sortBookings(s.docs.map(ServiceBooking.fromFirestore).toList()));

  Future<ServiceBooking?> bookingById(String id) async {
    try {
      final doc = await _bookings.doc(id).get();
      if (!doc.exists) return null;
      return ServiceBooking.fromFirestore(doc);
    } catch (e) {
      debugPrint('[ServiceMarketplaceService] bookingById failed: $e');
      return null;
    }
  }

  Stream<ServiceBooking?> watchBookingById(String id) => _bookings
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ServiceBooking.fromFirestore(d) : null);

  List<ServiceBooking> _sortBookings(List<ServiceBooking> list) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ── Bookings: writes ────────────────────────────────────────────────────

  /// Requester opens a job against a listing. No price yet — that comes from
  /// the provider's quote.
  Future<String> requestBooking(ServiceBooking booking) async {
    final ref = _bookings.doc();
    await ref.set({
      ...booking.toFirestore(),
      'status': ServiceBookingStatus.requested.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _listings
        .doc(booking.listingId)
        .set({'bookingCount': FieldValue.increment(1)}, SetOptions(merge: true))
        .catchError(
            (Object e) => debugPrint('[ServiceMarketplaceService] booking count bump failed: $e'));
    return ref.id;
  }

  /// Provider responds to a request with a price.
  Future<void> submitQuote(String bookingId,
      {required double quotedPriceKes, String? quoteNote}) {
    return _bookings.doc(bookingId).set({
      'status': ServiceBookingStatus.quoted.name,
      'quotedPriceKes': quotedPriceKes,
      'quoteNote': quoteNote,
      'quotedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Requester accepts the quote. Locks the fee split in at this moment so
  /// later changes to PlatformConstants never rewrite an existing booking's
  /// history — the same reasoning marketplace_checkout.dart applies by
  /// computing its fee at checkout time rather than reading it live.
  Future<void> acceptQuote(String bookingId) async {
    final doc = await _bookings.doc(bookingId).get();
    final d = doc.data();
    if (d == null) return;
    final quoted = (d['quotedPriceKes'] as num?)?.toDouble();
    if (quoted == null) return;
    final isRecurring = d['isRecurring'] as bool? ?? false;
    final fees = ServiceFeeBreakdown.compute(
      agreedPriceKes: quoted,
      isRecurring: isRecurring,
    );
    await _bookings.doc(bookingId).set({
      'status': ServiceBookingStatus.accepted.name,
      'agreedPriceKes': fees.agreedPriceKes,
      'platformFeeKes': fees.platformFeeKes,
      'providerPayoutKes': fees.providerPayoutKes,
      'requesterBookingFeeKes': fees.requesterBookingFeeKes,
      'requesterTotalKes': fees.requesterTotalKes,
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markScheduled(String bookingId, {DateTime? confirmedDate}) {
    return _bookings.doc(bookingId).set({
      'status': ServiceBookingStatus.scheduled.name,
      if (confirmedDate != null)
        'preferredDate': Timestamp.fromDate(confirmedDate),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markCompleted(String bookingId) {
    return _bookings.doc(bookingId).set({
      'status': ServiceBookingStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> decline(String bookingId, {String? reason}) {
    return _bookings.doc(bookingId).set({
      'status': ServiceBookingStatus.declined.name,
      'cancellationReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancel(String bookingId, {String? reason}) {
    return _bookings.doc(bookingId).set({
      'status': ServiceBookingStatus.cancelled.name,
      'cancellationReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Mocked checkout — identical shape to marketplace_checkout.dart's
  /// `_pay()`: a simulated delay standing in for a real M-Pesa STK push,
  /// documented there and in firestore.rules/rules-tests as "simulated
  /// rather than reconciled through authenticated callbacks." Real payment
  /// integration is explicitly out of scope for this pass — see
  /// IMPLEMENTATION_NOTES_SERVICES.md.
  Future<void> simulatedPay(String bookingId) async {
    await Future.delayed(const Duration(seconds: 2)); // M-Pesa STK push (simulated)
    await _bookings.doc(bookingId).set({
      'paymentStatus': 'simulated_paid',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
