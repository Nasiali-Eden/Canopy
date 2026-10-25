// lib/Organization/Home/Programmes/programme_enquiry_sheet.dart
//
// Enquiry sheet (ORG_HANDOFF §3.6, T) — members ask the organisation a
// question about a programme. Needs a signed-in member; name and contact are
// pre-filled from their profile. Lands in the org's Enquiries inbox.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../Models/programme.dart';
import '../../../Models/programme_enquiry.dart';
import '../../../theme/canopy_components.dart';
import 'programme_logic.dart';

Future<void> showProgrammeEnquirySheet(BuildContext context, Programme programme, {String? orgName}) =>
    showCanopySheet(context, builder: (_) => ProgrammeEnquirySheet(programme: programme, orgName: orgName));

class ProgrammeEnquirySheet extends StatefulWidget {
  final Programme programme;
  final String? orgName;
  const ProgrammeEnquirySheet({super.key, required this.programme, this.orgName});

  @override
  State<ProgrammeEnquirySheet> createState() => _ProgrammeEnquirySheetState();
}

class _ProgrammeEnquirySheetState extends State<ProgrammeEnquirySheet> {
  final _message = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _name = '';
  bool _sending = false, _showErrors = false;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final u = _user;
    if (u != null) {
      _email.text = u.email ?? '';
      _phone.text = u.phoneNumber ?? '';
      _name = u.displayName ?? '';
      FirebaseFirestore.instance.collection('Users').doc(u.uid).get().then((d) {
        final m = d.data() ?? {};
        if (!mounted) return;
        setState(() {
          _name = ((m['name'] ?? m['displayName'] ?? m['fullName'] ?? _name) as String?) ?? '';
          if (_phone.text.isEmpty) _phone.text = (m['phone'] ?? m['phoneNumber'] ?? '') as String;
        });
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? get _messageError => _message.text.trim().length < 5 ? 'Write your question.' : null;
  String? get _contactError =>
      _phone.text.trim().isEmpty && _email.text.trim().isEmpty ? 'Leave a phone number or email so they can reply.' : null;

  Future<void> _send() async {
    setState(() => _showErrors = true);
    if (_messageError != null || _contactError != null) return;
    setState(() => _sending = true);
    try {
      await ProgrammeLogic.sendEnquiry(ProgrammeEnquiry(
        id: '',
        programmeId: widget.programme.id,
        programmeTitle: widget.programme.title,
        orgId: widget.programme.orgId,
        fromUserId: _user!.uid,
        fromUserName: _name.isEmpty ? 'Community member' : _name,
        message: _message.text.trim(),
        contactPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        contactEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
      ));
      if (!mounted) return;
      Navigator.pop(context);
      showCanopySnack(context, 'Sent to ${widget.orgName ?? 'the organisation'}. They reply by phone or email.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't send. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const CanopySheetBody(
        title: 'Ask a question',
        children: [CanopySignedOutState(line: 'Sign in to ask the organisation a question.')],
      );
    }
    return CanopySheetBody(
      title: 'Ask a question',
      caption: 'About ${widget.programme.title}',
      children: [
        CanopyTextField(
          label: 'Your question',
          hint: 'e.g. Do I need to bring my own tools?',
          controller: _message,
          minLines: 3,
          maxLines: 6,
          maxLength: 600,
          autofocus: true,
          error: _showErrors ? _messageError : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField.phone(label: 'Phone', controller: _phone, onChanged: (_) => setState(() {})),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          error: _showErrors ? _contactError : null,
          onChanged: (_) => setState(() {}),
        ),
      ],
      actions: [CanopyButton(label: 'Send question', expand: true, loading: _sending, onPressed: _send)],
    );
  }
}
