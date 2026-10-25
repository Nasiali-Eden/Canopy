// lib/Culture/Heritage/Feedback/heritage_feedback_screen.dart
//
// Feedback (ARCHIVE_HANDOFF §3.5, F). Tabs All / Needs response / Resolved;
// FeedbackItems (status label · age · owner or "Unassigned" + Assign to me ·
// the member's words · entry reference with its visibility). Open disputes
// are pinned at the top as a ruled card. Respond: status + owner, entry,
// the member's words, a reply ("The member sees this reply"), what the
// status becomes after sending, Send, and "Edit the entry".

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Archive/heritage_archive_screen.dart' show showEntryActions;
import '../Disputes/heritage_disputes_screen.dart';
import '../Models/cultural_comment.dart';
import '../Models/cultural_entry.dart';
import '../Services/archive_feedback_service.dart';
import '../Services/heritage_providers.dart';

String _age(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} min';
  if (d.inHours < 24) return '${d.inHours} h';
  return '${d.inDays} d';
}

String _actionWord(String a) => switch (a) {
      'ask_question' => 'Question',
      'add_variation' => 'Addition',
      'propose_relation' => 'Suggested connection',
      'dispute' => 'Dispute',
      _ => 'Comment',
    };

StatusLabel feedbackStatusLabel(CulturalComment c, CanopyPalette p) => switch (c.status) {
      'resolved' => StatusLabel('Resolved', color: p.success),
      'under_review' => StatusLabel('Under review', color: p.info),
      _ => StatusLabel('Pending', color: p.warning),
    };

class HeritageFeedbackScreen extends StatefulWidget {
  final String orgId;
  const HeritageFeedbackScreen({required this.orgId, super.key});

  @override
  State<HeritageFeedbackScreen> createState() => _HeritageFeedbackScreenState();
}

class _HeritageFeedbackScreenState extends State<HeritageFeedbackScreen> {
  int _tab = 0;
  Stream<List<CulturalComment>>? _stream;
  String _idsKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HeritageEntriesProvider>().fetchEntries(widget.orgId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final entries = context.watch<HeritageEntriesProvider>().entries;
    final ids = entries.map((e) => e.id).toList()..sort();
    final key = ids.join(',');
    if (key != _idsKey || _stream == null) {
      _idsKey = key;
      _stream = ArchiveFeedbackService.instance.comments(widget.orgId, ids);
    }
    final byId = {for (final e in entries) e.id: e};
    return CanopyScaffold(
      body: StreamBuilder<List<CulturalComment>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(title: "Couldn't load feedback");
          if (!snap.hasData) return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 4)]);
          final all = snap.data!;
          final openDisputes = all.where((c) => c.isDispute && c.status != 'resolved').toList();
          final needs = all.where((c) => c.status == 'pending').toList();
          final resolved = all.where((c) => c.status == 'resolved').toList();
          final shown = switch (_tab) { 1 => needs, 2 => resolved, _ => all.where((c) => !(c.isDispute && c.status != 'resolved')).toList() };
          return Column(children: [
            CanopyUnderlineTabs(
              tabs: const ['All', 'Needs response', 'Resolved'],
              index: _tab,
              badges: {1: needs.length},
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
                children: [
                  if (openDisputes.isNotEmpty && _tab != 2) ...[
                    Container(
                      padding: const EdgeInsets.only(top: CanopySpace.s12),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.ink, width: 2))),
                      child: Row(children: [
                        Expanded(child: Text('OPEN DISPUTES · ${openDisputes.length}', style: CanopyType.eyebrow.copyWith(color: p.ink))),
                        CanopyButton.quiet(
                          label: 'All disputes',
                          size: CanopyButtonSize.compact,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: context.read<HeritageEntriesProvider>(),
                              child: HeritageDisputesScreen(orgId: widget.orgId),
                            ),
                          )),
                        ),
                      ]),
                    ),
                    for (final c in openDisputes) ...[
                      const SizedBox(height: CanopySpace.s8),
                      DisputeCard(comment: c, entry: byId[c.entryId]),
                    ],
                    const SizedBox(height: CanopySpace.section),
                  ],
                  if (shown.isEmpty)
                    CanopyEmptyState(
                      boxed: true,
                      icon: Icons.forum_outlined,
                      title: switch (_tab) { 1 => 'Nothing needs a response', 2 => 'Nothing resolved yet', _ => 'No feedback yet' },
                      line: 'Members write to the archive from any entry on Heritage.',
                    )
                  else
                    CanopyCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.outline),
                          _FeedbackItem(comment: shown[i], entry: byId[shown[i].entryId]),
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _FeedbackItem extends StatelessWidget {
  final CulturalComment comment;
  final CulturalEntry? entry;
  const _FeedbackItem({required this.comment, required this.entry});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final c = comment;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedbackRespondScreen(comment: c, entry: entry))),
      child: Padding(
        padding: const EdgeInsets.all(CanopySpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LabelRow(children: [
            feedbackStatusLabel(c, p),
            StatusLabel(_actionWord(c.commentAction), color: p.inkMuted),
            StatusLabel(_age(c.createdAt), color: p.inkMuted),
          ]),
          const SizedBox(height: CanopySpace.s4),
          Text('"${c.commentBody}"', maxLines: 3, overflow: TextOverflow.ellipsis, style: CanopyType.body.copyWith(color: p.ink)),
          Text('— ${c.commenterName.isEmpty ? 'Member' : c.commenterName}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s8),
          Row(children: [
            if (entry != null) ...[
              Expanded(child: Text(entry!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.label.copyWith(color: p.ink))),
              VisibilityLabel(visibilityFrom(entry!.visibility)),
            ] else
              const Spacer(),
          ]),
          const SizedBox(height: CanopySpace.s4),
          Row(children: [
            Expanded(
              child: Text(c.ownerName == null ? 'Unassigned' : 'Owner: ${c.ownerName}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ),
            if (c.ownerUid == null && c.status != 'resolved')
              CanopyButton.quiet(
                label: 'Assign to me',
                size: CanopyButtonSize.compact,
                onPressed: () async {
                  try {
                    await ArchiveFeedbackService.instance.assignToMe(c.id);
                  } catch (_) {
                    if (context.mounted) showCanopySnack(context, "Couldn't assign. Try again.", error: true);
                  }
                },
              ),
          ]),
        ]),
      ),
    );
  }
}

