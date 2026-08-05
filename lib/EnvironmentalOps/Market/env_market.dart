// lib/EnvironmentalOps/Market/env_market.dart
//
// The materials market — supply side of the Canopy Marketplace.
//
// What changed, and why it matters:
//
// This screen used to query `market_listings where org_id == myOrg` on BOTH
// tabs. That made it an inventory screen wearing a marketplace's clothes: an
// organisation could only ever see its own posts. A processor's buy order for
// 500kg of PET was invisible to every collector in the county who could have
// filled it — the single largest functional gap in the app, because the whole
// premise of Layer 2 is removing the broker by letting the two sides see each
// other.
//
// It now reads the unified /listings collection scoped by the LOCATION SWITCH,
// with an explicit Everyone / Mine toggle. Buy orders ("Wanted") and sell
// listings ("Offered") are both public within the active geography.

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../Models/marketplace/canopy_listing.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../Services/Marketplace/listing_service.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/widgets/location_switcher.dart';
import 'create_listing_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class EnvMarketScreen extends StatefulWidget {
  const EnvMarketScreen({super.key});

  @override
  State<EnvMarketScreen> createState() => _EnvMarketScreenState();
}

class _EnvMarketScreenState extends State<EnvMarketScreen> {
  /// Wanted (buy orders) vs Offered (sell listings).
  ListingIntent _intent = ListingIntent.seeking;

  /// Everyone in the active geography, or only this org's own posts.
  bool _onlyMine = false;

  // org state
  String? _orgId;
  Map<String, dynamic>? _orgData;

  // material taxonomy sample images: subTypeId → imageUrl
  Map<String, String> _sampleImages = {};

  @override
  void initState() {
    super.initState();
    _loadOrg();
    _loadTaxonomy();
  }

