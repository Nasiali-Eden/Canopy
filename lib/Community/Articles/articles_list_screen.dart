// lib/Community/Articles/articles_list_screen.dart
//
// Community updates — every published article, newest first, paginated.
// Search field + category filter chips (client-side), ArticleCards, and the
// five data states.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';
import 'article_card.dart';

const _kArticles = 'articles';

class ArticlesListScreen extends StatefulWidget {
  const ArticlesListScreen({super.key});

  @override
  State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}

class _ArticlesListScreenState extends State<ArticlesListScreen> {
  String? _category;
  String _query = '';

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot? _last;
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  static const _pageSize = 20;

  static const _categories = <(String?, String)>[
    (null, 'All'),
    ('news', 'News'),
    ('announcement', 'Announcement'),
    ('education', 'Education'),
    ('impact_story', 'Impact story'),
    ('event_recap', 'Event recap'),
    // Blockchain/financial-literacy pieces from the Super Admin org.
    ('special', 'Special'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadPage();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // Index-free: ordering by publishedAt alone returns only live articles.
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection(_kArticles)
          .orderBy('publishedAt', descending: true)
          .limit(_pageSize);
      if (_last != null) q = q.startAfterDocument(_last!);
      final snap = await q.get();
      if (!mounted) return;
      setState(() {
        if (snap.docs.length < _pageSize) _hasMore = false;
        if (snap.docs.isNotEmpty) _last = snap.docs.last;
        _docs.addAll(snap.docs);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    final q = _query.toLowerCase();
    return _docs.where((d) {
      final data = d.data();
      if (_category != null && (data['category'] ?? data['topic']) != _category) {
        return false;
      }
      return q.isEmpty ||
          (data['title']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Map<String?, int> get _counts {
    final m = <String?, int>{null: _docs.length};
    for (final d in _docs) {
      final c = (d.data()['category'] ?? d.data()['topic']) as String?;
      m[c] = (m[c] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final counts = _counts;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Community updates'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, 0),
            child: CanopyTextField.search(
              hint: 'Search articles',
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: CanopySpace.s4),
          CanopyChipRail(chips: [
            for (final c in _categories)
              if (c.$1 == null || (counts[c.$1] ?? 0) > 0)
                CanopyFilterChip(
                  label: c.$2,
                  count: counts[c.$1],
                  selected: _category == c.$1,
                  onTap: () => setState(() => _category = c.$1),
                ),
          ]),
          Expanded(child: _body(items)),
        ],
      ),
    );
  }

  Widget _body(List<QueryDocumentSnapshot<Map<String, dynamic>>> items) {
    if (_docs.isEmpty && _loading) {
      return ListView(
        padding: const EdgeInsets.all(CanopySpace.gutter),
        children: const [
          CanopyCardSkeleton(),
          SizedBox(height: CanopySpace.s12),
          CanopyCardSkeleton(),
        ],
      );
    }
    if (_docs.isEmpty && _failed) {
      return CanopyErrorState(
        title: "Couldn't load community updates",
        onRetry: _loadPage,
      );
    }
    if (_docs.isEmpty) {
      return const CanopyEmptyState(
        icon: Icons.article_outlined,
        title: 'No community updates yet',
        line: 'News from organisations in your area will show up here.',
      );
    }
    if (items.isEmpty) {
      return CanopyEmptyState(
        icon: Icons.search_off_outlined,
        title: 'No articles match',
        line: _query.isNotEmpty
            ? 'Nothing matches "$_query".'
            : 'No articles in this category yet.',
        actionLabel: 'Clear filters',
        onAction: () => setState(() {
          _query = '';
          _search.clear();
          _category = null;
        }),
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8,
          CanopySpace.gutter, CanopySpace.s32),
      itemCount: items.length + (_loading || _failed ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: CanopySpace.s12),
      itemBuilder: (_, i) {
        if (i == items.length) {
          return _failed
              ? CanopyErrorState(
                  inline: true,
                  title: "Couldn't load more.",
                  onRetry: _loadPage)
              : const CanopyCardSkeleton();
        }
        return ArticleCard(id: items[i].id, data: items[i].data());
      },
    );
  }
}
