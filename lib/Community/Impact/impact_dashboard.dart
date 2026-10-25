// lib/Community/Impact/impact_dashboard.dart
//
// Impact dashboard (DESIGN_HANDOFF.md §3): segmented Community / My impact
// (a lens on one dataset), CSV export in the app bar, stat tiles, the 14-day
// chart (verified vs pending), recent contributions with status labels and
// gold point numerals, and an honest "On the roadmap" PDF report.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Models/contribution.dart';
import '../../Models/user.dart';
import '../../Services/Impact/impact_service.dart';
import '../../theme/canopy_components.dart';
import 'progress_visuals.dart';

enum _Lens { community, mine }

class ImpactDashboardScreen extends StatefulWidget {
  final bool embedded;
  const ImpactDashboardScreen({super.key, this.embedded = false});

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen> {
  _Lens _lens = _Lens.mine;
  bool _exporting = false;

  Future<void> _export(String uid) async {
    setState(() => _exporting = true);
    try {
      final csv = await ImpactService().exportUserContributionsCsv(userId: uid);
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        showCanopySnack(context,
            'Your contributions CSV is copied. Paste it into a spreadsheet.');
      }
    } catch (_) {
      if (mounted) {
        showCanopySnack(context, "Couldn't export your contributions.",
            error: true, actionLabel: 'Retry', onAction: () => _export(uid));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s4,
              CanopySpace.gutter, CanopySpace.s12),
          child: CanopySegmented<_Lens>(
            options: const [(_Lens.mine, 'My impact'), (_Lens.community, 'Community')],
            value: _lens,
            onChanged: (v) => setState(() => _lens = v),
          ),
        ),
        Expanded(
          child: _lens == _Lens.community
              ? const _CommunityLens()
              : user == null
                  ? const CanopySignedOutState(
                      line: 'Sign in to track your contributions and points.')
                  : _MyLens(userId: user.uid),
        ),
      ],
    );
    if (widget.embedded) return body;

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Impact', actions: [
        if (user != null)
          _exporting
              ? const SizedBox(
                  width: CanopySpace.minTouch,
                  child: Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))))
              : CanopyIconButton(
                  icon: Icons.download_outlined,
                  tooltip: 'Export CSV',
                  onPressed: () => _export(user.uid),
                ),
      ]),
      body: body,
    );
  }
}

