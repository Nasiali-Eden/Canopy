// lib/Models/services/service_listing.dart
//
// THE Home Services record. Firestore path: /service_listings/{listingId}
//
// Piloting two categories per the roadmap: trash collection and landscaping
// (see ServiceCategory below — adding a third is one enum case plus a
// ServiceOffering entry, nothing structural). Structurally this mirrors
// CanopyListing (lib/Models/marketplace/canopy_listing.dart) on purpose: same
// flat CanopyLocation spread, same SellerSnapshot-shaped provider block, same
// fromFirestore/toFirestore/copyWith shape — a member who has browsed the
// Marketplace already knows how to read a Services card. It is a distinct
// Firestore collection rather than a third `side` on CanopyListing because
// bookings (below) have no equivalent on the goods side: a service is
// requested and quoted, not bought off the shelf.
//
// Pricing is deliberately soft. A provider sets their own rate — Canopy never
// dictates it — so `ServicePricing` only ever advertises a starting figure or
// a range; the number that actually gets charged is negotiated per job and
// lives on ServiceBooking.agreedPriceKes once both sides confirm it. See
// ServiceBooking's header for how the platform fee vs. the requester's
// booking fee are split.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../geo/canopy_location.dart';
import '../../MarketPlace/The Market/marketplace_listing.dart' show SellerSnapshot, CircularBadgeTier;

export '../../MarketPlace/The Market/marketplace_listing.dart'
    show SellerSnapshot, CircularBadgeTier;

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY & OFFERINGS
// ─────────────────────────────────────────────────────────────────────────────

/// Piloting trash collection and landscaping first — see the roadmap's
/// Services section. Both are fee-only categories: the provider sets and
/// keeps the job price, Canopy takes a commission plus a small requester
/// booking fee (PlatformConstants.serviceCommissionDefaultPct /
/// serviceBookingFeeKes). Categories that need a personal trade licence
/// (electrical, plumbing/gas) are deliberately not opened yet — see the
/// Services research doc's category table for why.
enum ServiceCategory {
  trashCollection,
  landscaping;

  String get label => switch (this) {
        ServiceCategory.trashCollection => 'Trash Collection',
        ServiceCategory.landscaping => 'Landscaping',
      };

  String get emoji => switch (this) {
        ServiceCategory.trashCollection => '🗑️',
        ServiceCategory.landscaping => '🌿',
      };

  String get tagline => switch (this) {
        ServiceCategory.trashCollection =>
          'Weekly or daily pickup for homes and compounds',
        ServiceCategory.landscaping =>
          'Garden design, planting, and upkeep',
      };

  /// The chip choices a provider picks from when listing under this
  /// category, and a requester filters by when browsing. Free-text tags
  /// would work too, but a closed vocabulary keeps "weekly pickup" from
  /// fragmenting into five spellings across providers.
  List<String> get offeringOptions => switch (this) {
        ServiceCategory.trashCollection => const [
            'weekly_pickup',
            'daily_pickup',
            'one_off_pickup',
            'bulky_waste',
            'compound_cleanup',
          ],
        ServiceCategory.landscaping => const [
            'garden_design',
            'planting',
            'lawn_mowing',
            'irrigation',
            'full_install',
            'maintenance_contract',
          ],
      };

  static String offeringLabel(String key) => switch (key) {
        'weekly_pickup' => 'Weekly pickup',
        'daily_pickup' => 'Daily pickup',
        'one_off_pickup' => 'One-off pickup',
        'bulky_waste' => 'Bulky waste removal',
        'compound_cleanup' => 'Compound cleanup',
        'garden_design' => 'Garden design',
        'planting' => 'Planting',
        'lawn_mowing' => 'Lawn mowing',
        'irrigation' => 'Irrigation',
        'full_install' => 'Full installation',
        'maintenance_contract' => 'Maintenance contract',
        _ => key,
      };

