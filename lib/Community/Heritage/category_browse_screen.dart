// lib/Community/Heritage/category_browse_screen.dart
//
// Category browse (HERITAGE_HANDOFF §3.5). Backdrop priority: category node →
// community node → country → plain category gradient. Title, community chips,
// removable subcategory chip, "[N] entries", 2-col grid in the category's
// shape. Empty after filters: "No [community] [category] entries yet" +
// Clear filters. Without a country (search's "browse by category") it lists
// the category across every country.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../theme/canopy_components.dart';
import 'heritage_item_screen.dart';
import 'heritage_ui.dart';

class HeritageBrowseScreen extends StatefulWidget {
  final String? countryId;
  final String? countryName;
  final String? contentType;
  final String? communityId;
  final String? communityName;
  final String? subcategory;
  final String title;

  const HeritageBrowseScreen({
    super.key,
    this.countryId,
    this.countryName,
    this.contentType,
    this.communityId,
    this.communityName,
    this.subcategory,
    required this.title,
  });

  @override
  State<HeritageBrowseScreen> createState() => _HeritageBrowseScreenState();
}

class _HeritageBrowseScreenState extends State<HeritageBrowseScreen> {
  final _service = HeritageDataService();
  late Stream<List<HeritageItem>> _items = _load();
  late String? _community = widget.communityId;
  late String? _subcategory = widget.subcategory;

  Stream<List<HeritageItem>> _load() => widget.countryId == null
      ? _service.streamItemsAnywhere(contentType: widget.contentType!)
      : _service.streamItems(countryId: widget.countryId!, contentType: widget.contentType);

  HeritageContentType? get _type =>
      widget.contentType == null ? null : HeritageContentTypes.byKey(widget.contentType!);

  @override
  Widget build(BuildContext context) {
    final cat = _type?.category ?? HeritageCategory.communities;
    final shape = _type?.shape ?? HeritageCardShape.tile;
    final countryId = widget.countryId;
    // Backdrop priority: category → community → country → plain.
    Widget backdrop = HeritageFallback(category: cat, icon: _type?.icon, iconSize: 56);
    if (countryId != null) {
      backdrop = StreamBuilder<String?>(
        stream: widget.contentType == null
            ? Stream.value(null)
            : _service.streamNodeBg(HeritageDataService.categoryNodeId(countryId, widget.contentType!)),
        builder: (_, catBg) => StreamBuilder<String?>(
          stream: widget.communityId == null
              ? Stream.value(null)
              : _service.streamNodeBg(HeritageDataService.communityNodeId(widget.communityId!)),
          builder: (_, commBg) => StreamBuilder<String?>(
            stream: _service.streamNodeBg(countryId),
            builder: (_, countryBg) {
              final url = catBg.data ?? commBg.data ?? countryBg.data;
              return url == null
                  ? HeritageFallback(category: cat, icon: _type?.icon, iconSize: 56)
                  : HeritageMedia(url: url, category: cat);
            },
          ),
        ),
      );
    }

    return StreamBuilder<List<HeritageItem>>(
      stream: _items,
      builder: (context, snap) {
        final all = snap.data ?? const <HeritageItem>[];
        final communities = <String, String>{
          for (final i in all)
            if ((i.communityId ?? '').isNotEmpty) i.communityId!: (i.communityName ?? i.communityId!),
        };
        final byCommunity =
            _community == null ? all : all.where((i) => i.communityId == _community).toList();
        final shown = _subcategory == null
            ? byCommunity
            : byCommunity.where((i) => i.typeData['subcategory'] == _subcategory).toList();
        final communityLabel = _community == null ? null : communities[_community] ?? widget.communityName;

        return HeritageBackdropPage(
          backdropHeight: 360,
          backdrop: backdrop,
          titleBlock: Builder(builder: (context) {
            final h = context.heritage;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryLabel(
                    [
                      if (widget.countryName != null) widget.countryName!,
                      if (communityLabel != null) communityLabel,
                    ].join(' · ').isEmpty
                        ? 'All countries'
                        : [
                            if (widget.countryName != null) widget.countryName!,
                            if (communityLabel != null) communityLabel,
                          ].join(' · '),
                    category: cat),
                const SizedBox(height: CanopySpace.s4),
                Text(widget.title, style: CanopyType.heritageTitle.copyWith(color: h.ink)),
                if (snap.hasData)
                  Text('${shown.length} ${shown.length == 1 ? 'entry' : 'entries'}',
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
                    title: "Couldn't load ${widget.title.toLowerCase()}.",
                    onRetry: () => setState(() => _items = _load())),
              )
            else if (!snap.hasData)
              HeritageSkeletonRail(shape: shape, category: cat)
            else ...[
              if (communities.length > 1 || _subcategory != null) ...[
                const SizedBox(height: CanopySpace.s12),
                CanopyChipRail(chips: [
                  if (_subcategory != null)
                    CanopyRemovableChip(
                        label: heritageHumanize(_subcategory!),
                        onRemove: () => setState(() => _subcategory = null)),
                  if (communities.length > 1) ...[
                    CanopyFilterChip(
                        label: 'All communities',
                        selected: _community == null,
                        onTap: () => setState(() => _community = null)),
                    for (final e in communities.entries)
                      CanopyFilterChip(
                        label: e.value,
                        selected: _community == e.key,
                        onTap: () => setState(() => _community = e.key),
                      ),
                  ],
                ]),
              ],
              const SizedBox(height: CanopySpace.s16),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                  child: CanopyEmptyState(
                    boxed: true,
                    icon: _type?.icon ?? Icons.search_off_outlined,
                    title:
                        'No ${[if (communityLabel != null) communityLabel, widget.title.toLowerCase()].join(' ')} entries yet',
                    actionLabel: _community != null || _subcategory != null ? 'Clear filters' : null,
                    onAction: _community != null || _subcategory != null
                        ? () => setState(() {
                              _community = null;
                              _subcategory = null;
                            })
                        : null,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                  child: LayoutBuilder(builder: (context, c) {
                    final cols = shape == HeritageCardShape.banner || shape == HeritageCardShape.row ? 1 : 2;
                    final w = (c.maxWidth - CanopySpace.s12 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: CanopySpace.s12,
                      runSpacing: CanopySpace.s12,
                      children: [
                        for (final it in shown)
                          HeritageCard(
                            item: it,
                            shape: shape,
                            width: w,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => HeritageItemScreen(item: it))),
                          ),
                      ],
                    );
                  }),
                ),
            ],
          ],
        );
      },
    );
  }
}
