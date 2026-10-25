// lib/MarketPlace/market_ui.dart
//
// Marketplace components (MARKETPLACE_SELLER_DESIGN_BRIEF §3, on the v2
// global rules — the handoff has no dedicated board). Product card shared by
// buyer and seller views, inventory row, provenance block (each fact shown
// only when recorded), shop header, seller stat strip, status labels, and
// the one request/response flow used by both the maker marketplace and the
// materials market. Money is shown, never moved — checkout isn't built, so
// buying is a request to the maker.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide MaterialType;

import '../Models/marketplace/canopy_listing.dart';
import '../Models/marketplace/marketplace_seller_profile.dart';
import '../Services/Marketplace/listing_service.dart';
import '../theme/canopy_components.dart';
import '../theme/tokens/services_tokens.dart' show CanopyFees;

// ─────────────────────────────────────────────────────────────────────────────
// VOCABULARY
// ─────────────────────────────────────────────────────────────────────────────

/// Maker categories offered in the listing wizard and buyer filters.
const kMakerCategories = <ListingCategory>[
  ListingCategory.fashion,
  ListingCategory.jewellery,
  ListingCategory.furniture,
  ListingCategory.ceramics,
  ListingCategory.homeware,
  ListingCategory.sculpture,
  ListingCategory.prints,
  ListingCategory.artisan,
];

String makerCategoryLabel(ListingCategory c) => switch (c) {
      ListingCategory.fashion => 'Fashion & textiles',
      ListingCategory.jewellery => 'Jewellery & accessories',
      ListingCategory.furniture => 'Furniture & objects',
      ListingCategory.ceramics => 'Ceramics & glass art',
      ListingCategory.homeware => 'Home & lifestyle',
      ListingCategory.sculpture => 'Sculpture & 3D art',
      ListingCategory.prints => 'Print & paper art',
      ListingCategory.artisan => 'Other made goods',
      ListingCategory.materials => 'Materials',
      ListingCategory.processed => 'Processed materials',
    };

IconData makerCategoryIcon(ListingCategory c) => switch (c) {
      ListingCategory.fashion => Icons.checkroom_outlined,
      ListingCategory.jewellery => Icons.diamond_outlined,
      ListingCategory.furniture => Icons.chair_outlined,
      ListingCategory.ceramics => Icons.local_drink_outlined,
      ListingCategory.homeware => Icons.home_outlined,
      ListingCategory.sculpture => Icons.architecture_outlined,
      ListingCategory.prints => Icons.print_outlined,
      ListingCategory.materials || ListingCategory.processed => Icons.recycling,
      ListingCategory.artisan => Icons.handyman_outlined,
    };

/// Live · Paused · Sold out · Closed.
StatusLabel listingStatusLabel(ListingStatus s, CanopyPalette p) => switch (s) {
      ListingStatus.active => StatusLabel('Live', color: p.success),
      ListingStatus.paused => StatusLabel('Paused', color: p.warning),
      ListingStatus.fulfilled => StatusLabel('Sold out', color: p.inkMuted),
      ListingStatus.closed => StatusLabel('Closed', color: p.inkMuted),
    };

String makerName(CanopyListing l) =>
    [l.seller.shopName, l.orgName ?? ''].firstWhere((s) => s.trim().isNotEmpty, orElse: () => 'Canopy maker');

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD (buyer) · INVENTORY ROW (seller)
// ─────────────────────────────────────────────────────────────────────────────

class ProductCard extends StatelessWidget {
  final CanopyListing listing;
  final VoidCallback? onTap;
  final double width;
  const ProductCard({super.key, required this.listing, this.onTap, this.width = double.infinity});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final l = listing;
    final material = l.materials.isNotEmpty ? l.materials.first.label : null;
    return SizedBox(
      width: width,
      child: Semantics(
        button: onTap != null,
        label: '${l.title}, ${l.pricing.display}, by ${makerName(l)}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CanopyRadius.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              child: AspectRatio(aspectRatio: 4 / 5, child: CanopyImage(url: l.coverImage, fallbackIcon: makerCategoryIcon(l.category))),
            ),
            const SizedBox(height: CanopySpace.s8),
            if (!l.isActive) ...[listingStatusLabel(l.status, p), const SizedBox(height: CanopySpace.s2)],
            Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
            Text(l.pricing.display, style: CanopyType.body.copyWith(color: p.ink)),
            Text([makerName(l), if (material != null) material].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: p.inkMuted)),
          ]),
        ),
      ),
    );
  }
}

