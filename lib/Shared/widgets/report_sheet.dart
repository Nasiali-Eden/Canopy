// lib/Shared/widgets/report_sheet.dart
//
// "Report" sheet: pick a reason, add a note if you like, and optionally block
// the person who posted it. Used on feed posts, listings and heritage entries.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Services/Moderation/moderation_service.dart';
import '../../theme/canopy_components.dart';

Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  String? ownerId,
  String subject = 'this',
}) {
  if (FirebaseAuth.instance.currentUser == null) {
    showCanopySnack(context, 'Sign in to report something.', error: true);
    return Future.value();
  }
  return showCanopySheet<void>(
    context,
    tall: true,
    builder: (_) => _ReportBody(targetType: targetType, targetId: targetId, ownerId: ownerId, subject: subject),
  );
}

class _ReportBody extends StatefulWidget {
  final String targetType, targetId, subject;
  final String? ownerId;
  const _ReportBody({required this.targetType, required this.targetId, required this.subject, this.ownerId});

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  String? _reason;
  bool _block = false, _sending = false;
  final _details = TextEditingController();

  bool get _canBlock => (widget.ownerId ?? '').isNotEmpty && widget.ownerId != FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _sending = true);
    try {
      await ModerationService.instance.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        ownerId: widget.ownerId,
        reason: _reason!,
        details: _details.text,
      );
      if (_block && _canBlock) await ModerationService.instance.block(widget.ownerId!);
      if (!mounted) return;
      Navigator.pop(context);
      showCanopySnack(context, _block ? "Thanks. We'll review it, and you won't see their posts." : "Thanks. We'll review it.");
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        showCanopySnack(context, "Couldn't send the report. Try again.", error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: 'Report ${widget.subject}',
      caption: 'Tell us what is wrong. The Canopy team reviews every report. The person is not told it was you.',
      children: [
        Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
          for (final r in ModerationService.reasons)
            CanopyFilterChip(label: r.$2, selected: _reason == r.$1, onTap: () => setState(() => _reason = r.$1)),
        ]),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Anything else? (optional)', controller: _details, minLines: 2, maxLines: 4, maxLength: 500),
        if (_canBlock) ...[
          const SizedBox(height: CanopySpace.s8),
          CanopySwitchRow(
            title: 'Also block this person',
            caption: "You won't see their posts",
            value: _block,
            onChanged: (v) => setState(() => _block = v),
          ),
        ],
        const SizedBox(height: CanopySpace.s8),
        Text('If someone is in danger, contact the emergency services first.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
      actions: [
        CanopyButton(label: 'Send report', expand: true, loading: _sending, onPressed: _reason == null || _sending ? null : _send),
      ],
    );
  }
}

/// "Blocked people": see who you have blocked and undo it.
Future<void> showBlockedSheet(BuildContext context) => showCanopySheet<void>(
      context,
      tall: true,
      builder: (_) => const _BlockedBody(),
    );

class _BlockedBody extends StatelessWidget {
  const _BlockedBody();

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: 'Blocked people',
      caption: "You don't see their posts. They aren't told.",
      children: [
        StreamBuilder<Set<String>>(
          stream: ModerationService.instance.watchBlocked(),
          builder: (context, snap) {
            final ids = (snap.data ?? const <String>{}).toList();
            if (ids.isEmpty) {
              return Text('You have not blocked anyone.', style: CanopyType.body.copyWith(color: p.inkMuted));
            }
            return CanopyListGroup(children: [
              for (final id in ids)
                CanopyListRow(
                  icon: Icons.person_off_outlined,
                  title: 'Member ${id.substring(0, id.length < 6 ? id.length : 6)}…',
                  chevron: false,
                  trailing: CanopyButton.quiet(label: 'Unblock', size: CanopyButtonSize.compact, onPressed: () => ModerationService.instance.unblock(id)),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
