import 'package:flutter/material.dart';
import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/canopy_bottom_bar.dart';
import 'Feed/seller_feed.dart';
import 'Shop/seller_shop.dart';
import 'Learn/learn.dart';
import 'Profile/seller_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SellerHomeScreen
//
//  Root shell for the Canopy Marketplace seller.
//  Mirrors OrganizationHome structure exactly.
//
//  Tabs:
//    0 · Feed        — community feed + seller impact strip
//    1 · Shop        — listings, orders, browse  [FAB: New Listing]
//    2 · Learn       — blockchain articles for organizations and artisans
//    3 · Profile     — seller storefront + verified history
// ─────────────────────────────────────────────────────────────────────────────

class SellerHomeScreen extends StatefulWidget {
  /// Builders for context switching. Passed through to SellerProfilePage.
  /// Defined here (not in SellerProfilePage) to avoid circular imports.
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? envOpsContextBuilder;
  final WidgetBuilder? culturalContextBuilder;
  final bool hasEnvOps;
  final bool hasCultural;

  const SellerHomeScreen({
    super.key,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.envOpsContextBuilder,
    this.culturalContextBuilder,
    this.hasEnvOps = false,
    this.hasCultural = false,
  });

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  int _index = 0;

  void _onCreateListing() {
    // TODO: navigate to the Create Listing flow inside SellerShopPage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Create Listing — coming soon',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: AppTheme.tertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const SellerFeedPage(),
      const SellerShopPage(),
      const LearnPage(),
      SellerProfilePage(
        orgContextBuilder: widget.orgContextBuilder,
        memberContextBuilder: widget.memberContextBuilder,
        envOpsContextBuilder: widget.envOpsContextBuilder,
        culturalContextBuilder: widget.culturalContextBuilder,
        hasEnvOps: widget.hasEnvOps,
        hasCultural: widget.hasCultural,
      ),
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        
        bottomNavigationBar: CanopyBottomBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          // Shop is the centre of gravity for a seller — gold when it is the
          // active tab, brand green elsewhere. Same rule the old bar used, now
          // expressed once instead of across three theme callbacks.
          selectedColor: _index == 1 ? AppTheme.tertiary : AppTheme.primary,
          destinations: const [
            CanopyNavDestination(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Feed',
            ),
            CanopyNavDestination(
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront_rounded,
              label: 'Shop',
            ),
            CanopyNavDestination(
              icon: Icons.school_outlined,
              activeIcon: Icons.school_rounded,
              label: 'Learn',
            ),
            CanopyNavDestination(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
