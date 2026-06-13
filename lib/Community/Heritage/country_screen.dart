// lib/Community/Heritage/country_screen.dart
//
// Phase 2 — generic, data-driven Country hub (replaces the hardcoded
// _KenyaScreen). The country background image is the fixed full-screen backdrop;
// content scrolls over it to reveal, in canonical order:
//   • a Communities rail (if any community has entries)
//   • one section per content type PRESENT (≥1 public entry), each a preview
//     rail of the first items in that type's card shape + "Show all".
// No tribe list, no tabs, no hardcoded data. Empty country → glass "check back
// later". One Firestore stream feeds the whole screen (parity-safe).

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../Shared/theme/glass.dart';
import 'category_browse_screen.dart';
import 'community_screen.dart';
import 'heritage_item_screen.dart';
import 'heritage_widgets.dart';

class CountryScreen extends StatelessWidget {
  final HeritageCountry country;
  const CountryScreen({super.key, required this.country});

  String get _countryId => country.id;

  @override
  Widget build(BuildContext context) {
    final service = HeritageDataService();
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: GlassPalette.base,
      body: Stack(
        children: [
          // Fixed country backdrop; content scrolls over it.
          StreamBuilder<String?>(
            stream: service.streamNodeBg(_countryId),
            builder: (_, snap) => GlassBackground(
              imageUrl: snap.data,
              tint: GlassPalette.accent,
            ),
          ),
          SafeArea(
            bottom: false,
            child: StreamBuilder<List<HeritageItem>>(
              stream: service.streamItems(countryId: _countryId),
              builder: (context, snap) {
                // Always render every category — real cards where entries exist,
                // glassy placeholder cards where they don't — so the design is
                // represented even before content is added.
                final items = snap.data ?? const <HeritageItem>[];
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _header()),
                    ..._sections(context, items),
                    SliverToBoxAdapter(child: SizedBox(height: bottomPad + 90)),
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

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (country.flagEmoji.isNotEmpty)
            Text(country.flagEmoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 6),
          Text(
            country.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (country.nameNative.isNotEmpty &&
                  country.nameNative != country.name)
                country.nameNative,
              if (country.continent.isNotEmpty) country.continent,
            ].join(' · '),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────────────────────
  List<Widget> _sections(BuildContext context, List<HeritageItem> items) {
    // Group entries by content type and collect communities, client-side.
    final byType = <String, List<HeritageItem>>{};
    final communities = <String, _Comm>{};
    for (final it in items) {
      byType.putIfAbsent(it.contentType, () => []).add(it);
      final cid = it.communityId;
      if (cid != null && cid.isNotEmpty) {
        final name = (it.communityName ?? '').trim();
        final ex = communities[cid];
        communities[cid] = _Comm(
          id: cid,
          name: name.isNotEmpty ? name : (ex?.name ?? cid),
          count: (ex?.count ?? 0) + 1,
        );
      }
    }

    final widgets = <Widget>[];

    // Communities — always shown (placeholder chips when empty).
    final commList = communities.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    widgets.add(SliverToBoxAdapter(
      child: GlassSectionTitle(
        icon: Icons.groups_outlined,
        title: 'Communities',
        count: commList.isEmpty ? null : '${commList.length}',
        accent: HeritageContentTypes.communitiesAccent,
        onSeeAll: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunitiesListScreen(
                countryId: _countryId, countryName: country.name),
          ),
        ),
      ),
    ));
    widgets.add(SliverToBoxAdapter(child: _communitiesRail(context, commList)));

    // Every content type, in canonical order — real cards or placeholders.
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
                countryId: _countryId,
                contentType: type.key,
                title: type.label,
                subtitle: country.name,
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

  // Per-shape preview rail — at most 4 real cards; glassy placeholders if empty.
  Widget _itemRail(
      BuildContext context, HeritageContentType type, List<HeritageItem> all) {
    final has = all.isNotEmpty;
    final items = all.take(4).toList();
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
    final count = has ? items.length : 3;
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: w,
          child: has
              ? HeritageItemCard(
                  item: items[i],
                  compact: compact,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HeritageItemScreen(item: items[i]),
                    ),
                  ),
                )
              : HeritagePlaceholderCard(
                  icon: type.icon, accent: type.accent, compact: compact),
        ),
      ),
    );
  }

  Widget _communitiesRail(BuildContext context, List<_Comm> list) {
    const accent = HeritageContentTypes.communitiesAccent;
    if (list.isEmpty) {
      return SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const SizedBox(
            width: 150,
            child: HeritagePlaceholderCard(
                icon: Icons.groups_outlined, accent: accent),
          ),
        ),
      );
    }
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = list[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HeritageBrowseScreen(
                  countryId: _countryId,
                  communityId: c.id,
                  title: c.name,
                  subtitle: 'Community in ${country.name}',
                  accent: accent,
                  icon: Icons.groups_outlined,
                ),
              ),
            ),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.45)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text('${c.count} ${c.count == 1 ? 'entry' : 'entries'}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Comm {
  final String id;
  final String name;
  final int count;
  const _Comm({required this.id, required this.name, required this.count});
}
