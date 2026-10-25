// lib/Shared/Pages/community_guidelines.dart
//
// Community guidelines (v2). Two uses:
//   • onboarding gate (default): agree → saved → routed to the member or
//     organisation home;
//   • readOnly (Settings, About): just the guidelines, with a back button.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Community/Home/community_home.dart';
import '../../Models/user.dart';
import '../../Organization/Home/org_home.dart';
import '../../Services/Authentication/community_auth.dart';
import '../../theme/canopy_components.dart';
import 'welcome_screen.dart';

const _kGuidelines = [
  (Icons.handshake_outlined, 'Respect everyone', 'Be kind and welcoming. Harassment and discrimination are not tolerated.'),
  (Icons.fact_check_outlined, 'Log honestly', 'Record what you actually did. Organisations check contributions before they count.'),
  (Icons.health_and_safety_outlined, 'Stay safe', 'Follow the organiser and local safety guidance. Never put yourself at risk.'),
  (Icons.photo_camera_outlined, 'Ask before you share', "Don't post people's faces, homes or private details without their consent."),
  (Icons.diversity_3_outlined, 'Honour culture', "Heritage belongs to its communities. Respect an archive's restrictions on what can be shared."),
];

class CommunityGuidelinesScreen extends StatefulWidget {
  final bool readOnly;
  const CommunityGuidelinesScreen({super.key, this.readOnly = false});

  @override
  State<CommunityGuidelinesScreen> createState() => _CommunityGuidelinesScreenState();
}

class _CommunityGuidelinesScreenState extends State<CommunityGuidelinesScreen> {
  bool _accepted = false, _saving = false;

  Future<void> _continue() async {
    final user = Provider.of<F_User?>(context, listen: false);
    final nav = Navigator.of(context);
    void go(Widget w) => nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => w), (_) => false);
    if (user == null) return go(const WelcomeScreen());
    setState(() => _saving = true);
    try {
      await CommunityAuthService().setGuidelinesAccepted(uid: user.uid);
      final db = FirebaseFirestore.instance;
      final isMember = (await db.collection('members').doc(user.uid).get()).exists;
      if (!mounted) return;
      if (isMember) return go(const CommunityHomeScreen());
      final isRep = (await db.collection('org_rep').doc(user.uid).get()).exists;
      if (!mounted) return;
      go(isRep ? const OrganizationHome() : const CommunityHomeScreen());
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showCanopySnack(context, "Couldn't save. Check your connection and try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
      children: [
        Text('Canopy works because people trust what they see here. Five things we ask of everyone:',
            style: CanopyType.body.copyWith(color: p.inkMuted)),
        const SizedBox(height: CanopySpace.s16),
        CanopyListGroup(children: [
          for (final (icon, title, line) in _kGuidelines)
            CanopyListRow(
              leading: Icon(icon, color: p.primaryInk),
              title: title,
              subtitle: line,
              chevron: false,
            ),
        ]),
      ],
    );
    if (widget.readOnly) {
      return CanopyScaffold(appBar: canopyAppBar(context, title: 'Community guidelines'), body: list);
    }
    return PopScope(
      canPop: !_saving,
      child: CanopyScaffold(
        appBar: canopyAppBar(context, title: 'Community guidelines', showBack: false),
        body: list,
        sticky: StickyActionBar(children: [
          CanopyCheckRow(
            label: 'I agree to follow these guidelines',
            value: _accepted,
            onChanged: (v) {
              if (!_saving) setState(() => _accepted = v);
            },
          ),
          const SizedBox(height: CanopySpace.s8),
          CanopyButton(label: 'Continue', expand: true, loading: _saving, onPressed: _accepted && !_saving ? _continue : null),
        ]),
      ),
    );
  }
}