  String get firestoreKey => name;

  static ServiceCategory fromString(String? v) => ServiceCategory.values
      .firstWhere((e) => e.name == v, orElse: () => ServiceCategory.trashCollection);
}

enum ServiceListingStatus {
  active,
  paused,
  closed;

  String get label => switch (this) {
        ServiceListingStatus.active => 'Active',
        ServiceListingStatus.paused => 'Paused',
        ServiceListingStatus.closed => 'Closed',
      };

  static ServiceListingStatus fromString(String? v) => ServiceListingStatus.values
      .firstWhere((e) => e.name == v, orElse: () => ServiceListingStatus.active);
}

/// How the provider prices the job. `quoteOnly` is the honest default for
/// landscaping installs, where cost depends entirely on the site; the two
/// piloted categories both allow an advertised starting figure so a
/// requester isn't browsing blind.
enum ServiceRateType {
  monthly,
  perVisit,
  quoteOnly;

  String get suffix => switch (this) {
        ServiceRateType.monthly => '/month',
        ServiceRateType.perVisit => '/visit',
        ServiceRateType.quoteOnly => '',
      };

  static ServiceRateType fromString(String? v) => ServiceRateType.values
      .firstWhere((e) => e.name == v, orElse: () => ServiceRateType.quoteOnly);
}

/// The provider's own advertised rate — never the final charged price. See
/// the file header: the number that actually gets paid is negotiated per job
/// on ServiceBooking.
class ServicePricing {
  final ServiceRateType rateType;

  /// Starting figure, e.g. 800 for "From KSh 800/month". Null when the
  /// provider only takes quotes.
  final double? fromKes;

  /// Optional upper bound of a range, e.g. 1500 for "KSh 800–1,500/month".
  final double? toKes;

  const ServicePricing({
    this.rateType = ServiceRateType.quoteOnly,
    this.fromKes,
    this.toKes,
  });

  bool get isQuoteOnly => rateType == ServiceRateType.quoteOnly || fromKes == null;

  /// "From KSh 800/month" / "KSh 800–1,500/month" / "Quote on request"
  String get display {
    if (isQuoteOnly) return 'Quote on request';
    String fmt(double n) => n.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    if (toKes != null && toKes! > fromKes!) {
      return 'KSh ${fmt(fromKes!)}–${fmt(toKes!)}${rateType.suffix}';
    }
    return 'From KSh ${fmt(fromKes!)}${rateType.suffix}';
  }