class InventoryRow extends StatelessWidget {
  final CanopyListing listing;
  final VoidCallback? onTap;
  final Widget? trailing;
  const InventoryRow({super.key, required this.listing, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final l = listing;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s16, vertical: CanopySpace.s12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.xs),
            child: SizedBox(width: 56, height: 56, child: CanopyImage(url: l.coverImage, fallbackIcon: makerCategoryIcon(l.category))),
          ),
          const SizedBox(width: CanopySpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LabelRow(children: [
                listingStatusLabel(l.status, p),
                if (l.responseCount > 0) StatusLabel('${l.responseCount} request${l.responseCount == 1 ? '' : 's'}', color: p.info),
              ]),
              Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
              Text(
                [
                  l.pricing.display,
                  if (l.isCreative) l.quantity.isMadeToOrder ? 'Made to order' : '${l.quantity.stockCount} in stock',
                  if (l.viewCount > 0) '${l.viewCount} views',
                ].join(' · '),
                style: CanopyType.caption.copyWith(color: p.inkMuted),
              ),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVENANCE
// ─────────────────────────────────────────────────────────────────────────────

/// Material, source and kg diverted — each shown only when recorded. Returns
/// nothing at all when no provenance exists (no generic "eco" badge).
class ProvenanceBlock extends StatelessWidget {
  final CanopyListing listing;
  const ProvenanceBlock({super.key, required this.listing});

  static bool hasAny(CanopyListing l) =>
      l.materials.isNotEmpty || l.materialDna.isNotEmpty || l.impact.kgDiverted > 0;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    if (!hasAny(l)) return const SizedBox.shrink();
    final sources = <String>[
      for (final d in l.materialDna)
        [
          if ((d.collectorName ?? '').isNotEmpty) 'Collected by ${d.collectorName}',
          if ((d.collectorCity ?? '').isNotEmpty) d.collectorCity!,
          if ((d.processorName ?? '').isNotEmpty) 'processed by ${d.processorName}',
          if (d.weightKg != null && d.weightKg! > 0) '${d.weightKg!.toStringAsFixed(d.weightKg! < 10 ? 1 : 0)} kg',
        ].join(' · '),
    ].where((s) => s.isNotEmpty).toList();
    return CanopyListGroup(header: 'Where it comes from', children: [
      if (l.materials.isNotEmpty)
        CanopyFactRow(icon: Icons.recycling, label: 'Made from', value: l.materials.map((m) => m.label).join(', ')),
      for (final s in sources) CanopyFactRow(icon: Icons.person_pin_circle_outlined, label: 'Source', value: s),
      if (l.hasOnPlatformSource)
        const CanopyFactRow(icon: Icons.link, label: 'Sourcing', value: 'Bought through the Canopy materials market'),
      if (l.impact.kgDiverted > 0)
        CanopyFactRow(
          icon: Icons.scale_outlined,
          label: 'Kept out of waste',
          value: '${l.impact.kgDiverted.toStringAsFixed(l.impact.kgDiverted < 10 ? 1 : 0)} kg',
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOP HEADER · SELLER STATS
// ─────────────────────────────────────────────────────────────────────────────

class ShopHeader extends StatelessWidget {
  final MarketplaceSellerProfile shop;
  final Widget? action;
  const ShopHeader({super.key, required this.shop, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final tags = [...shop.categories, ...shop.specialisations];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 196,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            bottom: 36,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.md),
              child: shop.bannerUrl == null ? Container(color: p.surfaceBrand) : CanopyImage(url: shop.bannerUrl),
            ),
          ),
          Positioned(
            left: CanopySpace.s16,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: p.canvas, borderRadius: BorderRadius.circular(24)),
              child: CanopyAvatar(url: shop.logoUrl, name: shop.name, size: 72, org: true),
            ),
          ),
          if (action != null) Positioned(right: 0, bottom: 0, child: action!),
        ]),
      ),
      const SizedBox(height: CanopySpace.s12),
      Row(children: [
        Flexible(child: Text(shop.name, style: CanopyType.title.copyWith(color: p.ink))),
        if (shop.verified) ...[const SizedBox(width: CanopySpace.s4), Icon(Icons.verified, size: 18, color: p.primary)],
      ]),
      Text([shop.role, if (shop.location.isNotEmpty) shop.location].join(' · '), style: CanopyType.label.copyWith(color: p.inkMuted)),
      if (shop.bio.trim().isNotEmpty) ...[
        const SizedBox(height: CanopySpace.s8),
        Text(shop.bio.trim(), style: CanopyType.body.copyWith(color: p.ink)),
      ],
      if (tags.isNotEmpty) ...[
        const SizedBox(height: CanopySpace.s8),
        Text(tags.take(6).join(' · '), style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
    ]);
  }
}

