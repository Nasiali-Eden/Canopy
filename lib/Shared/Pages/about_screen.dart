// lib/Shared/Pages/about_screen.dart
//
// About (v2) — only what is true today. Canopy's aim lives in its own
// article ("What Canopy is working toward") so people can read it, upvote
// and respond, instead of having it stated here as fact. The row appears
// once that article is published.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../Community/Articles/article_view_screen.dart';
import '../../Services/Article/special_articles_seed.dart' show kAimArticleHeading;
import '../../theme/canopy_components.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'About Canopy'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.surfaceBrand, borderRadius: BorderRadius.circular(CanopyRadius.md)),
            child: Icon(Icons.eco_outlined, color: p.primaryInk, size: 32),
          ),
          const SizedBox(height: CanopySpace.s16),
          Text('Canopy connects neighbours, organisations and makers around real work in their area.',
              style: CanopyType.title.copyWith(color: p.ink, height: 1.4)),
          const SizedBox(height: CanopySpace.section),
          CanopyListGroup(children: [
            const CanopyFactRow(label: 'Piloting in', value: 'Kibera, Nairobi, with SHIELD International'),
          ]),
          const SizedBox(height: CanopySpace.section),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('articles').where('heading', isEqualTo: kAimArticleHeading).limit(3).snapshots(),
            builder: (context, snap) {
              final docs = (snap.data?.docs ?? const []).where((d) => d.data()['isPublished'] == true).toList();
              if (docs.isEmpty) return const SizedBox.shrink();
              final d = docs.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: CanopySpace.s16),
                child: CanopyListGroup(children: [
                  CanopyListRow(
                    icon: Icons.flag_outlined,
                    title: kAimArticleHeading,
                    subtitle: 'Our aim — read it, upvote and respond',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArticleViewScreen(articleId: d.id, articleData: d.data())),
                    ),
                  ),
                ]),
              );
            },
          ),
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.route_outlined,
              title: 'Roadmap',
              subtitle: "What works today and what's planned",
              onTap: () => Navigator.pushNamed(context, '/roadmap'),
            ),
            CanopyListRow(icon: Icons.rule_outlined, title: 'Community guidelines', onTap: () => Navigator.pushNamed(context, '/guidelines')),
            CanopyListRow(icon: Icons.privacy_tip_outlined, title: 'Privacy policy', onTap: () => Navigator.pushNamed(context, '/privacy')),
          ]),
        ],
      ),
    );
  }
}
