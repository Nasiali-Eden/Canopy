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
import '../../../theme/canopy_components.dart';

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
      showCanopySnack(context, published.isEmpty
          ? 'Already up to date.'
          : 'Published ${published.length} article${published.length == 1 ? '' : 's'}.');
    } catch (_) {
      if (!mounted) return;
      showCanopySnack(context, "Couldn't publish. Try again.", error: true);
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
    return Padding(
      padding: const EdgeInsets.only(bottom: CanopySpace.s12),
      child: CanopyCallout(
        icon: Icons.hub_outlined,
        title: 'Special articles ready to publish',
        text: "The blockchain explainer and ETF guide from the roadmap — publish what's missing in one go.",
        action: Align(
          alignment: Alignment.centerLeft,
          child: CanopyButton.secondary(
              label: 'Publish', size: CanopyButtonSize.compact, loading: _publishing, onPressed: _publish),
        ),
      ),
    );
  }
}
