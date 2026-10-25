// lib/EnvironmentalOps/Market/env_market.dart
//
// Operations › Market (ENVOPS_HANDOFF §3.3). The supply side of the Canopy
// Marketplace, read from the unified /listings collection scoped by place —
// so a processor's buy order is visible to every collector near it.
//
// Chips Offered / Wanted / Recurring / Yours; segmented Near here /
// Everywhere; "[N] kg diverted"; MaterialListingCards; sticky "Post a
// listing". Cards respond for real: "I have this" / "I want this" writes a
// listing response; your own listing shows its responses and can be closed.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Models/marketplace/canopy_listing.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../Shared/widgets/location_switcher.dart' show showLocationPicker;
import '../../theme/canopy_components.dart';
import '../../MarketPlace/market_ui.dart' show showListingResponses;
import '../envops_ui.dart';
import '../../Shared/widgets/report_sheet.dart';
import 'create_listing_screen.dart';

enum _Chip { offered, wanted, recurring, yours }

class EnvMarketScreen extends StatefulWidget {
  const EnvMarketScreen({super.key});

  @override
  State<EnvMarketScreen> createState() => _EnvMarketScreenState();
}

class _EnvMarketScreenState extends State<EnvMarketScreen> {
  _Chip _chip = _Chip.offered;
  bool _everywhere = false;
  EnvironmentOpsContext? _ctx;

  @override
  void initState() {
    super.initState();
    EnvironmentOpsService.instance.resolveContext().then((c) => mounted ? setState(() => _ctx = c) : null).catchError((_) {});
  }

  ListingQuery _query(LocationFilter here) => ListingQuery(
        location: _chip == _Chip.yours || _everywhere ? LocationFilter.everywhere : here,
        side: ListingSide.supply,
        intent: switch (_chip) {
          _Chip.offered => ListingIntent.offering,
          _Chip.wanted || _Chip.recurring => ListingIntent.seeking,
          _Chip.yours => null,
        },
        orgId: _chip == _Chip.yours ? _ctx?.orgId : null,
      );

