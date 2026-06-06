import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Shared/theme/app_theme.dart';
import '../Home/community_home.dart' show timeAgo;
import 'article_view_screen.dart';

const _kArticles = 'articles';

class ArticlesListScreen extends StatefulWidget {
  const ArticlesListScreen({super.key});

  @override
  State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}

class _ArticlesListScreenState extends State<ArticlesListScreen> {
  String? _selectedCategory;
  bool _searchActive = false;
  String _searchQuery = '';

  final List<DocumentSnapshot> _docs = [];
  DocumentSnapshot? _lastDocument;
  bool _loadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;

  static const _categories = [
    {'label': 'All', 'value': null},
    {'label': 'News', 'value': 'news'},
    {'label': 'Announcement', 'value': 'announcement'},
    {'label': 'Education', 'value': 'education'},
    {'label': 'Impact Story', 'value': 'impact_story'},
    {'label': 'Event Recap', 'value': 'event_recap'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      // Firestore: articles — published, newest first, paginated
      Query query;
      if (_selectedCategory != null) {
        query = FirebaseFirestore.instance
            .collection(_kArticles)
            .where('isPublished', isEqualTo: true)
            .where('category', isEqualTo: _selectedCategory)
            .orderBy('publishedAt', descending: true)
            .limit(_pageSize);
      } else {
        query = FirebaseFirestore.instance
            .collection(_kArticles)
            .where('isPublished', isEqualTo: true)
            .orderBy('publishedAt', descending: true)
            .limit(_pageSize);
      }

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snap = await query.get();
      if (!mounted) return;
      setState(() {
        if (snap.docs.length < _pageSize) _hasMore = false;
        if (snap.docs.isNotEmpty) _lastDocument = snap.docs.last;
        _docs.addAll(snap.docs);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _applyCategory(String? cat) {
    setState(() {
      _selectedCategory = cat;
      _docs.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    _loadPage();
  }

  List<DocumentSnapshot> get _filtered {
    if (_searchQuery.isEmpty) return _docs;
    final q = _searchQuery.toLowerCase();
    return _docs.where((d) {
      final title =
          ((d.data() as Map<String, dynamic>)['title']?.toString() ?? '')
              .toLowerCase();
      return title.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.darkGreen,
        title: _searchActive
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search articles...',
                  border: InputBorder.none,
                  hintStyle:
                      TextStyle(color: AppTheme.darkGreen.withOpacity(0.4)),
                ),
                style:
                    const TextStyle(color: AppTheme.darkGreen, fontSize: 16),
              )
            : const Text('Community Updates',
                style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(
                _searchActive ? Icons.close : Icons.search_outlined,
                color: AppTheme.darkGreen),
            onPressed: () => setState(() {
              _searchActive = !_searchActive;
              _searchQuery = '';
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: _categories.map((c) {
                  final String? val = c['value'];
                  final selected = _selectedCategory == val;
                  return GestureDetector(
                    onTap: () => _applyCategory(val),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.lightGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c['label'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.darkGreen.withOpacity(0.8))),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty && !_loadingMore
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 64,
                            color: AppTheme.lightGreen.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('No articles found',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppTheme.darkGreen)),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          const Text('Try a different search term',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary)),
                        );
                      }
                      final doc = _filtered[i];
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ArticleCard(
                          data: data,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleViewScreen(
                                articleId: doc.id,
                                articleData: data,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Article list card ─────────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ArticleCard({required this.data, required this.onTap});

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
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final coverImageUrl = data['coverImageUrl'] as String?;
    final category = data['category'] as String?;
    final authorName = data['authorName'] as String? ?? '';
    final authorAvatarUrl = data['authorAvatarUrl'] as String?;
    final publishedAt = data['publishedAt'] as Timestamp?;
    final readTime = data['readTimeMinutes'] as int? ?? 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: coverImageUrl != null
                      ? Image.network(
                          coverImageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverFallback(),
                          loadingBuilder: (_, child, prog) =>
                              prog == null ? child : _coverFallback(),
                        )
                      : _coverFallback(),
                ),
                if (category != null && category.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGreen.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_categoryLabel(category),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            fontSize: 15,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(body,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.darkGreen.withOpacity(0.6),
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (authorAvatarUrl != null)
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(authorAvatarUrl),
                          onBackgroundImageError: (_, __) {},
                        )
                      else
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary.withOpacity(0.15),
                          child: Text(
                              authorName.isNotEmpty
                                  ? authorName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$authorName${publishedAt != null ? ' · ${timeAgo(publishedAt)}' : ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkGreen.withOpacity(0.6)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.schedule_outlined,
                          size: 12,
                          color: AppTheme.darkGreen.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text('$readTime min read',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkGreen.withOpacity(0.5))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() => Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.lightGreen.withOpacity(0.4),
              AppTheme.primary.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: const Center(
            child:
                Icon(Icons.article, size: 32, color: AppTheme.primary)),
      );
}
