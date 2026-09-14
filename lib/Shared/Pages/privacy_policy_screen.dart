// lib/Shared/Pages/privacy_policy_screen.dart
//
// Phase 2.3 (Minimal Release Roadmap) — privacy policy draft. Covers, per the
// roadmap's own scope for this deliverable: what's collected per role, the
// community-owned-data principle already stated in the Community Platform
// doc, what's anchored on Cardano versus kept off-chain (per the Cardano
// pilot plan), M-Pesa payment data handling, and retention/deletion.
//
// Marked DRAFT in the UI on purpose — this is legal-facing content and the
// roadmap explicitly calls it a draft, not a final policy. Worth a real
// legal review before ship, and worth revisiting once the Phase 0.1 Konza
// application (if pursued) clarifies any additional government-data-sharing
// language needed.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'about_screen.dart' show kCanopyDescription;

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Privacy Policy',
            style: TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DRAFT — pending legal review',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppTheme.darkGreen),
              ),
            ),
            const SizedBox(height: 16),
            Text(kCanopyDescription,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppTheme.darkGreen.withOpacity(0.75))),
            const SizedBox(height: 24),
            const _Section(
              title: 'What we collect',
              body:
                  'What Canopy collects depends on your role. Every account has '
                  'a phone number and an approximate location (your community/'
                  'zone). Residents and Volunteers add photos when logging '
                  'contributions. Collectors and Processors add material and '
                  'transaction details. Verifiers may optionally link a '
                  'national ID to unlock verification duties. Organisations '
                  'provide organisation details (name, sector, logo, cover '
                  'photo, contact info) at registration.',
            ),
            const _Section(
              title: 'Community-owned data',
              body:
                  'Canopy does not sell your data. Aggregated, anonymised '
                  'insights — dumpsite density, verified cleanup outcomes, '
                  'material-recovery volumes — may be shared with county '
                  'governments and policymakers, but only with community '
                  'consent, and never as data that identifies you individually.',
            ),
            const _Section(
              title: 'What goes on the blockchain — and what never does',
              body:
                  'Canopy anchors proof of verified environmental action on '
                  'the Cardano blockchain (currently Preprod, a test network — '
                  'see the app\'s Transparency screen for status). What\'s '
                  'anchored is a cryptographic hash: a fingerprint that proves '
                  'a record existed and hasn\'t been altered, not the record '
                  'itself. Your name, phone number, exact GPS coordinates, '
                  'photos, and M-Pesa details are never included in anything '
                  'anchored on-chain — only opaque, derived, or aggregate '
                  'values ever are, and that\'s enforced in code, not just '
                  'policy.',
            ),
            const _Section(
              title: 'Payments',
              body:
                  'Marketplace and collection payouts run through M-Pesa. '
                  'Canopy stores what\'s needed to complete and reconcile a '
                  'payment (transaction reference, amount, timestamp) — never '
                  'your M-Pesa PIN, and payment references are treated the '
                  'same as other sensitive fields: never anchored on-chain.',
            ),
            const _Section(
              title: 'Retention & deletion',
              body:
                  'You can request deletion of your account and personal data '
                  'at any time from Settings. Verified contribution records '
                  'that other users or organisations rely on (e.g. a '
                  'collection handoff another party confirmed) may be retained '
                  'in de-identified form after account deletion, consistent '
                  'with the verification history those other parties depend '
                  'on. Anchored hashes, by the nature of a public blockchain, '
                  'cannot be deleted after the fact — this is exactly why no '
                  'personal data is ever put into one.',
            ),
            const SizedBox(height: 8),
            Text(
              'Questions about this policy can be sent through the Help '
              'screen once it\'s live, or directly to SHIELD International.',
              style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.darkGreen.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen)),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppTheme.darkGreen.withOpacity(0.75))),
        ],
      ),
    );
  }
}
