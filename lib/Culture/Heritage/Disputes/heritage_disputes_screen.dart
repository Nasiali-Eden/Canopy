// lib/Culture/Heritage/Disputes/heritage_disputes_screen.dart
//
// Disputes (ARCHIVE_HANDOFF §3.5, T). DisputeCard: 1.5 ink border; Under
// review + opened date; the claim; entry · owner · visibility; "Record
// resolution" (primary) + "Change visibility". Resolved disputes stay
// listed with their resolution note.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Archive/heritage_archive_screen.dart' show changeEntryVisibility;
import '../Models/cultural_comment.dart';
import '../Models/cultural_entry.dart';
import '../Services/archive_feedback_service.dart';
import '../Services/heritage_providers.dart';

class HeritageDisputesScreen extends StatefulWidget {
  final String orgId;
  const HeritageDisputesScreen({required this.orgId, super.key});

  @override
  State<HeritageDisputesScreen> createState() => _HeritageDisputesScreenState();
}

class _HeritageDisputesScreenState extends State<HeritageDisputesScreen> {
  Stream<List<CulturalComment>>? _stream;

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<HeritageEntriesProvider>().entries;
    _stream ??= ArchiveFeedbackService.instance.comments(widget.orgId, entries.map((e) => e.id).toList());
    final byId = {for (final e in entries) e.id: e};
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Disputes'),
      body: StreamBuilder<List<CulturalComment>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(title: "Couldn't load disputes");
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final disputes = snap.data!.where((c) => c.isDispute).toList()
            ..sort((a, b) => (a.status == 'resolved' ? 1 : 0).compareTo(b.status == 'resolved' ? 1 : 0));
          if (disputes.isEmpty) {
            return const CanopyEmptyState(icon: Icons.gavel_outlined, title: 'No disputes', line: 'When a member says an entry is wrong, it appears here first.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
            itemCount: disputes.length,
            separatorBuilder: (_, __) => const SizedBox(height: CanopySpace.s12),
            itemBuilder: (_, i) => DisputeCard(comment: disputes[i], entry: byId[disputes[i].entryId]),
          );
        },
      ),
    );
  }
}

class DisputeCard extends StatelessWidget {
  final CulturalComment comment;
  final CulturalEntry? entry;
  const DisputeCard({super.key, required this.comment, this.entry});

  Future<void> _resolve(BuildContext context) async {
    final note = TextEditingController();
    final ok = await showCanopySheet<bool>(context, builder: (ctx) {
      return CanopySheetBody(
        title: 'Record resolution',
        caption: 'This note stays on the record with the dispute.',
        children: [CanopyTextField(label: 'What was decided', controller: note, minLines: 3, maxLines: 6, autofocus: true)],
        actions: [CanopyButton(label: 'Record resolution', expand: true, onPressed: () => Navigator.pop(ctx, true))],
      );
    });
    if (ok == true && note.text.trim().isNotEmpty) {
      try {
        await ArchiveFeedbackService.instance.resolveDispute(comment.id, note.text);
        if (context.mounted) showCanopySnack(context, 'Resolution recorded.');
      } catch (_) {
        if (context.mounted) showCanopySnack(context, "Couldn't record it. Try again.", error: true);
      }
    }
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final c = comment;
    final resolved = c.status == 'resolved';
    final v = visibilityFrom(entry?.visibility);
    return CanopyCard(
      borderColor: resolved ? null : p.ink,
      borderWidth: resolved ? 1 : 1.5,
      padding: const EdgeInsets.all(CanopySpace.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LabelRow(children: [
          StatusLabel(resolved ? 'Resolved' : 'Under review', color: resolved ? p.success : p.danger),
          StatusLabel('Opened ${DateFormat('d MMM').format(c.createdAt)}', color: p.inkMuted),
        ]),
        const SizedBox(height: CanopySpace.s8),
        Text('"${c.commentBody}"', style: CanopyType.body.copyWith(color: p.ink)),
        Text('— ${c.commenterName.isEmpty ? 'Member' : c.commenterName}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
        const SizedBox(height: CanopySpace.s12),
        CanopyListGroup(children: [
          CanopyFactRow(label: 'Entry', value: entry?.title ?? 'Entry'),
          CanopyFactRow(label: 'Owner', value: c.ownerName ?? 'Unassigned'),
          if (entry != null) CanopyFactRow(label: 'Visibility', value: v == null ? 'Draft' : visibilityWord(v)),
        ]),
        if (resolved && (c.resolutionNote ?? '').isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s12),
          Text('Resolution', style: CanopyType.label.copyWith(color: p.inkMuted)),
          Text(c.resolutionNote!, style: CanopyType.body.copyWith(color: p.ink)),
        ],
        if (!resolved) ...[
          const SizedBox(height: CanopySpace.s12),
          Row(children: [
            Expanded(child: CanopyButton(label: 'Record resolution', expand: true, onPressed: () => _resolve(context))),
            if (entry != null) ...[
              const SizedBox(width: CanopySpace.s8),
              CanopyButton.secondary(label: 'Visibility', onPressed: () => changeEntryVisibility(context, entry!.id, v)),
            ],
          ]),
        ],
      ]),
    );
  }
}
