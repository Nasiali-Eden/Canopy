// lib/Community/Heritage/country_screen.dart
//
// Country hub (HERITAGE_HANDOFF §3.3). Backdrop 520 → "HERITAGE · COUNTRY"
// label, name (heritageDisplay 56), "[N] entries · [N] communities · [N]
// organisations" → sheet: Communities rail (only if any), then one section
// per category IN FIXED ORDER, each in its own shape. Zero-entry categories
// are not rendered; a single entry is one full-width card; "Show all [N]"
// only when > 4.
// States: loading (skeleton rails per shape) · whole-country empty (full
// photo + scrimFull + glass "Check back later") · error.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../theme/canopy_components.dart';
import 'category_browse_screen.dart';
import 'community_screen.dart';
import 'heritage_item_screen.dart';
import 'heritage_ui.dart';

class CountryScreen extends StatefulWidget {
  final HeritageCountry country;
  const CountryScreen({super.key, required this.country});

  @override
  State<CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends State<CountryScreen> {
  final _service = HeritageDataService();
  late Stream<List<HeritageItem>> _items = _service.streamItems(countryId: widget.country.id);
  late final Stream<({String? bg, String? card})> _images =
      _service.streamNodeImages(widget.country.id);

  HeritageCountry get c => widget.country;

  void _open(HeritageItem it) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => HeritageItemScreen(item: it)));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<({String? bg, String? card})>(
      stream: _images,
      builder: (context, img) {
        final backdrop = HeritageMedia(url: img.data?.bg, category: HeritageCategory.places);
        return StreamBuilder<List<HeritageItem>>(
          stream: _items,
          builder: (context, snap) {
            if (snap.hasData && snap.data!.isEmpty) return _empty(backdrop);
            final items = snap.data ?? const <HeritageItem>[];
            return HeritageBackdropPage(
              backdropHeight: 520,
              backdrop: backdrop,
              titleBlock: _title(items),
              sheetChildren: snap.hasError
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(CanopySpace.gutter),
                        child: CanopyErrorState(
                          inline: true,
                          title: "Couldn't load ${c.name}.",
                          onRetry: () => setState(
                              () => _items = _service.streamItems(countryId: c.id)),
                        ),
                      ),
                    ]
                  : !snap.hasData
                      ? _skeleton()
                      : _sections(items),
            );
          },
        );
      },
    );
  }

  Widget _title(List<HeritageItem> items) => Builder(builder: (context) {
        final h = context.heritage;
        final communities = items.map((i) => i.communityId).whereType<String>().toSet().length;
        final orgs = items.map((i) => i.orgId).where((o) => o.isNotEmpty).toSet().length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HERITAGE · COUNTRY',
                style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
            const SizedBox(height: CanopySpace.s4),
            Text(c.name,
                style: CanopyType.heritageDisplay
                    .copyWith(color: h.ink, fontSize: 56, height: 60 / 56)),
            if (items.isNotEmpty)
              Text(
                  '${items.length} ${items.length == 1 ? 'entry' : 'entries'} · $communities ${communities == 1 ? 'community' : 'communities'} · $orgs ${orgs == 1 ? 'organisation' : 'organisations'}',
                  style: CanopyType.body.copyWith(color: h.inkMuted)),
          ],
        );
      });

  List<Widget> _skeleton() => [
        for (final cat in [HeritageCategory.communities, HeritageCategory.stories, HeritageCategory.food]) ...[
          HeritageSectionHeader(title: ' ', accent: cat.fill),
          HeritageSkeletonRail(shape: cat.shape, category: cat),
        ],
      ];

  List<Widget> _sections(List<HeritageItem> items) {
    final byType = <String, List<HeritageItem>>{};
    final comms = <String, (String, int)>{};
    for (final it in items) {
      byType.putIfAbsent(it.contentType, () => []).add(it);
      final id = it.communityId;
      if (id != null && id.isNotEmpty) {
        final prev = comms[id];
        final name = (it.communityName ?? '').trim();
        comms[id] = (name.isNotEmpty ? name : (prev?.$1 ?? id), (prev?.$2 ?? 0) + 1);
      }
    }
    final commList = comms.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.$2.compareTo(a.value.$2);
        return byCount != 0 ? byCount : a.value.$1.compareTo(b.value.$1);
      });

    return [
      if (commList.isNotEmpty) ...[
        HeritageSectionHeader(
          title: 'Communities',
          accent: HeritageCategory.communities.fill,
          count: commList.length,
          onShowAll: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CommunitiesListScreen(countryId: c.id, countryName: c.name)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
          child: Row(children: [
            for (final e in commList.take(HeritageCardSize.railPreviewMax)) ...[
              StreamBuilder<({String? bg, String? card})>(
                stream: _service.streamNodeImages(HeritageDataService.communityNodeId(e.key)),
                builder: (_, img) => CommunityBanner(
                  name: e.value.$1,
                  count: e.value.$2,
                  imageUrl: img.data?.card ?? img.data?.bg,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityDetailScreen(
                        countryId: c.id,
                        countryName: c.name,
                        communityId: e.key,
                        communityName: e.value.$1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: CanopySpace.s12),
            ],
          ]),
        ),
      ],
      for (final t in HeritageContentTypes.ordered)
        if ((byType[t.key] ?? const []).isNotEmpty) ...[
          HeritageSectionHeader(
            title: t.label,
            accent: t.category.fill,
            count: byType[t.key]!.length,
            onShowAll: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HeritageBrowseScreen(
                    countryId: c.id, countryName: c.name, contentType: t.key, title: t.label),
              ),
            ),
          ),
          HeritageRail(items: byType[t.key]!, shape: t.shape, onOpen: _open),
        ],
    ];
  }

  Widget _empty(Widget backdrop) {
    return HeritageTheme(
      child: Builder(builder: (context) {
        final h = context.heritage;
        return Scaffold(
          backgroundColor: h.base,
          body: Stack(
            fit: StackFit.expand,
            children: [
              backdrop,
              ColoredBox(color: h.scrimFull),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(CanopySpace.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context)),
                      const Spacer(),
                      Text(c.name,
                          style: CanopyType.heritageDisplay.copyWith(color: h.ink)),
                      const SizedBox(height: CanopySpace.s16),
                      CheckBackLater(
                        glass: true,
                        line:
                            "No entries from ${c.name} have been published yet. Organisations are still documenting.",
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
