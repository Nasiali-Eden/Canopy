import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../Shared/theme/app_theme.dart';

const _kArticles = 'articles';

class ArticleViewScreen extends StatelessWidget {
  final String articleId;
  final Map<String, dynamic> articleData;

  const ArticleViewScreen({
    super.key,
    required this.articleId,
    required this.articleData,
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

  List<Widget> _parseBody(String body, BuildContext context) {
    final lines = body.split('\n');
    final widgets = <Widget>[];
    bool isFirst = true;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            line.substring(3),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                  fontSize: 18,
                ),
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            line,
            style: TextStyle(
              fontSize: 16,
              height: 1.75,
              color: const Color(0xFF2A3A2F),
              fontStyle: isFirst ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ));
        isFirst = false;
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      // Firestore: articles/{articleId} — stream for live updates
      stream: FirebaseFirestore.instance
          .collection(_kArticles)
          .doc(articleId)
          .snapshots(),
      builder: (context, snap) {
        final data = (snap.hasData && snap.data!.exists)
            ? (snap.data!.data() as Map<String, dynamic>)
            : articleData;

        final title = data['title'] as String? ?? '';
        final body = data['body'] as String? ?? '';
        final coverImageUrl = data['coverImageUrl'] as String?;
        final category = data['category'] as String?;
        final authorName = data['authorName'] as String? ?? '';
        final authorAvatarUrl = data['authorAvatarUrl'] as String?;
        final readTime = data['readTimeMinutes'] as int? ?? 1;
        final publishedAt = data['publishedAt'] as Timestamp?;
        final dateStr = publishedAt != null
            ? DateFormat('d MMMM yyyy').format(publishedAt.toDate())
            : '';

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppTheme.darkGreen,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  background: coverImageUrl != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              coverImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _gradientBg(),
                              loadingBuilder: (_, child, prog) =>
                                  prog == null ? child : _gradientBg(),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0x99000000),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : _gradientBg(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category != null && category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_categoryLabel(category),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (authorAvatarUrl != null)
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(authorAvatarUrl),
                              onBackgroundImageError: (_, __) {},
                            )
                          else
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppTheme.primary.withOpacity(0.15),
                              child: Text(
                                  authorName.isNotEmpty
                                      ? authorName[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(authorName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.darkGreen)),
                              Text(
                                '$dateStr · $readTime min read',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppTheme.darkGreen.withOpacity(0.55)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Divider(
                          height: 32,
                          color: AppTheme.lightGreen.withOpacity(0.3)),
                      ..._parseBody(body, context),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.lightGreen.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppTheme.primary.withOpacity(0.15),
                              child: Icon(Icons.business,
                                  size: 18, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Published by',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.darkGreen
                                              .withOpacity(0.55))),
                                  Text(authorName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.darkGreen,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('Follow'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.small(
            onPressed: () {
              // TODO: Replace with share_plus when added to pubspec.yaml
              // Share.share('$title\nhttps://canopy.app/articles/$articleId');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
            backgroundColor: AppTheme.primary,
            child:
                const Icon(Icons.share_outlined, color: Colors.white, size: 18),
          ),
        );
      },
    );
  }

  Widget _gradientBg() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.darkGreen, AppTheme.primary],
          ),
        ),
      );
}