  factory ServicePricing.fromMap(Map<String, dynamic> m) => ServicePricing(
        rateType: ServiceRateType.fromString(m['rateType'] as String?),
        fromKes: (m['fromKes'] as num?)?.toDouble(),
        toKes: (m['toKes'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'rateType': rateType.name,
        'fromKes': fromKes,
        'toKes': toKes,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE LISTING
// ─────────────────────────────────────────────────────────────────────────────

class ServiceListing {
  final String id;

  final ServiceCategory category;
  final ServiceListingStatus status;

  final String title;
  final String description;

  /// Keys into ServiceCategory.offeringOptions — what this provider
  /// specifically does within the category.
  final List<String> offerings;

  final List<String> images;

  // ── Who ──
  /// Reuses the Marketplace's provider shape (sellerId/shopName/badgeTier/
  /// rating) rather than a parallel type — a provider and a seller are both
  /// "who's on the other side of this listing" and render the same way.
  final SellerSnapshot provider;
  final String? orgId;
  final String? orgName;
  final String postedByUid;

  // ── Commercial ──
  final ServicePricing pricing;

  /// How far the provider will travel from their base, for the "near you"
  /// framing on the browse screen. 0 = not stated.
  final double serviceRadiusKm;

  // ── Where ──
  final CanopyLocation location;

  // ── Discovery ──
  final List<String> tags;
  final bool isFeatured;

  // ── Engagement ──
  final int viewCount;
  final int bookingCount;
  final double averageRating;
  final int reviewCount;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const ServiceListing({
    required this.id,
    this.category = ServiceCategory.trashCollection,
    this.status = ServiceListingStatus.active,
    required this.title,
    this.description = '',
    this.offerings = const [],
    this.images = const [],
    required this.provider,
    this.orgId,
    this.orgName,
    this.postedByUid = '',
    this.pricing = const ServicePricing(),
    this.serviceRadiusKm = 0,
    this.location = CanopyLocation.empty,
    this.tags = const [],
    this.isFeatured = false,
    this.viewCount = 0,
    this.bookingCount = 0,
    this.averageRating = 0,
    this.reviewCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == ServiceListingStatus.active;
  String? get coverImage => images.isNotEmpty ? images.first : null;
  bool get isVerifiedProvider => provider.badgeTier == CircularBadgeTier.verified;

  List<String> get offeringLabels =>
      offerings.map(ServiceCategory.offeringLabel).toList();

  factory ServiceListing.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceListing.fromMap(doc.id, d);
  }

  factory ServiceListing.fromMap(String id, Map<String, dynamic> d) {
    return ServiceListing(
      id: id,
      category: ServiceCategory.fromString(d['category'] as String?),
      status: ServiceListingStatus.fromString(d['status'] as String?),
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      offerings: (d['offerings'] as List<dynamic>?)?.cast<String>() ?? const [],
      images: (d['images'] as List<dynamic>?)?.cast<String>() ?? const [],
      provider:
          SellerSnapshot.fromMap(d['provider'] as Map<String, dynamic>? ?? {}),
      orgId: d['orgId'] as String?,
      orgName: d['orgName'] as String?,
      postedByUid: d['postedByUid'] as String? ?? '',
      pricing:
          ServicePricing.fromMap(d['pricing'] as Map<String, dynamic>? ?? {}),
      serviceRadiusKm: (d['serviceRadiusKm'] as num?)?.toDouble() ?? 0,
      location: CanopyLocation.fromFirestore(d),
      tags: (d['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      isFeatured: d['isFeatured'] as bool? ?? false,
      viewCount: (d['viewCount'] as num?)?.toInt() ?? 0,
      bookingCount: (d['bookingCount'] as num?)?.toInt() ?? 0,
      averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (d['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'category': category.firestoreKey,
        'status': status.name,
        'title': title,
        'description': description,
        'offerings': offerings,
        'images': images,
        'provider': provider.toMap(),
        'orgId': orgId,
        'orgName': orgName,
        'postedByUid': postedByUid,
        'pricing': pricing.toMap(),
        'serviceRadiusKm': serviceRadiusKm,
        'tags': tags,
        'isFeatured': isFeatured,
        'viewCount': viewCount,
        'bookingCount': bookingCount,
        'averageRating': averageRating,
        'reviewCount': reviewCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        // Geography spread flat, same convention as CanopyListing.
        ...location.toFirestore(),
      };

  ServiceListing copyWith({
    ServiceCategory? category,
    ServiceListingStatus? status,
    String? title,
    String? description,
    List<String>? offerings,
    List<String>? images,
    ServicePricing? pricing,
    double? serviceRadiusKm,
    CanopyLocation? location,
    int? viewCount,
    int? bookingCount,
    DateTime? updatedAt,
  }) {
    return ServiceListing(
      id: id,
      category: category ?? this.category,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      offerings: offerings ?? this.offerings,
      images: images ?? this.images,
      provider: provider,
      orgId: orgId,
      orgName: orgName,
      postedByUid: postedByUid,
      pricing: pricing ?? this.pricing,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      location: location ?? this.location,
      tags: tags,
      isFeatured: isFeatured,
      viewCount: viewCount ?? this.viewCount,
      bookingCount: bookingCount ?? this.bookingCount,
      averageRating: averageRating,
      reviewCount: reviewCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
