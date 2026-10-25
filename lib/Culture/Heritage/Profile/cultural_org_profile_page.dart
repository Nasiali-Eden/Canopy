// lib/Culture/Heritage/Profile/cultural_org_profile_page.dart
//
// Archive profile (ARCHIVE_HANDOFF §3.5, T). Organisation, metrics (entries ·
// public · communities), default visibility (used by the creator), languages,
// archive team, backgrounds & country page, connections, disputes, edit
// profile, switch context, sign out. Every row goes somewhere real.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../Organization/Home/Dashboard/edit_org_details_screen.dart';
import '../../../Services/Authentication/auth.dart';
import '../../../Shared/Pages/login.dart';
import '../../../Shared/widgets/role_context_switcher.dart';
import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Connections/heritage_connections_screen.dart';
import '../Create/country_completeness_card.dart';
import '../Create/heritage_backgrounds_screen.dart';
import '../Disputes/heritage_disputes_screen.dart';
import '../Services/heritage_providers.dart';

class CulturalOrgProfilePage extends StatelessWidget {
  final String orgId;
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? envOpsContextBuilder;
  final bool hasEnvOps;

  const CulturalOrgProfilePage({
    required this.orgId,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.envOpsContextBuilder,
    this.hasEnvOps = false,
    super.key,
  });

  static const _languages = ['English', 'Kiswahili', 'Dholuo', 'Gĩkũyũ', 'Luhya', 'Kalenjin', 'Kamba', 'Maa', 'Somali', 'Ekegusii', 'Meru', 'Mijikenda'];