  void _post() {
    final c = _ctx;
    if (c == null) {
      showCanopySnack(context, 'Link an organisation before posting.', error: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateListingScreen(orgId: c.orgId, orgData: c.orgData)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final location = context.watch<LocationProvider>();
    final here = location.filter;
    return CanopyScaffold(
      body: Column(children: [
        const SizedBox(height: CanopySpace.s12),
        CanopyChipRail(chips: [
          for (final c in _Chip.values)
            if (c != _Chip.yours || _ctx != null)
              CanopyFilterChip(
                label: switch (c) { _Chip.offered => 'Offered', _Chip.wanted => 'Wanted', _Chip.recurring => 'Recurring', _Chip.yours => 'Yours' },
                selected: _chip == c,
                onTap: () => setState(() => _chip = c),
              ),
        ]),
        if (_chip != _Chip.yours)
          Padding(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CanopySegmented<bool>(
                options: const [(false, 'Near here'), (true, 'Everywhere')],
                value: _everywhere,
                onChanged: (v) => setState(() => _everywhere = v),
              ),
              Row(children: [
                Expanded(
                  child: FutureBuilder<MarketplaceTotals>(
                    future: ListingService.instance.totals(_everywhere ? LocationFilter.everywhere : here),
                    builder: (context, t) => Text(
                      [
                        _everywhere ? 'Everywhere' : here.label,
                        if (t.data != null) '${t.data!.kgDiverted.round()} kg diverted',
                      ].join(' · '),
                      style: CanopyType.caption.copyWith(color: p.inkMuted),
                    ),
                  ),
                ),
                if (!_everywhere)
                  CanopyButton.quiet(label: 'Change place', size: CanopyButtonSize.compact, onPressed: () => showLocationPicker(context)),
              ]),
            ]),
          ),
        Expanded(
          child: StreamBuilder<List<CanopyListing>>(
            stream: ListingService.instance.watch(_query(here)),
            builder: (context, snap) {
              if (snap.hasError) return CanopyErrorState(title: "Couldn't load listings", onRetry: () => setState(() {}));
              if (!snap.hasData) {
                return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [
                  CanopyCardSkeleton(),
                  SizedBox(height: CanopySpace.s12),
                  CanopyCardSkeleton(),
                ]);
              }
              var list = snap.data!;
              if (_chip == _Chip.recurring) list = list.where((l) => l.fulfilment.isRecurring).toList();
              if (_chip == _Chip.wanted) list = list.where((l) => !l.fulfilment.isRecurring).toList();
              if (list.isEmpty) return _empty(here, location);
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: CanopySpace.s12),
                itemBuilder: (_, i) {
                  final l = list[i];
                  return MaterialListingCard(
                    listing: l,
                    imageUrl: l.coverImage,
                    isOwn: l.orgId != null && l.orgId == _ctx?.orgId,
                    responderName: _ctx?.orgName,
                  );
                },
              );
            },
          ),
        ),
      ]),
      sticky: StickyActionBar(children: [FieldButton(label: 'Post a listing', onPressed: _post)]),
    );
  }

  Widget _empty(LocationFilter here, LocationProvider location) {
    final title = switch (_chip) {
      _Chip.offered => 'Nothing offered ${_everywhere ? 'yet' : 'in ${here.label} yet'}',
      _Chip.wanted => 'Nobody is buying ${_everywhere ? 'yet' : 'in ${here.label} yet'}',
      _Chip.recurring => 'No standing buy orders ${_everywhere ? 'yet' : 'in ${here.label}'}',
      _Chip.yours => "You haven't posted a listing",
    };
    final widen = !_everywhere && _chip != _Chip.yours;
    return CanopyEmptyState(
      icon: Icons.storefront_outlined,
      title: title,
      line: widen ? 'Widen to everywhere to see more.' : 'Post material you have, or what you want to buy.',
      actionLabel: widen ? 'Show everywhere' : null,
      onAction: widen ? () => setState(() => _everywhere = true) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MATERIAL LISTING CARD
// ─────────────────────────────────────────────────────────────────────────────

class MaterialListingCard extends StatelessWidget {
  final CanopyListing listing;
  final String? imageUrl;
  final bool isOwn;
  final String? responderName;

  const MaterialListingCard({super.key, required this.listing, required this.imageUrl, required this.isOwn, this.responderName});

  String get _kind => listing.isSeeking ? (listing.fulfilment.isRecurring ? 'Recurring buy' : 'Buy order') : 'Selling';

  List<String> get _logistics => [
        if (listing.isSeeking) ...[
          if (listing.fulfilment.willCollect) 'We collect',
          if (listing.fulfilment.acceptsDelivery) 'Deliver to us',
        ] else ...[
          if (listing.fulfilment.acceptsDelivery) 'We deliver',
          if (listing.fulfilment.willCollect) 'Buyer collects',
        ],
      ];

  String get _digits => listing.contactPhone.replaceAll(RegExp(r'\D'), '');

  Future<void> _call(BuildContext context) async {
    final ok = await launchUrl(Uri.parse('tel:${listing.contactPhone}'));
    if (!ok && context.mounted) showCanopySnack(context, "Couldn't open the dialler.", error: true);
  }

  Future<void> _whatsapp(BuildContext context) async {
    final text = Uri.encodeComponent('Hi, I saw your listing "${listing.title}" on Canopy.');
    final ok = await launchUrl(Uri.parse('https://wa.me/$_digits?text=$text'), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showCanopySnack(context, "Couldn't open WhatsApp.", error: true);
  }

  Future<void> _directions() {
    final l = listing.location;
    return launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${l.lat},${l.lng}'),
        mode: LaunchMode.externalApplication);
  }

  void _responses(BuildContext context) => showListingResponses(context, listing);

  Future<void> _close(BuildContext context) async {
    final ok = await showCanopyConfirm(context,
        title: 'Close this listing?', message: 'It stops showing on the market. Responses stay with you.', confirmLabel: 'Close listing');
    if (!ok) return;
    try {
      await ListingService.instance.setStatus(listing.id, ListingStatus.closed);
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't close it. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final qty = listing.quantity.quantityKg?.round() ?? 0;
    final grade = listing.materialGrade ?? '';
    final place = listing.location.label;
    return CanopyCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(CanopyRadius.md - 1)),
          child: AspectRatio(aspectRatio: 16 / 7, child: CanopyImage(url: imageUrl, fallbackIcon: Icons.recycling)),
        ),
        Padding(
          padding: const EdgeInsets.all(CanopySpace.s12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LabelRow(children: [
              StatusLabel(_kind, color: listing.isSeeking ? p.info : p.success),
              for (final l in _logistics) StatusLabel(l, color: p.inkMuted),
              if (isOwn) StatusLabel('Yours', color: p.ink),
            ]),
            const SizedBox(height: CanopySpace.s4),
            Text([listing.title, if (grade.isNotEmpty) 'Grade $grade'].join(' · '), style: CanopyType.subhead.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$qty kg', style: CanopyField.signalValue.copyWith(fontSize: 22, color: p.ink)),
              const SizedBox(width: CanopySpace.s12),
              Text(listing.pricing.display, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
            ]),
            if (listing.isSeeking && (listing.quantity.quantityKg ?? 0) > 0) ...[
              const SizedBox(height: CanopySpace.s8),
              CanopyProgressBar(value: listing.quantity.fillProgress, ink: true),
              const SizedBox(height: CanopySpace.s2),
              Text('${listing.quantity.remainingKg.round()} kg still needed', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ],
            const SizedBox(height: CanopySpace.s4),
            Text(
              [listing.orgName ?? listing.seller.shopName, if (place.isNotEmpty && place != 'Unknown location') place]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: CanopyType.caption.copyWith(color: p.inkMuted),
            ),
            if (listing.story.isNotEmpty) ...[
              const SizedBox(height: CanopySpace.s4),
              Text(listing.story, maxLines: 2, overflow: TextOverflow.ellipsis, style: CanopyType.body.copyWith(color: p.ink)),
            ],
            const SizedBox(height: CanopySpace.s12),
            if (isOwn)
              Row(children: [
                Expanded(
                  child: FieldButton.secondary(
                    label: 'Responses${listing.responseCount > 0 ? ' · ${listing.responseCount}' : ''}',
                    onPressed: () => _responses(context),
                  ),
                ),
                const SizedBox(width: CanopySpace.s8),
                CanopyButton.quietDanger(label: 'Close', onPressed: () => _close(context)),
              ])
            else if (listing.contactPhone.isEmpty)
              Text('No contact number on this listing.', style: CanopyType.caption.copyWith(color: p.inkMuted))
            else
              Row(children: [
                Expanded(child: FieldButton(label: 'Call', onPressed: () => _call(context))),
                const SizedBox(width: CanopySpace.s8),
                Expanded(child: FieldButton.secondary(label: 'WhatsApp', onPressed: () => _whatsapp(context))),
                if (listing.location.lat != null && listing.location.lng != null) ...[
                  const SizedBox(width: CanopySpace.s4),
                  CanopyIconButton(icon: Icons.directions_outlined, tooltip: 'Directions', onPressed: _directions),
                ],
                CanopyIconButton(
                    icon: Icons.flag_outlined,
                    tooltip: 'Report this listing',
                    onPressed: () => showReportSheet(context,
                        targetType: 'listing', targetId: listing.id, ownerId: listing.postedByUid, subject: 'this listing')),
              ]),
          ]),
        ),
      ]),
    );
  }
}
