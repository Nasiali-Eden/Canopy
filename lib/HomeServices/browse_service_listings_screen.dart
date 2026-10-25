// lib/HomeServices/browse_service_listings_screen.dart
//
// Browse (SERVICES_HANDOFF §3.2): search "Search [category] providers" →
// (regulated) "Every [trade] here has a licence Canopy has checked." → count
// → ListingCards → quiet "Are you a [trade]? List your service".
// States: loading · no providers yet (+ List your service) · no search
// results (+ Clear search) · error. Unverified electrical/plumbing listings
// never appear here (ServiceMarketplaceService client filter).

import 'package:flutter/material.dart';

import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import 'create_service_listing_screen.dart';
import 'service_listing_detail_screen.dart';
import 'services_ui.dart';

class BrowseServiceListingsScreen extends StatefulWidget {
  final ServiceCategory category;
  const BrowseServiceListingsScreen({required this.category, super.key});

  @override
  State<BrowseServiceListingsScreen> createState() => _BrowseServiceListingsScreenState();
}

class _BrowseServiceListingsScreenState extends State<BrowseServiceListingsScreen> {
  final _search = TextEditingController();
  String _query = '';
  int _retry = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _list() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateServiceListingScreen(initialCategory: widget.category)));

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final c = widget.category;
    final stream = ServiceMarketplaceService.instance
        .watchListings(ServiceListingQuery(category: c, searchText: _query));

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: c.name2),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s8),
            child: CanopyTextField.search(
              hint: 'Search ${c.name2.toLowerCase()} providers',
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          if (c.requiresLicenseVerification)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s8),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: CanopyIconSize.s16, color: p.success),
                  const SizedBox(width: CanopySpace.s8),
                  Expanded(
                    child: Text('Every ${c.tradeNoun} here has a licence Canopy has checked.',
                        style: CanopyType.caption.copyWith(color: p.ink)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ServiceListing>>(
              key: ValueKey(_retry),
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return CanopyErrorState(
                      title: "Couldn't load providers",
                      onRetry: () => setState(() => _retry++));
                }
                if (!snap.hasData) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                    children: const [
                      CanopySkeleton(height: 118, radius: CanopyRadius.md),
                      SizedBox(height: CanopySpace.s12),
                      CanopySkeleton(height: 118, radius: CanopyRadius.md),
                    ],
                  );
                }
                final list = snap.data!;
                if (list.isEmpty && _query.isNotEmpty) {
                  return CanopyEmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No providers match "$_query"',
                    actionLabel: 'Clear search',
                    onAction: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  );
                }
                if (list.isEmpty) {
                  return CanopyEmptyState(
                    icon: c.icon,
                    title: 'No ${c.name2.toLowerCase()} providers yet',
                    line: 'Be the first to offer this in your area.',
                    actionLabel: 'List your service',
                    onAction: _list,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
                  children: [
                    Text('${list.length} provider${list.length == 1 ? '' : 's'}',
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                    const SizedBox(height: CanopySpace.s8),
                    for (final l in list) ...[
                      ListingCard(
                        listing: l,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ServiceListingDetailScreen(listingId: l.id)),
                        ),
                      ),
                      const SizedBox(height: CanopySpace.s12),
                    ],
                    Center(
                      child: CanopyButton.quiet(
                        label: 'Are you a ${c.tradeNoun}? List your service',
                        onPressed: _list,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