class _MyLens extends StatelessWidget {
  final String userId;
  const _MyLens({required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = ImpactService();
    return StreamBuilder<int>(
      stream: service.watchUserImpactPoints(userId: userId),
      builder: (context, pointsSnap) => StreamBuilder<List<Contribution>>(
        stream: service.watchUserContributions(userId: userId),
        builder: (context, snap) {
          if (snap.hasError || pointsSnap.hasError) {
            return const CanopyErrorState(title: "Couldn't load your impact");
          }
          if (!snap.hasData) return const _Skeleton();
          final list = snap.data!;
          final summary = service.summarize(
              impactPoints: pointsSnap.data ?? 0, contributions: list);
          final pending = list
              .where((c) => !c.isVerified)
              .fold<int>(0, (a, c) => a + c.estimatedImpactPoints);
          final p = context.canopy;

          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0,
                CanopySpace.gutter, CanopySpace.s32),
            children: [
              CanopyCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VERIFIED POINTS',
                              style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                          const SizedBox(height: CanopySpace.s4),
                          CanopyCountUp(
                              value: summary.impactPoints,
                              style: CanopyType.hero.copyWith(color: p.goldInk)),
                        ],
                      ),
                    ),
                    if (pending > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusLabel('Pending', color: p.warning),
                          PointsLabel(pending),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CanopySpace.s12),
              Row(
                children: [
                  Expanded(
                    child: CanopyStatTile(
                        value: '${summary.contributionsCount}',
                        label: 'Contributions'),
                  ),
                  const SizedBox(width: CanopySpace.s12),
                  Expanded(
                    child: CanopyStatTile(
                        value: summary.hours.toStringAsFixed(1), label: 'Hours'),
                  ),
                  const SizedBox(width: CanopySpace.s12),
                  Expanded(
                    child: CanopyStatTile(
                        value: '${list.where((c) => c.isVerified).length}',
                        label: 'Verified'),
                  ),
                ],
              ),
              const SizedBox(height: CanopySpace.s16),
              ProgressVisuals(contributions: list),
              const SizedBox(height: CanopySpace.section),
              const CanopySectionHeader(
                  title: 'Recent contributions', padding: EdgeInsets.zero),
              if (list.isEmpty)
                CanopyEmptyState(
                  boxed: true,
                  icon: Icons.eco_outlined,
                  title: 'No contributions yet',
                  line: 'Log your first one to see it here.',
                  actionLabel: 'Log a contribution',
                  onAction: () =>
                      Navigator.pushNamed(context, '/contributions/log'),
                )
              else
                CanopyListGroup(children: [
                  for (final c in list.take(10))
                    CanopyListRow(
                      title: c.notes?.trim().isNotEmpty == true
                          ? c.notes!.trim()
                          : '${c.type} contribution',
                      subtitle: c.createdAt == null
                          ? 'Just now'
                          : DateFormat('d MMM yyyy').format(c.createdAt!),
                      below: StatusLabel(
                          c.isVerified ? 'Verified' : 'Pending verification',
                          color: c.isVerified ? p.success : p.warning),
                      trailing: PointsLabel(c.estimatedImpactPoints),
                    ),
                ]),
              const SizedBox(height: CanopySpace.section),
              const CanopyComingSoon(
                boxed: true,
                icon: Icons.picture_as_pdf_outlined,
                title: 'PDF impact report',
                line: 'A shareable report of your verified work. Use CSV export for now.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommunityLens extends StatelessWidget {
  const _CommunityLens();

  @override
  Widget build(BuildContext context) {
    final service = ImpactService();
    final p = context.canopy;
    return StreamBuilder<int>(
      stream: service.watchCommunityTotalImpactPoints(),
      builder: (context, total) => StreamBuilder<List<Contribution>>(
        stream: service.watchCommunityContributions(),
        builder: (context, snap) {
          if (snap.hasError || total.hasError) {
            return const CanopyErrorState(
                title: "Couldn't load community impact");
          }
          if (!snap.hasData) return const _Skeleton();
          final list = snap.data!;
          final people = list.map((c) => c.userId).toSet().length;
          final hours = list.fold<double>(0, (a, c) => a + (c.hours ?? 0));
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0,
                CanopySpace.gutter, CanopySpace.s32),
            children: [
              CanopyHero(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COMMUNITY TOTAL',
                        style: CanopyType.eyebrow
                            .copyWith(color: CanopyPalette.onHeroMuted)),
                    const SizedBox(height: CanopySpace.s4),
                    Text(NumberFormat.decimalPattern().format(total.data ?? 0),
                        style: CanopyType.hero
                            .copyWith(color: CanopyPalette.onHeroPoints)),
                    Text('verified points, all members',
                        style: CanopyType.caption
                            .copyWith(color: CanopyPalette.onHeroMuted)),
                  ],
                ),
              ),
              const SizedBox(height: CanopySpace.s12),
              Row(
                children: [
                  Expanded(
                      child: CanopyStatTile(
                          value: '${list.length}', label: 'Contributions')),
                  const SizedBox(width: CanopySpace.s12),
                  Expanded(
                      child: CanopyStatTile(value: '$people', label: 'People')),
                  const SizedBox(width: CanopySpace.s12),
                  Expanded(
                      child: CanopyStatTile(
                          value: hours.toStringAsFixed(0), label: 'Hours')),
                ],
              ),
              const SizedBox(height: CanopySpace.s16),
              ProgressVisuals(contributions: list),
              const SizedBox(height: CanopySpace.s12),
              Text(
                  'Figures come from contributions logged in Canopy. Pending estimates are shown separately and never counted as earned.',
                  style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ],
          );
        },
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
        children: const [
          CanopySkeleton(height: 110, radius: CanopyRadius.md),
          SizedBox(height: CanopySpace.s12),
          CanopySkeleton(height: 72, radius: CanopyRadius.md),
          SizedBox(height: CanopySpace.s16),
          CanopySkeleton(height: 230, radius: CanopyRadius.md),
        ],
      );
}
