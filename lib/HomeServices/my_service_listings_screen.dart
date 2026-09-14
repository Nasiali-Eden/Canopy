// lib/HomeServices/my_service_listings_screen.dart
//
// A provider's own listings, manage-card style — same visual language as
// OrgArticlesScreen's _ArticleManageCard (rounded 18px card, thumb chip,
// status pill, tap target for the primary action) so "manage things I
// posted" reads the same across Articles and Services.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../Shared/theme/app_theme.dart';
import 'create_service_listing_screen.dart';
import 'service_listing_detail_screen.dart';

class MyServiceListingsScreen extends StatelessWidget {
  const MyServiceListingsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _pickCategoryAndCreate(BuildContext context) async {
    final category = await showModalBottomSheet<ServiceCategory>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What are you listing?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
            const SizedBox(height: 16),
            for (final c in ServiceCategory.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(c.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
                subtitle: Text(c.tagline, style: TextStyle(fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.55))),
                onTap: () => Navigator.pop(sheetContext, c),
              ),
          ],
        ),
      ),
    );
    if (category != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateServiceListingScreen(category: category)),
      );
    }
  }

  Future<void> _toggleStatus(ServiceListing listing) {
    final next = listing.status == ServiceListingStatus.active
        ? ServiceListingStatus.paused
        : ServiceListingStatus.active;
    return ServiceMarketplaceService.instance.setListingStatus(listing.id, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('My Listings',
            style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () => _pickCategoryAndCreate(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: StreamBuilder<List<ServiceListing>>(
        stream: ServiceMarketplaceService.instance.watchListingsByProvider(_uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = snap.data ?? const [];
          if (listings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined, size: 40, color: AppTheme.darkGreen.withOpacity(0.3)),
                    const SizedBox(height: 14),
                    const Text("You haven't listed a service yet",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
                    const SizedBox(height: 6),
                    Text('Tap "New" to offer trash collection or landscaping.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.55))),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: listings.length,
            itemBuilder: (context, i) => _ListingManageCard(
              listing: listings[i],
              onToggleStatus: () => _toggleStatus(listings[i]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ServiceListingDetailScreen(listingId: listings[i].id)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ListingManageCard extends StatelessWidget {
  final ServiceListing listing;
  final VoidCallback onToggleStatus;
  final VoidCallback onTap;

  const _ListingManageCard({required this.listing, required this.onToggleStatus, required this.onTap});

  Color get _statusColor => switch (listing.status) {
        ServiceListingStatus.active => AppTheme.primary,
        ServiceListingStatus.paused => AppTheme.tertiary,
        ServiceListingStatus.closed => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(listing.category.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
                    const SizedBox(height: 3),
                    Text(listing.pricing.display,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusPill(label: listing.status.label, color: _statusColor),
                        const SizedBox(width: 10),
                        Icon(Icons.event_note_outlined, size: 13, color: AppTheme.darkGreen.withOpacity(0.4)),
                        const SizedBox(width: 3),
                        Text('${listing.bookingCount} bookings',
                            style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
                        const SizedBox(width: 10),
                        Icon(Icons.visibility_outlined, size: 13, color: AppTheme.darkGreen.withOpacity(0.4)),
                        const SizedBox(width: 3),
                        Text('${listing.viewCount}',
                            style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggleStatus,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    listing.status == ServiceListingStatus.active
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 22,
                    color: AppTheme.darkGreen.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
