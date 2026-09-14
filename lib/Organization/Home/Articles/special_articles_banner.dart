// lib/Organization/Home/Articles/special_articles_banner.dart
//
// Phase 5.1 — surfaces a one-tap "publish the two SHIELD blockchain
// articles" action on the org's own Articles screen, but only when:
//   1. this org is the Super Admin org — either via the
//      lib/Shared/config/platform_config.dart bootstrap constant, or
//      flagged `isSuperAdmin` on its `organizations/{orgId}` doc (mirrors
//      the isSuperAdminOrg() gate in firestore.rules — this is a UX
//      convenience, not the real enforcement), and
//   2. at least one of the two seed articles hasn't been published yet.
// Once both are published the banner just stops rendering — no dismiss
// state to track.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../Services/Article/article_service.dart';
import '../../../Services/Article/special_articles_seed.dart';
import '../../../Shared/config/platform_config.dart';
import '../../../Shared/theme/app_theme.dart';

class SpecialArticlesBanner extends StatefulWidget {
  final String orgId;
  final String? uid;
  final Set<String> existingHeadings;

  const SpecialArticlesBanner({
    super.key,
    required this.orgId,
    required this.uid,
    required this.existingHeadings,
  });

  @override
  State<SpecialArticlesBanner> createState() => _SpecialArticlesBannerState();
}

class _SpecialArticlesBannerState extends State<SpecialArticlesBanner> {
  bool _publishing = false;

  bool get _missingAny => kSpecialArticleSeeds.any((seed) => !widget
      .existingHeadings
      .map((h) => h.trim().toLowerCase())
      .contains(seed.heading.trim().toLowerCase()));

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final published = await publishMissingSpecialArticles(
        service: ArticleService(),
        orgId: widget.orgId,
        createdBy: widget.uid,
        existingHeadings: widget.existingHeadings,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(published.isEmpty
              ? 'Already up to date.'
              : 'Published ${published.length} article${published.length == 1 ? '' : 's'}.'),
          backgroundColor: AppTheme.darkGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_missingAny) return const SizedBox.shrink();

    // Bootstrap path — see lib/Shared/config/platform_config.dart. Skips
    // the Firestore round-trip entirely once that constant is filled in.
    if (widget.orgId == kSuperAdminOrgId) {
      return _content(context);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .get(),
      builder: (context, snap) {
        final isSuperAdmin = snap.data?.data()?['isSuperAdmin'] == true;
        if (!isSuperAdmin) return const SizedBox.shrink();
        return _content(context);
      },
    );
  }

  Widget _content(BuildContext context) {
    return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.hub_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Special articles ready to publish',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'The blockchain explainer & ETF guide from the roadmap — '
                      'one tap publishes what\'s missing.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _publishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _publish,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Publish',
                          style: TextStyle(
                              color: AppTheme.darkGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
            ],
          ),
        );
  }
}
