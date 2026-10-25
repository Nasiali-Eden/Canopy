// lib/MarketPlace/The Market/eco_shop.dart
//
// Buyer › Market (MARKETPLACE_SELLER_DESIGN_BRIEF §4, F). Browse, search and
// filter made goods from /listings, scoped by the location switch (Near
// here / Everywhere). Makers rail, materials wanted near you, product grid.
// No sample products: an empty place says so and offers to widen.

import 'dart:async';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:provider/provider.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Models/marketplace/canopy_listing.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../Shared/widgets/location_switcher.dart' show showLocationPicker;
import '../../theme/canopy_components.dart';
import '../market_ui.dart';
import 'marketplace_item_view.dart';
import 'marketplace_shop_view.dart';

class EcoShopScreen extends StatefulWidget {
  const EcoShopScreen({super.key});

  @override
  State<EcoShopScreen> createState() => _EcoShopScreenState();
}

class _EcoShopScreenState extends State<EcoShopScreen> {
  ListingCategory? _category;
  String _query = '';
  bool _everywhere = false;
  StreamSubscription<List<CanopyListing>>? _sub;
  List<CanopyListing> _all = const [];
  bool _loading = true;
  Object? _error;
  LocationFilter? _bound;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final f = _everywhere ? LocationFilter.everywhere : context.watch<LocationProvider>().filter;
    if (_bound != f) {
      _bound = f;
      _subscribe(f);
    }
  }

  void _subscribe(LocationFilter f) {
    _sub?.cancel();
    _loading = true;
    _error = null;
    _sub = ListingService.instance.watch(ListingQuery(location: f)).listen((all) {
      if (mounted) {
        setState(() {
          _all = all;
          _loading = false;
        });
      }
    }, onError: (Object e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    });
  }

  void _setEverywhere(bool v) {
    setState(() => _everywhere = v);
    final f = v ? LocationFilter.everywhere : context.read<LocationProvider>().filter;
    _bound = f;
    _subscribe(f);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<CanopyListing> get _products {
    final q = _query.toLowerCase();
    return _all.where((l) {
      if (!l.isCreative || !l.isOffering) return false;
      if (_category != null && l.category != _category) return false;
      if (q.isEmpty) return true;
      return '${l.title} ${l.story} ${l.tagline} ${l.seller.shopName} ${l.materials.map((m) => m.label).join(' ')}'.toLowerCase().contains(q);
    }).toList();
  }

  List<CanopyListing> get _wanted => _all.where((l) => l.isSupply && l.isSeeking).take(3).toList();

  void _open(CanopyListing l) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => MarketplaceItemViewScreen(listingId: l.id)));

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final here = context.watch<LocationProvider>().filter;
    final products = _products;
    final makers = <String, CanopyListing>{};
    for (final l in products) {
      if (l.seller.sellerId.isNotEmpty) makers.putIfAbsent(l.seller.sellerId, () => l);
    }
    final kg = products.fold<double>(0, (s, l) => s + l.impact.kgDiverted);

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Market'),
      body: RefreshIndicator(
        onRefresh: () async => _subscribe(_bound ?? here),
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, 0),
            sliver: SliverList.list(children: [
              CanopyTextField.search(hint: 'Search made goods, makers, materials', onChanged: (v) => setState(() => _query = v.trim())),
              const SizedBox(height: CanopySpace.s12),
              CanopySegmented<bool>(options: const [(false, 'Near here'), (true, 'Everywhere')], value: _everywhere, onChanged: _setEverywhere),
              Row(children: [
                Expanded(
                  child: Text(
                    [
                      _everywhere ? 'Everywhere' : here.label,
                      if (makers.isNotEmpty) '${makers.length} maker${makers.length == 1 ? '' : 's'}',
                      if (kg > 0) '${kg.toStringAsFixed(kg < 10 ? 1 : 0)} kg reused',
                    ].join(' · '),
                    style: CanopyType.caption.copyWith(color: p.inkMuted),
                  ),
                ),
                if (!_everywhere) CanopyButton.quiet(label: 'Change place', size: CanopyButtonSize.compact, onPressed: () => showLocationPicker(context)),
              ]),
            ]),
          ),
          SliverToBoxAdapter(
            child: CanopyChipRail(chips: [
              CanopyFilterChip(label: 'All', selected: _category == null, onTap: () => setState(() => _category = null)),
              for (final c in kMakerCategories)
                CanopyFilterChip(label: c.label, selected: _category == c, onTap: () => setState(() => _category = _category == c ? null : c)),
            ]),
          ),
          if (_error != null)
            SliverFillRemaining(hasScrollBody: false, child: CanopyErrorState(title: "Couldn't load the market", onRetry: () => _subscribe(_bound ?? here)))
          else if (_loading)
            const SliverPadding(
              padding: EdgeInsets.all(CanopySpace.gutter),
              sliver: SliverToBoxAdapter(child: CanopyCardSkeleton()),
            )
          else if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: CanopyEmptyState(
                icon: Icons.storefront_outlined,
                title: _query.isNotEmpty || _category != null ? 'Nothing matches' : 'No made goods listed ${_everywhere ? 'yet' : 'in ${here.label} yet'}',
                line: _everywhere ? 'Makers list things they made from recovered material here.' : 'Try everywhere to see more.',
                actionLabel: _everywhere ? null : 'Show everywhere',
                onAction: _everywhere ? null : () => _setEverywhere(true),
              ),
            )
          else ...[
            if (makers.length > 1 && _query.isEmpty && _category == null) ...[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
                sliver: SliverToBoxAdapter(child: CanopySectionHeader(title: 'Makers', padding: EdgeInsets.zero)),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                    scrollDirection: Axis.horizontal,
                    itemCount: makers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: CanopySpace.s16),
                    itemBuilder: (_, i) {
                      final l = makers.values.elementAt(i);
                      return InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarketplaceShopViewScreen(sellerId: l.seller.sellerId))),
                        child: SizedBox(
                          width: 72,
                          child: Column(children: [
                            CanopyAvatar(url: l.seller.shopLogoUrl, name: makerName(l), size: 56, org: true),
                            const SizedBox(height: CanopySpace.s4),
                            Text(makerName(l), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: p.ink)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (_wanted.isNotEmpty && _query.isEmpty && _category == null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
                sliver: SliverList.list(children: [
                  const CanopySectionHeader(title: 'Materials wanted near you', padding: EdgeInsets.zero),
                  CanopyListGroup(children: [
                    for (final w in _wanted)
                      CanopyListRow(
                        icon: Icons.campaign_outlined,
                        title: w.title,
                        subtitle: [
                          if (w.quantity.quantityKg != null) '${w.quantity.remainingKg.round()} kg needed',
                          w.pricing.display,
                          makerName(w),
                        ].join(' · '),
                        onTap: () => _open(w),
                      ),
                  ]),
                ]),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
              sliver: SliverToBoxAdapter(child: CanopySectionHeader(title: 'Made from what was thrown away', padding: EdgeInsets.zero)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: CanopySpace.s16,
                  crossAxisSpacing: CanopySpace.s12,
                  childAspectRatio: .56,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(listing: products[i], onTap: () => _open(products[i])),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
