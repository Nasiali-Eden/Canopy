// lib/Models/services/service_listing.dart
//
// THE Home Services record. Firestore path: /service_listings/{listingId}
//
// Piloted with trash collection and landscaping, then extended per the
// Services Tab research doc (claude/canopy_services_tab_research.html §5):
// junk removal and moving/hauling sit in the exact same no-personal-license
// regulatory bucket as the original two; handyman is listable but its copy
// must exclude regulated trade work; electrical and plumbing/gas need a
// personal trade license (EPRA / NCA) that Canopy verifies before the
// listing goes public — see LicenseVerificationStatus below. Pest control
// is deliberately not added — the research doc calls it the most
// regulatorily stacked category found and recommends deferring it past the
// pilot, not folding it in alongside these. Structurally this mirrors
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

/// Every category below is fee-only: the provider sets and keeps the job
/// price, Canopy takes a commission plus a small requester booking fee
/// (PlatformConstants.serviceCommissionDefaultPct / serviceBookingFeeKes).
/// That posture is what the research doc's §5.1 found keeps every category
/// here outside Kenya's Private Employment Agency licensing regime — it's
/// not category-specific, so it isn't repeated per case below.
///
/// What *is* category-specific is whether the individual doing the work
/// needs to hold a personal trade license, independent of Canopy or any
/// pricing model — see `requiresLicenseVerification`. Trash collection,
/// landscaping, junk removal, moving/hauling and handyman need none.
/// Electrical and plumbing/gas do (EPRA, NCA) — a listing under either
/// stays hidden from public browse until Canopy verifies the uploaded
/// document (see ServiceListing.licenseVerificationStatus).
enum ServiceCategory {
  trashCollection,
  landscaping,
  junkRemoval,
  movingHauling,
  handyman,
  electrical,
  plumbing;

  String get label => switch (this) {
        ServiceCategory.trashCollection => 'Trash Collection',
        ServiceCategory.landscaping => 'Landscaping',
        ServiceCategory.junkRemoval => 'Junk Removal',
        ServiceCategory.movingHauling => 'Moving & Hauling',
        ServiceCategory.handyman => 'Handyman',
        ServiceCategory.electrical => 'Electrical',
        ServiceCategory.plumbing => 'Plumbing',
      };

  // No emoji (design rule) — the UI draws ServiceCategoryUi.icon glyphs.

  String get tagline => switch (this) {
        ServiceCategory.trashCollection =>
          'Weekly or daily pickup for homes and compounds',
        ServiceCategory.landscaping =>
          'Garden design, planting, and upkeep',
        ServiceCategory.junkRemoval =>
          'Bulky-item and junk hauling, priced per load',
        ServiceCategory.movingHauling =>
          'Local moves, hauling, and delivery help',
        ServiceCategory.handyman =>
          'General repairs and small fixes around the home',
        ServiceCategory.electrical =>
          'Licensed residential electrical work',
        ServiceCategory.plumbing =>
          'Pipe, tap, and gas-fitting repairs',
      };

  /// Trash collection, landscaping, junk removal, moving/hauling, and
  /// handyman all clear the research doc's two bars (§5.2) with no new
  /// verification infrastructure — no personal license required, and the
  /// home-entry trust question is the same one Canopy's existing
  /// Collector/Verifier vetting already covers. Electrical and plumbing/gas
  /// need the individual doing the work to hold a personal credential
  /// (EPRA, NCA) that Canopy has to check — a listing under either category
  /// is created but stays out of public browse until that's done. Keep this
  /// in sync with firestore.rules' service_listings create rule, which
  /// hardcodes the same two categories (rules can't call into this enum).
  bool get requiresLicenseVerification => switch (this) {
        ServiceCategory.electrical => true,
        ServiceCategory.plumbing => true,
        _ => false,
      };

