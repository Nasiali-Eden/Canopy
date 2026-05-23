import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Community/Home/community_home.dart';
import '../../Organization/Home/org_home.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/widgets/role_context_switcher.dart';

class MarketplaceSellerStubScreen extends StatelessWidget {
  final String orgId;
  final String? sellerRole;

  const MarketplaceSellerStubScreen({
    super.key,
    required this.orgId,
    this.sellerRole,
  });

  Future<Map<String, dynamic>?> _fetchOrgData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final orgDoc =
          await firestore.collection('organizations').doc(orgId).get();
      if (orgDoc.exists) {
        return orgDoc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      return null;
    }
  }

  String _getRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'collector':
        return 'Collector';
      case 'processor':
        return 'Processor';
      case 'maker':
        return 'Maker / Artisan';
      default:
        return 'Seller';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'collector':
        return AppTheme.primary;
      case 'processor':
        return AppTheme.accent;
      case 'maker':
        return AppTheme.tertiary;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchOrgData(),
      builder: (context, snapshot) {
        final orgData = snapshot.data;
        final hasMarketplace = orgData?['marketplaceStatus'] == 'approved';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              color: AppTheme.darkGreen,
            ),
            title: Text(
              'Marketplace',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // ── Role Context Switcher ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RoleContextSwitcher(
                    activeContext: 'marketplace',
                    hasMarketplace: hasMarketplace,
                    onOrgTap: () {
                      // Switch to Org context (full shell)
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrganizationHome(),
                        ),
                        (route) => false,
                      );
                    },
                    onMemberTap: () {
                      // Switch to Community context (full shell)
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CommunityHomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    onMarketplaceTap: () {
                      // Already on marketplace context, no-op
                    },
                  ),
                ),
                const SizedBox(height: 32),
                // ── Seller Role Badge ─────────────────────────────────
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getRoleColor(sellerRole).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getRoleColor(sellerRole).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconForRole(sellerRole),
                          size: 14,
                          color: _getRoleColor(sellerRole),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getRoleLabel(sellerRole),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(sellerRole),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Placeholder Text ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        'Your marketplace listings will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.darkGreen.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Full marketplace screen coming soon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.lightGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForRole(String? role) {
    switch (role?.toLowerCase()) {
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
