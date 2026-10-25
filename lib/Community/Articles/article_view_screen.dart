// lib/Community/Articles/article_view_screen.dart
//
// Article view (DESIGN_HANDOFF.md §3 — editorial ramp). Cover (16:9, designed
// fallback) → category eyebrow → artTitle → org byline + date/read time →
// collaborators → body: first paragraph artLead, `## `/`# ` artH2 (28 above,
// 8 below), `### ` heading, `> ` artQuote, paragraphs artBody with 16 gaps →
// "Published by" row that opens the organisation's public page → upvote +
// responses (article_responses.dart).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Organization/Explorer/org_view_screen.dart';
import '../../Shared/utils/rich_body.dart';
import '../../theme/canopy_components.dart';
import 'article_responses.dart';

const _kArticles = 'articles';
const _kOrganizations = 'organizations';

class ArticleViewScreen extends StatefulWidget {
  final String articleId;
  final Map<String, dynamic> articleData;

  const ArticleViewScreen({
    super.key,
    required this.articleId,
    required this.articleData,
  });

  @override
  State<ArticleViewScreen> createState() => _ArticleViewScreenState();
}

class _ArticleViewScreenState extends State<ArticleViewScreen> {
  // Firestore: articles/{articleId} — live, falls back to the passed data.
  late final _stream = FirebaseFirestore.instance
      .collection(_kArticles)
      .doc(widget.articleId)
      .snapshots();

  static const _categories = {
    'news': 'News',
    'announcement': 'Announcement',
    'education': 'Education',
    'impact_story': 'Impact story',
    'event_recap': 'Event recap',
    'special': 'Special',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final removed = snap.hasData && !snap.data!.exists;
        final data = (snap.hasData && snap.data!.exists)
            ? snap.data!.data()!
            : widget.articleData;
        if (removed && widget.articleData.isEmpty) {
          return CanopyScaffold(
            appBar: canopyAppBar(context),
            body: const CanopyEmptyState(
              icon: Icons.article_outlined,
              title: 'This article was removed',
              line: 'Its organisation took it down.',
            ),
          );
        }
        return _Article(articleId: widget.articleId, data: data, categories: _categories);
      },
    );
  }
}

class _Article extends StatelessWidget {
  final String articleId;
  final Map<String, dynamic> data;
  final Map<String, String> categories;
  const _Article({required this.articleId, required this.data, required this.categories});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final title = (data['title'] as String?)?.trim() ?? '';
    final body = richBodyToMarkdown(data['body']);
    final cover = (data['coverImageUrl'] ?? data['coverPhotoUrl']) as String?;
    final category = data['category'] as String?;
    final orgId = data['orgId'] as String?;
    final orgName =
        ((data['orgName'] ?? data['authorName']) as String?)?.trim() ?? '';
    final orgLogo = (data['orgLogoUrl'] ?? data['authorAvatarUrl']) as String?;
    final readTime = data['readTimeMinutes'] as int? ?? 1;
    final publishedAt = data['publishedAt'] as Timestamp?;
    final date = publishedAt != null
        ? DateFormat('d MMMM yyyy').format(publishedAt.toDate())
        : null;
    final collaborators = (data['collaboratorOrgs'] as List?)
            ?.whereType<Map>()
            .map((m) => (m['name'] as String?)?.trim())
            .whereType<String>()
            .where((n) => n.isNotEmpty)
            .toList() ??
        const <String>[];

    return CanopyScaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.sizeOf(context).width * 9 / 16,
            backgroundColor: p.canvas,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: CanopySpace.s4),
              child: CanopyIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onImage: true,
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CanopyImage(url: cover, fallbackIcon: Icons.article_outlined),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [p.scrim, p.scrim.withAlpha(0)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter,
                CanopySpace.s24, CanopySpace.gutter, CanopySpace.s32),
            sliver: SliverList.list(
              children: [
                if (category != null && category.isNotEmpty) ...[
                  Text((categories[category] ?? category).toUpperCase(),
                      style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                  const SizedBox(height: CanopySpace.s8),
                ],
                Semantics(
                  header: true,
                  child: Text(title,
                      style: CanopyType.artTitle.copyWith(color: p.ink)),
                ),
                const SizedBox(height: CanopySpace.s16),
                Row(
                  children: [
                    CanopyAvatar(url: orgLogo, name: orgName, size: 40, org: true),
                    const SizedBox(width: CanopySpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(orgName.isEmpty ? 'Canopy' : orgName,
                              style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                          Text(
                            [if (date != null) date, '$readTime min read']
                                .join(' · '),
                            style: CanopyType.caption.copyWith(color: p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (collaborators.isNotEmpty) ...[
                  const SizedBox(height: CanopySpace.s12),
                  Text.rich(
                    TextSpan(
                      style: CanopyType.caption.copyWith(color: p.inkMuted),
                      children: [
                        const TextSpan(text: 'With '),
                        TextSpan(
                          text: collaborators.length <= 2
                              ? collaborators.join(' and ')
                              : '${collaborators.first} and ${collaborators.length - 1} others',
                          style: CanopyType.caption.copyWith(
                              color: p.ink, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: CanopySpace.s20),
                Divider(height: 1, color: p.outline),
                const SizedBox(height: CanopySpace.s20),
                ..._parseBody(body, p),
                const SizedBox(height: CanopySpace.s24),
                CanopyListGroup(children: [
                  CanopyListRow(
                    leading: CanopyAvatar(
                        url: orgLogo, name: orgName, size: 40, org: true),
                    title: orgName.isEmpty ? 'Canopy' : orgName,
                    subtitle: 'Published by',
                    onTap: orgId == null || orgId.isEmpty
                        ? null
                        : () => _openOrg(context, orgId),
                  ),
                ]),
                const SizedBox(height: CanopySpace.s24),
                ArticleResponsesSection(
                  articleId: articleId,
                  orgId: orgId,
                  articleUpvotes: (data['upvotes'] as num?)?.toInt() ?? 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrg(BuildContext context, String orgId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_kOrganizations)
          .doc(orgId)
          .get();
      if (!context.mounted) return;
      if (!doc.exists) {
        showCanopySnack(context, "This organisation's page isn't available.");
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => OrgViewScreen(orgId: orgId, orgData: doc.data()!)),
      );
    } catch (_) {
      if (context.mounted) {
        showCanopySnack(context, "Couldn't open the organisation. Try again.",
            error: true);
      }
    }
  }

  List<Widget> _parseBody(String body, CanopyPalette p) {
    final widgets = <Widget>[];
    var first = true;
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: CanopySpace.s20, bottom: CanopySpace.s8),
          child: Text(line.substring(4),
              style: CanopyType.heading.copyWith(color: p.ink)),
        ));
      } else if (line.startsWith('## ') || line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 28, bottom: CanopySpace.s8),
          child: Text(line.substring(line.indexOf(' ') + 1),
              style: CanopyType.artH2.copyWith(color: p.ink)),
        ));
      } else if (line.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
          padding: const EdgeInsets.only(left: CanopySpace.s16),
          decoration: BoxDecoration(
              border: Border(left: BorderSide(color: p.ink, width: 2))),
          child: Text(line.substring(2),
              style: CanopyType.artQuote.copyWith(color: p.ink)),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: CanopySpace.s16),
          child: Text(line,
              style: (first ? CanopyType.artLead : CanopyType.artBody)
                  .copyWith(color: first ? p.inkMuted : p.ink)),
        ));
        first = false;
      }
    }
    return widgets;
  }
}
