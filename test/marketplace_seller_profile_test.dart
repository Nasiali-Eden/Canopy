import 'package:flutter_test/flutter_test.dart';
import 'package:impact_trail/Models/marketplace/marketplace_seller_profile.dart';

void main() {
  test('reads the snake_case registration schema', () {
    final profile = MarketplaceSellerProfile.fromMap('seller-1', {
      'shop_name': 'River Loop Studio',
      'marketplace_role': 'Maker',
      'shop_logo_url': 'logo.png',
      'specialisations': ['plastic', 'glass'],
      'creative_categories': ['homeware'],
      'kg_diverted': 42.5,
      'active_listings': 3,
      'city': 'Nairobi',
      'area': 'Kibera',
    });

    expect(profile.name, 'River Loop Studio');
    expect(profile.location, 'Kibera, Nairobi');
    expect(profile.specialisations, ['plastic', 'glass']);
    expect(profile.kgDiverted, 42.5);
    expect(profile.activeListings, 3);
  });

  test('reads the legacy camelCase marketplace schema', () {
    final profile = MarketplaceSellerProfile.fromMap('seller-2', {
      'shopName': 'Second Life Works',
      'shopLogoUrl': 'legacy.png',
      'materialSpecialties': ['copper'],
      'totalKgDiverted': 18,
      'totalListings': 7,
      'averageRating': 4.8,
    });

    expect(profile.name, 'Second Life Works');
    expect(profile.logoUrl, 'legacy.png');
    expect(profile.specialisations, ['copper']);
    expect(profile.rating, 4.8);
  });
}
