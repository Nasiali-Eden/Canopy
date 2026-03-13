import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Services/Authentication/auth.dart';
import '../../Shared/Pages/login.dart';
import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SellerProfilePage
//
//  Marketplace seller profile. Displays:
//    1. Shop header (banner with shop logo, name, role, location, bio)
//    2. Stats row (kg_diverted, impact_points, active_listings)
//    3. Transaction history section
//    4. Material specialisations
//    5. Craft badge (for Makers only)
//    6. Settings section
//    7. Sign out button
//
//  Data source: marketplace_sellers/{uid}
// ─────────────────────────────────────────────────────────────────────────────

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  final AuthService _authService = AuthService();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: const Text(
            'My Profile',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 18,
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
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Navigate to edit profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit profile — coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
        ],
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
          final shopName = sellerData['shop_name'] as String? ?? 'Shop';
          final role = sellerData['marketplace_role'] as String? ?? 'Seller';
          final city = sellerData['city'] as String? ?? '';
          final area = sellerData['area'] as String? ?? '';
          final bio = sellerData['bio'] as String? ?? '';
          final shopLogoUrl = sellerData['shop_logo_url'] as String?;
          final kgDiverted = sellerData['kg_diverted'] as double? ?? 0.0;
          final impactPoints = sellerData['impact_points'] as int? ?? 0;
          final activeListings = sellerData['active_listings'] as int? ?? 0;
          final specialisations =
              List<String>.from(sellerData['specialisations'] as List? ?? []);
          final creativeCategories = List<String>.from(
              sellerData['creative_categories'] as List? ?? []);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Shop Header
                _buildShopHeader(
                  shopName: shopName,
                  role: role,
                  city: city,
                  area: area,
                  bio: bio,
                  logoUrl: shopLogoUrl,
                ),

                const SizedBox(height: 20),

                // Stats Row
                _buildStatsRow(
                  kgDiverted: kgDiverted,
                  impactPoints: impactPoints,
                  activeListings: activeListings,
                ),

                const SizedBox(height: 24),

                // Transaction History
                _buildTransactionHistorySection(context),

                const SizedBox(height: 24),

                // Specialisations
                if (specialisations.isNotEmpty)
                  _buildSpecialisationsSection(
                    specialisations: specialisations,
                    creativeCategories: creativeCategories,
                    role: role,
                  ),

                if (specialisations.isNotEmpty) const SizedBox(height: 24),

                // Craft Badge (Makers only)
                if (role == 'Maker') ...[
                  _buildCraftBadgeSection(context),
                  const SizedBox(height: 24),
                ],

                // Settings
                _buildSettingsSection(context),

                const SizedBox(height: 16),

                // Sign Out
                _buildSignOutButton(context),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShopHeader({
    required String shopName,
    required String role,
    required String city,
    required String area,
    required String bio,
    required String? logoUrl,
  }) {
    final locationText = [area, city].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.darkGreen, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + Role
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.storefront_outlined,
                              size: 32,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _roleIcon(role),
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            role,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Location
          if (locationText.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: Colors.white.withOpacity(0.75),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Bio
          if (bio.isNotEmpty)
            Text(
              bio,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required double kgDiverted,
    required int impactPoints,
    required int activeListings,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Kg Diverted',
              value: kgDiverted.toStringAsFixed(1),
              icon: Icons.scale_outlined,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Impact Points',
              value: impactPoints.toString(),
              icon: Icons.stars_outlined,
              color: AppTheme.tertiary,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('M-Pesa redemption — coming soon'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Listings',
              value: activeListings.toString(),
              icon: Icons.storefront_outlined,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistorySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: AppTheme.tertiary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Transaction History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 40,
                  color: AppTheme.primary.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your verified transaction history will appear here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Every completed sale builds your pricing leverage.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkGreen.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialisationsSection({
    required List<String> specialisations,
    required List<String> creativeCategories,
    required String role,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specialisations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialisations.map((spec) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Text(
                  spec,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              );
            }).toList(),
          ),
          if (role == 'Maker' && creativeCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Creative Categories',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: creativeCategories.map((cat) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCraftBadgeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.tertiary.withOpacity(0.12),
              AppTheme.tertiary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.tertiary.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.verified_rounded,
              size: 48,
              color: AppTheme.tertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Pending Review',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.tertiary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Circular Craft Badge',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.tertiary.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Awarded for sourcing materials directly from the Canopy supply chain.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.darkGreen.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                // TODO: Navigate to learn more
              },
              child: const Text('Learn More'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.storefront_outlined,
                title: 'Edit Shop Details',
                onTap: () {
                  // TODO: Navigate to edit shop
                },
              ),
              _SettingsItem(
                icon: Icons.category,
                title: 'Edit Specialisations',
                onTap: () {
                  // TODO: Navigate to edit specialisations
                },
              ),
              _SettingsItem(
                icon: Icons.lock,
                title: 'Change Password',
                onTap: () {
                  // TODO: Navigate to change password
                },
              ),
              _SettingsItem(
                icon: Icons.notifications,
                title: 'Notifications',
                onTap: () {
                  // TODO: Navigate to notifications
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (shouldSignOut == true) {
                await _authService.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.logout, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      ),
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

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'collector':
        return Icons.recycling_outlined;
      case 'processor':
        return Icons.factory_outlined;
      case 'maker':
        return Icons.palette_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: isLast ? const Radius.circular(16) : Radius.zero,
                  ),
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon,
                              color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.darkGreen,
                                ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 62),
                  child: Divider(
                    height: 1,
                    color: AppTheme.lightGreen.withOpacity(0.2),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
