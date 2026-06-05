import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../Models/programme.dart';
import '../../../Models/programme_enquiry.dart';
import '../../../Shared/theme/app_theme.dart';
import 'programme_logic.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Programme Enquiry Sheet
//
// Opened from ProgrammeDetail when the programme allows enquiries.
// Dual-write on submit: creates ProgrammeEnquiry + signals org inbox.
// ─────────────────────────────────────────────────────────────────────────────

class ProgrammeEnquirySheet extends StatefulWidget {
  final Programme programme;

  const ProgrammeEnquirySheet({super.key, required this.programme});

  @override
  State<ProgrammeEnquirySheet> createState() => _ProgrammeEnquirySheetState();
}

class _ProgrammeEnquirySheetState extends State<ProgrammeEnquirySheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final enquiry = ProgrammeEnquiry(
        id:             '', // assigned by Firestore
        programmeId:    widget.programme.id,
        programmeTitle: widget.programme.title,
        orgId:          widget.programme.orgId,
        fromUserId:     user?.uid ?? 'anon',
        fromUserName:   user?.displayName ?? 'Community member',
        message:        _messageCtrl.text.trim(),
        contactPhone:   _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        contactEmail:   _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );

      await ProgrammeLogic.sendEnquiry(enquiry);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your message has been sent to ${widget.programme.orgId}. '
                  'They\'ll get back to you soon.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not send. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Send an enquiry',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGreen),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.programme.title,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.darkGreen.withOpacity(0.5)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.darkGreen),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),

                // Scrollable form content
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      // Message
                      TextFormField(
                        controller: _messageCtrl,
                        maxLines: 5,
                        decoration: _deco(
                          'Your message',
                          'What would you like to know about this programme?',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please write a message'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Optional contact fields
                      Text(
                        'HOW TO REACH YOU (OPTIONAL)',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppTheme.darkGreen.withOpacity(0.4)),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration:
                            _deco('Phone number', 'e.g. +254 712 345 678'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _deco('Email', 'your@email.com'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Send button
                      FilledButton(
                        onPressed: _sending ? null : _send,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          disabledBackgroundColor:
                              AppTheme.primary.withOpacity(0.4),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _sending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Send message',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _deco(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle:
          TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.35)),
      filled: true,
      fillColor: const Color(0xFFF7F5F0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppTheme.lightGreen.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}