  void _go(BuildContext context, WidgetBuilder? b) {
    if (b == null) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: b), (_) => false);
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showCanopyConfirm(context, title: 'Sign out?', message: "You'll need to sign in again to manage the archive.", confirmLabel: 'Sign out');
    if (!ok) return;
    await AuthService().signOut();
    if (context.mounted) _go(context, (_) => LoginPage());
  }

  Future<void> _setDefaultVisibility(BuildContext context, ArchiveVisibility? current) async {
    final picked = await showCanopySheet<ArchiveVisibility>(context, builder: (ctx) {
      return CanopySheetBody(
        title: 'Default visibility',
        caption: 'New entries start here. You can change it on each entry.',
        children: [VisibilitySelector(value: current, onChanged: (v) => Navigator.pop(ctx, v))],
      );
    });
    if (picked == null) return;
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(orgId).update({'archive_default_visibility': visibilityKey(picked)});
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    }
  }

  Future<void> _setLanguages(BuildContext context, List<String> current) async {
    final selected = {...current};
    final ok = await showCanopySheet<bool>(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        return CanopySheetBody(
          title: 'Languages',
          caption: 'Languages your archive records knowledge in.',
          children: [
            Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
              for (final l in _languages)
                CanopyFilterChip(label: l, selected: selected.contains(l), onTap: () => set(() => selected.contains(l) ? selected.remove(l) : selected.add(l))),
            ]),
          ],
          actions: [CanopyButton(label: 'Save', expand: true, onPressed: () => Navigator.pop(ctx, true))],
        );
      });
    });
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(orgId).update({'archive_languages': selected.toList()});
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final entriesProv = context.read<HeritageEntriesProvider>();
    Widget withEntries(Widget w) => ChangeNotifierProvider.value(value: entriesProv, child: w);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('organizations').doc(orgId).snapshots(),
      builder: (context, orgSnap) {
        final o = orgSnap.data?.data() ?? const <String, dynamic>{};
        final name = ((o['org_name'] ?? o['name']) as String?) ?? 'Your organisation';
        final place = [o['area'], o['city']].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
        final defaultV = visibilityFrom(o['archive_default_visibility'] as String?) ?? ArchiveVisibility.public;
        final langs = ((o['archive_languages'] as List?) ?? const []).map((e) => '$e').toList();
        final entries = context.watch<HeritageEntriesProvider>().entries.where((e) => !e.isDraft).toList();
        final public = entries.where((e) => e.visibility == 'public').length;
        final communities = entries.map((e) => e.locality).whereType<String>().where((s) => s.isNotEmpty).toSet().length;
        final disputes = entries.where((e) => e.hasActiveDispute).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
          children: [
            Row(children: [
              CanopyAvatar(url: (o['logoUrl'] ?? o['profilePhoto']) as String?, name: name, size: 56, org: true),
              const SizedBox(width: CanopySpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: CanopyType.title.copyWith(color: p.ink)),
                  Text(['Cultural Archive', if (place.isNotEmpty) place].join(' · '), style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ]),
              ),
            ]),
            const SizedBox(height: CanopySpace.section),
            Row(children: [
              Expanded(child: CanopyStatTile(value: '${entries.length}', label: 'Entries', ruled: true)),
              const SizedBox(width: CanopySpace.s12),
              Expanded(child: CanopyStatTile(value: '$public', label: 'Public', ruled: true)),
              const SizedBox(width: CanopySpace.s12),
              Expanded(child: CanopyStatTile(value: '$communities', label: 'Communities', ruled: true)),
            ]),
            const SizedBox(height: CanopySpace.section),
            CountryCompletenessCard(
              orgId: orgId,
              onOpenBackgrounds: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeritageBackgroundsScreen(orgId: orgId))),
            ),
            const CanopySectionHeader(title: 'Archive', padding: EdgeInsets.only(top: CanopySpace.section)),
            CanopyListGroup(children: [
              CanopyListRow(
                icon: Icons.shield_outlined,
                title: 'Default visibility',
                subtitle: 'New entries start here',
                trailing: VisibilityLabel(defaultV),
                onTap: () => _setDefaultVisibility(context, defaultV),
              ),
              CanopyListRow(
                icon: Icons.translate,
                title: 'Languages',
                subtitle: langs.isEmpty ? 'Not set' : langs.join(', '),
                onTap: () => _setLanguages(context, langs),
              ),
              CanopyListRow(
                icon: Icons.landscape_outlined,
                title: 'Backgrounds & country page',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeritageBackgroundsScreen(orgId: orgId))),
              ),
              CanopyListRow(
                icon: Icons.link,
                title: 'Connections',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => withEntries(HeritageConnectionsScreen(orgId: orgId)))),
              ),
              CanopyListRow(
                icon: Icons.gavel_outlined,
                title: 'Disputes',
                subtitle: disputes == 0 ? null : '$disputes open',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => withEntries(HeritageDisputesScreen(orgId: orgId)))),
              ),
              if (orgContextBuilder != null)
                CanopyListRow(
                  icon: Icons.people_outline,
                  title: 'Archive team',
                  subtitle: "Managed in your organisation's People",
                  onTap: () => _go(context, orgContextBuilder),
                ),
            ]),
            const CanopySectionHeader(title: 'Organisation', padding: EdgeInsets.only(top: CanopySpace.section)),
            CanopyListGroup(children: [
              CanopyListRow(
                icon: Icons.edit_outlined,
                title: 'Edit organisation profile',
                onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => EditOrgDetailsScreen(orgId: orgId))),
              ),
            ]),
            const CanopySectionHeader(title: 'Workspace', padding: EdgeInsets.only(top: CanopySpace.section)),
            RoleContextSwitcher(
              activeContext: 'cultural',
              hasMarketplace: o['marketplaceStatus'] == 'approved',
              hasEnvOps: hasEnvOps,
              hasCultural: true,
              onOrgTap: () => _go(context, orgContextBuilder),
              onMemberTap: () => _go(context, memberContextBuilder),
              onEnvOpsTap: envOpsContextBuilder == null ? null : () => _go(context, envOpsContextBuilder),
              onCulturalTap: () {},
            ),
            const SizedBox(height: CanopySpace.section),
            Center(child: CanopyButton.quietDanger(label: 'Sign out', onPressed: () => _signOut(context))),
          ],
        );
      },
    );
  }
}