/// Listings live · kg diverted · impact points — the last two only when > 0.
class SellerStatStrip extends StatelessWidget {
  final int liveListings;
  final double kgDiverted;
  final int impactPoints;
  final int requests;
  const SellerStatStrip({super.key, required this.liveListings, this.kgDiverted = 0, this.impactPoints = 0, this.requests = 0});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      CanopyStatTile(value: '$liveListings', label: 'Live listings', ruled: true),
      CanopyStatTile(value: '$requests', label: 'Buyer requests', ruled: true),
      if (kgDiverted > 0) CanopyStatTile(value: kgDiverted.toStringAsFixed(kgDiverted < 10 ? 1 : 0), label: 'Kg diverted', ruled: true),
      if (impactPoints > 0) CanopyStatTile(value: '$impactPoints', label: 'Impact points', ruled: true),
    ];
    return Row(children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: CanopySpace.s12),
        Expanded(child: tiles[i]),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST / RESPOND · RESPONSES
// ─────────────────────────────────────────────────────────────────────────────

/// "Request to buy" (made goods), "I want this" / "I have this" (materials).
/// Writes a ListingResponse. Returns true when sent.
Future<bool> showListingRequestSheet(BuildContext context, CanopyListing listing, {String? responderName}) async {
  if (FirebaseAuth.instance.currentUser == null) {
    showCanopySnack(context, 'Sign in to contact the seller.', error: true);
    return false;
  }
  final sent = await showCanopySheet<bool>(context, builder: (_) => _RequestSheet(listing: listing, responderName: responderName));
  if (sent == true && context.mounted) {
    showCanopySnack(context, 'Sent to ${makerName(listing)}. They\'ll contact you to arrange it.');
  }
  return sent == true;
}

