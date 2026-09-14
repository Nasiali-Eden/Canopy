// lib/Shared/Pages/about_screen.dart
//
// Phase 2.2 (Minimal Release Roadmap) — "Canopy's description — one source,
// used everywhere." Uses the canonical description from the internal project
// summary verbatim, rather than a new one written for this screen. Also
// closes the '/about' dead route flagged in the Phase 2.1 audit — there was
// no About screen to push to before this file existed.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one canonical description of Canopy — reuse this constant anywhere
/// else in the app that describes what Canopy is (store listing copy,
/// privacy-policy preamble, etc.) instead of writing a new description.
const String kCanopyDescription =
    'The circular economy, verified. A community-owned platform turning '
    'waste collection, environmental action, and cultural knowledge into '
    'proof — permanent, portable, and paid.';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('About Canopy',
            style: TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              kCanopyDescription,
              style: TextStyle(
                fontSize: 17,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 28),
            _InfoRow(
              icon: Icons.groups_outlined,
              label: 'Piloting in',
              value: 'Kibera, Nairobi — SHIELD International',
            ),
            const _InfoRow(
              icon: Icons.verified_outlined,
              label: 'Built on',
              value:
                  'Community-owned data. Aggregated, anonymised insight may be '
                  'shared with county governments and policymakers with '
                  'community consent — Canopy does not sell this data.',
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined,
                  color: AppTheme.darkGreen),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/privacy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen.withOpacity(0.55))),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppTheme.darkGreen.withOpacity(0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
