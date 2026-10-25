// lib/Shared/widgets/workspace_switch.dart
//
// One place that knows how to move between workspaces (member · org ·
// marketplace · env ops · cultural archive) for an org rep. Used by the org
// masthead's workspace chip and any other shell that needs the RoleSwitcher
// sheet without the card.

import 'package:flutter/material.dart';

import '../../Community/Home/community_home.dart';
import '../../Culture/culture_home.dart';
import '../../EnvironmentalOps/env_ops_shell.dart';
import '../../MarketPlace/market_home.dart';
import '../../Organization/Home/org_home.dart';
import 'role_context_switcher.dart';

RoleContextSwitcher workspaceSwitcher(
  BuildContext context, {
  required String activeContext,
  required String orgId,
  required Map<String, dynamic> org,
}) {
  final hasMarketplace = org['marketplaceStatus'] == 'approved';
  final hasEnvOps = org['envOpsStatus'] == 'approved';
  final hasCultural = org['culturalStatus'] == 'approved';
  void go(Widget screen) => Navigator.of(context, rootNavigator: true)
      .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => screen), (_) => false);
  return RoleContextSwitcher(
    activeContext: activeContext,
    hasMarketplace: hasMarketplace,
    hasEnvOps: hasEnvOps,
    hasCultural: hasCultural,
    onMemberTap: () => go(const CommunityHomeScreen()),
    onOrgTap: () => go(const OrganizationHome()),
    onMarketplaceTap: () => go(const SellerHomeScreen()),
    onEnvOpsTap: () => go(EnvOpsShell(
      hasMarketplace: hasMarketplace,
      hasCultural: hasCultural,
      orgContextBuilder: (_) => const OrganizationHome(),
      memberContextBuilder: (_) => const CommunityHomeScreen(),
      marketplaceContextBuilder: hasMarketplace ? (_) => const SellerHomeScreen() : null,
      culturalContextBuilder: hasCultural
          ? (_) => CultureHomeScreen(
              orgId: orgId, memberContextBuilder: (_) => const CommunityHomeScreen())
          : null,
    )),
    onCulturalTap: () => go(CultureHomeScreen(
        orgId: orgId, memberContextBuilder: (_) => const CommunityHomeScreen())),
  );
}
