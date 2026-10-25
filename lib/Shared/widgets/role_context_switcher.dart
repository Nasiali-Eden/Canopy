// lib/Shared/widgets/role_context_switcher.dart
//
// RoleSwitcher (DESIGN_HANDOFF.md §2): a card at the top of Profile, shown
// only to people with more than one context. It says which context you're in
// and opens a sheet that explains what each of the others unlocks. Used by
// the member, org, marketplace, env-ops and culture shells.

import 'package:flutter/material.dart';

import '../../Organization/Access/org_picker.dart';
import '../../theme/canopy_components.dart';

class RoleContextSwitcher extends StatelessWidget {
  final String activeContext; // 'org' | 'member' | 'marketplace' | 'envOps' | 'cultural'
  final bool hasMarketplace;
  final bool hasEnvOps;
  final bool hasCultural;
  final VoidCallback onOrgTap;
  final VoidCallback onMemberTap;
  final VoidCallback? onMarketplaceTap;
  final VoidCallback? onEnvOpsTap;
  final VoidCallback? onCulturalTap;

  const RoleContextSwitcher({
    super.key,
    required this.activeContext,
    required this.hasMarketplace,
    this.hasEnvOps = false,
    this.hasCultural = false,
    required this.onOrgTap,
    required this.onMemberTap,
    this.onMarketplaceTap,
    this.onEnvOpsTap,
    this.onCulturalTap,
  });

  List<(String, String, String, IconData, VoidCallback?)> get _contexts => [
        ('member', 'Member', 'Your impact, events and community feed',
            Icons.person_outline, onMemberTap),
        ('org', 'Organisation workspace', 'Host events, publish articles, manage people',
            Icons.apartment_outlined, onOrgTap),
        if (hasMarketplace)
          ('marketplace', 'Marketplace seller', 'Your shop, listings and buy orders',
              Icons.storefront_outlined, onMarketplaceTap),
        if (hasEnvOps)
          ('envOps', 'Environmental Ops', 'Territory, trees, fleet and material market',
              Icons.eco_outlined, onEnvOpsTap),
        if (hasCultural)
          ('cultural', 'Cultural Archive', 'Catalogue heritage entries for your communities',
              Icons.auto_stories_outlined, onCulturalTap),
      ];

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final current = _contexts.firstWhere((c) => c.$1 == activeContext,
        orElse: () => _contexts.first);
    return CanopyCard(
      onTap: () => openSheet(context),
      child: Row(
        children: [
          Icon(current.$4, size: CanopyIconSize.nav, color: p.ink),
          const SizedBox(width: CanopySpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("YOU'RE IN", style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                Text(current.$2, style: CanopyType.subhead.copyWith(color: p.ink)),
                Text('${_contexts.length - 1} other workspace${_contexts.length == 2 ? '' : 's'}',
                    style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ],
            ),
          ),
          Text('Switch', style: CanopyType.label.copyWith(color: p.primaryInk)),
          Icon(Icons.chevron_right, size: CanopyIconSize.s18, color: p.primaryInk),
        ],
      ),
    );
  }

  void openSheet(BuildContext context) {
    showCanopySheet<void>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: 'Switch workspace',
        caption: 'Each workspace shows the tools for that role.',
        children: [
          CanopyListGroup(children: [
            for (final c in _contexts)
              CanopyListRow(
                icon: c.$4,
                title: c.$2,
                subtitle: c.$3,
                chevron: c.$1 != activeContext,
                trailing: c.$1 == activeContext
                    ? StatusLabel('Current', color: ctx.canopy.success)
                    : null,
                onTap: c.$1 == activeContext || c.$5 == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        c.$5!();
                      },
              ),
          ]),
          OrgPickerGroup(onClose: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }
}
