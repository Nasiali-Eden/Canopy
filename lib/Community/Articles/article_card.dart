// lib/Community/Articles/article_card.dart
//
// Content card for an article (DESIGN_HANDOFF.md §2 ContentCard): 16:9 cover
// with the designed fallback, category eyebrow, heading title, two-line
// excerpt, org avatar + "Org · +N partners · N min read · 2d ago".
// Used by Home "Community updates" and the articles list.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../Shared/utils/rich_body.dart';
import '../../theme/canopy_components.dart';
import '../Home/home_feed.dart' show timeAgo;
import 'article_view_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ARTICLE CONTENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class ArticleCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const ArticleCard({super.key, required this.id, required this.data});

  static const categories = {
    'news': 'News',
    'announcement': 'Announcement',
    'education': 'Education',
    'impact_story': 'Impact story',
    'event_recap': 'Event recap',
    'special': 'Special',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final title = (data['title'] as String?)?.trim() ?? '';
    final excerpt = richBodyToPlainText(data['body']);
    // Articles may store the cover under either key — read both.
    final imageUrl =
        (data['coverImageUrl'] ?? data['coverPhotoUrl']) as String?;
    final category = data['category'] as String? ?? '';
    final publishedAt = data['publishedAt'] as Timestamp?;
    final readMins = data['readTimeMinutes'] as int?;
    final orgName =
        ((data['orgName'] ?? data['authorName']) as String?)?.trim() ?? '';
    final orgLogoUrl =
        (data['orgLogoUrl'] ?? data['authorAvatarUrl']) as String?;
    final partners = (data['collaboratorOrgs'] as List?)
            ?.whereType<Map>()
            .where((m) => (m['name'] as String?)?.trim().isNotEmpty == true)
            .length ??
        0;
    final meta = [
      orgName.isEmpty ? 'Canopy' : orgName,
      if (partners > 0) '+$partners partner${partners == 1 ? '' : 's'}',
      if (readMins != null) '$readMins min read',
      if (publishedAt != null) timeAgo(publishedAt),
      if (((data['upvotes'] as num?)?.toInt() ?? 0) > 0) '${(data['upvotes'] as num).toInt()} upvote${(data['upvotes'] as num).toInt() == 1 ? '' : 's'}',
    ].join(' · ');

    return CanopyCard(
      padding: null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleViewScreen(articleId: id, articleData: data),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child:
                CanopyImage(url: imageUrl, fallbackIcon: Icons.article_outlined),
          ),
          Padding(
            padding: const EdgeInsets.all(CanopySpace.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category.isNotEmpty) ...[
                  Text((categories[category] ?? category).toUpperCase(),
                      style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                  const SizedBox(height: CanopySpace.s4),
                ],
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CanopyType.heading.copyWith(color: p.ink)),
                if (excerpt.trim().isNotEmpty) ...[
                  const SizedBox(height: CanopySpace.s4),
                  Text(excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CanopyType.body.copyWith(color: p.inkMuted)),
                ],
                const SizedBox(height: CanopySpace.s12),
                Row(
                  children: [
                    CanopyAvatar(
                        url: orgLogoUrl, name: orgName, size: 24, org: true),
                    const SizedBox(width: CanopySpace.s8),
                    Expanded(
                      child: Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CanopyType.caption.copyWith(color: p.inkMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
