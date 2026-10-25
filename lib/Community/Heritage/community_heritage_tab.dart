// lib/Community/Heritage/community_heritage_tab.dart
//
// Heritage home + search (HERITAGE_HANDOFF §3.1–3.2).
//
// Home: backdrop images/BG.png (470) · app bar "HERITAGE" label + glass
// search · lede (heritageTitle 30/38) · sheet: Countries — ≤3 live →
// stacked live banners; 4+ → rail of live banners — then Soon countries in a
// 2-col grid (6 shown, then a dashed "[N] more countries opening" row) ·
// Featured rail (tiles with category label; hidden when empty) · glass nav
// (owned by the shell; this tab reports scroll direction so it hides on
// scroll down).
// States: loading (skeleton banner + grid), error (callout + retry).
//
// Search: solid page, focused field, category filter chips with counts,
// results grouped by category as row cards. No results: "Nothing in the
// archive matches …" + category labels to browse.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../Culture/Heritage/Services/heritage_bundled_images.dart';
import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../theme/canopy_components.dart';
import 'category_browse_screen.dart';
import 'country_screen.dart';
import 'heritage_item_screen.dart';
import 'heritage_map_screen.dart';
import 'heritage_ui.dart';

class CommunityHeritageTab extends StatefulWidget {
  /// Reports scroll direction so the shell's glass nav hides on scroll down.
  final ValueChanged<ScrollDirection>? onScrollDirectionChanged;

  const CommunityHeritageTab({super.key, this.onScrollDirectionChanged});

  @override
  State<CommunityHeritageTab> createState() => _CommunityHeritageTabState();
}

class _CommunityHeritageTabState extends State<CommunityHeritageTab> {
  final _service = HeritageDataService();
  late Future<List<HeritageCountry>> _countries = _service.loadCountries();
  late Stream<Map<String, ({int entries, int communities})>> _stats =
      _service.streamCountryStats();
  late final Stream<List<HeritageItem>> _featured = _service.streamFeatured(limit: 40);

  void _retry() => setState(() {
        _countries = _service.loadCountries();
        _stats = _service.streamCountryStats();
      });

  void _openCountry(HeritageCountry c) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => CountryScreen(country: c)));

  void _openItem(HeritageItem i) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => HeritageItemScreen(item: i)));

  @override
  Widget build(BuildContext context) {
    return HeritageBackdropPage(
      showBack: false,
      backdropHeight: 470,
      onScrollDirection: widget.onScrollDirectionChanged,
      bottomPadding: 96, // clears the floating glass nav
      backdrop: Image.asset('images/BG.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const HeritageFallback(category: HeritageCategory.places)),
      actions: [
        GlassIconButton(
          icon: Icons.map_outlined,
          tooltip: 'Culture map',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeritageMapScreen())),
        ),
        const SizedBox(width: CanopySpace.s8),
        GlassIconButton(
          icon: Icons.search,
          tooltip: 'Search the archive',
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const HeritageSearchScreen())),
        ),
      ],
      titleBlock: Builder(builder: (context) {
        final h = context.heritage;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HERITAGE', style: CanopyType.heritageFieldLabel.copyWith(color: h.ink)),
            const SizedBox(height: CanopySpace.s8),
            Text('Every culture has its own logic, its own reason for being.',
                style: CanopyType.heritageTitle
                    .copyWith(color: h.ink, fontSize: 30, height: 38 / 30)),
          ],
        );
      }),
      sheetChildren: [
        FutureBuilder<List<HeritageCountry>>(
          future: _countries,
          builder: (context, cs) => StreamBuilder<Map<String, ({int entries, int communities})>>(
            stream: _stats,
            builder: (context, st) {
              if (cs.hasError || st.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(CanopySpace.gutter),
                  child: CanopyErrorState(
                      inline: true, title: "Couldn't load countries.", onRetry: _retry),
                );
              }
              if (!cs.hasData || !st.hasData) return const _CountriesSkeleton();
              return _Countries(
                countries: cs.data!,
                stats: st.data!,
                service: _service,
                onOpen: _openCountry,
              );
            },
          ),
        ),
        StreamBuilder<List<HeritageItem>>(
          stream: _featured,
          builder: (context, snap) => _HomeSections(
            items: snap.data ?? const <HeritageItem>[],
            onOpen: _openItem,
          ),
        ),
      ],
    );
  }
}

class _Countries extends StatelessWidget {
  final List<HeritageCountry> countries;
  final Map<String, ({int entries, int communities})> stats;
  final HeritageDataService service;
  final ValueChanged<HeritageCountry> onOpen;
  const _Countries(
      {required this.countries, required this.stats, required this.service, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final live = countries.where((c) => (stats[c.id]?.entries ?? 0) > 0).toList()
      ..sort((a, b) => (stats[b.id]!.entries).compareTo(stats[a.id]!.entries));

    Widget liveCard(HeritageCountry c, {double? width}) =>
        StreamBuilder<({String? bg, String? card})>(
          stream: service.streamNodeImages(c.id),
          builder: (_, img) => SizedBox(
            width: width,
            child: CountryCard(
              country: c,
              stats: stats[c.id],
              imageUrl: img.data?.card ?? img.data?.bg,
              onTap: () => onOpen(c),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeritageSectionHeader(title: 'Countries', accent: HeritageCategory.places.fill),
        if (live.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
            child: CheckBackLater(
                line: 'The first country pages open as organisations publish entries.'),
          )
        else if (live.length <= 3)
          for (final c in live)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s12),
              child: liveCard(c),
            )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
            child: Row(children: [
              for (final c in live) ...[
                liveCard(c, width: 280),
                const SizedBox(width: CanopySpace.s12),
              ],
            ]),
          ),
      ],
    );
  }
}

