// lib/Shared/Authentication/join_community.dart
//
// Create account (v2): choose how you'll join — member or organisation —
// then continue into that registration. Makers, field teams and archives
// are organisation capabilities, applied for after registering.

import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';
import '../Pages/login.dart';
import 'member/member_register_screen.dart';
import 'organization/org_register_wizard.dart';

class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  bool _org = false;

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Create account'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Text('How will you join?', style: CanopyType.display.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          Text('You can always join an organisation later from your profile.', style: CanopyType.body.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.section),
          CanopyOptionCard(
            selected: !_org,
            onTap: () => setState(() => _org = false),
            icon: Icons.person_outline,
            title: 'As a member',
            caption: 'Join activities, log your contributions, report issues and follow organisations.',
          ),
          const SizedBox(height: CanopySpace.s12),
          CanopyOptionCard(
            selected: _org,
            onTap: () => setState(() => _org = true),
            icon: Icons.apartment_outlined,
            title: 'For an organisation',
            caption: 'Register an NGO, recycler, school, collective or archive. Run events and verify contributions.',
          ),
          const SizedBox(height: CanopySpace.s16),
          Text('Selling made goods, running field operations or keeping a cultural archive are added to an organisation after it registers.',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'Continue',
          expand: true,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _org ? const OrgRegisterWizard() : const MemberRegisterScreen()),
          ),
        ),
        const SizedBox(height: CanopySpace.s8),
        CanopyButton(
          label: 'I already have an account',
          variant: CanopyButtonVariant.quiet,
          expand: true,
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
        ),
      ]),
    );
  }
}
