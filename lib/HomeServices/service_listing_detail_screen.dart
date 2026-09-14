// lib/HomeServices/service_listing_detail_screen.dart
//
// Read-only listing detail — provider profile + pricing + a single "Request
// this service" call to action. Deliberately no in-line quote here: the job
// price is negotiated on ServiceBooking, not advertised on the listing (see
// ServiceListing's file header).

import 'package:flutter/material.dart';

import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../Shared/theme/app_theme.dart';
import 'request_service_booking_screen.dart';

class ServiceListingDetailScreen extends StatefulWidget {
  final String listingId;

  const ServiceListingDetailScreen({required this.listingId, super.key});

  @override
  State<ServiceListingDetailScreen> createState() =>
      _ServiceListingDetailScreenState();
}

class _ServiceListingDetailScreenState
    extends State<ServiceListingDetailScreen> {
  @override
  void initState() {
    super.initState();
    ServiceMarketplaceService.instance.incrementListingView(widget.listingId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      body: StreamBuilder<ServiceListing?>(
        stream: ServiceMarketplaceService.instance.watchListingById(widget.listingId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final listing = snap.data;
          if (listing == null) {
            return const Center(child: Text('This listing is no longer available'));
          }
          return _Body(listing: listing);
        },
      ),
      bottomNavigationBar: StreamBuilder<ServiceListing?>(
        stream: ServiceMarketplaceService.instance.watchListingById(widget.listingId),
        builder: (context, snap) {
          final listing = snap.data;
          if (listing == null) return const SizedBox.shrink();
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RequestServiceBookingScreen(listing: listing),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 17),
                    SizedBox(width: 8),
                    Text('Request this service',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ServiceListing listing;
  const _Body({required this.listing});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppTheme.darkGreen,
          pinned: true,
          expandedHeight: 190,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(listing.category.emoji, style: const TextStyle(fontSize: 56)),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
                      ),
                    ),
                    if (listing.isVerifiedProvider)
                      const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  listing.category.label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
                const SizedBox(height: 16),

                // ── Provider card ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.lightGreen.withOpacity(0.25),
                        child: Text(
                          listing.provider.shopName.isNotEmpty
                              ? listing.provider.shopName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.provider.shopName.isNotEmpty
                                  ? listing.provider.shopName
                                  : 'Independent provider',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (listing.reviewCount > 0) ...[
                                  const Icon(Icons.star_rounded, size: 14, color: AppTheme.tertiary),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${listing.averageRating.toStringAsFixed(1)} (${listing.reviewCount})',
                                    style: TextStyle(
                                        fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.6)),
                                  ),
                                ] else
                                  Text('New provider',
                                      style: TextStyle(
                                          fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.5))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  listing.pricing.display,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary),
                ),
                Text(
                  "Starting figure — the provider confirms your final price once they see the job",
                  style: TextStyle(fontSize: 11.5, color: AppTheme.darkGreen.withOpacity(0.55)),
                ),
                const SizedBox(height: 18),

                if (listing.offeringLabels.isNotEmpty) ...[
                  const _SectionLabel('What they offer'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: listing.offeringLabels
                        .map((o) => _Chip(label: o))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                ],

                if (listing.description.isNotEmpty) ...[
                  const _SectionLabel('About this provider'),
                  const SizedBox(height: 8),
                  Text(
                    listing.description,
                    style: TextStyle(
                        fontSize: 13.5, height: 1.5, color: AppTheme.darkGreen.withOpacity(0.75)),
                  ),
                  const SizedBox(height: 18),
                ],

                if (listing.location.isNotEmpty) ...[
                  const _SectionLabel('Coverage'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: AppTheme.darkGreen.withOpacity(0.5)),
                      const SizedBox(width: 6),
                      Text(listing.location.label,
                          style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.75))),
                      if (listing.serviceRadiusKm > 0) ...[
                        const SizedBox(width: 10),
                        Text('· ${listing.serviceRadiusKm.round()}km radius',
                            style: TextStyle(fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.5))),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.darkGreen)),
    );
  }
}