  Future<void> _loadOrg() async {
    try {
      final contextData = await EnvironmentOpsService.instance.resolveContext();
      final orgId = contextData?.orgId;
      final orgDoc = contextData?.orgData;
      if (orgId == null || orgDoc == null) return;
      if (mounted) {
        setState(() {
          _orgId = orgId;
          _orgData = orgDoc;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTaxonomy() async {
    try {
      final raw = await rootBundle
          .loadString('assets/environmental/material_types.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cats = (json['categories'] as List).cast<Map<String, dynamic>>();
      final map = <String, String>{};
      for (final cat in cats) {
        for (final sub
            in (cat['sub_types'] as List).cast<Map<String, dynamic>>()) {
          final id = sub['id'] as String;
          final url = sub['sample_image_url'] as String?;
          if (url != null) map[id] = url;
        }
      }
      if (mounted) setState(() => _sampleImages = map);
    } catch (_) {}
  }

  String _imageForListing(CanopyListing l) {
    if (l.coverImage != null && l.coverImage!.isNotEmpty) return l.coverImage!;
    final subId = l.materialSubTypeId ?? '';
    return _sampleImages[subId] ??
        'https://picsum.photos/seed/${subId.isEmpty ? 'material' : subId}/400/250';
  }

  ListingQuery _query(LocationProvider location) => ListingQuery(
        // Scoping by geography rather than by org is the whole change.
        location: _onlyMine ? LocationFilter.everywhere : location.filter,
        side: ListingSide.supply,
        intent: _intent,
        orgId: _onlyMine ? _orgId : null,
      );

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            if (!_onlyMine) const LocationSwitcher(),
            _buildStatStrip(location),
            const SizedBox(height: 12),
            _buildTabSwitcher(),
            const SizedBox(height: 8),
            _buildScopeToggle(location),
            const SizedBox(height: 4),
            Expanded(child: _buildListings(location)),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (_orgId == null || _orgData == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Loading organisation data…'),
                    behavior: SnackBarBehavior.floating),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateListingScreen(
                  orgId: _orgId!,
                  orgData: _orgData!,
                ),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'Post Listing',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  Widget _buildStatStrip(LocationProvider location) {
    return FutureBuilder<MarketplaceTotals>(
      future: ListingService.instance.totals(location.filter),
      builder: (context, snap) {
        final t = snap.data;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Wanted here',
                      value: t == null ? '—' : '${t.seeking}')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'Offered here',
                      value: t == null ? '—' : '${t.offering}')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'Kg diverted',
                      value: t == null
                          ? '—'
                          : t.kgDiverted.round().toString())),
            ],
          ),
        );
      },
    );
  }

  // ── Tab switcher ─────────────────────────────────────────────────────────

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Tab(
              label: 'Wanted',
              active: _intent == ListingIntent.seeking,
              onTap: () =>
                  setState(() => _intent = ListingIntent.seeking)),
          const SizedBox(width: 8),
          _Tab(
              label: 'Offered',
              active: _intent == ListingIntent.offering,
              onTap: () =>
                  setState(() => _intent = ListingIntent.offering)),
        ],
      ),
    );
  }

  Widget _buildScopeToggle(LocationProvider location) {
    if (_orgId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _onlyMine
                ? 'Your organisation only'
                : 'Everyone in ${location.filter.label}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen.withOpacity(0.55),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _onlyMine = !_onlyMine),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _onlyMine
                    ? AppTheme.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.35), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _onlyMine
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 14,
                      color: AppTheme.primary),
                  const SizedBox(width: 5),
                  const Text('Only mine',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live listings ─────────────────────────────────────────────────────────

  Widget _buildListings(LocationProvider location) {
    return StreamBuilder<List<CanopyListing>>(
      stream: ListingService.instance.watch(_query(location)),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primary)),
          );
        }
        if (snap.hasError) {
          return _buildErrorState(snap.error.toString());
        }

        final listings = snap.data ?? const <CanopyListing>[];
        if (listings.isEmpty) return _buildEmptyState(location);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: listings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final l = listings[i];
            return _ListingCard(
              listing: l,
              imageUrl: _imageForListing(l),
              isOwn: l.orgId != null && l.orgId == _orgId,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(LocationProvider location) {
    final wanted = _intent == ListingIntent.seeking;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  wanted
                      ? Icons.search_outlined
                      : Icons.storefront_outlined,
                  size: 34,
                  color: AppTheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              wanted
                  ? 'Nobody is buying in ${location.filter.label} yet'
                  : 'Nothing offered in ${location.filter.label} yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              // A dense marketplace is local; an empty one should point you
              // outward rather than look broken.
              location.filter.isEverywhere
                  ? 'Post the first listing and start the market here'
                  : 'Widen to a region or country to see more',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkGreen.withOpacity(0.40),
              ),
            ),
            if (!location.filter.isEverywhere) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: location.showEverywhere,
                icon: const Icon(Icons.public_rounded, size: 16),
                label: const Text('Show everywhere'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 34, color: AppTheme.darkGreen.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'Could not load listings',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen.withOpacity(0.7)),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkGreen.withOpacity(0.45)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final CanopyListing listing;
  final String imageUrl;
  final bool isOwn;

  const _ListingCard({
    required this.listing,
    required this.imageUrl,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final isSeeking = listing.isSeeking;
    final grade = listing.materialGrade ?? '';
    final quantity = listing.quantity.quantityKg?.round() ?? 0;
    final unitWord = listing.pricing.unit == PriceUnit.perKg ? 'kg' : 'unit';
    final locationLabel = listing.location.label;
    final catLabel = listing.tagline;
    final notes = listing.story;

    final statusColor = switch (listing.status) {
      ListingStatus.active => const Color(0xFF2D7A4F),
      ListingStatus.paused => Colors.amber,
      ListingStatus.fulfilled => AppTheme.accent,
      ListingStatus.closed => Colors.grey,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isSeeking
            // Wanted posts read differently from offers at a glance — they are
            // a call to action, not a shelf item.
            ? Border.all(color: AppTheme.tertiary.withOpacity(0.55), width: 1.4)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ──────────────────────────────────────────────────────
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.primary.withOpacity(0.08),
                    child: Center(
                      child: Icon(Icons.image_outlined,
                          size: 36,
                          color: AppTheme.primary.withOpacity(0.25)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.primary.withOpacity(0.08),
                    child: Center(
                      child: Text(
                        _emojiForCategory(catLabel),
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Intent is the first thing you read on the card.
                Positioned(
                  top: 10,
                  left: 10,
                  child: _Badge(
                    label: isSeeking ? 'WANTED' : 'FOR SALE',
                    color: isSeeking ? AppTheme.tertiary : AppTheme.primary,
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black45)
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      if (listing.fulfilment.isRecurring)
                        _Badge(
                            label: 'Recurring',
                            color: const Color(0xFF6A1B9A)),
                      if (listing.fulfilment.isRecurring)
                        const SizedBox(width: 5),
                      _Badge(
                        label: listing.status.label.toUpperCase(),
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (grade.isNotEmpty) ...[
                      _GradeChip(label: grade),
                      const SizedBox(width: 6),
                    ],
                    if (catLabel.isNotEmpty)
                      Expanded(
                        child: Text(
                          catLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.50),
                          ),
                        ),
                      ),
                    if (isOwn) _GradeChip(label: 'Yours'),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      listing.pricing.display,
                      style: const TextStyle(
                        color: AppTheme.tertiary,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSeeking ? 'offered' : 'asking',
                      style: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.50),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Icon(Icons.scale_outlined,
                        size: 13,
                        color: AppTheme.darkGreen.withOpacity(0.45)),
                    const SizedBox(width: 4),
                    Text(
                      '$quantity $unitWord',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (listing.fulfilment.willCollect) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.local_shipping_outlined,
                          size: 13,
                          color: AppTheme.accent.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'They collect',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (locationLabel.isNotEmpty &&
                        locationLabel != 'Unknown location') ...[
                      const Spacer(),
                      Icon(Icons.place_outlined,
                          size: 13,
                          color: AppTheme.darkGreen.withOpacity(0.40)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.50),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Fill progress makes a buy order feel live rather than static.
                if (isSeeking && (listing.quantity.quantityKg ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: listing.quantity.fillProgress,
                      minHeight: 5,
                      backgroundColor: AppTheme.lightGreen.withOpacity(0.22),
                      valueColor: const AlwaysStoppedAnimation(
                          AppTheme.tertiary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.quantity.remainingKg.round()} $unitWord still needed'
                    '${listing.responseCount > 0 ? ' · ${listing.responseCount} responded' : ''}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.darkGreen.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.50),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                Row(
                  children: [
                    if (isOwn)
                      _ActionBtn(
                        label:
                            'Responses${listing.responseCount > 0 ? ' (${listing.responseCount})' : ''}',
                        onTap: () => _soon(context),
                      )
                    else
                      _ActionBtn(
                        // The action the old screen could never offer, because
                        // you only ever saw your own posts.
                        label: isSeeking ? 'I have this' : 'I want this',
                        onTap: () => _soon(context),
                      ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      label: isOwn ? 'Edit' : 'Contact',
                      outlined: true,
                      onTap: () => _soon(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _emojiForCategory(String catLabel) {
    final lower = catLabel.toLowerCase();
    if (lower.contains('plastic')) return '♻️';
    if (lower.contains('metal')) return '🔩';
    if (lower.contains('electron')) return '📱';
    if (lower.contains('paper') || lower.contains('card')) return '📦';
    if (lower.contains('glass')) return '🍾';
    if (lower.contains('rubber')) return '⚙️';
    if (lower.contains('wood')) return '🪵';
    if (lower.contains('text')) return '👕';
    return '♻️';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent
                : AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? Colors.white
                  : AppTheme.darkGreen.withOpacity(0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  final String label;
  const _GradeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, this.outlined = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.primary.withOpacity(0.6)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.primary)),
      );
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
    );
  }
}
