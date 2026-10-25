// lib/Community/Recognition/leaderboard_screen.dart
//
// Leaderboard (DESIGN_HANDOFF.md §3): segmented People / Organisations (the
// latter is an honest "On the roadmap" state), a podium for the top three
// (medals), dense rows for the rest, and a sticky "you" row with points to the
// next position. Gold is recognition-only: medals, points numerals, the one
// "you" ring. Rules live in a sheet.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Rank/leaderboard_service.dart';
import '../../theme/canopy_components.dart';

enum _Board { people, orgs }

class LeaderboardScreen extends StatefulWidget {
  final LeaderboardService? service;
  const LeaderboardScreen({super.key, this.service});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final _service = widget.service ?? LeaderboardService();
  late Stream<List<RankEntry>> _board;
  Future<PersonalRank>? _personal;
  Stream<int>? _ownPoints;
  String? _uid;
  int _limit = 50;
  _Board _tab = _Board.people;

  @override
  void initState() {
    super.initState();
    _board = _service.watchPeopleLeaderboard(limit: _limit);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = Provider.of<F_User?>(context)?.uid;
    if (_uid != uid) {
      _uid = uid;
      _ownPoints = uid == null ? null : _service.watchOwnPoints(uid);
      _personal = uid == null ? null : _service.getPersonalRank(uid);
    }
  }

  void _reload() => setState(() {
        _board = _service.watchPeopleLeaderboard(limit: _limit);
        _personal = _uid == null ? null : _service.getPersonalRank(_uid!);
      });

