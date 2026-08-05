// lib/Models/marketplace/canopy_listing.dart
//
// THE unified marketplace record. Firestore path: /listings/{listingId}
//
// Before this model the marketplace existed twice and neither half worked:
//
//   • lib/MarketPlace/**  — eco_shop, seller_shop, item view, shop view and
//     checkout, all rendering hardcoded placeholder objects. Zero Firestore
//     calls. The rich MarketplaceListing model existed but nothing read or
//     wrote the /listings collection it described.
//   • lib/EnvironmentalOps/Market/ — the real data. Wrote MarketOrder to
//     `marketOrders` AND a snake_case mirror to `market_listings`, then read
//     it back filtered by `org_id == myOrg`. Buy orders existed in the schema
//     but no one outside the posting org could ever see them.
//
// CanopyListing collapses both into one document that answers two questions
// independently:
//
//   side   — WHAT is being traded.  supply (materials) | creative (artisan)
//   intent — WHICH DIRECTION.       offering (for sale) | seeking (wanted)
//
// That 2×2 is the whole marketplace. A processor's buy order is
// (supply, seeking). A collector's bale of PET is (supply, offering). An
// artisan's copper bangle is (creative, offering). A maker's Creator Buy
// Request — the "materials wanted by an environmental participant" case — is
// (supply, seeking) posted by a creative-side member. All four render in one
// feed, filterable by county.
//
// Geography is flat (geo_county_id etc. via CanopyLocation) so any tier of the
// location switch is a single-field Firestore predicate.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../geo/canopy_location.dart';
// Reuses the value types already defined for the creative side rather than
// duplicating them: ListingCategory, MaterialType, CircularBadgeTier,
// MaterialDnaLink, SellerSnapshot, ListingImpact.
import '../../MarketPlace/The Market/marketplace_listing.dart';

export '../../MarketPlace/The Market/marketplace_listing.dart'
    show
        ListingCategory,
        MaterialType,
        CircularBadgeTier,
        MaterialDnaLink,
        SellerSnapshot,
        ListingImpact;

// ─────────────────────────────────────────────────────────────────────────────
// SIDE & INTENT
// ─────────────────────────────────────────────────────────────────────────────

/// Which half of the marketplace a listing belongs to.
enum ListingSide {
  /// Materials and processed goods — collectors, processors. Priced per kg,
  /// specification-driven.
  supply,

  /// Artisan and maker goods — finished works. Priced per item, story-driven.
  creative;

  String get label => switch (this) {
        ListingSide.supply => 'Materials',
        ListingSide.creative => 'Made',
      };

  String get firestoreKey => name;

  static ListingSide fromString(String? v) => ListingSide.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ListingSide.creative,
      );
}

/// Which direction value flows. This is the axis the app was missing — buying
/// existed in `MarketOrderType` but never surfaced in any browsable feed.
enum ListingIntent {
  /// "I have this, buy it from me." A sale listing.
  offering,

  /// "I want this, sell it to me." A buy order / wanted post / Creator Buy
  /// Request. Shows in the same feed as offers, visually distinguished.
  seeking;

  String get label => switch (this) {
        ListingIntent.offering => 'For sale',
        ListingIntent.seeking => 'Wanted',
      };

  /// Verb used in card copy: "Selling" / "Looking for".
  String get verb => switch (this) {
        ListingIntent.offering => 'Selling',
        ListingIntent.seeking => 'Looking for',
      };

  String get firestoreKey => name;

  static ListingIntent fromString(String? v) {
    // Accepts the legacy market_listings vocabulary so old documents migrate
    // cleanly: buy_order / recurring_buy → seeking, sell_listing → offering.
    switch (v) {
      case 'seeking':
      case 'buy':
      case 'buy_order':
      case 'recurring_buy':
        return ListingIntent.seeking;
      case 'offering':
      case 'sell':
      case 'sell_listing':
        return ListingIntent.offering;
      default:
        return ListingIntent.offering;
    }
  }
}

enum ListingStatus {
  active,
  fulfilled,
  paused,
  closed;

  String get label => switch (this) {
        ListingStatus.active => 'Active',
        ListingStatus.fulfilled => 'Fulfilled',
        ListingStatus.paused => 'Paused',
        ListingStatus.closed => 'Closed',
      };

