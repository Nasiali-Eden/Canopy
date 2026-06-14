// lib/Community/Heritage/community_screen.dart
//
// Phase 3 — the "Communities" destination for a country. Lists the communities
// that actually have public entries (parity-safe; derived from entries by
// HeritageDataService), each opening a community-filtered browse. No hardcoded
// tribe list.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../Shared/theme/glass.dart';
import 'category_browse_screen.dart';
import 'heritage_item_screen.dart';
import 'heritage_widgets.dart';

class CommunitiesListScreen extends StatelessWidget {
  final String countryId;
  final String countryName;

  const CommunitiesListScreen({
    super.key,
    required this.countryId,
    required this.countryName,
  });

  static const Color _accent = HeritageContentTypes.communitiesAccent;

  @override
  Widget build(BuildContext context) {
    final service = HeritageDataService();
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: GlassPalette.base,
      body: Stack(
        children: [
          StreamBuilder<String?>(
            stream: service.streamNodeBg(countryId),
            builder: (_, snap) =>
                GlassBackground(imageUrl: snap.data, tint: _accent),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accent.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.groups_outlined,
                            size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Communities',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4)),
                            Text(countryName,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<CommunitySummary>>(
                    stream: service.streamCommunitiesForCountry(countryId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white70, strokeWidth: 2),
                        );
                      }
                      final communities =
                          snap.data ?? const <CommunitySummary>[];
                      if (communities.isEmpty) {
                        return const GlassEmptyState(
                          icon: Icons.groups_outlined,
                          title: 'No communities yet',
                          message:
                              'Community entries will appear here as soon as they\'re added.',
                        );
                      }
                      return ListView.separated(
                        padding:
                            EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 24),
                        itemCount: communities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _CommunityRow(c: communities[i], onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityDetailScreen(
                                countryId: countryId,
                                countryName: countryName,
                                communityId: communities[i].id,
                                communityName: communities[i].name,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 16,
            child: CircleGlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  final CommunitySummary c;
  final VoidCallback onTap;
  const _CommunityRow({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CommunitiesListScreen._accent.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: CommunitiesListScreen._accent.withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${c.entryCount} ${c.entryCount == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: Colors.white.withOpacity(0.5), size: 22),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY DETAIL — hero header over the community background + its entries
// ─────────────────────────────────────────────────────────────────────────────

class CommunityDetailScreen extends StatelessWidget {
  final String countryId;
  final String countryName;
  final String communityId;
  final String communityName;

  const CommunityDetailScreen({
    super.key,
    required this.countryId,
    required this.countryName,
    required this.communityId,
    required this.communityName,
  });

  static const Color _accent = HeritageContentTypes.communitiesAccent;

  @override
  Widget build(BuildContext context) {
    final service = HeritageDataService();
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: GlassPalette.base,
      body: Stack(
        children: [
          // Backdrop: community background, falling back to the country's.
          StreamBuilder<String?>(
            stream: service
                .streamNodeBg(HeritageDataService.communityNodeId(communityId)),
            builder: (_, commSnap) {
              final commBg = commSnap.data;
              if (commBg != null && commBg.isNotEmpty) {
                return GlassBackground(imageUrl: commBg, tint: _accent);
              }
              return StreamBuilder<String?>(
                stream: service.streamNodeBg(countryId),
                builder: (_, cSnap) =>
                    GlassBackground(imageUrl: cSnap.data, tint: _accent),
              );
            },
          ),
          SafeArea(
            bottom: false,
            child: StreamBuilder<List<HeritageItem>>(
              stream: service.streamItems(
                  countryId: countryId, communityId: communityId),
              builder: (context, snap) {
                final items = snap.data ?? const <HeritageItem>[];
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _hero(items.length)),
                    ..._sections(context, items),
                    SliverToBoxAdapter(child: SizedBox(height: bottomPad + 28)),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 16,
            child: CircleGlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              communityName.isNotEmpty ? communityName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  communityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count > 0
                      ? '$count ${count == 1 ? 'entry' : 'entries'} · in $countryName'
                      : 'Community in $countryName',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // One rail per content type present in this community (real cards, ≤4, +
  // "Show all"); placeholder rails for absent types so the design reads.
  List<Widget> _sections(BuildContext context, List<HeritageItem> items) {
    final byType = <String, List<HeritageItem>>{};
    for (final it in items) {
      byType.putIfAbsent(it.contentType, () => []).add(it);
    }
    final widgets = <Widget>[];
    for (final type in HeritageContentTypes.ordered) {
      final list = byType[type.key] ?? const <HeritageItem>[];
      widgets.add(SliverToBoxAdapter(
        child: GlassSectionTitle(
          icon: type.icon,
          title: type.label,
          count: list.isEmpty ? null : '${list.length}',
          accent: type.accent,
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HeritageBrowseScreen(
                countryId: countryId,
                contentType: type.key,
                communityId: communityId,
                title: '${type.label} · $communityName',
                subtitle: 'in $countryName',
                accent: type.accent,
                icon: type.icon,
              ),
            ),
          ),
        ),
      ));
      widgets.add(SliverToBoxAdapter(child: _itemRail(context, type, list)));
    }
    return widgets;
  }

  Widget _itemRail(
      BuildContext context, HeritageContentType type, List<HeritageItem> all) {
    final has = all.isNotEmpty;
    final list = all.take(4).toList();
    double w, h;
    var compact = false;
    switch (type.shape) {
      case HeritageCardShape.poster:
        w = 150;
        h = 210;
        break;
      case HeritageCardShape.banner:
        w = 280;
        h = 160;
        break;
      case HeritageCardShape.row:
        w = 240;
        h = 72;
        compact = true;
        break;
      case HeritageCardShape.tile:
        w = 150;
        h = 162;
        break;
    }
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: has ? list.length : 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: w,
          child: has
              ? HeritageItemCard(
                  item: list[i],
                  compact: compact,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HeritageItemScreen(item: list[i]),
                    ),
                  ),
                )
              : HeritagePlaceholderCard(
                  icon: type.icon, accent: type.accent, compact: compact),
        ),
      ),
    );
  }
}