  /// Shown on the listing form under the category. For handyman it's a
  /// disclaimer (§5.2's "listing copy needs to say this explicitly, not
  /// leave it implicit"); for the two licensed trades it names the
  /// credential Canopy checks before the listing goes public. Null for
  /// every category that needs neither.
  String? get regulatoryNote => switch (this) {
        ServiceCategory.handyman =>
          'For general repairs only — wiring, gas, and structural work need a separately licensed provider, not a handyman listing.',
        ServiceCategory.electrical =>
          "Requires a valid EPRA electrician's license. Upload a photo of it — Canopy verifies it before your listing goes public.",
        ServiceCategory.plumbing =>
          'Requires NCA contractor registration where applicable. Upload proof — Canopy verifies it before your listing goes public.',
        _ => null,
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
        ServiceCategory.junkRemoval => const [
            'furniture_removal',
            'appliance_removal',
            'construction_debris',
            'general_junk',
            'one_off_load',
          ],
        ServiceCategory.movingHauling => const [
            'local_move',
            'furniture_delivery',
            'hauling',
            'loading_help',
          ],
        ServiceCategory.handyman => const [
            'general_repairs',
            'furniture_assembly',
            'painting',
            'fixture_install',
            'carpentry',
          ],
        ServiceCategory.electrical => const [
            'wiring_repair',
            'fixture_install_electrical',
            'panel_work',
            'inspection',
            'rewiring',
          ],
        ServiceCategory.plumbing => const [
            'tap_repair',
            'pipe_repair',
            'drain_unblock',
            'gas_fitting',
            'installation',
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
        'furniture_removal' => 'Furniture removal',
        'appliance_removal' => 'Appliance removal',
        'construction_debris' => 'Construction debris',
        'general_junk' => 'General junk',
        'one_off_load' => 'One-off load',
        'local_move' => 'Local move',
        'furniture_delivery' => 'Furniture delivery',
        'hauling' => 'Hauling',
        'loading_help' => 'Loading help',
        'general_repairs' => 'General repairs',
        'furniture_assembly' => 'Furniture assembly',
        'painting' => 'Painting',
        'fixture_install' => 'Fixture install',
        'carpentry' => 'Carpentry',
        'wiring_repair' => 'Wiring repair',
        'fixture_install_electrical' => 'Fixture install',
        'panel_work' => 'Panel work',
        'inspection' => 'Inspection',
        'rewiring' => 'Rewiring',
        'tap_repair' => 'Tap repair',
        'pipe_repair' => 'Pipe repair',
        'drain_unblock' => 'Drain unblocking',
        'gas_fitting' => 'Gas fitting',
        'installation' => 'Installation',
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

/// The provider's-license review pipeline for `ServiceCategory.
/// requiresLicenseVerification` categories (electrical, plumbing today).
/// `notRequired` is the default for every other category — nothing to
/// review, the listing is public the moment it's created (same as before
/// this pipeline existed). `pending` -> `verified`/`rejected` is a manual
/// review step: nothing in the app advances it automatically today, the
/// same disclosed honesty gap as IncidentStatus/contribution `status`
/// (there's no verifier-assignment mechanism yet) — see
/// USER_PAGES_SERVICE_CATEGORIES_BRIEF.md for how Canopy actually reviews
/// the uploaded document right now (Firebase console, by hand).
enum LicenseVerificationStatus {
  notRequired,
  pending,
  verified,
  rejected;

  String get label => switch (this) {
        LicenseVerificationStatus.notRequired => '',
        LicenseVerificationStatus.pending => 'Pending verification',
        LicenseVerificationStatus.verified => 'License verified',
        LicenseVerificationStatus.rejected => 'Verification rejected',
      };

  static LicenseVerificationStatus fromString(String? v) =>
      LicenseVerificationStatus.values.firstWhere((e) => e.name == v,
          orElse: () => LicenseVerificationStatus.notRequired);
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

  /// How customers reach the provider. Payment is agreed directly.
  final String contactPhone;

  // ── Commercial ──
  final ServicePricing pricing;

  /// How far the provider will travel from their base, for the "near you"
  /// framing on the browse screen. 0 = not stated.
  final double serviceRadiusKm;

  // ── Where ──
  final CanopyLocation location;

  // ── Licensing (electrical / plumbing today — see
  // ServiceCategory.requiresLicenseVerification) ──
  /// Storage download URL for the photo of the provider's license/
  /// registration document. Null for every category that doesn't need one.
  final String? licenseDocumentUrl;
  final LicenseVerificationStatus licenseVerificationStatus;
  final String? licenseRejectionReason;
  final DateTime? licenseVerifiedAt;
  final String? licenseVerifiedBy;

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
    this.contactPhone = '',
    this.pricing = const ServicePricing(),
    this.serviceRadiusKm = 0,
    this.location = CanopyLocation.empty,
    this.licenseDocumentUrl,
    this.licenseVerificationStatus = LicenseVerificationStatus.notRequired,
    this.licenseRejectionReason,
    this.licenseVerifiedAt,
    this.licenseVerifiedBy,
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

  bool get requiresLicenseVerification => category.requiresLicenseVerification;

  /// Whether this listing should appear in public browse/search. A
  /// regulated-category listing stays out until Canopy verifies the
  /// uploaded document — see ServiceMarketplaceService's browse queries,
  /// which apply this same gate client-side.
  bool get isPubliclyListable =>
      isActive &&
      (!requiresLicenseVerification ||
          licenseVerificationStatus == LicenseVerificationStatus.verified);

  bool get isPendingLicenseVerification =>
      requiresLicenseVerification &&
      licenseVerificationStatus == LicenseVerificationStatus.pending;

  bool get isLicenseVerificationRejected =>
      licenseVerificationStatus == LicenseVerificationStatus.rejected;

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
      contactPhone: d['contactPhone'] as String? ?? '',
      pricing:
          ServicePricing.fromMap(d['pricing'] as Map<String, dynamic>? ?? {}),
      serviceRadiusKm: (d['serviceRadiusKm'] as num?)?.toDouble() ?? 0,
      location: CanopyLocation.fromFirestore(d),
      licenseDocumentUrl: d['licenseDocumentUrl'] as String?,
      licenseVerificationStatus:
          LicenseVerificationStatus.fromString(d['licenseVerificationStatus'] as String?),
      licenseRejectionReason: d['licenseRejectionReason'] as String?,
      licenseVerifiedAt: (d['licenseVerifiedAt'] as Timestamp?)?.toDate(),
      licenseVerifiedBy: d['licenseVerifiedBy'] as String?,
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
        'contactPhone': contactPhone,
        'pricing': pricing.toMap(),
        'serviceRadiusKm': serviceRadiusKm,
        'licenseDocumentUrl': licenseDocumentUrl,
        'licenseVerificationStatus': licenseVerificationStatus.name,
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
    String? licenseDocumentUrl,
    LicenseVerificationStatus? licenseVerificationStatus,
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
      contactPhone: contactPhone,
      pricing: pricing ?? this.pricing,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      location: location ?? this.location,
      licenseDocumentUrl: licenseDocumentUrl ?? this.licenseDocumentUrl,
      licenseVerificationStatus: licenseVerificationStatus ?? this.licenseVerificationStatus,
      licenseRejectionReason: licenseRejectionReason,
      licenseVerifiedAt: licenseVerifiedAt,
      licenseVerifiedBy: licenseVerifiedBy,
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
