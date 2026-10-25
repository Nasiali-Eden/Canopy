// lib/Organization/Home/Dashboard/contribution_review_screen.dart
//
// Contributions to confirm (ORG_HANDOFF §3.1). Pending contributions linked
// to this organisation's activities; "Confirm" calls the existing
// confirmContribution Cloud Function, which checks the verifier claim, org
// membership and self-verification server-side, awards points and marks the
// contribution verified. Nothing here writes points directly.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';

class PendingContribution {
  final String id;
  final Map<String, dynamic> data;
  final String activityTitle;
  PendingContribution(this.id, this.data, this.activityTitle);

  String get title => (data['title'] as String?)?.trim().isNotEmpty == true
      ? data['title'] as String
      : '${data['workType'] ?? data['type'] ?? 'Contribution'}';
  String? get photo =>
      (data['photos'] as List?)?.whereType<String>().firstOrNull ??
      (data['beforeImages'] as List?)?.whereType<String>().firstOrNull;
  int get points => (data['estimatedImpactPoints'] as num?)?.toInt() ?? 0;
  String get userId => data['userId'] as String? ?? '';
  DateTime? get createdAt => (data['createdAt'] as Timestamp?)?.toDate();
}

/// Pending contributions against [orgId]'s activities. Index-free: org
/// activities by one equality, then contributions by activityId whereIn
/// batches of 10, filtered to status == pending client-side.
Future<List<PendingContribution>> loadPendingContributions(String orgId) async {
  final db = FirebaseFirestore.instance;
  final acts = await db.collection('activities').where('orgId', isEqualTo: orgId).get();
  final titles = {for (final d in acts.docs) d.id: (d.data()['title'] as String?) ?? 'Activity'};
  final ids = titles.keys.toList();
  final out = <PendingContribution>[];
  for (var i = 0; i < ids.length; i += 10) {
    final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
    final snap = await db.collection('contributions').where('activityId', whereIn: chunk).get();
    for (final d in snap.docs) {
      final data = d.data();
      if (data['status'] == 'pending' && data['deleted'] != true) {
        out.add(PendingContribution(d.id, data, titles[data['activityId']] ?? 'Activity'));
      }
    }
  }
  out.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
  return out;
}

final Map<String, Future<String>> _names = {};
Future<String> contributorName(String uid) => _names.putIfAbsent(
    uid,
    () => FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .get()
        .then((d) => ((d.data()?['name'] ?? d.data()?['displayName']) as String?) ?? 'Member')
        .catchError((_) => 'Member'));

class ContributionReviewScreen extends StatefulWidget {
  final String orgId;
  const ContributionReviewScreen({super.key, required this.orgId});

  @override
  State<ContributionReviewScreen> createState() => _ContributionReviewScreenState();
}

class _ContributionReviewScreenState extends State<ContributionReviewScreen> {
  late Future<List<PendingContribution>> _future = loadPendingContributions(widget.orgId);
  final Set<String> _busy = {};
  final Set<String> _done = {};

  Future<void> _confirm(PendingContribution c) async {
    setState(() => _busy.add(c.id));
    try {
      final r = await FirebaseFunctions.instance
          .httpsCallable('confirmContribution')
          .call<Map<String, dynamic>>({'contributionId': c.id});
      final pts = (r.data['confirmedPoints'] as num?)?.toInt() ?? c.points;
      if (!mounted) return;
      setState(() => _done.add(c.id));
      showCanopySnack(context, 'Confirmed. $pts points awarded.');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      showCanopySnack(
        context,
        switch (e.code) {
          'permission-denied' => e.message?.contains('own') == true
              ? "You can't confirm your own contribution."
              : 'Only approved verifiers in your organisation can confirm contributions.',
          'failed-precondition' => e.message ?? "This contribution can't be confirmed.",
          _ => "Couldn't confirm. Try again.",
        },
        error: true,
      );
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't confirm. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Contributions to confirm'),
      body: FutureBuilder<List<PendingContribution>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(
                title: "Couldn't load contributions",
                onRetry: () => setState(() => _future = loadPendingContributions(widget.orgId)));
          }
          if (!snap.hasData) {
            return ListView(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              children: const [CanopyListSkeleton(rows: 3, leadingSize: 64)],
            );
          }
          final list = snap.data!.where((c) => !_done.contains(c.id)).toList();
          if (list.isEmpty) {
            return const CanopyEmptyState(
              icon: Icons.task_alt_outlined,
              title: 'Nothing to confirm',
              line: 'Contributions members link to your activities show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = loadPendingContributions(widget.orgId));
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: CanopySpace.s12),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Text(
                      'Confirming awards the member their points. Check the photos match the activity.',
                      style: CanopyType.body.copyWith(color: p.inkMuted));
                }
                final c = list[i - 1];
                return CanopyCard(
                  padding: null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CanopyImage(url: c.photo, fallbackIcon: Icons.photo_outlined)),
                      Padding(
                        padding: const EdgeInsets.all(CanopySpace.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LabelRow(children: [
                              StatusLabel('Pending', color: p.warning),
                              PointsLabel(c.points),
                            ]),
                            const SizedBox(height: CanopySpace.s4),
                            Text(c.title, style: CanopyType.subhead.copyWith(color: p.ink)),
                            FutureBuilder<String>(
                              future: contributorName(c.userId),
                              builder: (_, n) => Text(
                                [
                                  n.data ?? '…',
                                  c.activityTitle,
                                  if (c.data['hours'] != null) '${c.data['hours']} h',
                                ].join(' · '),
                                style: CanopyType.caption.copyWith(color: p.inkMuted),
                              ),
                            ),
                            if ((c.data['description'] as String?)?.trim().isNotEmpty ?? false) ...[
                              const SizedBox(height: CanopySpace.s8),
                              Text((c.data['description'] as String).trim(),
                                  style: CanopyType.body.copyWith(color: p.ink)),
                            ],
                            const SizedBox(height: CanopySpace.s12),
                            CanopyButton.secondary(
                              label: 'Confirm',
                              expand: true,
                              loading: _busy.contains(c.id),
                              onPressed: () => _confirm(c),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
