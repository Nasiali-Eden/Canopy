// lib/Organization/Home/Articles/org_articles.dart
//
// Articles list (ORG_HANDOFF §3.3, T). Underline tabs All / Drafts /
// Published; cards with a content-state label + Edit / Publish·Unpublish
// (+ delete in the overflow, confirmed). Private/public callouts explain
// who sees what. The editor is CreateArticleScreen.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../Services/Article/article_service.dart';
import '../../../Shared/Activities/create_article.dart';
import '../../../Shared/utils/rich_body.dart';
import '../../../theme/canopy_components.dart';
import '../../org_ui.dart';
import 'special_articles_banner.dart';

class OrgArticlesScreen extends StatefulWidget {
  final String orgId;
  const OrgArticlesScreen({super.key, required this.orgId});

  @override
  State<OrgArticlesScreen> createState() => _OrgArticlesScreenState();
}

class _OrgArticlesScreenState extends State<OrgArticlesScreen> {
  final _service = ArticleService();
  late Stream<List<Map<String, dynamic>>> _stream = _service.watchOrgArticles(widget.orgId);
  int _tab = 0;
  final Set<String> _busy = {};

  static const _categories = {
    'news': 'News',
    'announcement': 'Announcement',
    'education': 'Education',
    'impact_story': 'Impact story',
    'event_recap': 'Event recap',
    'special': 'Special',
  };

  bool _published(Map<String, dynamic> a) =>
      (a['isPublished'] as bool?) ?? ((a['status'] as String?) == 'published');

  void _edit([Map<String, dynamic>? a]) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => CreateArticleScreen(orgId: widget.orgId, existing: a)));

  Future<void> _toggle(Map<String, dynamic> a) async {
    final id = a['id'] as String;
    final pub = _published(a);
    setState(() => _busy.add(id));
    try {
      await _service.updateArticle(
        articleId: id,
        heading: (a['heading'] ?? a['title'] ?? '') as String,
        category: (a['category'] ?? a['topic'] ?? 'news') as String,
        body: richBodyToMarkdown(a['body']),
        orgId: widget.orgId,
        publish: !pub,
      );
      if (mounted) {
        showCanopySnack(context, pub ? 'Moved to drafts.' : 'Published — members see it on Home.');
      }
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showCanopyConfirm(
      context,
      title: 'Delete this article?',
      message: '"${(a['heading'] ?? a['title'] ?? 'This article')}" will be removed for everyone. This can\'t be undone.',
      confirmLabel: 'Delete article',
      danger: true,
    );
    if (!ok) return;
    try {
      await _service.deleteArticle(a['id'] as String);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't delete. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Articles'),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(
                title: "Couldn't load your articles",
                onRetry: () => setState(() => _stream = _service.watchOrgArticles(widget.orgId)));
          }
          if (!snap.hasData) {
            return ListView(
                padding: const EdgeInsets.all(CanopySpace.gutter),
                children: const [CanopyListSkeleton(rows: 3, leadingSize: 64)]);
          }
          final all = snap.data!;
          final drafts = all.where((a) => !_published(a)).toList();
          final published = all.where(_published).toList();
          final shown = switch (_tab) { 1 => drafts, 2 => published, _ => all };
          final headings = all
              .map((a) => (a['heading'] ?? a['title'] ?? '') as String)
              .where((h) => h.isNotEmpty)
              .toSet();

          return Column(children: [
            CanopyUnderlineTabs(
              tabs: ['All ${all.length}', 'Drafts ${drafts.length}', 'Published ${published.length}'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
                children: [
                  SpecialArticlesBanner(
                    orgId: widget.orgId,
                    uid: FirebaseAuth.instance.currentUser?.uid,
                    existingHeadings: headings,
                  ),
                  if (_tab == 1)
                    const Padding(
                      padding: EdgeInsets.only(bottom: CanopySpace.s12),
                      child: CanopyCallout(icon: Icons.lock_outline, text: 'Only your team sees drafts.'),
                    ),
                  if (_tab == 2)
                    const Padding(
                      padding: EdgeInsets.only(bottom: CanopySpace.s12),
                      child: CanopyCallout(
                          icon: Icons.public, text: 'Members see these on their Home feed.'),
                    ),
                  if (shown.isEmpty)
                    CanopyEmptyState(
                      boxed: true,
                      icon: Icons.article_outlined,
                      title: _tab == 1
                          ? 'No drafts'
                          : _tab == 2
                              ? 'Nothing published yet'
                              : 'No articles yet',
                      line: 'Share news, impact stories and event recaps with the community.',
                    )
                  else
                    for (final a in shown) ...[
                      _card(a, p),
                      const SizedBox(height: CanopySpace.s12),
                    ],
                ],
              ),
            ),
          ]);
        },
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(label: 'Write an article', expand: true, onPressed: () => _edit()),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> a, CanopyPalette p) {
    final pub = _published(a);
    final title = ((a['heading'] ?? a['title'] ?? '') as String).trim();
    final cat = (a['category'] ?? a['topic']) as String?;
    final cover = (a['coverImageUrl'] ?? a['coverPhotoUrl']) as String?;
    final when = ((pub ? a['publishedAt'] : a['updatedAt'] ?? a['createdAt']) as dynamic);
    final date = when is DateTime
        ? when
        : (when?.toDate != null ? (when.toDate() as DateTime) : null);
    final id = a['id'] as String;
    return CanopyCard(
      padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.xs),
            child: SizedBox(
                width: 64, height: 64, child: CanopyImage(url: cover, fallbackIcon: Icons.article_outlined)),
          ),
          const SizedBox(width: CanopySpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LabelRow(children: [
                ContentStateLabel(pub ? ContentState.published : ContentState.draft),
                if (cat != null) StatusLabel(_categories[cat] ?? cat, color: p.inkMuted),
              ]),
              const SizedBox(height: CanopySpace.s2),
              Text(title.isEmpty ? 'Untitled' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CanopyType.bodyStrong.copyWith(color: p.ink)),
              if (date != null)
                Text('${pub ? 'Published' : 'Edited'} ${DateFormat('d MMM yyyy').format(date)}',
                    style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_horiz, color: p.inkMuted),
            onSelected: (v) => v == 'delete' ? _delete(a) : null,
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: CanopyType.body.copyWith(color: p.danger))),
            ],
          ),
        ]),
        Row(children: [
          CanopyButton.quiet(label: 'Edit', size: CanopyButtonSize.compact, onPressed: () => _edit(a)),
          const Spacer(),
          CanopyButton.secondary(
            label: pub ? 'Unpublish' : 'Publish',
            size: CanopyButtonSize.compact,
            loading: _busy.contains(id),
            onPressed: () => _toggle(a),
          ),
        ]),
      ]),
    );
  }
}
