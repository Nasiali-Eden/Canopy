// lib/HomeServices/services_home_screen.dart
//
// Replaces ComingSoonScreen as the destination of home_feed.dart's
// "Services" entry card (Phase 4.1 of the roadmap). A category picker —
// piloting trash collection and landscaping only, per ServiceCategory.
// Structurally this is the Services equivalent of EcoShopScreen's landing
// tier: pick a lane, then browse.

import 'package:flutter/material.dart';

import '../Models/services/service_listing.dart';
import '../Shared/theme/app_theme.dart';
import 'browse_service_listings_screen.dart';
import 'my_service_bookings_screen.dart';
import 'my_service_listings_screen.dart';

class ServicesHomeScreen extends StatelessWidget {
  const ServicesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Services',
            style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'My bookings',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyServiceBookingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'My listings',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyServiceListingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Book trusted local help',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "We're piloting two categories first — providers set their own "
            'price, you get a quote before anything is charged.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.darkGreen.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 20),
          for (final category in ServiceCategory.values) ...[
            _CategoryCard(
              category: category,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BrowseServiceListingsScreen(category: category),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(category.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    category.tagline,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.darkGreen.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 15, color: AppTheme.darkGreen.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }
}