  static ListingStatus fromString(String? v) => ListingStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ListingStatus.active,
      );
}

/// How a listing is priced. Supply side trades per kilogram; creative side
/// trades per item. Mixing them in one `price` field is what made the two
/// marketplaces impossible to merge before.
enum PriceUnit {
  perKg,
  perItem,
  perBale,
  negotiableOnly;

  String get suffix => switch (this) {
        PriceUnit.perKg => '/kg',
        PriceUnit.perItem => '',
        PriceUnit.perBale => '/bale',
        PriceUnit.negotiableOnly => '',
      };

  static PriceUnit fromString(String? v) => PriceUnit.values.firstWhere(
        (e) => e.name == v,
        orElse: () => PriceUnit.perItem,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORTING VALUE TYPES
// ─────────────────────────────────────────────────────────────────────────────

class ListingPricing {
  final double amountKes;
  final PriceUnit unit;
  final bool negotiable;
  final double? originalAmountKes;
  final String currency;

  const ListingPricing({
    this.amountKes = 0,
    this.unit = PriceUnit.perItem,
    this.negotiable = false,
    this.originalAmountKes,
    this.currency = 'KES',
  });

  bool get hasDiscount =>
      originalAmountKes != null && originalAmountKes! > amountKes;

  int get discountPercent => hasDiscount
      ? (((originalAmountKes! - amountKes) / originalAmountKes!) * 100).round()
      : 0;

  /// "KSh 1,200" / "KSh 22/kg" / "Negotiable"
  String get display {
    if (unit == PriceUnit.negotiableOnly || (amountKes <= 0 && negotiable)) {
      return 'Negotiable';
    }
    if (amountKes <= 0) return 'Price on request';
    final n = amountKes.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return 'KSh $n${unit.suffix}';
  }

  factory ListingPricing.fromMap(Map<String, dynamic> m) => ListingPricing(
        amountKes: (m['amountKes'] as num?)?.toDouble() ?? 0,
        unit: PriceUnit.fromString(m['unit'] as String?),
        negotiable: m['negotiable'] as bool? ?? false,
        originalAmountKes: (m['originalAmountKes'] as num?)?.toDouble(),
        currency: m['currency'] as String? ?? 'KES',
      );

  Map<String, dynamic> toMap() => {
        'amountKes': amountKes,
        'unit': unit.name,
        'negotiable': negotiable,
        'originalAmountKes': originalAmountKes,
        'currency': currency,
      };
}

/// Quantity is meaningful on both sides but means different things: kilograms
/// wanted/available on the supply side, units in stock on the creative side.
class ListingQuantity {
  final double? quantityKg;
  final double? minimumKg;
  final double? filledKg;

  /// Creative side. 0 = made to order.
  final int stockCount;

  const ListingQuantity({
    this.quantityKg,
    this.minimumKg,
    this.filledKg,
    this.stockCount = 1,
  });

  bool get isMadeToOrder => stockCount == 0;

  double get fillProgress {
    final target = quantityKg ?? 0;
    if (target <= 0) return 0;
    return ((filledKg ?? 0) / target).clamp(0, 1).toDouble();
  }

  double get remainingKg =>
      ((quantityKg ?? 0) - (filledKg ?? 0)).clamp(0, double.infinity);

  factory ListingQuantity.fromMap(Map<String, dynamic> m) => ListingQuantity(
        quantityKg: (m['quantityKg'] as num?)?.toDouble(),
        minimumKg: (m['minimumKg'] as num?)?.toDouble(),
        filledKg: (m['filledKg'] as num?)?.toDouble(),
        stockCount: (m['stockCount'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'quantityKg': quantityKg,
        'minimumKg': minimumKg,
        'filledKg': filledKg,
        'stockCount': stockCount,
      };
}

/// Who moves the goods. Carried over from the env-ops buy order flow, which
/// was the only place this was ever captured.
class ListingFulfilment {
  final bool willCollect;
  final bool acceptsDelivery;
  final bool isRecurring;

  const ListingFulfilment({
    this.willCollect = false,
    this.acceptsDelivery = false,
    this.isRecurring = false,
  });

  factory ListingFulfilment.fromMap(Map<String, dynamic> m) =>
      ListingFulfilment(
        willCollect: m['willCollect'] as bool? ?? false,
        acceptsDelivery: m['acceptsDelivery'] as bool? ?? false,
        isRecurring: m['isRecurring'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'willCollect': willCollect,
        'acceptsDelivery': acceptsDelivery,
        'isRecurring': isRecurring,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// CANOPY LISTING
// ─────────────────────────────────────────────────────────────────────────────

class CanopyListing {
  final String id;

  // ── What & which direction ──
  final ListingSide side;
  final ListingIntent intent;
  final ListingStatus status;

  // ── Content ──
  final String title;

  /// The maker's narrative. The creative side's core differentiator — a buyer
  /// in Amsterdam reads this. Optional on the supply side.
  final String story;
  final String tagline;
  final ListingCategory category;
  final List<MaterialType> materials;

  /// Supply-side taxonomy ids from assets/environmental/material_types.json.
  final String? materialSubTypeId;
  final String? materialGrade;

  final List<String> images;

  // ── Who ──
  final SellerSnapshot seller;

  /// Set when an organisation posted this (buy orders, processor listings)
  /// rather than an individual member.
  final String? orgId;
  final String? orgName;
  final String postedByUid;

  // ── Commercial ──
  final ListingPricing pricing;
  final ListingQuantity quantity;
  final ListingFulfilment fulfilment;

  // ── Provenance & impact — the moat ──
  final List<MaterialDnaLink> materialDna;
  final ListingImpact impact;
  final CircularBadgeTier circularBadge;

  // ── Where ──
  final CanopyLocation location;

  // ── Discovery ──
  final List<String> tags;
  final bool isFeatured;

  // ── Engagement ──
  final int viewCount;
  final int wishlistCount;
  final int responseCount;
  final double averageRating;
  final int reviewCount;

  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Seeking listings go stale — a buy order from March is noise in July.
  final DateTime? expiresAt;

  const CanopyListing({
    required this.id,
    this.side = ListingSide.creative,
    this.intent = ListingIntent.offering,
    this.status = ListingStatus.active,
    required this.title,
    this.story = '',
    this.tagline = '',
    this.category = ListingCategory.artisan,
    this.materials = const [],
    this.materialSubTypeId,
    this.materialGrade,
    this.images = const [],
    required this.seller,
    this.orgId,
    this.orgName,
    this.postedByUid = '',
    this.pricing = const ListingPricing(),
    this.quantity = const ListingQuantity(),
    this.fulfilment = const ListingFulfilment(),
    this.materialDna = const [],
    this.impact = const ListingImpact(),
    this.circularBadge = CircularBadgeTier.none,
    this.location = CanopyLocation.empty,
    this.tags = const [],
    this.isFeatured = false,
    this.viewCount = 0,
    this.wishlistCount = 0,
    this.responseCount = 0,
    this.averageRating = 0,
    this.reviewCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  // ── Convenience ───────────────────────────────────────────────────────────

  bool get isSeeking => intent == ListingIntent.seeking;
  bool get isOffering => intent == ListingIntent.offering;
  bool get isSupply => side == ListingSide.supply;
  bool get isCreative => side == ListingSide.creative;
  bool get isActive => status == ListingStatus.active;

  String? get coverImage => images.isNotEmpty ? images.first : null;

  bool get hasDna => materialDna.isNotEmpty;
  bool get hasOnChainDna => materialDna.any((d) => d.isOnChain);
  bool get hasOnPlatformSource => materialDna.any((d) => d.isOnPlatform);

  /// Collectors named in this item's provenance chain. The narrative anchor:
  /// the collector who picked up the plastic in Kibera is named on the tag in
  /// Amsterdam — so the names have to survive into the listing.
  List<String> get creditedCollectors => materialDna
      .map((d) => d.collectorName)
      .whereType<String>()
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList();

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Card badge copy: "Wanted · Materials", "For sale · Made".
  String get typeLabel => '${intent.label} · ${side.label}';

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory CanopyListing.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CanopyListing.fromMap(doc.id, d);
  }

  factory CanopyListing.fromMap(String id, Map<String, dynamic> d) {
    return CanopyListing(
      id: id,
      side: ListingSide.fromString(d['side'] as String?),
      intent: ListingIntent.fromString(
          (d['intent'] ?? d['listing_type'] ?? d['orderType']) as String?),
      status: ListingStatus.fromString(d['status'] as String?),
      title: d['title'] as String? ?? '',
      story: d['story'] as String? ?? '',
      tagline: d['tagline'] as String? ?? '',
      category:
          ListingCategory.fromString(d['category'] as String? ?? 'artisan'),
      materials: (d['materials'] as List<dynamic>?)
              ?.map((e) => MaterialType.fromString(e as String))
              .toList() ??
          const [],
      materialSubTypeId: d['materialSubTypeId'] as String?,
      materialGrade: d['materialGrade'] as String?,
      images: (d['images'] as List<dynamic>?)?.cast<String>() ?? const [],
      seller:
          SellerSnapshot.fromMap(d['seller'] as Map<String, dynamic>? ?? {}),
      orgId: d['orgId'] as String?,
      orgName: d['orgName'] as String?,
      postedByUid: d['postedByUid'] as String? ?? '',
      pricing:
          ListingPricing.fromMap(d['pricing'] as Map<String, dynamic>? ?? {}),
      quantity:
          ListingQuantity.fromMap(d['quantity'] as Map<String, dynamic>? ?? {}),
      fulfilment: ListingFulfilment.fromMap(
          d['fulfilment'] as Map<String, dynamic>? ?? {}),
      materialDna: (d['materialDna'] as List<dynamic>?)
              ?.map((e) => MaterialDnaLink.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      impact: ListingImpact.fromMap(d['impact'] as Map<String, dynamic>? ?? {}),
      circularBadge:
          CircularBadgeTier.fromString(d['circularBadge'] as String? ?? 'none'),
      location: CanopyLocation.fromFirestore(d),
      tags: (d['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      isFeatured: d['isFeatured'] as bool? ?? false,
      viewCount: (d['viewCount'] as num?)?.toInt() ?? 0,
      wishlistCount: (d['wishlistCount'] as num?)?.toInt() ?? 0,
      responseCount: (d['responseCount'] as num?)?.toInt() ?? 0,
      averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (d['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'side': side.firestoreKey,
        'intent': intent.firestoreKey,
        'status': status.name,
        'title': title,
        'story': story,
        'tagline': tagline,
        'category': category.name,
        'materials': materials.map((m) => m.name).toList(),
        'materialSubTypeId': materialSubTypeId,
        'materialGrade': materialGrade,
        'images': images,
        'seller': seller.toMap(),
        'orgId': orgId,
        'orgName': orgName,
        'postedByUid': postedByUid,
        'pricing': pricing.toMap(),
        'quantity': quantity.toMap(),
        'fulfilment': fulfilment.toMap(),
        'materialDna': materialDna.map((d) => d.toMap()).toList(),
        'impact': impact.toMap(),
        'circularBadge': circularBadge.name,
        'tags': tags,
        'isFeatured': isFeatured,
        'viewCount': viewCount,
        'wishlistCount': wishlistCount,
        'responseCount': responseCount,
        'averageRating': averageRating,
        'reviewCount': reviewCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'expiresAt':
            expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        // Geography spread flat so every tier is a single-field predicate.
        ...location.toFirestore(),
      };

  CanopyListing copyWith({
    ListingSide? side,
    ListingIntent? intent,
    ListingStatus? status,
    String? title,
    String? story,
    ListingPricing? pricing,
    ListingQuantity? quantity,
    CanopyLocation? location,
    List<MaterialDnaLink>? materialDna,
    ListingImpact? impact,
    CircularBadgeTier? circularBadge,
    int? responseCount,
    DateTime? updatedAt,
  }) {
    return CanopyListing(
      id: id,
      side: side ?? this.side,
      intent: intent ?? this.intent,
      status: status ?? this.status,
      title: title ?? this.title,
      story: story ?? this.story,
      tagline: tagline,
      category: category,
      materials: materials,
      materialSubTypeId: materialSubTypeId,
      materialGrade: materialGrade,
      images: images,
      seller: seller,
      orgId: orgId,
      orgName: orgName,
      postedByUid: postedByUid,
      pricing: pricing ?? this.pricing,
      quantity: quantity ?? this.quantity,
      fulfilment: fulfilment,
      materialDna: materialDna ?? this.materialDna,
      impact: impact ?? this.impact,
      circularBadge: circularBadge ?? this.circularBadge,
      location: location ?? this.location,
      tags: tags,
      isFeatured: isFeatured,
      viewCount: viewCount,
      wishlistCount: wishlistCount,
      responseCount: responseCount ?? this.responseCount,
      averageRating: averageRating,
      reviewCount: reviewCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt,
    );
  }

  // ── Legacy migration ──────────────────────────────────────────────────────

  /// Reads a document from the retired `market_listings` collection (snake_case,
  /// org-scoped, free-text location) into the unified shape. Used by the
  /// backfill and as a read-time fallback so nothing disappears mid-migration.
  factory CanopyListing.fromLegacyMarketListing(
    String id,
    Map<String, dynamic> d, {
    CanopyLocation? resolvedLocation,
  }) {
    final qty = (d['quantity_kg'] as num?)?.toDouble();
    return CanopyListing(
      id: id,
      side: ListingSide.supply,
      intent: ListingIntent.fromString(d['listing_type'] as String?),
      status: (d['status'] as String?) == 'active'
          ? ListingStatus.active
          : ListingStatus.closed,
      title: (d['sub_type_label'] as String?)?.isNotEmpty == true
          ? d['sub_type_label'] as String
          : (d['category_label'] as String? ?? 'Material listing'),
      story: d['notes'] as String? ?? '',
      tagline: d['category_label'] as String? ?? '',
      category: ListingCategory.materials,
      materialSubTypeId: d['sub_type_id'] as String?,
      materialGrade: d['grade'] as String?,
      images: [
        if ((d['image_url'] as String?)?.isNotEmpty == true)
          d['image_url'] as String
      ],
      seller: SellerSnapshot(
        sellerId: d['posted_by_uid'] as String? ?? '',
        shopName: d['org_name'] as String? ?? '',
        city: resolvedLocation?.countyName ?? '',
      ),
      orgId: d['org_id'] as String?,
      orgName: d['org_name'] as String?,
      postedByUid: d['posted_by_uid'] as String? ?? '',
      pricing: ListingPricing(
        amountKes: (d['price_per_unit'] as num?)?.toDouble() ?? 0,
        unit: (d['unit'] as String?) == 'kg'
            ? PriceUnit.perKg
            : PriceUnit.perItem,
      ),
      quantity: ListingQuantity(quantityKg: qty, stockCount: 1),
      fulfilment: ListingFulfilment(
        willCollect: d['can_collect'] as bool? ?? false,
        acceptsDelivery: d['can_deliver'] as bool? ?? false,
        isRecurring: d['is_recurring'] as bool? ?? false,
      ),
      location: resolvedLocation ??
          CanopyLocation(venue: d['location_text'] as String?),
      responseCount: (d['responses_count'] as num?)?.toInt() ?? 0,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSE — a member answering a seeking listing
//
// Firestore: /listings/{listingId}/responses/{responseId}
// This is the mechanism that makes "wanted" posts actionable rather than
// decorative: a collector sees a processor's buy order for 500kg of PET in
// their county and offers 80kg against it.
// ─────────────────────────────────────────────────────────────────────────────

class ListingResponse {
  final String id;
  final String listingId;
  final String responderUid;
  final String responderName;
  final String? responderPhotoUrl;

  /// What they can supply / want to buy against this listing.
  final double? quantityKg;
  final double? offeredPriceKes;
  final String message;

  /// pending | accepted | declined | completed
  final String status;
  final DateTime createdAt;

  const ListingResponse({
    required this.id,
    required this.listingId,
    required this.responderUid,
    required this.responderName,
    this.responderPhotoUrl,
    this.quantityKg,
    this.offeredPriceKes,
    this.message = '',
    this.status = 'pending',
    required this.createdAt,
  });

  factory ListingResponse.fromFirestore(String listingId, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ListingResponse(
      id: doc.id,
      listingId: listingId,
      responderUid: d['responderUid'] as String? ?? '',
      responderName: d['responderName'] as String? ?? '',
      responderPhotoUrl: d['responderPhotoUrl'] as String?,
      quantityKg: (d['quantityKg'] as num?)?.toDouble(),
      offeredPriceKes: (d['offeredPriceKes'] as num?)?.toDouble(),
      message: d['message'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'responderUid': responderUid,
        'responderName': responderName,
        'responderPhotoUrl': responderPhotoUrl,
        'quantityKg': quantityKg,
        'offeredPriceKes': offeredPriceKes,
        'message': message,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
