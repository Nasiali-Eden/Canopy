// lib/Community/Profile/roadmap_screen.dart
//
// Roadmap (v2) — what works today and what is planned, stated plainly.
// Planned items make no claim that any part already exists.

import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  static const _built = [
    ('Community', 'Activities, QR check-in, logging contributions, points, the leaderboard and your impact.'),
    ('Organisations', 'Events with live QR, people and teams, broadcasts, partnerships, programmes and articles.'),
    ('Services', 'Book home services, quotes and M-Pesa requests.'),
    ('Heritage', 'Browse stories, food, music and more by country and community.'),
    ('Field work', 'Territory mapping, tree plantings, collector handoffs and the materials market.'),
  ];

  static const _next = [
    ('Paying for made goods', 'Checkout for the marketplace. Today buyers send a request and arrange payment with the maker.'),
    ('Independent verification', 'Evidence checked by someone outside the organisation. Nothing is third-party verified yet.'),
    ('Permanent public records', 'Verified impact published as records anyone can check. Not built.'),
    ('Audio in the archive', 'Recording songs and spoken stories in the app.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    Widget group(String title, List<(String, String)> items, bool done) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CanopySectionHeader(title: title, padding: const EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            for (final i in items)
              CanopyListRow(
                leading: Icon(done ? Icons.check_circle_outline : Icons.schedule, color: done ? p.success : p.inkMuted),
                title: i.$1,
                subtitle: i.$2,
                chevron: false,
              ),
          ]),
        ]);
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Roadmap'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
        children: [group('Working today', _built, true), group('Planned', _next, false)],
      ),
    );
  }
}
