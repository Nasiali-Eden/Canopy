// lib/Culture/culture_home.dart
//
// Cultural Archive shell (ARCHIVE_HANDOFF). Standard workspace — the
// parchment theme is retired. Tabs Archive · Add entry · Feedback · Profile;
// "Add entry" opens the creator and is shown only to the organisation's
// representative (uploads are org-only). Others get a read-only archive.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Shared/widgets/canopy_bottom_bar.dart';
import '../theme/canopy_components.dart';
import 'Heritage/Archive/heritage_archive_screen.dart';
import 'Heritage/Create/create_entry_screen.dart';
import 'Heritage/Feedback/heritage_feedback_screen.dart';
import 'Heritage/Profile/cultural_org_profile_page.dart';
import 'Heritage/Services/heritage_providers.dart';

class CultureHomeScreen extends StatefulWidget {
  final String orgId;
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? envOpsContextBuilder;
  final bool hasEnvOps;

  const CultureHomeScreen({
    required this.orgId,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.envOpsContextBuilder,
    this.hasEnvOps = false,
    super.key,
  });

  @override
  State<CultureHomeScreen> createState() => _CultureHomeScreenState();
}

class _CultureHomeScreenState extends State<CultureHomeScreen> {
  String _tab = 'archive';
  bool? _isRep;

  @override
  void initState() {
    super.initState();
    _resolveRep();
  }

  Future<void> _resolveRep() async {
    var rep = false;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final o = (await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).get()).data();
        final u = (await FirebaseFirestore.instance.collection('Users').doc(uid).get()).data();
        rep = o?['org_rep_uid'] == uid || u?['orgId'] == widget.orgId;
      }
    } catch (_) {}
    if (mounted) setState(() => _isRep = rep);
  }

  List<String> get _keys => (_isRep ?? false) ? const ['archive', 'add', 'feedback', 'profile'] : const ['archive', 'feedback', 'profile'];

  void _tap(int i, BuildContext ctx) {
    final k = _keys[i];
    if (k == 'add') {
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => CreateEntryScreen(orgId: widget.orgId),
      ));
      return;
    }
    setState(() => _tab = k);
  }

  @override
  Widget build(BuildContext context) {
    final keys = _keys;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HeritageEntriesProvider()..fetchEntries(widget.orgId)),
      ],
      child: Builder(builder: (context) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _tab != 'archive') setState(() => _tab = 'archive');
          },
          child: CanopyScaffold(
            appBar: canopyAppBar(context, title: switch (_tab) { 'feedback' => 'Feedback', 'profile' => 'Profile', _ => 'Cultural Archive' }, showBack: false),
            body: switch (_tab) {
              'feedback' => HeritageFeedbackScreen(orgId: widget.orgId),
              'profile' => CulturalOrgProfilePage(
                  orgId: widget.orgId,
                  orgContextBuilder: widget.orgContextBuilder,
                  memberContextBuilder: widget.memberContextBuilder,
                  envOpsContextBuilder: widget.envOpsContextBuilder,
                  hasEnvOps: widget.hasEnvOps,
                ),
              _ => HeritageArchiveScreen(orgId: widget.orgId, canEdit: _isRep ?? false),
            },
            bottomNavigationBar: CanopyBottomBar(
              currentIndex: keys.indexOf(_tab).clamp(0, keys.length - 1),
              onTap: (i) => _tap(i, context),
              destinations: [
                for (final k in keys)
                  switch (k) {
                    'add' => const CanopyNavDestination(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle, label: 'Add entry'),
                    'feedback' => const CanopyNavDestination(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: 'Feedback'),
                    'profile' => const CanopyNavDestination(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
                    _ => const CanopyNavDestination(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Archive'),
                  },
              ],
            ),
          ),
        );
      }),
    );
  }
}
