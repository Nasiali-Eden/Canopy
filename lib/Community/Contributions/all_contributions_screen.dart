// lib/Community/Contributions/all_contributions_screen.dart
//
// My contributions (v2): logged / verified / points strip, status segmented
// (All · In review · Verified · Not accepted), work-type chips, then feed
// cards (owner view). Single-equality query on userId, sorted on the client,
// so no composite index is needed. Points come from the impact ledger.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../Services/Impact/impact_service.dart';
import '../../theme/canopy_components.dart';
import 'entry_feed_card.dart';

const _kWorkTypes = ['Cleanup', 'Tree Planting', 'School Upgrading', 'Waste Management', 'Water & Sanitation', 'Infrastructure'];

class AllContributionsScreen extends StatefulWidget {
  final String? userId;
  const AllContributionsScreen({super.key, this.userId});

  @override
  State<AllContributionsScreen> createState() => _AllContributionsScreenState();
}

class _AllContributionsScreenState extends State<AllContributionsScreen> {
  String? _type;
  String? _status;
  int _shown = 20;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _subscribe();

  Stream<QuerySnapshot<Map<String, dynamic>>> _subscribe() =>
      FirebaseFirestore.instance.collection('contributions').where('userId', isEqualTo: widget.userId).snapshots();

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final bar = canopyAppBar(context, title: 'My contributions', actions: [
      CanopyIconButton(icon: Icons.add, tooltip: 'Log a contribution', onPressed: () => Navigator.pushNamed(context, '/contributions/log')),
    ]);
    if (widget.userId == null) return CanopyScaffold(appBar: bar, body: const CanopySignedOutState());
    return CanopyScaffold(
      appBar: bar,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(title: "Couldn't load your contributions", onRetry: () => setState(() => _stream = _subscribe()));
          }
          if (!snap.hasData) return const CanopyListSkeleton();
          final all = snap.data!.docs.where((d) => d.data()['deleted'] != true).toList()
            ..sort((a, b) {
              final ta = a.data()['createdAt'] as Timestamp?, tb = b.data()['createdAt'] as Timestamp?;
              return (tb?.millisecondsSinceEpoch ?? 1 << 62).compareTo(ta?.millisecondsSinceEpoch ?? 1 << 62);
            });
          if (all.isEmpty) {
            return CanopyEmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: 'Nothing logged yet',
              line: 'Log a clean-up, planting or recycling run. An organisation reviews it, then it counts.',
              actionLabel: 'Log a contribution',
              primaryAction: true,
              onAction: () => Navigator.pushNamed(context, '/contributions/log'),
            );
          }
          final verified = all.where((d) => d.data()['status'] == 'verified').length;
          final types = {for (final d in all) (d.data()['workType'] ?? d.data()['type'] ?? '') as String}..remove('');
          final chipTypes = [..._kWorkTypes.where(types.contains), ...types.where((t) => !_kWorkTypes.contains(t))];
          final filtered = all.where((d) {
            final data = d.data();
            final t = data['workType'] ?? data['type'];
            final s = data['status'] ?? 'pending';
            return (_type == null || t == _type) && (_status == null || s == _status);
          }).toList();
          final page = filtered.take(_shown).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: CanopySpace.s32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
                child: CanopyCard(
                  padding: const EdgeInsets.symmetric(vertical: CanopySpace.s12),
                  child: Row(children: [
                    Expanded(child: CanopyStatTile(value: '${all.length}', label: 'Logged')),
                    Expanded(child: CanopyStatTile(value: '$verified', label: 'Verified', ruled: true)),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: ImpactService().watchUserImpactPoints(userId: widget.userId!),
                        builder: (_, s) => CanopyStatTile(
                          value: s.hasData ? '${s.data}' : '–',
                          label: 'Points',
                          ruled: true,
                          valueColor: p.goldInk,
                          onTap: () => Navigator.pushNamed(context, '/impact'),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s12),
                child: CanopySegmented<String?>(
                  options: const [(null, 'All'), ('pending', 'In review'), ('verified', 'Verified'), ('rejected', 'Not accepted')],
                  value: _status,
                  onChanged: (v) => setState(() {
                    _status = v;
                    _shown = 20;
                  }),
                ),
              ),
              if (chipTypes.length > 1)
                CanopyChipRail(chips: [
                  CanopyFilterChip(label: 'All types', selected: _type == null, onTap: () => setState(() => _type = null)),
                  for (final t in chipTypes)
                    CanopyFilterChip(
                      label: t,
                      icon: feedTypeIcon(t),
                      selected: _type == t,
                      onTap: () => setState(() {
                        _type = _type == t ? null : t;
                        _shown = 20;
                      }),
                    ),
                ]),
              const SizedBox(height: CanopySpace.s16),
              if (filtered.isEmpty)
                CanopyEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nothing matches',
                  line: 'No contributions with these filters.',
                  actionLabel: 'Clear filters',
                  onAction: () => setState(() {
                    _type = null;
                    _status = null;
                  }),
                )
              else
                for (final d in page)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s24),
                    child: EntryFeedCard(
                      key: ValueKey(d.id),
                      editable: true,
                      entry: FeedEntry.fromContribution(d.data(), contributionId: d.id),
                    ),
                  ),
              if (filtered.length > page.length)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                  child: CanopyButton(
                    label: 'Show ${(filtered.length - page.length).clamp(0, 20)} more',
                    variant: CanopyButtonVariant.secondary,
                    expand: true,
                    onPressed: () => setState(() => _shown += 20),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
