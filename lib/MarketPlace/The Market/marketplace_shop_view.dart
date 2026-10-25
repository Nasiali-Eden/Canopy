// lib/MarketPlace/The Market/marketplace_shop_view.dart
//
// Buyer › A maker's shop (MARKETPLACE_SELLER_DESIGN_BRIEF §4, T). Shop
// header (banner, logo, name, location, bio, specialisations) and the
// maker's live listings. Impact figures appear only when recorded on the
// seller's profile — no invented royalties or collector counts.

import 'package:flutter/material.dart' hide MaterialType;

import '../../Models/marketplace/canopy_listing.dart';
import '../../Models/marketplace/marketplace_seller_profile.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../Services/Marketplace/marketplace_seller_repository.dart';
import '../../theme/canopy_components.dart';
import '../market_ui.dart';
import 'marketplace_item_view.dart';

class MarketplaceShopViewScreen extends StatefulWidget {
  final String sellerId;

  const MarketplaceShopViewScreen({super.key, required this.sellerId});

  @override
  State<MarketplaceShopViewScreen> createState() => _MarketplaceShopViewScreenState();
}

class _MarketplaceShopViewScreenState extends State<MarketplaceShopViewScreen> {
  late Future<MarketplaceSellerProfile?> _shop = MarketplaceSellerRepository().fetch(widget.sellerId);

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: ''),
      body: FutureBuilder<MarketplaceSellerProfile?>(
        future: _shop,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(
                title: "Couldn't load this shop", onRetry: () => setState(() => _shop = MarketplaceSellerRepository().fetch(widget.sellerId)));
          }
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final shop = snap.data;
          if (shop == null) return const CanopyEmptyState(icon: Icons.storefront_outlined, title: 'This shop isn\'t on Canopy any more');
          return StreamBuilder<List<CanopyListing>>(
            stream: ListingService.instance.watchByMember(widget.sellerId),
            builder: (context, ls) {
              final live = (ls.data ?? const <CanopyListing>[]).where((l) => l.isActive && l.isOffering).toList();
              return CustomScrollView(slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, 0),
                  sliver: SliverList.list(children: [
                    ShopHeader(shop: shop),
                    if (shop.kgDiverted > 0 || shop.totalSales > 0) ...[
                      const SizedBox(height: CanopySpace.s16),
                      Row(children: [
                        if (shop.kgDiverted > 0)
                          Expanded(
                            child: CanopyStatTile(
                                value: shop.kgDiverted.toStringAsFixed(shop.kgDiverted < 10 ? 1 : 0), label: 'Kg of material reused', ruled: true),
                          ),
                        if (shop.kgDiverted > 0 && shop.totalSales > 0) const SizedBox(width: CanopySpace.s12),
                        if (shop.totalSales > 0) Expanded(child: CanopyStatTile(value: '${shop.totalSales}', label: 'Sales', ruled: true)),
                      ]),
                    ],
                    CanopySectionHeader(title: 'In the shop · ${live.length}', padding: const EdgeInsets.only(top: CanopySpace.section)),
                    if (ls.hasError)
                      const CanopyErrorState(inline: true, title: "Couldn't load listings.")
                    else if (!ls.hasData)
                      const CanopyCardSkeleton()
                    else if (live.isEmpty)
                      Text('Nothing for sale right now.', style: CanopyType.body.copyWith(color: p.inkMuted)),
                  ]),
                ),
                if (live.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: CanopySpace.s16,
                        crossAxisSpacing: CanopySpace.s12,
                        childAspectRatio: .56,
                      ),
                      itemCount: live.length,
                      itemBuilder: (_, i) => ProductCard(
                        listing: live[i],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarketplaceItemViewScreen(listingId: live[i].id))),
                      ),
                    ),
                  ),
              ]);
            },
          );
        },
      ),
    );
  }
}