class _CountriesSkeleton extends StatelessWidget {
  const _CountriesSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s24, CanopySpace.gutter, 0),
        child: Column(children: [
          const CanopySkeleton(height: 260, radius: HeritageCardSize.radius),
          const SizedBox(height: CanopySpace.s12),
          Row(children: const [
            Expanded(child: CanopySkeleton(height: 88, radius: HeritageCardSize.radius)),
            SizedBox(width: CanopySpace.s12),
            Expanded(child: CanopySkeleton(height: 88, radius: HeritageCardSize.radius)),
          ]),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH
// ─────────────────────────────────────────────────────────────────────────────

class HeritageSearchScreen extends StatefulWidget {
  const HeritageSearchScreen({super.key});

  @override
  State<HeritageSearchScreen> createState() => _HeritageSearchScreenState();
}

class _HeritageSearchScreenState extends State<HeritageSearchScreen> {
  // Search runs over the recent public set, client-side (index-free).
  late final Stream<List<HeritageItem>> _all = HeritageDataService().streamFeatured(limit: 300);
  String _q = '';
  String? _type;

  bool _match(HeritageItem it) {
    final q = _q.toLowerCase();
    return it.title.toLowerCase().contains(q) ||
        it.description.toLowerCase().contains(q) ||
        it.tags.any((t) => t.toLowerCase().contains(q)) ||
        (it.communityName ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return HeritagePlainPage(
      title: 'Search',
      body: StreamBuilder<List<HeritageItem>>(
        stream: _all,
        builder: (context, snap) {
          final h = context.heritage;
          final matching = _q.isEmpty ? const <HeritageItem>[] : (snap.data ?? const []).where(_match).toList();
          final counts = <String, int>{};
          for (final it in matching) {
            counts[it.contentType] = (counts[it.contentType] ?? 0) + 1;
          }
          final shown = _type == null ? matching : matching.where((i) => i.contentType == _type).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: CanopySpace.s32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s4),
                child: CanopyTextField.search(
                  hint: 'Stories, food, music, places…',
                  autofocus: true,
                  onChanged: (v) => setState(() {
                    _q = v.trim();
                    _type = null;
                  }),
                ),
              ),
              if (counts.isNotEmpty)
                CanopyChipRail(chips: [
                  CanopyFilterChip(
                      label: 'All', count: matching.length, selected: _type == null,
                      onTap: () => setState(() => _type = null)),
                  for (final t in HeritageContentTypes.ordered)
                    if (counts.containsKey(t.key))
                      CanopyFilterChip(
                        label: t.label,
                        count: counts[t.key],
                        selected: _type == t.key,
                        onTap: () => setState(() => _type = t.key),
                      ),
                ]),
              if (!snap.hasData && _q.isNotEmpty)
                const Padding(
                    padding: EdgeInsets.all(CanopySpace.gutter), child: CanopyListSkeleton(rows: 3))
              else if (_q.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(CanopySpace.gutter),
                  child: Text('Search entries published by organisations across the archive.',
                      style: CanopyType.body.copyWith(color: h.inkMuted)),
                )
              else if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(CanopySpace.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nothing in the archive matches "$_q" yet.',
                          style: CanopyType.heritageSection.copyWith(color: h.ink)),
                      const SizedBox(height: CanopySpace.s16),
                      Text('BROWSE BY CATEGORY',
                          style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
                      const SizedBox(height: CanopySpace.s8),
                      Wrap(
                        spacing: CanopySpace.s16,
                        runSpacing: CanopySpace.s12,
                        children: [
                          for (final t in HeritageContentTypes.ordered)
                            InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HeritageBrowseScreen(contentType: t.key, title: t.label),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
                                child: CategoryLabel(t.label, category: t.category),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                for (final t in HeritageContentTypes.ordered)
                  if (shown.any((i) => i.contentType == t.key)) ...[
                    HeritageSectionHeader(title: t.label, accent: t.category.fill),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                      child: Column(children: [
                        for (final it in shown.where((i) => i.contentType == t.key)) ...[
                          LayoutBuilder(
                            builder: (_, c) => HeritageCard(
                              item: it,
                              shape: HeritageCardShape.row,
                              width: c.maxWidth,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => HeritageItemScreen(item: it))),
                            ),
                          ),
                          const SizedBox(height: CanopySpace.s8),
                        ],
                      ]),
                    ),
                  ],
            ],
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// HOME SECTIONS — mixed sizes, all from public entries, below the countries.
//   Featured (bento: one tall poster + two tiles) · Featured food (wide banner
//   strip) · Most discussed (one wide card, public) · Recently added (2-column
//   grid). A section with nothing to show is not rendered.
// ─────────────────────────────────────────────────────────────────────────────

class _HomeSections extends StatelessWidget {
  final List<HeritageItem> items; // newest activity first
  final ValueChanged<HeritageItem> onOpen;
  const _HomeSections({required this.items, required this.onOpen});

  static const _foodTypes = {'food_tradition', 'ingredient'};

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final h = context.heritage;

    final featured = items.take(3).toList();
    final food = items.where((i) => _foodTypes.contains(i.contentType)).take(8).toList();
    final discussed = [...items.where((i) => i.commentCount > 0)]
      ..sort((a, b) {
        final c = b.commentCount.compareTo(a.commentCount);
        return c != 0 ? c : b.viewCount.compareTo(a.viewCount);
      });
    final shownIds = {for (final i in featured) i.id};
    final recent = items.where((i) => !shownIds.contains(i.id)).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (featured.length >= 3) ...[
          HeritageSectionHeader(title: 'Featured', accent: h.inkMuted),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
            child: LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - CanopySpace.s12) / 2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeritageCard(
                      item: featured[0], shape: HeritageCardShape.poster, width: w, showCategory: true, onTap: () => onOpen(featured[0])),
                  const SizedBox(width: CanopySpace.s12),
                  Column(children: [
                    HeritageCard(
                        item: featured[1], shape: HeritageCardShape.tile, width: w, showCategory: true, onTap: () => onOpen(featured[1])),
                    const SizedBox(height: CanopySpace.s12),
                    HeritageCard(
                        item: featured[2], shape: HeritageCardShape.tile, width: w, showCategory: true, onTap: () => onOpen(featured[2])),
                  ]),
                ],
              );
            }),
          ),
        ] else if (featured.isNotEmpty) ...[
          HeritageSectionHeader(title: 'Featured', accent: h.inkMuted),
          HeritageRail(items: featured, shape: HeritageCardShape.tile, showCategory: true, onOpen: onOpen),
        ],
        if (food.isNotEmpty) ...[
          HeritageSectionHeader(title: 'Featured food', accent: HeritageCategory.food.fill),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
            child: Row(children: [
              for (final it in food) ...[
                HeritageCard(item: it, shape: HeritageCardShape.banner, width: 300, onTap: () => onOpen(it)),
                const SizedBox(width: CanopySpace.s12),
              ],
            ]),
          ),
        ],
        if (discussed.isNotEmpty) ...[
          HeritageSectionHeader(title: 'Most discussed', accent: h.inkMuted),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
            child: _MostDiscussedCard(item: discussed.first, onTap: () => onOpen(discussed.first)),
          ),
        ],
        if (recent.isNotEmpty) ...[
          HeritageSectionHeader(title: 'Recently added', accent: h.inkMuted),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
            child: LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - CanopySpace.s12) / 2;
              return Wrap(
                spacing: CanopySpace.s12,
                runSpacing: CanopySpace.s12,
                children: [
                  for (final it in recent)
                    HeritageCard(item: it, shape: HeritageCardShape.tile, width: w, showCategory: true, onTap: () => onOpen(it)),
                ],
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// The public entry people are talking about most: photo, title, a short
/// excerpt and the comment count.
class _MostDiscussedCard extends StatelessWidget {
  final HeritageItem item;
  final VoidCallback onTap;
  const _MostDiscussedCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    final cat = heritageCategoryFor(item.contentType);
    final cover = (item.coverImageUrl ?? '').isNotEmpty
        ? item.coverImageUrl
        : HeritageBundledImages.forContentType(item.contentType);
    final n = item.commentCount;
    return Semantics(
      button: true,
      label: '${item.title}, $n comments',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(HeritageGlass.radiusMedia),
                child: SizedBox(
                  width: 112,
                  height: 140,
                  child: HeritageMedia(url: cover, category: cat, icon: heritageIconFor(item.contentType)),
                ),
              ),
              const SizedBox(width: CanopySpace.s12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: CanopySpace.s4, right: CanopySpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CategoryLabel(item.contentTypeLabel, category: cat),
                      const SizedBox(height: CanopySpace.s4),
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CanopyType.heritageSection.copyWith(color: h.ink, fontSize: 20, height: 26 / 20)),
                      if (item.description.trim().isNotEmpty) ...[
                        const SizedBox(height: CanopySpace.s4),
                        Text(item.description.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: CanopyType.body.copyWith(color: h.inkMuted, height: 20 / 14)),
                      ],
                      const SizedBox(height: CanopySpace.s8),
                      Row(children: [
                        Icon(Icons.chat_bubble_outline, size: 16, color: h.ink),
                        const SizedBox(width: CanopySpace.s4 + 2),
                        Text('$n ${n == 1 ? 'comment' : 'comments'}',
                            style: CanopyType.label.copyWith(color: h.ink)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
