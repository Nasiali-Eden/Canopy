// lib/HomeServices/browse_service_listings_screen.dart
//
// Per-category browse — the Services equivalent of the Marketplace feed, but
// scoped to one ServiceCategory rather than the location switch (Services is
// piloting in one market first, so a geo filter would just be an empty state
// generator right now; ServiceMarketplaceService.watchListings already
// accepts a LocationFilter for when that's ready).

import 'package:flutter/material.dart';

import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../Shared/theme/app_theme.dart';
import 'create_service_listing_screen.dart';
import 'service_listing_detail_screen.dart';

class BrowseServiceListingsScreen extends StatefulWidget {
  final ServiceCategory category;

  const BrowseServiceListingsScreen({required this.category, super.key});

  @override
  State<BrowseServiceListingsScreen> createState() =>
      _BrowseServiceListingsScreenState();
}

class _BrowseServiceListingsScreenState
    extends State<BrowseServiceListingsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ServiceListingQuery(category: widget.category, searchText: _search);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: Text(widget.category.label,
            style: const TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.category.label.toLowerCase()} providers',
                  hintStyle: TextStyle(color: AppTheme.darkGreen.withOpacity(0.35)),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ServiceListing>>(
              stream: ServiceMarketplaceService.instance.watchListings(query),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final listings = snap.data ?? const [];
                if (listings.isEmpty) {
                  return _EmptyState(category: widget.category);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: listings.length,
                  itemBuilder: (context, i) => _ListingCard(
                    listing: listings[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ServiceListingDetailScreen(listingId: listings[i].id),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateServiceListingScreen(category: widget.category),
          ),
        ),
        backgroundColor: AppTheme.tertiary,
        foregroundColor: AppTheme.darkGreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('List your service',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final ServiceListing listing;
  final VoidCallback onTap;

  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(listing.category.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                      ),
                      if (listing.isVerifiedProvider) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 15, color: AppTheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    listing.provider.shopName.isNotEmpty
                        ? listing.provider.shopName
                        : 'Independent provider',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: listing.offeringLabels
                        .take(3)
                        .map((o) => _Chip(label: o))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        listing.pricing.display,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      if (listing.location.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.place_outlined,
                            size: 13, color: AppTheme.darkGreen.withOpacity(0.4)),
                        const SizedBox(width: 2),
                        Text(
                          listing.location.shortLabel,
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.darkGreen.withOpacity(0.5)),
                        ),
                      ],
                      if (listing.reviewCount > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded, size: 14, color: AppTheme.tertiary),
                        const SizedBox(width: 2),
                        Text(
                          listing.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.darkGreen.withOpacity(0.6)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.darkGreen),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ServiceCategory category;
  const _EmptyState({required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(
              'No ${category.label.toLowerCase()} providers yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to list — tap "List your service" below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
