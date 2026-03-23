import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum ListingCategory {
  artisan,    // Creative side — finished goods
  materials,  // Supply side — raw / processed
  processed,  // Supply side — refined outputs (pellets, sheets, etc.)
  fashion,
  sculpture,
  furniture,
  jewellery,
  homeware,
  prints,
  ceramics;

  String get label {
    switch (this) {
      case ListingCategory.artisan:     return 'Artisan';
      case ListingCategory.materials:   return 'Materials';
      case ListingCategory.processed:   return 'Processed';
      case ListingCategory.fashion:     return 'Fashion';
      case ListingCategory.sculpture:   return 'Sculpture';
      case ListingCategory.furniture:   return 'Furniture';
      case ListingCategory.jewellery:   return 'Jewellery';
      case ListingCategory.homeware:    return 'Homeware';
      case ListingCategory.prints:      return 'Prints';
      case ListingCategory.ceramics:    return 'Ceramics';
    }
  }

  String get emoji {
    switch (this) {
      case ListingCategory.artisan:     return '🎨';
      case ListingCategory.materials:   return '♻️';
      case ListingCategory.processed:   return '⚙️';
      case ListingCategory.fashion:     return '👗';
      case ListingCategory.sculpture:   return '🗿';
      case ListingCategory.furniture:   return '🪑';
      case ListingCategory.jewellery:   return '💍';
      case ListingCategory.homeware:    return '🏺';
      case ListingCategory.prints:      return '🖼️';
      case ListingCategory.ceramics:    return '🏺';
    }
  }

  static ListingCategory fromString(String v) {
    return ListingCategory.values.firstWhere(
          (e) => e.name.toLowerCase() == v.toLowerCase(),
      orElse: () => ListingCategory.artisan,
    );
  }
}

enum MaterialType {
  plastic,
  metal,
  glass,
  paper,
  rubber,
  wood,
  textile,
  electronics,
  mixed;

  String get label {
    switch (this) {
      case MaterialType.plastic:      return 'Plastic';
      case MaterialType.metal:        return 'Metal';
      case MaterialType.glass:        return 'Glass';
      case MaterialType.paper:        return 'Paper & Cardboard';
      case MaterialType.rubber:       return 'Rubber';
      case MaterialType.wood:         return 'Reclaimed Wood';
      case MaterialType.textile:      return 'Textile';
      case MaterialType.electronics:  return 'Electronics';
      case MaterialType.mixed:        return 'Mixed';
    }
  }

  static MaterialType fromString(String v) {
    return MaterialType.values.firstWhere(
          (e) => e.name.toLowerCase() == v.toLowerCase(),
      orElse: () => MaterialType.mixed,
    );
  }
}

enum CircularBadgeTier {
  none,
  standard,   // Open maker — declared but not on-platform sourced
  verified;   // Circular Craft Badge — on-platform sourced

  String get label {
    switch (this) {
      case CircularBadgeTier.none:      return 'Unverified';
      case CircularBadgeTier.standard:  return 'Maker';
      case CircularBadgeTier.verified:  return 'Circular Craft';
    }
  }

