// lib/Community/Profile/support_sheet.dart
//
// "Contact support" (replaces the Help Center link — DESIGN_HANDOFF §4).
// Writes a support_requests/{id} doc the Canopy team triages; the member's
// account email is attached so the team can reply.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';

Future<void> showSupportSheet(BuildContext context) =>
    showCanopySheet<void>(context, builder: (_) => const _SupportSheet());

class _SupportSheet extends StatefulWidget {
  const _SupportSheet();

  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<_SupportSheet> {
  static const _topics = ['Account', 'Points & verification', 'Events', 'Services', 'Something else'];
  final _message = TextEditingController();
  String _topic = _topics.first;
  bool _sending = false;
  bool _failed = false;
  bool _sent = false;
  bool _showError = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _showError = true);
    if (_message.text.trim().length < 10) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': user.uid,
        'email': user.email,
        'topic': _topic,
        'message': _message.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (_sent) {
      return CanopySheetBody(
        title: 'Message sent',
        caption: email == null
            ? 'The Canopy team will look at it soon.'
            : "The Canopy team will reply to $email.",
        actions: [
          CanopyButton(label: 'Done', expand: true, onPressed: () => Navigator.pop(context)),
        ],
      );
    }
    final tooShort = _showError && _message.text.trim().length < 10;
    return CanopySheetBody(
      title: 'Contact support',
      caption: 'Tell us what happened. Include what you were trying to do.',
      children: [
        Wrap(
          spacing: CanopySpace.s8,
          children: [
            for (final t in _topics)
              CanopyFilterChip(
                  label: t, selected: _topic == t, onTap: () => setState(() => _topic = t)),
          ],
        ),
        const SizedBox(height: CanopySpace.s12),
        CanopyTextField(
          label: 'Message',
          controller: _message,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          error: tooShort ? 'Add a little more detail (at least 10 characters).' : null,
          onChanged: (_) => setState(() {}),
        ),
        if (_failed) ...[
          const SizedBox(height: CanopySpace.s8),
          const CanopyCallout(
              kind: CalloutKind.danger,
              text: "Your message didn't send. Check your connection and try again."),
        ],
      ],
      actions: [
        CanopyButton(
            label: _failed ? 'Try again' : 'Send message',
            expand: true,
            loading: _sending,
            onPressed: _send),
      ],
    );
  }
}
