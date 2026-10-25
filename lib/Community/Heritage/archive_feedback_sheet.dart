// lib/Community/Heritage/archive_feedback_sheet.dart
//
// "Talk to the archive" — how a member reaches the organisation that
// published an entry: ask a question, add something, or say something is
// wrong (a dispute). Writes cultural_comments, which the org answers from
// the Cultural Archive's Feedback tab. Needs a signed-in member.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';

Future<void> showArchiveFeedbackSheet(BuildContext context, {required String entryId, required String orgId, required String entryTitle}) async {
  final sent = await showCanopySheet<bool>(context, builder: (_) => _Sheet(entryId: entryId, orgId: orgId, entryTitle: entryTitle));
  if (sent == true && context.mounted) showCanopySnack(context, 'Sent. The archive will reply here and on your notifications.');
}

class _Sheet extends StatefulWidget {
  final String entryId, orgId, entryTitle;
  const _Sheet({required this.entryId, required this.orgId, required this.entryTitle});

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  String _action = 'ask_question';
  final _msg = TextEditingController();
  bool _busy = false, _showErrors = false;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _showErrors = true);
    if (_msg.text.trim().length < 10) return;
    final u = _user!;
    setState(() => _busy = true);
    try {
      final prof = (await FirebaseFirestore.instance.collection('Users').doc(u.uid).get()).data() ?? {};
      await FirebaseFirestore.instance.collection('cultural_comments').add({
        'entry_id': widget.entryId,
        'org_id': widget.orgId,
        'commenter_id': u.uid,
        'commenter_name': (prof['name'] ?? prof['displayName'] ?? u.displayName ?? 'Member') as String,
        'voice_tier': 'open',
        'comment_body': _msg.text.trim(),
        'comment_action': _action,
        'status': 'pending',
        'has_reply': false,
        'is_resolved': false,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showCanopySnack(context, "Couldn't send. Try again.", error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (_user == null) {
      return const CanopySheetBody(title: 'Talk to the archive', children: [CanopySignedOutState(line: 'Sign in to write to the archive.')]);
    }
    return CanopySheetBody(
      title: 'Talk to the archive',
      caption: 'About ${widget.entryTitle}',
      children: [
        CanopySegmented<String>(
          options: const [('ask_question', 'Ask'), ('add_variation', 'Add to it'), ('dispute', "Something's wrong")],
          value: _action,
          onChanged: (v) => setState(() => _action = v),
        ),
        const SizedBox(height: CanopySpace.s8),
        Text(
          switch (_action) {
            'add_variation' => 'Share another version, a name, a memory or a detail the entry is missing.',
            'dispute' => 'Tell the archive what is wrong or should not be shared. Disputes are reviewed first.',
            _ => 'Ask the organisation that published it.',
          },
          style: CanopyType.caption.copyWith(color: p.inkMuted),
        ),
        const SizedBox(height: CanopySpace.s12),
        CanopyTextField(
          controller: _msg,
          hint: 'Write in any language',
          minLines: 3,
          maxLines: 8,
          maxLength: 1500,
          autofocus: true,
          error: _showErrors && _msg.text.trim().length < 10 ? 'Write a little more.' : null,
          onChanged: (_) => setState(() {}),
        ),
      ],
      actions: [CanopyButton(label: 'Send', expand: true, loading: _busy, onPressed: _send)],
    );
  }
}