class _RequestSheet extends StatefulWidget {
  final CanopyListing listing;
  final String? responderName;
  const _RequestSheet({required this.listing, this.responderName});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _amount = TextEditingController();
  final _price = TextEditingController();
  final _phone = TextEditingController(text: FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
  final _msg = TextEditingController();
  int _count = 1;
  bool _busy = false, _showErrors = false;

  bool get _perKg => widget.listing.isSupply;

  @override
  void dispose() {
    for (final c in [_amount, _price, _phone, _msg]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _showErrors = true);
    final kg = double.tryParse(_amount.text.trim());
    if (_perKg && (kg == null || kg <= 0)) return;
    if (_phone.text.trim().isEmpty) return;
    final u = FirebaseAuth.instance.currentUser!;
    setState(() => _busy = true);
    try {
      final note = [
        if (!_perKg) 'Quantity: $_count',
        'Phone: ${_phone.text.trim()}',
        if (_msg.text.trim().isNotEmpty) _msg.text.trim(),
      ].join('\n');
      await ListingService.instance.respond(ListingResponse(
        id: u.uid,
        listingId: widget.listing.id,
        responderUid: u.uid,
        responderName: widget.responderName ?? u.displayName ?? 'Canopy member',
        responderPhotoUrl: u.photoURL,
        quantityKg: _perKg ? kg : null,
        offeredPriceKes: _perKg ? double.tryParse(_price.text.trim()) : null,
        message: note,
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showCanopySnack(context, "Couldn't send. Try again.", error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final l = widget.listing;
    final title = _perKg ? (l.isSeeking ? 'I have this' : 'I want this') : 'Request to buy';
    final total = !_perKg && l.pricing.amountKes > 0 ? l.pricing.amountKes * _count : 0;
    return CanopySheetBody(
      title: title,
      caption: '${l.title} · ${l.pricing.display}',
      children: [
        if (_perKg)
          CanopyTextField(
            label: l.isSeeking ? 'How much you can supply (kg)' : 'How much you want (kg)',
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            error: _showErrors && (double.tryParse(_amount.text.trim()) ?? 0) <= 0 ? 'Enter a quantity.' : null,
            onChanged: (_) => setState(() {}),
          )
        else
          Row(children: [
            Expanded(child: Text('Quantity', style: CanopyType.bodyStrong.copyWith(color: p.ink))),
            CanopyIconButton(icon: Icons.remove, tooltip: 'Fewer', onPressed: _count > 1 ? () => setState(() => _count--) : null),
            SizedBox(width: 40, child: Text('$_count', textAlign: TextAlign.center, style: CanopyType.title.copyWith(color: p.ink))),
            CanopyIconButton(
              icon: Icons.add,
              tooltip: 'More',
              onPressed: l.quantity.isMadeToOrder || _count < l.quantity.stockCount ? () => setState(() => _count++) : null,
            ),
          ]),
        if (_perKg) ...[
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField.money(label: 'Your price per kg (optional)', controller: _price),
        ],
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField.phone(
          label: 'Your phone',
          controller: _phone,
          error: _showErrors && _phone.text.trim().isEmpty ? 'So they can reach you.' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Message (optional)', hint: 'Delivery, collection, sizes…', controller: _msg, minLines: 2, maxLines: 4),
        if (total > 0) ...[
          const SizedBox(height: CanopySpace.s12),
          Text('About ${CanopyFees.ksh(total.round())} for $_count', style: CanopyType.bodyStrong.copyWith(color: p.ink)),
        ],
        const SizedBox(height: CanopySpace.s8),
        Text('Paying through Canopy isn\'t built yet — you arrange payment and handover with the seller.',
            style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
      actions: [CanopyButton(label: 'Send request', expand: true, loading: _busy, onPressed: _send)],
    );
  }
}

/// The requests a seller received on one listing.
Future<void> showListingResponses(BuildContext context, CanopyListing listing) =>
    showCanopySheet(context, tall: true, builder: (_) => _ResponsesSheet(listing: listing));

class _ResponsesSheet extends StatelessWidget {
  final CanopyListing listing;
  const _ResponsesSheet({required this.listing});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(title: 'Requests', caption: listing.title, children: [
      StreamBuilder<List<ListingResponse>>(
        stream: ListingService.instance.watchResponses(listing.id),
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(inline: true, title: "Couldn't load requests.");
          if (!snap.hasData) return const CanopyListSkeleton(rows: 3);
          if (snap.data!.isEmpty) return const CanopyEmptyState(boxed: true, icon: Icons.forum_outlined, title: 'No requests yet');
          return CanopyListGroup(children: [
            for (final r in snap.data!)
              CanopyListRow(
                leading: CanopyAvatar(url: r.responderPhotoUrl, name: r.responderName, size: 40),
                title: r.responderName,
                subtitle: [
                  if (r.quantityKg != null) '${r.quantityKg!.round()} kg',
                  if (r.offeredPriceKes != null) '${CanopyFees.ksh(r.offeredPriceKes!.round())}/kg',
                  _ago(r.createdAt),
                ].join(' · '),
                below: r.message.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: CanopySpace.s4),
                        child: Text(r.message, style: CanopyType.body.copyWith(color: p.ink)),
                      ),
                chevron: false,
              ),
          ]);
        },
      ),
    ]);
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}