class FeedbackRespondScreen extends StatefulWidget {
  final CulturalComment comment;
  final CulturalEntry? entry;
  const FeedbackRespondScreen({super.key, required this.comment, this.entry});

  @override
  State<FeedbackRespondScreen> createState() => _FeedbackRespondScreenState();
}

class _FeedbackRespondScreenState extends State<FeedbackRespondScreen> {
  late final _reply = TextEditingController(text: widget.comment.replyText ?? '');
  late bool _resolve = widget.comment.status == 'resolved' || widget.comment.commentAction == 'ask_question';
  bool _busy = false, _showErrors = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _showErrors = true);
    if (_reply.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ArchiveFeedbackService.instance.reply(widget.comment.id, _reply.text, resolved: _resolve);
      if (!mounted) return;
      showCanopySnack(context, 'Reply sent.');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't send. Your reply is still here — try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final c = widget.comment;
    final e = widget.entry;
    final mine = c.ownerUid == FirebaseAuth.instance.currentUser?.uid;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: _actionWord(c.commentAction)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          LabelRow(children: [
            feedbackStatusLabel(c, p),
            StatusLabel(c.ownerName == null ? 'Unassigned' : (mine ? 'Yours' : 'Owner: ${c.ownerName}'), color: p.inkMuted),
          ]),
          if (e != null) ...[
            const SizedBox(height: CanopySpace.s12),
            CanopyCard(
              padding: EdgeInsets.zero,
              child: ArchiveEntryRow(
                typeKey: e.contentType,
                community: e.locality,
                title: e.title,
                coverUrl: e.imageUrl,
                visibility: visibilityFrom(e.visibility),
                onTap: () => openEntryPreview(context, e.id, published: !e.isDraft),
              ),
            ),
          ],
          const SizedBox(height: CanopySpace.s16),
          Text('${c.commenterName.isEmpty ? 'The member' : c.commenterName} wrote', style: CanopyType.label.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s4),
          Container(
            padding: const EdgeInsets.only(left: CanopySpace.s12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: p.outlineStrong, width: 2))),
            child: Text(c.commentBody, style: CanopyType.body.copyWith(fontSize: 16, height: 1.5, color: p.ink)),
          ),
          const SizedBox(height: CanopySpace.section),
          CanopyTextField(
            label: 'Your reply',
            helper: 'The member sees this reply.',
            controller: _reply,
            minLines: 4,
            maxLines: 10,
            error: _showErrors && _reply.text.trim().isEmpty ? 'Write a reply first.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          Text('After sending', style: CanopyType.label.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          CanopySegmented<bool>(
            options: const [(false, 'Under review'), (true, 'Resolved')],
            value: _resolve,
            onChanged: (v) => setState(() => _resolve = v),
          ),
          if (e != null) ...[
            const SizedBox(height: CanopySpace.s16),
            CanopyButton.quiet(label: 'Edit the entry', expand: true, onPressed: () => showEntryActions(context, e)),
          ],
        ],
      ),
      sticky: StickyActionBar(children: [CanopyButton(label: 'Send reply', expand: true, loading: _busy, onPressed: _send)]),
    );
  }
}