  void _rules() => showCanopySheet<void>(
        context,
        builder: (ctx) {
          final p = ctx.canopy;
          Widget para(String t) => Padding(
                padding: const EdgeInsets.only(bottom: CanopySpace.s12),
                child: Text(t, style: CanopyType.body.copyWith(color: p.ink)),
              );
          return CanopySheetBody(
            title: 'How impact points work',
            children: [
              para(
                  "Only verified contributions count toward your rank. An approved verifier from the activity's organisation reviews your contribution — you can't verify your own work."),
              CanopyListGroup(children: const [
                CanopyListRow(title: 'Time', subtitle: '10 points per hour, up to 24 hours per submission'),
                CanopyListRow(title: 'Effort', subtitle: '20 points for a verified contribution'),
                CanopyListRow(title: 'Materials', subtitle: '20 points for a verified contribution'),
              ]),
              const SizedBox(height: CanopySpace.s12),
              para(
                  "Longer descriptions, extra material labels and work categories don't earn bonuses. Pending estimates don't affect your position. Equal scores share a rank: 1, 1, 3."),
              para(
                  'This is the global, all-time board for verified scoring version 1. Historical estimates are excluded until reviewed.'),
            ],
            actions: [
              CanopyButton.secondary(
                  label: 'Got it',
                  expand: true,
                  onPressed: () => Navigator.pop(ctx)),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Leaderboard', actions: [
        CanopyIconButton(
            icon: Icons.info_outline,
            tooltip: 'How points work',
            onPressed: _rules),
      ]),
      body: _uid == null
          ? const CanopySignedOutState(
              line: 'Sign in to see where you stand in the community.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(CanopySpace.gutter,
                      CanopySpace.s4, CanopySpace.gutter, CanopySpace.s12),
                  child: CanopySegmented<_Board>(
                    options: const [
                      (_Board.people, 'People'),
                      (_Board.orgs, 'Organisations'),
                    ],
                    value: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                ),
                Expanded(
                  child: _tab == _Board.orgs
                      ? const CanopyComingSoon(
                          icon: Icons.groups_outlined,
                          title: 'Organisation ranking',
                          line:
                              'Coming later, with its own scoring for verified events and organisation impact.',
                        )
                      : _people(),
                ),
              ],
            ),
      sticky: _uid == null || _tab == _Board.orgs ? null : _youBar(),
    );
  }

  Widget _people() {
    return StreamBuilder<List<RankEntry>>(
      stream: _board,
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyErrorState(
              title: "Couldn't load the leaderboard", onRetry: _reload);
        }
        if (!snap.hasData) {
          return ListView(
            padding: const EdgeInsets.all(CanopySpace.gutter),
            children: const [
              CanopySkeleton(height: 190, radius: CanopyRadius.md),
              SizedBox(height: CanopySpace.s16),
              CanopyListSkeleton(rows: 5),
            ],
          );
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return CanopyEmptyState(
            icon: Icons.leaderboard_outlined,
            title: 'The board is just beginning',
            line: 'Your first verified contribution earns your place.',
            actionLabel: 'Log a contribution',
            onAction: () => Navigator.pushNamed(context, '/contributions/log'),
          );
        }
        final ranks = [
          for (var i = 0; i < entries.length; i++)
            LeaderboardService.rankAt(entries, i)
        ];
        final podium = entries.length >= 3 ? 3 : 0;
        final p = context.canopy;
        return ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0,
              CanopySpace.gutter, CanopySpace.s32),
          children: [
            Text('People · Global · All time · Verified points',
                style: CanopyType.caption.copyWith(color: p.inkMuted)),
            const SizedBox(height: CanopySpace.s16),
            if (podium == 3) ...[
              _Podium(entries: entries.take(3).toList(), ranks: ranks, uid: _uid),
              const SizedBox(height: CanopySpace.s16),
            ],
            CanopyListGroup(children: [
              for (var i = podium; i < entries.length; i++)
                _RankRow(entry: entries[i], rank: ranks[i], me: entries[i].userId == _uid),
            ]),
            if (entries.length == _limit)
              Padding(
                padding: const EdgeInsets.only(top: CanopySpace.s12),
                child: CanopyButton.secondary(
                  label: 'Show more',
                  expand: true,
                  onPressed: () {
                    _limit += 50;
                    _reload();
                  },
                ),
              ),
            const SizedBox(height: CanopySpace.s12),
            Text('Equal points share the same position.',
                style: CanopyType.caption.copyWith(color: p.inkMuted)),
          ],
        );
      },
    );
  }

  Widget _youBar() {
    return StreamBuilder<int>(
      stream: _ownPoints,
      builder: (context, own) => FutureBuilder<PersonalRank>(
        future: _personal,
        builder: (context, snap) {
          final p = context.canopy;
          final pr = snap.data;
          final stale =
              pr != null && own.data != null && own.data != pr.entry.points;
          return StickyActionBar(children: [
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(pr?.rank == null ? '—' : '#${pr!.rank}',
                      style: CanopyType.heading.copyWith(color: p.ink)),
                ),
                CanopyAvatar(
                    url: pr?.entry.photoUrl,
                    name: pr?.entry.name ?? '',
                    size: 32,
                    ring: p.gold),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You', style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                      Text(
                        snap.hasError
                            ? 'Your position is unavailable'
                            : pr == null
                                ? 'Loading your position…'
                                : pr.rank == null
                                    ? 'Your first verified contribution starts your ranking'
                                    : pr.pointsToNext == null
                                        ? 'You share the top score'
                                        : '${pr.pointsToNext} pts to move up · ${pr.pendingPoints} pending',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CanopyType.caption.copyWith(color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (stale)
                  CanopyButton.quiet(
                      label: 'Refresh',
                      size: CanopyButtonSize.compact,
                      onPressed: _reload)
                else if (pr != null)
                  PointsLabel(pr.entry.points, signed: false),
              ],
            ),
          ]);
        },
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<RankEntry> entries;
  final List<int> ranks;
  final String? uid;
  const _Podium({required this.entries, required this.ranks, required this.uid});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    // Display order 2 · 1 · 3, first place raised.
    const order = [1, 0, 2];
    const heights = [96.0, 124.0, 80.0];
    return CanopyCard(
      padding: const EdgeInsets.fromLTRB(
          CanopySpace.s12, CanopySpace.s20, CanopySpace.s12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var k = 0; k < 3; k++)
            Expanded(
              child: Builder(builder: (context) {
                final i = order[k];
                final e = entries[i];
                final kind = switch (ranks[i]) {
                  1 => MedalKind.gold,
                  2 => MedalKind.silver,
                  _ => MedalKind.bronze,
                };
                final me = e.userId == uid;
                return Column(
                  children: [
                    CanopyAvatar(
                        url: e.photoUrl,
                        name: e.name,
                        size: i == 0 ? 56 : 48,
                        ring: me ? p.gold : null),
                    const SizedBox(height: CanopySpace.s8),
                    Text(me ? 'You' : e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: CanopyType.label.copyWith(color: p.ink)),
                    PointsLabel(e.points, signed: false),
                    const SizedBox(height: CanopySpace.s8),
                    Container(
                      height: heights[k],
                      margin: const EdgeInsets.symmetric(horizontal: CanopySpace.s4),
                      decoration: BoxDecoration(
                        color: p.surfaceMuted,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(CanopyRadius.sm)),
                      ),
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: CanopySpace.s12),
                      child: CanopyMedal(kind: kind),
                    ),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final RankEntry entry;
  final int rank;
  final bool me;
  const _RankRow({required this.entry, required this.rank, required this.me});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      color: me ? p.surfaceBrand : null,
      child: CanopyListRow(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              child: Text('$rank',
                  style: CanopyType.bodyStrong.copyWith(
                      color: p.inkMuted,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            CanopyAvatar(
                url: entry.photoUrl,
                name: entry.name,
                size: 32,
                ring: me ? p.gold : null),
          ],
        ),
        title: me ? '${entry.name} (you)' : entry.name,
        trailing: PointsLabel(entry.points, signed: false),
      ),
    );
  }
}
