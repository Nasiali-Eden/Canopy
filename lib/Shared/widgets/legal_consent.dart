// lib/Shared/widgets/legal_consent.dart
//
// "I am 18 or older and I agree to the Terms and the Privacy policy" — the
// checkbox shown when someone creates an account, plus the helper that records
// the confirmation on their profile.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Config/legal.dart';
import '../../theme/canopy_components.dart';

Future<void> openLegalUrl(BuildContext context, String url) async {
  try {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showCanopySnack(context, "Couldn't open that page.", error: true);
  } catch (_) {
    if (context.mounted) showCanopySnack(context, "Couldn't open that page.", error: true);
  }
}

/// Records that the person confirmed their age and accepted the terms. Safe to
/// call right after registration; it never throws.
Future<void> recordLegalConsent(String uid) async {
  try {
    await FirebaseFirestore.instance.collection('Users').doc(uid).set({
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'ageConfirmedMinimum': kMinimumAge,
    }, SetOptions(merge: true));
  } catch (_) {}
}

class LegalConsentRow extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? error;
  const LegalConsentRow({super.key, required this.value, required this.onChanged, this.error});

  @override
  State<LegalConsentRow> createState() => _LegalConsentRowState();
}

class _LegalConsentRowState extends State<LegalConsentRow> {
  late final _terms = TapGestureRecognizer()..onTap = () => openLegalUrl(context, kTermsUrl);
  late final _privacy = TapGestureRecognizer()..onTap = () => openLegalUrl(context, kPrivacyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final link = CanopyType.body.copyWith(color: p.primaryInk, decoration: TextDecoration.underline);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => widget.onChanged(!widget.value),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: widget.value, onChanged: (v) => widget.onChanged(v ?? false)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(TextSpan(style: CanopyType.body.copyWith(color: p.ink), children: [
                TextSpan(text: 'I am $kMinimumAge or older (or have a parent or guardian\'s permission) and I agree to the '),
                TextSpan(text: 'Terms of service', style: link, recognizer: _terms),
                const TextSpan(text: ' and the '),
                TextSpan(text: 'Privacy policy', style: link, recognizer: _privacy),
                const TextSpan(text: '.'),
              ])),
            ),
          ),
        ]),
      ),
      if (widget.error != null)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: CanopySpace.s4),
          child: Text(widget.error!, style: CanopyType.caption.copyWith(color: p.danger)),
        ),
    ]);
  }
}
