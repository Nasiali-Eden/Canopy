class MarketplaceSellerProfile {
  final String id;
  final String name;
  final String role;
  final String bio;
  final String city;
  final String area;
  final String? logoUrl;
  final String? bannerUrl;
  final List<String> specialisations;
  final List<String> categories;
  final double kgDiverted;
  final int activeListings;
  final int totalSales;
  final double rating;
  final bool verified;
  final DateTime? createdAt;

  const MarketplaceSellerProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.bio,
    required this.city,
    required this.area,
    required this.logoUrl,
    required this.bannerUrl,
    required this.specialisations,
    required this.categories,
    required this.kgDiverted,
    required this.activeListings,
    required this.totalSales,
    required this.rating,
    required this.verified,
    required this.createdAt,
  });

  String get location => [
        if (area.trim().isNotEmpty) area.trim(),
        if (city.trim().isNotEmpty && city.trim() != area.trim()) city.trim(),
      ].join(', ');

  String get initials {
    final words =
        name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    return words.take(2).map((word) => word[0]).join();
  }

  factory MarketplaceSellerProfile.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    T? value<T>(List<String> keys) {
      for (final key in keys) {
        final candidate = data[key];
        if (candidate is T) return candidate;
      }
      return null;
    }

    List<String> strings(List<String> keys) {
      final raw = value<List<dynamic>>(keys);
      return raw
              ?.whereType<Object>()
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [];
    }

    DateTime? date(List<String> keys) {
      final raw = keys.map((key) => data[key]).whereType<Object?>().firstOrNull;
      if (raw is DateTime) return raw;
      // Avoid a Firestore dependency in this value model. Timestamp-like
      // objects expose toDate and are handled dynamically at the boundary.
      try {
        final converted = (raw as dynamic)?.toDate();
        return converted is DateTime ? converted : null;
      } catch (_) {
        return null;
      }
    }

    return MarketplaceSellerProfile(
      id: id,
      name: value<String>(['shop_name', 'shopName', 'name']) ?? 'Canopy seller',
      role: value<String>(['marketplace_role', 'marketplaceRole', 'role']) ??
          'Marketplace seller',
      bio: value<String>(['bio', 'story', 'description']) ?? '',
      city: value<String>(['city', 'county']) ?? '',
      area: value<String>(['area', 'location']) ?? '',
      logoUrl: value<String>(['shop_logo_url', 'shopLogoUrl', 'logoUrl']),
      bannerUrl: value<String>(['banner_url', 'bannerUrl']),
      specialisations: strings(
        ['specialisations', 'materialSpecialties', 'materials'],
      ),
      categories: strings(['creative_categories', 'categories']),
      kgDiverted:
          (value<num>(['kg_diverted', 'totalKgDiverted']) ?? 0).toDouble(),
      activeListings:
          (value<num>(['active_listings', 'totalListings']) ?? 0).toInt(),
      totalSales: (value<num>(['total_sales', 'totalSales']) ?? 0).toInt(),
      rating: (value<num>(['average_rating', 'averageRating']) ?? 0).toDouble(),
      verified: value<bool>(['verified', 'isVerified']) ?? false,
      createdAt: date(['createdAt', 'created_at', 'memberSince']),
    );
  }
}
