// lib/MarketPlace/Feed/seller_feed.dart
//
// Seller › Feed (MARKETPLACE_SELLER_DESIGN_BRIEF §4, T). Seller stat strip
// (only real numbers) → new buyer requests → materials wanted near you (from
// the materials market, so makers can source on-platform) → latest from the
// community. Every section is live data with an honest empty state.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:provider/provider.dart';

import '../../Community/Articles/article_card.dart';
import '../../Models/marketplace/canopy_listing.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../theme/canopy_components.dart';
import '../The Market/marketplace_item_view.dart';
import '../market_ui.dart';

class SellerFeedPage extends StatelessWidget {
  const SellerFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const CanopyScaffold(body: CanopySignedOutState());
    final here = context.watch<LocationProvider>().filter;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Marketplace', showBack: false),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('marketplace_sellers').doc(uid).snapshots(),
        builder: (context, seller) {
          final d = seller.data?.data() ?? const <String, dynamic>{};
          final kg = (d['kg_diverted'] as num?)?.toDouble() ?? 0;
          final points = (d['impact_points'] as num?)?.toInt() ?? 0;
          return StreamBuilder<List<CanopyListing>>(
            stream: ListingService.instance.watchByMember(uid),
            builder: (context, mine) {
              final listings = (mine.data ?? const <CanopyListing>[]).where((l) => l.isCreative && l.status != ListingStatus.closed).toList();
              final withRequests = listings.where((l) => l.responseCount > 0).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
                children: [
                  if ((d['shop_name'] as String?)?.isNotEmpty ?? false)
                    Text('Hello, ${d['shop_name']}', style: CanopyType.title.copyWith(color: p.ink)),
                  const SizedBox(height: CanopySpace.s16),
                  SellerStatStrip(
                    liveListings: listings.where((l) => l.isActive).length,
                    requests: withRequests.fold(0, (s, l) => s + l.responseCount),
                    kgDiverted: kg,
                    impactPoints: points,
                  ),
                  const CanopySectionHeader(title: 'Buyer requests', padding: EdgeInsets.only(top: CanopySpace.section)),
                  if (withRequests.isEmpty)
                    Text(listings.isEmpty ? 'List something in your Shop — requests from buyers arrive here.' : 'No requests yet.',
                        style: CanopyType.body.copyWith(color: p.inkMuted))
                  else
                    CanopyCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < withRequests.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.outline),
                          InventoryRow(listing: withRequests[i], onTap: () => showListingResponses(context, withRequests[i])),
                        ],
                      ]),
                    ),
                  const CanopySectionHeader(title: 'Material for sale near you', padding: EdgeInsets.only(top: CanopySpace.section)),
                  StreamBuilder<List<CanopyListing>>(
                    stream: ListingService.instance.watch(ListingQuery(location: here, side: ListingSide.supply, intent: ListingIntent.offering), limit: 20),
                    builder: (context, snap) {
                      if (snap.hasError) return const CanopyErrorState(inline: true, title: "Couldn't load the materials market.");
                      if (!snap.hasData) return const CanopyListSkeleton(rows: 2);
                      final items = snap.data!.take(5).toList();
                      if (items.isEmpty) {
                        return Text('No material for sale in ${here.label} yet.', style: CanopyType.body.copyWith(color: p.inkMuted));
                      }
                      return CanopyListGroup(children: [
                        for (final l in items)
                          CanopyListRow(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(CanopyRadius.xs),
                              child: SizedBox(width: 44, height: 44, child: CanopyImage(url: l.coverImage, fallbackIcon: Icons.recycling)),
                            ),
                            title: l.title,
                            subtitle: [
                              if (l.quantity.quantityKg != null) '${l.quantity.quantityKg!.round()} kg',
                              l.pricing.display,
                              makerName(l),
                            ].join(' · '),
                            onTap: () => Navigator.of(context, rootNavigator: true)
                                .push(MaterialPageRoute(builder: (_) => MarketplaceItemViewScreen(listingId: l.id))),
                          ),
                      ]);
                    },
                  ),
                  const CanopySectionHeader(title: 'From the community', padding: EdgeInsets.only(top: CanopySpace.section)),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // Index-free: ordering by publishedAt alone returns only live articles.
                    stream: FirebaseFirestore.instance.collection('articles').orderBy('publishedAt', descending: true).limit(3).snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) return const CanopyErrorState(inline: true, title: "Couldn't load articles.");
                      if (!snap.hasData) return const CanopyCardSkeleton();
                      if (snap.data!.docs.isEmpty) {
                        return Text('Nothing published yet.', style: CanopyType.body.copyWith(color: p.inkMuted));
                      }
                      return Column(children: [
                        for (final a in snap.data!.docs) ...[ArticleCard(id: a.id, data: a.data()), const SizedBox(height: CanopySpace.s12)],
                      ]);
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
