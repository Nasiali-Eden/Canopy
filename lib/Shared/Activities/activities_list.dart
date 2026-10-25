// lib/Shared/Activities/activities_list.dart
//
// Activities list (DESIGN_HANDOFF.md §3) — the new ActivityCard. Type filter
// chips (ink when selected), upcoming soonest-first, then a "Past" section.
// Status, type, timeframe and location are filtered client-side so the
// stream stays index-free (see CommunityService.getActivitiesStream).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Models/user.dart';
import '../../Providers/location_provider.dart';
import '../../Services/Community/community_service.dart';
import '../../Services/Geo/geo_registry.dart';
import '../../theme/canopy_components.dart';
import 'activity_card.dart';
import 'activity_filter_sheet.dart';

const _typeOptions = <(String?, String)>[
  (null, 'All'),
  ('cleanup', 'Clean-up'),
  ('tree_planting', 'Planting'),
  ('awareness', 'Awareness'),
  ('training', 'Training'),
  ('monitoring', 'Monitoring'),
  ('other', 'Other'),
];

class ActivitiesListScreen extends StatefulWidget {
  final bool embedded;
  final ActivityFilter filter;

  const ActivitiesListScreen({
    super.key,
    this.embedded = false,
    this.filter = const ActivityFilter(),
  });

  @override
  State<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen> {
  late String? _type = widget.filter.type;
  int _retry = 0;

  @override
  void didUpdateWidget(ActivitiesListScreen old) {
    super.didUpdateWidget(old);
    if (old.filter.type != widget.filter.type) {
      setState(() => _type = widget.filter.type);
    }
  }

  List<QueryDocumentSnapshot> _filter(
      List<QueryDocumentSnapshot> docs, LocationFilter scope) {
    final statuses =
        CommunityService.visibleStatuses(includeFull: widget.filter.showFull);
    final tf = widget.filter.timeframe;
    final now = DateTime.now();
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!statuses.contains(data['status'] as String? ?? 'open')) return false;
      if (_type != null && data['type'] != _type) return false;
      if (tf != null) {
        final dt = (data['scheduledAt'] as Timestamp?)?.toDate();
        if (dt == null) return false;
        final ok = switch (tf) {
          'today' => dt.year == now.year && dt.month == now.month && dt.day == now.day,
          'this_week' => dt.isAfter(now) &&
              dt.isBefore(now.add(Duration(days: 7 - now.weekday + 1))),
          'this_month' => dt.year == now.year && dt.month == now.month,
          _ => true,
        };
        if (!ok) return false;
      }
      if (widget.filter.useLocationScope && !scope.isEverywhere) {
        // Pre-geo docs resolve on the fly from legacy {area, city}.
        final raw = (data['location'] as Map<String, dynamic>?) ?? data;
        final resolved = GeoRegistry.instance.resolveFromDocument(raw);
        if (!widget.filter.matchesLocation(resolved, scope)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CanopySpace.s4),
        CanopyChipRail(chips: [
          for (final t in _typeOptions)
            CanopyFilterChip(
              label: t.$2,
              selected: _type == t.$1,
              onTap: () => setState(() => _type = t.$1),
            ),
        ]),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            key: ValueKey(_retry),
            stream: CommunityService().getActivitiesStream(
              type: _type,
              includeFull: widget.filter.showFull,
            ),
            builder: (context, snap) {
              if (snap.hasError) {
                return CanopyErrorState(
                  title: "Couldn't load activities",
                  onRetry: () => setState(() => _retry++),
                );
              }
              if (!snap.hasData) {
                return ListView(
                  padding: const EdgeInsets.all(CanopySpace.gutter),
                  children: const [
                    ActivityShimmerCard(),
                    SizedBox(height: CanopySpace.s16),
                    ActivityShimmerCard(),
                  ],
                );
              }
              final scope = context.watch<LocationProvider>().filter;
              final docs = _filter(snap.data!.docs, scope);
              final hasFilter = !widget.filter.isDefault || _type != null;
              final scoped = widget.filter.useLocationScope && !scope.isEverywhere;

              if (docs.isEmpty) {
                if (scoped) {
                  return CanopyEmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'Nothing happening in ${scope.label}',
                    line: 'Widen your location to see activities nearby.',
                    actionLabel: 'Show everywhere',
                    onAction: context.read<LocationProvider>().showEverywhere,
                  );
                }
                return CanopyEmptyState(
                  icon: hasFilter
                      ? Icons.filter_list_off_outlined
                      : Icons.event_note_outlined,
                  title: hasFilter
                      ? 'No activities match your filters'
                      : 'No upcoming activities',
                  line: hasFilter
                      ? 'Try another type or time.'
                      : 'Activities appear here once organisations create them.',
                  actionLabel: hasFilter && _type != null ? 'Show all types' : null,
                  onAction: hasFilter && _type != null
                      ? () => setState(() => _type = null)
                      : null,
                );
              }

              // Stream is newest-first; upcoming reads better soonest-first.
              Map<String, dynamic> d(QueryDocumentSnapshot x) =>
                  x.data() as Map<String, dynamic>;
              final upcoming = docs
                  .where((x) => !CommunityService.hasEnded(d(x)))
                  .toList()
                  .reversed
                  .toList();
              final past =
                  docs.where((x) => CommunityService.hasEnded(d(x))).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter,
                    CanopySpace.s8, CanopySpace.gutter, 100),
                children: [
                  for (final doc in upcoming) ...[
                    ActivityCard(activityId: doc.id, activity: d(doc)),
                    const SizedBox(height: CanopySpace.s16),
                  ],
                  if (past.isNotEmpty) ...[
                    const CanopySectionHeader(
                        title: 'Past', padding: EdgeInsets.zero),
                    for (final doc in past) ...[
                      ActivityCard(activityId: doc.id, activity: d(doc)),
                      const SizedBox(height: CanopySpace.s16),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) return ColoredBox(color: context.canopy.canvas, child: body);

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Activities'),
      floatingActionButton: OrganizerFab(user: user),
      body: body,
    );
  }
}

/// "New activity" FAB — only for organisers.
class OrganizerFab extends StatelessWidget {
  final F_User? user;
  const OrganizerFab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: CommunityService().getUserRole(userId: user!.uid),
      builder: (context, snap) {
        if (snap.data?.toLowerCase() != 'organizer') {
          return const SizedBox.shrink();
        }
        return CanopyFab(
          label: 'New activity',
          icon: Icons.add,
          onPressed: () => Navigator.pushNamed(context, '/activities/create'),
        );
      },
    );
  }
}
