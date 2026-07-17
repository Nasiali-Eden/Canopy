import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../Services/Article/article_service.dart';
import '../../../Shared/Activities/create_article.dart';
import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/utils/rich_body.dart';

const _kBg = Color(0xFFF7F5F0);

// ─────────────────────────────────────────────────────────────────────────────
// OrgArticles — an organisation's article library (manage / edit / publish)
// ─────────────────────────────────────────────────────────────────────────────

class OrgArticlesScreen extends StatelessWidget {
  final String orgId;

  const OrgArticlesScreen({super.key, required this.orgId});

  void _openEditor(BuildContext context, {Map<String, dynamic>? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CreateArticleScreen(orgId: orgId, existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ArticleService();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        foregroundColor: AppTheme.darkGreen,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 15, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Articles',
                style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.4,
                    height: 1.1)),
            Text('Stories you share with the community',
                style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.38),
                    fontWeight: FontWeight.w500,
                    fontSize: 11)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => _openEditor(context),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 4),
                  Text('New',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.watchOrgArticles(orgId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final articles = snap.data ?? const [];
          if (articles.isEmpty) {
            return _EmptyState(onCreate: () => _openEditor(context));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: articles.length,
            itemBuilder: (context, i) => _ArticleManageCard(
              data: articles[i],
              onEdit: () => _openEditor(context, existing: articles[i]),
              onTogglePublish: () => _togglePublish(context, service, articles[i]),
              onDelete: () => _confirmDelete(context, service, articles[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _togglePublish(BuildContext context, ArticleService service,
      Map<String, dynamic> a) async {
    final isPublished = (a['isPublished'] as bool?) ??
        ((a['status'] as String?) == 'published');
    try {
      await service.updateArticle(
        articleId: a['id'] as String,
        heading: (a['heading'] ?? a['title'] ?? '') as String,
        category: (a['category'] ?? a['topic'] ?? 'news') as String,
        body: richBodyToMarkdown(a['body']),
        orgId: orgId,
        publish: !isPublished,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublished
                ? 'Moved to drafts.'
                : 'Article published.'),
            backgroundColor: AppTheme.darkGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update. Try again.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, ArticleService service,
      Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete article?'),
        content: Text(
            '“${(a['heading'] ?? a['title'] ?? 'This article') as String}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.deleteArticle(a['id'] as String);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manage card
// ─────────────────────────────────────────────────────────────────────────────

class _ArticleManageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onDelete;

  const _ArticleManageCard({
    required this.data,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onDelete,
  });

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'news':
        return 'News';
      case 'announcement':
        return 'Announcement';
      case 'education':
        return 'Education';
      case 'impact_story':
        return 'Impact Story';
      case 'event_recap':
        return 'Event Recap';
      default:
        return cat ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final heading = (data['heading'] ?? data['title'] ?? 'Untitled') as String;
    final cover = (data['coverPhotoUrl'] ?? data['coverImageUrl']) as String?;
    final category = (data['category'] ?? data['topic']) as String?;
    final readTime = data['readTimeMinutes'] as int? ?? 1;
    final published = (data['isPublished'] as bool?) ??
        ((data['status'] as String?) == 'published');
    final updatedAt = data['updatedAt'] as Timestamp?;
    final dateStr = updatedAt != null
        ? DateFormat('d MMM yyyy').format(updatedAt.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGreen.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: cover != null && cover.isNotEmpty
                          ? Image.network(cover,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _thumb())
                          : _thumb(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusPill(published: published),
                            if (category != null && category.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _categoryLabel(category),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkGreen.withOpacity(0.5),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          heading,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$readTime min read${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.darkGreen.withOpacity(0.25)),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.lightGreen.withOpacity(0.2)),
          Row(
            children: [
              _action(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: onEdit,
              ),
              _vDivider(),
              _action(
                icon: published
                    ? Icons.visibility_off_outlined
                    : Icons.publish_rounded,
                label: published ? 'Unpublish' : 'Publish',
                color: published ? null : AppTheme.primary,
                onTap: onTogglePublish,
              ),
              _vDivider(),
              _action(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: Colors.red.shade400,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumb() => Container(
        color: AppTheme.lightGreen.withOpacity(0.15),
        child: Icon(Icons.article_outlined,
            color: AppTheme.lightGreen.withOpacity(0.7), size: 24),
      );

  Widget _vDivider() => Container(
      width: 1, height: 22, color: AppTheme.lightGreen.withOpacity(0.2));

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppTheme.darkGreen.withOpacity(0.65);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool published;
  const _StatusPill({required this.published});

  @override
  Widget build(BuildContext context) {
    final color = published ? AppTheme.primary : AppTheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        published ? 'PUBLISHED' : 'DRAFT',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_stories_outlined,
                  size: 34, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No articles yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 8),
            Text(
              'Share news, impact stories and updates with your community. They appear on the community home.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.darkGreen.withOpacity(0.45)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Write your first article',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
