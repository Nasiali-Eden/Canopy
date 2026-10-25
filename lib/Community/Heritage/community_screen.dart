// lib/Community/Heritage/community_screen.dart
//
// Communities list (T) + Community detail (F) — HERITAGE_HANDOFF §3.4.
//   List: rows 88 with 120 media, name, "[N] entries"; sorted by count then
//     name. Only communities that actually have public entries.
//   Detail: backdrop community photo → falls back to the country photo →
//     dark radial from the communities accent + grain + giant initial at 5%.
//     Then category chips + sections as in the hub.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../theme/canopy_components.dart';
import 'category_browse_screen.dart';
import 'heritage_item_screen.dart';
import 'heritage_ui.dart';

class CommunitiesListScreen extends StatefulWidget {
  final String countryId;
  final String countryName;
  const CommunitiesListScreen({super.key, required this.countryId, required this.countryName});

  @override
  State<CommunitiesListScreen> createState() => _CommunitiesListScreenState();
}

class _CommunitiesListScreenState extends State<CommunitiesListScreen> {
  final _service = HeritageDataService();
  late Stream<List<CommunitySummary>> _stream =
      _service.streamCommunitiesForCountry(widget.countryId);

  @override
  Widget build(BuildContext context) {
    return HeritagePlainPage(
      title: 'Communities · ${widget.countryName}',
      body: StreamBuilder<List<CommunitySummary>>(
        stream: _stream,
        builder: (context, snap) {
          final h = context.heritage;
          if (snap.hasError) {
            return CanopyErrorState(
                title: "Couldn't load communities",
                onRetry: () => setState(
                    () => _stream = _service.streamCommunitiesForCountry(widget.countryId)));
          }
          if (!snap.hasData) {
            return ListView(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              children: [
                for (var i = 0; i < 4; i++) ...[
                  const CanopySkeleton(height: 88, radius: HeritageCardSize.radius),
                  const SizedBox(height: CanopySpace.s12),
                ],
              ],
            );
          }
          final list = [...snap.data!]..sort((a, b) {
              final c = b.entryCount.compareTo(a.entryCount);
              return c != 0 ? c : a.name.compareTo(b.name);
            });
          if (list.isEmpty) {
            return CheckBackLater(
                line: 'No community in ${widget.countryName} has published entries yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: CanopySpace.s12),
            itemBuilder: (_, i) {
              final c = list[i];
              return Semantics(
                button: true,
                label: '${c.name}, ${c.entryCount} entries',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityDetailScreen(
                        countryId: widget.countryId,
                        countryName: widget.countryName,
                        communityId: c.id,
                        communityName: c.name,
                      ),
                    ),
                  ),
                  child: Container(
                    height: 88,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: h.raised,
                      borderRadius: BorderRadius.circular(HeritageCardSize.radius),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 120,
                        child: StreamBuilder<({String? bg, String? card})>(
                          stream: _service.streamNodeImages(HeritageDataService.communityNodeId(c.id)),
                          builder: (_, img) {
                            final url = img.data?.card ?? img.data?.bg;
                            return url == null
                                ? HeritageFallback(
                                    category: HeritageCategory.communities,
                                    initial: c.name.isEmpty ? null : c.name.characters.first.toUpperCase())
                                : HeritageMedia(url: url, category: HeritageCategory.communities);
                          },
                        ),
                      ),
                      const SizedBox(width: CanopySpace.s16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CanopyType.heritageCardTitle.copyWith(color: h.ink)),
                            Text('${c.entryCount} ${c.entryCount == 1 ? 'entry' : 'entries'}',
                                style: CanopyType.caption.copyWith(color: h.inkMuted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: h.inkFaint),
                      const SizedBox(width: CanopySpace.s8),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CommunityDetailScreen extends StatefulWidget {
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

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _service = HeritageDataService();
  late Stream<List<HeritageItem>> _items = _service.streamItems(
      countryId: widget.countryId, communityId: widget.communityId);
  String? _type;

  void _open(HeritageItem it) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => HeritageItemScreen(item: it)));

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.communityName.isEmpty ? null : widget.communityName.characters.first.toUpperCase();
    return StreamBuilder<({String? bg, String? card})>(
      stream: _service.streamNodeImages(HeritageDataService.communityNodeId(widget.communityId)),
      builder: (context, own) => StreamBuilder<String?>(
        stream: _service.streamNodeBg(widget.countryId),
        builder: (context, country) {
          final url = own.data?.bg ?? own.data?.card ?? country.data;
          final backdrop = url == null
              ? HeritageFallback(category: HeritageCategory.communities, initial: initial)
              : HeritageMedia(url: url, category: HeritageCategory.communities);
          return StreamBuilder<List<HeritageItem>>(
            stream: _items,
            builder: (context, snap) {
              final items = snap.data ?? const <HeritageItem>[];
              final types = [
                for (final t in HeritageContentTypes.ordered)
                  if (items.any((i) => i.contentType == t.key)) t,
              ];
              final shownTypes = _type == null ? types : types.where((t) => t.key == _type).toList();
              return HeritageBackdropPage(
                backdropHeight: 440,
                backdrop: backdrop,
                titleBlock: Builder(builder: (context) {
                  final h = context.heritage;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMMUNITY · ${widget.countryName.toUpperCase()}',
                          style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
                      const SizedBox(height: CanopySpace.s4),
                      Text(widget.communityName,
                          style: CanopyType.heritageTitle.copyWith(color: h.ink)),
                      if (snap.hasData)
                        Text('${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                            style: CanopyType.body.copyWith(color: h.inkMuted)),
                    ],
                  );
                }),
                sheetChildren: [
                  if (snap.hasError)
                    Padding(
                      padding: const EdgeInsets.all(CanopySpace.gutter),
                      child: CanopyErrorState(
                        inline: true,
                        title: "Couldn't load this community.",
                        onRetry: () => setState(() => _items = _service.streamItems(
                            countryId: widget.countryId, communityId: widget.communityId)),
                      ),
                    )
                  else if (!snap.hasData)
                    HeritageSkeletonRail(
                        shape: HeritageCardShape.tile, category: HeritageCategory.communities)
                  else if (items.isEmpty)
                    CheckBackLater(line: 'No public entries from ${widget.communityName} yet.')
                  else ...[
                    if (types.length > 1) ...[
                      const SizedBox(height: CanopySpace.s12),
                      CanopyChipRail(chips: [
                        CanopyFilterChip(
                            label: 'All',
                            selected: _type == null,
                            onTap: () => setState(() => _type = null)),
                        for (final t in types)
                          CanopyFilterChip(
                            label: t.label,
                            count: items.where((i) => i.contentType == t.key).length,
                            selected: _type == t.key,
                            onTap: () => setState(() => _type = t.key),
                          ),
                      ]),
                    ],
                    for (final t in shownTypes) ...[
                      HeritageSectionHeader(
                        title: t.label,
                        accent: t.category.fill,
                        count: items.where((i) => i.contentType == t.key).length,
                        onShowAll: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HeritageBrowseScreen(
                              countryId: widget.countryId,
                              countryName: widget.countryName,
                              contentType: t.key,
                              communityId: widget.communityId,
                              communityName: widget.communityName,
                              title: t.label,
                            ),
                          ),
                        ),
                      ),
                      HeritageRail(
                        items: items.where((i) => i.contentType == t.key).toList(),
                        shape: t.shape,
                        onOpen: _open,
                      ),
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
