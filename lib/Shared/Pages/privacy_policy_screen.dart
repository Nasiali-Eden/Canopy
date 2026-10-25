// lib/Shared/Pages/privacy_policy_screen.dart
//
// Privacy policy (v2) — a DRAFT pending legal review, labelled as such.
// Rule: it describes only what the app does today. Nothing planned goes in
// here until it ships; update this screen in the same change that ships it.

import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    (
      'What we collect',
      'When you sign up: your name, username, email and the county or area you choose. In Edit profile you can '
          'add a photo and a phone number. When you log a contribution or report an issue: the photos, description '
          'and location you add. Organisations give their name, sector, logo, contact details and location when '
          'they register. Makers and field teams add listings, zones, tree plantings and collection handoffs.'
    ),
    (
      'Who can see it',
      'Your name and photo appear on the leaderboard and on contributions you log. Reported issues can be seen by '
          "anyone signed in. Each organisation's contact details are shown on its public page. When you send a maker "
          'or material request, the phone number you enter goes to that seller. Heritage entries are shown according '
          'to the visibility the archive chose.'
    ),
    (
      'Payments',
      'When you pay for a home service with M-Pesa, Canopy keeps the M-Pesa receipt number with the booking. '
          'Canopy never sees or stores your M-Pesa PIN. Marketplace purchases are arranged directly with the maker; '
          'the app does not take payment for them.'
    ),
    (
      'Changing your details',
      'You can change your name, photo, location and phone number at any time in Edit profile.'
    ),
    ('Selling data', 'Canopy does not sell your data.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Privacy policy'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          const CanopyCallout(kind: CalloutKind.warning, text: 'Draft, pending legal review.'),
          for (final (title, body) in _sections) ...[
            const SizedBox(height: CanopySpace.section),
            Text(title, style: CanopyType.title.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s8),
            Text(body, style: CanopyType.body.copyWith(fontSize: 16, height: 1.5, color: p.ink)),
          ],
          const SizedBox(height: CanopySpace.section),
          Text('Questions about this policy can go to SHIELD International.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }
}
