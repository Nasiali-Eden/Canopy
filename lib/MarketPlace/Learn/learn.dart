// lib/MarketPlace/Learn/learn.dart
//
// Seller › Learn (MARKETPLACE_SELLER_DESIGN_BRIEF §1.2, decision D). The old
// tab was hard-coded blockchain / carbon-credit articles with dead links.
// Decision: Learn shows real articles organisations publish on Canopy —
// education and impact stories first — and nothing invented. Empty is honest.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../Community/Articles/article_card.dart';
import '../../Community/Articles/articles_list_screen.dart';
import '../../theme/canopy_components.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  // Index-free: ordering by publishedAt alone returns only live articles.
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() =>
      FirebaseFirestore.instance.collection('articles').orderBy('publishedAt', descending: true).limit(40).snapshots();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _articles = _stream();

  static const _learnFirst = {'education', 'impact_story', 'event_recap'};

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Learn', showBack: false),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _articles,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(title: "Couldn't load articles", onRetry: () => setState(() => _articles = _stream()));
          }
          if (!snap.hasData) {
            return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [
              CanopyCardSkeleton(),
              SizedBox(height: CanopySpace.s12),
              CanopyCardSkeleton(),
            ]);
          }
          final docs = [...snap.data!.docs]..sort((a, b) {
              final ai = _learnFirst.contains(a.data()['category'] ?? a.data()['topic']) ? 0 : 1;
              final bi = _learnFirst.contains(b.data()['category'] ?? b.data()['topic']) ? 0 : 1;
              return ai.compareTo(bi);
            });
          if (docs.isEmpty) {
            return const CanopyEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Nothing to read yet',
              line: 'Guides and impact stories that organisations publish on Canopy appear here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
            children: [
              Text('Guides, impact stories and recaps from organisations on Canopy.', style: CanopyType.body.copyWith(color: p.inkMuted)),
              const SizedBox(height: CanopySpace.s16),
              for (final d in docs.take(12)) ...[
                ArticleCard(id: d.id, data: d.data()),
                const SizedBox(height: CanopySpace.s12),
              ],
              if (docs.length > 12)
                CanopyButton.secondary(
                  label: 'All articles',
                  expand: true,
                  onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const ArticlesListScreen())),
                ),
            ],
          );
        },
      ),
    );
  }
}
