import 'package:flutter/material.dart';

import '../../Shared/Activities/activities_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SellerActivitiesPage
//
//  IDENTICAL to the community activities page.
//  Sellers are community members and see all community activities.
//  No seller-specific content. Use existing activities list widget.
// ─────────────────────────────────────────────────────────────────────────────

class SellerActivitiesPage extends StatelessWidget {
  const SellerActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ActivitiesListScreen(embedded: true);
  }
}
