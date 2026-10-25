// lib/MarketPlace/The Market/marketplace_item_view.dart
//
// Buyer › Item (MARKETPLACE_SELLER_DESIGN_BRIEF §4, F). Photos, price,
// labels, maker (→ their shop), story, provenance (only what was recorded),
// details, and one action: "Request to buy" for made goods, "I have this" /
// "I want this" for materials. Your own listing shows its requests instead.
// Checkout isn't built — the request is honest about arranging payment.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:intl/intl.dart';

import '../../Models/marketplace/canopy_listing.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../theme/canopy_components.dart';
import '../Shop/seller_shop.dart' show ListingWizardScreen;
import '../market_ui.dart';
import 'marketplace_shop_view.dart';

class MarketplaceItemViewScreen extends StatefulWidget {
  final String listingId;

  const MarketplaceItemViewScreen({super.key, required this.listingId});

  @override
  State<MarketplaceItemViewScreen> createState() => _MarketplaceItemViewScreenState();
}

class _MarketplaceItemViewScreenState extends State<MarketplaceItemViewScreen> {
  CanopyListing? _listing;
  bool _loading = true, _failed = false;
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final l = await ListingService.instance.byId(widget.listingId);
      if (!mounted) return;
      setState(() {
        _listing = l;
        _loading = false;
      });
      if (l != null && l.postedByUid != FirebaseAuth.instance.currentUser?.uid) ListingService.instance.incrementView(l.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (_loading) return CanopyScaffold(appBar: canopyAppBar(context, title: ''), body: const Center(child: CircularProgressIndicator()));
    if (_failed) return CanopyScaffold(appBar: canopyAppBar(context, title: ''), body: CanopyErrorState(title: "Couldn't load this listing", onRetry: _load));
    final l = _listing;
    if (l == null) {
      return CanopyScaffold(
        appBar: canopyAppBar(context, title: ''),
        body: const CanopyEmptyState(icon: Icons.inventory_2_outlined, title: 'This listing is no longer available'),
      );
    }
    final mine = l.postedByUid == FirebaseAuth.instance.currentUser?.uid;
    final top = MediaQuery.paddingOf(context).top;
    final place = l.location.label;

    return CanopyScaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(children: [
              Positioned.fill(
                child: l.images.isEmpty
                    ? CanopyImage(url: null, fallbackIcon: makerCategoryIcon(l.category))
                    : PageView.builder(
                        itemCount: l.images.length,
                        onPageChanged: (i) => setState(() => _photo = i),
                        itemBuilder: (_, i) => CanopyImage(url: l.images[i]),
                      ),
              ),
              Positioned(
                top: top + CanopySpace.s8,
                left: CanopySpace.s12,
                child: CanopyIconButton(icon: Icons.arrow_back, tooltip: 'Back', onImage: true, onPressed: () => Navigator.maybePop(context)),
              ),
              if (l.images.length > 1)
                Positioned(
                  bottom: CanopySpace.s12,
                  right: CanopySpace.s12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s8, vertical: CanopySpace.s2),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(CanopyRadius.pill)),
                    child: Text('${_photo + 1} / ${l.images.length}', style: CanopyType.caption.copyWith(color: const Color(0xFFFFFFFF))),
                  ),
                ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
          sliver: SliverList.list(children: [
            LabelRow(children: [
              if (!l.isActive) listingStatusLabel(l.status, p),
              StatusLabel(l.isSupply ? (l.isSeeking ? 'Wanted' : 'Material for sale') : makerCategoryLabel(l.category), color: p.inkMuted),
            ]),
            const SizedBox(height: CanopySpace.s4),
            Text(l.title, style: CanopyType.display.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s4),
            Text(
              [
                l.pricing.display,
                if (l.isCreative) l.quantity.isMadeToOrder ? 'Made to order' : '${l.quantity.stockCount} available',
                if (l.isSupply && l.quantity.quantityKg != null) '${l.quantity.quantityKg!.round()} kg',
              ].join(' · '),
              style: CanopyType.subhead.copyWith(color: p.ink),
            ),
            const SizedBox(height: CanopySpace.s16),
            CanopyCard(
              padding: const EdgeInsets.all(CanopySpace.s12),
              onTap: l.seller.sellerId.isEmpty
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarketplaceShopViewScreen(sellerId: l.seller.sellerId))),
              child: Row(children: [
                CanopyAvatar(url: l.seller.shopLogoUrl, name: makerName(l), size: 44, org: true),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(makerName(l), style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                    if (place.isNotEmpty) Text(place, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  ]),
                ),
                if (l.seller.sellerId.isNotEmpty) Text('Shop', style: CanopyType.label.copyWith(color: p.primaryInk)),
              ]),
            ),
            if (l.story.trim().isNotEmpty) ...[
              const CanopySectionHeader(title: 'The story', padding: EdgeInsets.only(top: CanopySpace.section)),
              Text(l.story.trim(), style: CanopyType.body.copyWith(color: p.ink, height: 1.55)),
            ],
            if (ProvenanceBlock.hasAny(l)) ...[
              const SizedBox(height: CanopySpace.section),
              ProvenanceBlock(listing: l),
            ],
            const SizedBox(height: CanopySpace.section),
            CanopyListGroup(header: 'Details', children: [
              if (l.fulfilment.willCollect)
                CanopyFactRow(icon: Icons.storefront_outlined, label: l.isSeeking ? 'They collect' : 'Collection', value: l.isSeeking ? 'From you' : 'From the maker'),
              if (l.fulfilment.acceptsDelivery)
                CanopyFactRow(icon: Icons.local_shipping_outlined, label: 'Delivery', value: l.isSeeking ? 'Deliver to them' : 'Maker can deliver'),
              if (l.materialGrade != null) CanopyFactRow(icon: Icons.grade_outlined, label: 'Grade', value: l.materialGrade!),
              CanopyFactRow(icon: Icons.schedule, label: 'Listed', value: DateFormat('d MMM yyyy').format(l.createdAt)),
            ]),
          ]),
        ),
      ]),
      sticky: !l.isActive && !mine
          ? null
          : StickyActionBar(children: [
              if (mine)
                Row(children: [
                  Expanded(
                    child: CanopyButton.secondary(
                      label: 'Requests${l.responseCount > 0 ? ' · ${l.responseCount}' : ''}',
                      expand: true,
                      onPressed: () => showListingResponses(context, l),
                    ),
                  ),
                  if (l.isCreative) ...[
                    const SizedBox(width: CanopySpace.s12),
                    Expanded(
                      child: CanopyButton(
                        label: 'Edit',
                        expand: true,
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ListingWizardScreen(existing: l)));
                          _load();
                        },
                      ),
                    ),
                  ],
                ])
              else
                CanopyButton(
                  label: l.isSupply ? (l.isSeeking ? 'I have this' : 'I want this') : 'Request to buy',
                  expand: true,
                  onPressed: () => showListingRequestSheet(context, l),
                ),
            ]),
    );
  }
}
