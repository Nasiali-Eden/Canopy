import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';
import 'Feed/seller_feed.dart';
import 'Activities/seller_activities.dart';
import 'Shop/seller_shop.dart';
import 'Map/seller_map.dart';
import 'Profile/seller_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SellerHomeScreen
//
//  Root shell for the Canopy Marketplace seller.
//  Mirrors OrganizationHome structure exactly.
//
//  Tabs (spec Section 3.1):
//    0 · Feed        — community feed + seller impact strip
//    1 · Activities  — shared with all community members (unchanged)
//    2 · Shop        — listings, orders, browse  [FAB: New Listing]
//    3 · Map         — community map + marketplace layers
//    4 · Profile     — seller storefront + verified history
// ─────────────────────────────────────────────────────────────────────────────

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

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
      const SellerActivitiesPage(),
      const SellerShopPage(),
      const SellerMapPage(),
      const SellerProfilePage(),
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        // FAB only on Shop tab (index 2)
        floatingActionButton: _index == 2
            ? FloatingActionButton.extended(
          onPressed: _onCreateListing,
          backgroundColor: AppTheme.tertiary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Listing',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        )
            : null,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: _index == 2 ? AppTheme.tertiary : AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    );
                  }
                  return TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  );
                }),
              ),
              child: NavigationBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                indicatorColor: _index == 2
                    ? AppTheme.tertiary.withOpacity(0.15)
                    : AppTheme.primary.withOpacity(0.15),
                height: 70,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon:
                    Icon(Icons.home_rounded, color: AppTheme.primary),
                    label: 'Feed',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon: Icon(Icons.calendar_today_rounded,
                        color: AppTheme.primary),
                    label: 'Activities',
                  ),
                  // Centre tab — Shop, gold accent
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon:
                    Icon(Icons.storefront_rounded, color: AppTheme.tertiary),
                    label: 'Shop',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon:
                    Icon(Icons.map_rounded, color: AppTheme.primary),
                    label: 'Map',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon:
                    Icon(Icons.person_rounded, color: AppTheme.primary),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
