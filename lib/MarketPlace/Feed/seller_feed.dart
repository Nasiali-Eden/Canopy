import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SellerFeedPage
//
//  Marketplace seller feed. Displays:
//    1. Seller impact strip (donations, impact points, listings, buy orders)
//    2. Community feed (standard community contribution feed)
//
//  Data source: marketplace_sellers/{uid} for seller metrics
// ─────────────────────────────────────────────────────────────────────────────

class SellerFeedPage extends StatelessWidget {
  const SellerFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'Marketplace',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: AppTheme.primary.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Not authenticated',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.darkGreen.withOpacity(0.5),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 68,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('marketplace_sellers')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            final shopName = snapshot.data?['shop_name'] ?? 'Seller';
            final role = snapshot.data?['marketplace_role'] ?? 'Seller';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shopName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.tertiary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('marketplace_sellers')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (!snapshot.hasData) {
            return _buildEmptyState();
          }

          final sellerData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final activeListings = sellerData['active_listings'] as int? ?? 0;
          final kgDiverted = sellerData['kg_diverted'] as double? ?? 0.0;
          final impactPoints = sellerData['impact_points'] as int? ?? 0;
          final role = sellerData['marketplace_role'] as String? ?? 'Seller';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller Impact Strip
                _buildImpactStrip(
                  activeListings: activeListings,
                  kgDiverted: kgDiverted,
                  impactPoints: impactPoints,
                  role: role,
                ),

                // Community Feed placeholder
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community Feed',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildCommunityFeedPlaceholder(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImpactStrip({
    required int activeListings,
    required double kgDiverted,
    required int impactPoints,
    required String role,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.primary.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Impact',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatCard(
                  label: 'Listings Active',
                  value: activeListings.toString(),
                  icon: Icons.storefront_outlined,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Kg Diverted',
                  value: '${kgDiverted.toStringAsFixed(1)} kg',
                  icon: Icons.scale_outlined,
                  color: AppTheme.secondary,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Impact Points',
                  value: impactPoints.toString(),
                  icon: Icons.stars_outlined,
                  color: AppTheme.tertiary,
                ),
                const SizedBox(width: 12),
                if (role == 'Maker') ...[
                  _StatCard(
                    label: 'Craft Badge',
                    value: 'Pending',
                    icon: Icons.verified_outlined,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 12),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityFeedPlaceholder() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.feed_outlined,
                size: 40,
                color: AppTheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Community Feed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'View activities and contributions from the Canopy community',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TODO: Integrate community feed widget',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 48,
            color: AppTheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No seller data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Settings or data loading issue',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.darkGreen.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to detail view for this metric
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label detail view — coming soon'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