  static CircularBadgeTier fromString(String v) {
    return CircularBadgeTier.values.firstWhere(
          (e) => e.name.toLowerCase() == v.toLowerCase(),
      orElse: () => CircularBadgeTier.none,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MATERIAL DNA — provenance chain node
// Each link in the chain: collector → processor → maker
// ─────────────────────────────────────────────────────────────────────────────

class MaterialDnaLink {
  /// Who collected it — collector's Canopy user ID
  final String? collectorId;
  final String? collectorName;
  final String? collectorCity;      // e.g. "Kibera, Nairobi"
  final String? collectionSite;     // e.g. "Nairobi River, near Mathare bridge"
  final DateTime? collectionDate;
  final double? weightKg;
  final MaterialType material;

  /// Processor step (optional — may go collector → maker directly)
  final String? processorId;
  final String? processorName;

  /// On-chain Cardano transaction hash for this link (if anchored)
  final String? cardanoTxHash;

  /// Supply-side listing ID this material came from (on-platform sourcing)
  final String? supplyListingId;

  const MaterialDnaLink({
    this.collectorId,
    this.collectorName,
    this.collectorCity,
    this.collectionSite,
    this.collectionDate,
    this.weightKg,
    this.material = MaterialType.mixed,
    this.processorId,
    this.processorName,
    this.cardanoTxHash,
    this.supplyListingId,
  });

  factory MaterialDnaLink.fromMap(Map<String, dynamic> m) {
    return MaterialDnaLink(
      collectorId:      m['collectorId'] as String?,
      collectorName:    m['collectorName'] as String?,
      collectorCity:    m['collectorCity'] as String?,
      collectionSite:   m['collectionSite'] as String?,
      collectionDate:   (m['collectionDate'] as Timestamp?)?.toDate(),
      weightKg:         (m['weightKg'] as num?)?.toDouble(),
      material:         MaterialType.fromString(m['material'] as String? ?? 'mixed'),
      processorId:      m['processorId'] as String?,
      processorName:    m['processorName'] as String?,
      cardanoTxHash:    m['cardanoTxHash'] as String?,
      supplyListingId:  m['supplyListingId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'collectorId':    collectorId,
    'collectorName':  collectorName,
    'collectorCity':  collectorCity,
    'collectionSite': collectionSite,
    'collectionDate': collectionDate != null
        ? Timestamp.fromDate(collectionDate!)
        : null,
    'weightKg':       weightKg,
    'material':       material.name,
    'processorId':    processorId,
    'processorName':  processorName,
    'cardanoTxHash':  cardanoTxHash,
    'supplyListingId':supplyListingId,
  };

  /// True if this link is anchored on Cardano
  bool get isOnChain => cardanoTxHash != null && cardanoTxHash!.isNotEmpty;

  /// True if sourced directly through Canopy supply-side marketplace
  bool get isOnPlatform => supplyListingId != null && supplyListingId!.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// SELLER / SHOP SNAPSHOT — denormalized on the listing
// ─────────────────────────────────────────────────────────────────────────────

class SellerSnapshot {
  final String sellerId;
  final String shopName;
  final String? shopLogoUrl;
  final String city;
  final String country;
  final CircularBadgeTier badgeTier;
  final double averageRating;
  final int totalSales;

  const SellerSnapshot({
    required this.sellerId,
    required this.shopName,
    this.shopLogoUrl,
    required this.city,
    this.country = 'Kenya',
    this.badgeTier = CircularBadgeTier.none,
    this.averageRating = 0.0,
    this.totalSales = 0,
  });

  factory SellerSnapshot.fromMap(Map<String, dynamic> m) {
    return SellerSnapshot(
      sellerId:       m['sellerId'] as String? ?? '',
      shopName:       m['shopName'] as String? ?? '',
      shopLogoUrl:    m['shopLogoUrl'] as String?,
      city:           m['city'] as String? ?? '',
      country:        m['country'] as String? ?? 'Kenya',
      badgeTier:      CircularBadgeTier.fromString(m['badgeTier'] as String? ?? 'none'),
      averageRating:  (m['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalSales:     (m['totalSales'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'sellerId':       sellerId,
    'shopName':       shopName,
    'shopLogoUrl':    shopLogoUrl,
    'city':           city,
    'country':        country,
    'badgeTier':      badgeTier.name,
    'averageRating':  averageRating,
    'totalSales':     totalSales,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPACT METRICS — environmental story of the item
// ─────────────────────────────────────────────────────────────────────────────

class ListingImpact {
  /// kg of material diverted from landfill / environment
  final double kgDiverted;

  /// Canopy impact score (0–100) — higher = more harmful material saved
  final int impactScore;

  /// Number of collectors credited in this item's DNA
  final int collectorsCredited;

  /// If sold: royalty already paid to collectors (KES)
  final double royaltyPaidKes;

  const ListingImpact({
    this.kgDiverted = 0,
    this.impactScore = 0,
    this.collectorsCredited = 0,
    this.royaltyPaidKes = 0,
  });

  factory ListingImpact.fromMap(Map<String, dynamic> m) {
    return ListingImpact(
      kgDiverted:         (m['kgDiverted'] as num?)?.toDouble() ?? 0,
      impactScore:        (m['impactScore'] as num?)?.toInt() ?? 0,
      collectorsCredited: (m['collectorsCredited'] as num?)?.toInt() ?? 0,
      royaltyPaidKes:     (m['royaltyPaidKes'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'kgDiverted':         kgDiverted,
    'impactScore':        impactScore,
    'collectorsCredited': collectorsCredited,
    'royaltyPaidKes':     royaltyPaidKes,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE LISTING — core model
// Firestore path: /listings/{listingId}
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceListing {
  final String id;
  final String title;

  /// The "Story" — maker's narrative about the object, its origin, the process.
  /// Minimum 80 chars enforced at creation. This is the listing's core differentiator.
  final String story;

  /// Short tagline (shown on cards)
  final String tagline;

  final ListingCategory category;
  final List<MaterialType> materials;

  /// Primary image first; up to 6 slots
  final List<String> images;

  final SellerSnapshot seller;
  final ListingImpact impact;

  /// Material DNA — provenance chain. Multiple links for multi-material pieces.
  final List<MaterialDnaLink> materialDna;

  // Pricing
  final double priceKes;
  final double? originalPriceKes;   // if discounted
  final bool isFeatured;
  final bool isAvailable;
  final int stockCount;             // 0 = made-to-order

  // Location
  final String city;
  final String country;
  final String continent;           // 'Africa', 'Europe', etc.

  // Tags — searchable keywords
  final List<String> tags;

  final DateTime createdAt;
  final DateTime? updatedAt;

  // Engagement
  final int viewCount;
  final int wishlistCount;
  final double averageRating;
  final int reviewCount;

  // Circular Craft Badge — computed from seller + DNA
  final CircularBadgeTier circularBadge;

  const MarketplaceListing({
    required this.id,
    required this.title,
    required this.story,
    this.tagline = '',
    required this.category,
    this.materials = const [],
    this.images = const [],
    required this.seller,
    this.impact = const ListingImpact(),
    this.materialDna = const [],
    required this.priceKes,
    this.originalPriceKes,
    this.isFeatured = false,
    this.isAvailable = true,
    this.stockCount = 1,
    required this.city,
    this.country = 'Kenya',
    this.continent = 'Africa',
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.wishlistCount = 0,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.circularBadge = CircularBadgeTier.none,
  });

  // ── Convenience ──────────────────────────────────────────────────────────

  String? get coverImage => images.isNotEmpty ? images.first : null;

  bool get hasDiscount =>
      originalPriceKes != null && originalPriceKes! > priceKes;

  int get discountPercent => hasDiscount
      ? (((originalPriceKes! - priceKes) / originalPriceKes!) * 100).round()
      : 0;

  bool get hasDna => materialDna.isNotEmpty;

  bool get hasMadeToOrder => stockCount == 0;

  bool get hasOnChainDna => materialDna.any((d) => d.isOnChain);

  bool get hasOnPlatformSource => materialDna.any((d) => d.isOnPlatform);

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory MarketplaceListing.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MarketplaceListing(
      id:               doc.id,
      title:            d['title'] as String? ?? '',
      story:            d['story'] as String? ?? '',
      tagline:          d['tagline'] as String? ?? '',
      category:         ListingCategory.fromString(d['category'] as String? ?? 'artisan'),
      materials:        (d['materials'] as List<dynamic>?)
          ?.map((e) => MaterialType.fromString(e as String))
          .toList() ?? [],
      images:           (d['images'] as List<dynamic>?)?.cast<String>() ?? [],
      seller:           SellerSnapshot.fromMap(d['seller'] as Map<String, dynamic>? ?? {}),
      impact:           ListingImpact.fromMap(d['impact'] as Map<String, dynamic>? ?? {}),
      materialDna:      (d['materialDna'] as List<dynamic>?)
          ?.map((e) => MaterialDnaLink.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      priceKes:         (d['priceKes'] as num?)?.toDouble() ?? 0,
      originalPriceKes: (d['originalPriceKes'] as num?)?.toDouble(),
      isFeatured:       d['isFeatured'] as bool? ?? false,
      isAvailable:      d['isAvailable'] as bool? ?? true,
      stockCount:       (d['stockCount'] as num?)?.toInt() ?? 1,
      city:             d['city'] as String? ?? '',
      country:          d['country'] as String? ?? 'Kenya',
      continent:        d['continent'] as String? ?? 'Africa',
      tags:             (d['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt:        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:        (d['updatedAt'] as Timestamp?)?.toDate(),
      viewCount:        (d['viewCount'] as num?)?.toInt() ?? 0,
      wishlistCount:    (d['wishlistCount'] as num?)?.toInt() ?? 0,
      averageRating:    (d['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount:      (d['reviewCount'] as num?)?.toInt() ?? 0,
      circularBadge:    CircularBadgeTier.fromString(d['circularBadge'] as String? ?? 'none'),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title':            title,
    'story':            story,
    'tagline':          tagline,
    'category':         category.name,
    'materials':        materials.map((m) => m.name).toList(),
    'images':           images,
    'seller':           seller.toMap(),
    'impact':           impact.toMap(),
    'materialDna':      materialDna.map((d) => d.toMap()).toList(),
    'priceKes':         priceKes,
    'originalPriceKes': originalPriceKes,
    'isFeatured':       isFeatured,
    'isAvailable':      isAvailable,
    'stockCount':       stockCount,
    'city':             city,
    'country':          country,
    'continent':        continent,
    'tags':             tags,
    'createdAt':        Timestamp.fromDate(createdAt),
    'updatedAt':        updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    'viewCount':        viewCount,
    'wishlistCount':    wishlistCount,
    'averageRating':    averageRating,
    'reviewCount':      reviewCount,
    'circularBadge':    circularBadge.name,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOP / SELLER MODEL
// Firestore path: /sellers/{sellerId}
// ─────────────────────────────────────────────────────────────────────────────

class CanopyShop {
  final String id;
  final String shopName;
  final String? shopLogoUrl;
  final String? bannerUrl;
  final String bio;           // The maker's story
  final String city;
  final String country;
  final String continent;
  final CircularBadgeTier badgeTier;
  final List<String> materialSpecialties; // e.g. ['copper', 'glass']
  final List<String> categories;
  final double averageRating;
  final int totalSales;
  final int totalListings;
  final DateTime memberSince;
  final double totalKgDiverted;  // cumulative impact
  final int collectorsSupported; // collectors they've sourced from

  // Social
  final String? instagramHandle;
  final String? whatsappNumber;

  const CanopyShop({
    required this.id,
    required this.shopName,
    this.shopLogoUrl,
    this.bannerUrl,
    required this.bio,
    required this.city,
    this.country = 'Kenya',
    this.continent = 'Africa',
    this.badgeTier = CircularBadgeTier.none,
    this.materialSpecialties = const [],
    this.categories = const [],
    this.averageRating = 0.0,
    this.totalSales = 0,
    this.totalListings = 0,
    required this.memberSince,
    this.totalKgDiverted = 0,
    this.collectorsSupported = 0,
    this.instagramHandle,
    this.whatsappNumber,
  });

  factory CanopyShop.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CanopyShop(
      id:                   doc.id,
      shopName:             d['shopName'] as String? ?? '',
      shopLogoUrl:          d['shopLogoUrl'] as String?,
      bannerUrl:            d['bannerUrl'] as String?,
      bio:                  d['bio'] as String? ?? '',
      city:                 d['city'] as String? ?? '',
      country:              d['country'] as String? ?? 'Kenya',
      continent:            d['continent'] as String? ?? 'Africa',
      badgeTier:            CircularBadgeTier.fromString(d['badgeTier'] as String? ?? 'none'),
      materialSpecialties:  (d['materialSpecialties'] as List<dynamic>?)?.cast<String>() ?? [],
      categories:           (d['categories'] as List<dynamic>?)?.cast<String>() ?? [],
      averageRating:        (d['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalSales:           (d['totalSales'] as num?)?.toInt() ?? 0,
      totalListings:        (d['totalListings'] as num?)?.toInt() ?? 0,
      memberSince:          (d['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalKgDiverted:      (d['totalKgDiverted'] as num?)?.toDouble() ?? 0,
      collectorsSupported:  (d['collectorsSupported'] as num?)?.toInt() ?? 0,
      instagramHandle:      d['instagramHandle'] as String?,
      whatsappNumber:       d['whatsappNumber'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART ITEM & ORDER — for checkout flow
// ─────────────────────────────────────────────────────────────────────────────

class CartItem {
  final MarketplaceListing listing;
  int quantity;

  CartItem({required this.listing, this.quantity = 1});

  double get subtotal => listing.priceKes * quantity;
}

class CanopyOrder {
  final String id;
  final String buyerId;
  final List<CartItem> items;
  final double totalKes;
  final String paymentMethod;   // 'mpesa'
  final String? mpesaRef;
  final String deliveryAddress;
  final String status;          // 'pending', 'confirmed', 'shipped', 'delivered'
  final DateTime createdAt;

  const CanopyOrder({
    required this.id,
    required this.buyerId,
    required this.items,
    required this.totalKes,
    this.paymentMethod = 'mpesa',
    this.mpesaRef,
    required this.deliveryAddress,
    this.status = 'pending',
    required this.createdAt,
  });

  double get platformFee => totalKes * 0.05;     // 5% platform commission
  double get collectorRoyalty => totalKes * 0.04; // 4% flows to collectors
  double get sellerReceives => totalKes - platformFee;
}