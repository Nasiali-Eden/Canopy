// lib/MarketPlace/market_home.dart
//
// Marketplace seller shell (MARKETPLACE_SELLER_DESIGN_BRIEF §4). Tabs
// Feed · Shop · Learn · Profile on the shared v2 bottom bar. The Shop tab
// owns "New listing" — there's no dead-end create button here.

import 'package:flutter/material.dart';

import '../Shared/widgets/canopy_bottom_bar.dart';
import '../theme/canopy_components.dart';
import 'Feed/seller_feed.dart';
import 'Learn/learn.dart';
import 'Profile/seller_profile.dart';
import 'Shop/seller_shop.dart';

class SellerHomeScreen extends StatefulWidget {
  /// Builders for workspace switching, passed through to the Profile tab.
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: CanopyScaffold(
        body: IndexedStack(index: _index, children: [
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
        ]),
        bottomNavigationBar: CanopyBottomBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          destinations: const [
            CanopyNavDestination(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Feed'),
            CanopyNavDestination(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Shop'),
            CanopyNavDestination(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Learn'),
            CanopyNavDestination(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
