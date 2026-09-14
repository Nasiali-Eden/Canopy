import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Models/marketplace/marketplace_seller_profile.dart';

class MarketplaceSellerRepository {
  final FirebaseFirestore _db;

  MarketplaceSellerRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Stream<MarketplaceSellerProfile?> watch(String sellerId) {
    if (sellerId.trim().isEmpty) return Stream.value(null);
    return _db.collection('marketplace_sellers').doc(sellerId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        return MarketplaceSellerProfile.fromMap(snapshot.id, data);
      },
    );
  }

  Future<MarketplaceSellerProfile?> fetch(String sellerId) async {
    if (sellerId.trim().isEmpty) return null;
    final primary =
        await _db.collection('marketplace_sellers').doc(sellerId).get();
    if (primary.exists && primary.data() != null) {
      return MarketplaceSellerProfile.fromMap(primary.id, primary.data()!);
    }

    // Read-only compatibility for marketplace data written before seller
    // registration moved to /marketplace_sellers.
    final legacy = await _db.collection('sellers').doc(sellerId).get();
    if (legacy.exists && legacy.data() != null) {
      return MarketplaceSellerProfile.fromMap(legacy.id, legacy.data()!);
    }
    return null;
  }
}
