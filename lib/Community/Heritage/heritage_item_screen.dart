// lib/Community/Heritage/heritage_item_screen.dart
//
// Phase 3 — full, data-driven view of a single cultural entry. Renders ANY of
// the 12 content types generically from `type_data` (no per-type hardcoding):
// long-text fields become paragraphs, lists become chips, true booleans become
// badges. Glassy immersive layout. Backend ⇄ frontend parity — only what the
// entry actually holds is shown.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../Shared/theme/glass.dart';

class HeritageItemScreen extends StatelessWidget {
  final HeritageItem item;
  const HeritageItemScreen({super.key, required this.item});

  HeritageContentType? get _type => HeritageContentTypes.byKey(item.contentType);
  Color get _accent => _type?.accent ?? GlassPalette.accent;

  // Long-text keys rendered as full paragraphs, in priority order.
  static const _paragraphKeys = <String>[
    'body', 'body_english', 'body_swahili',
    'bio', 'cultural_significance', 'moral_or_meaning',
    'preparation_notes', 'technique_steps', 'construction_notes',
    'rhythm_notes', 'harvesting_knowledge', 'pattern_meaning',
    'what_is_being_lost', 'what_has_changed', 'restriction_note',
    'lyrics', 'lyrics_english', 'lyrics_swahili',
  ];

  // Keys handled elsewhere / not worth surfacing as generic rows.
  static const _skipKeys = <String>{'subcategory'};

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final subcategory = item.typeData['subcategory'] as String?;

    return Scaffold(
      backgroundColor: GlassPalette.base,
      body: Stack(
        children: [
          GlassBackground(imageUrl: item.coverImageUrl, tint: _accent),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(subcategory)),
                SliverToBoxAdapter(child: _body(context)),
                SliverToBoxAdapter(child: SizedBox(height: bottomPad + 32)),
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

  Widget _header(String? subcategory) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(
                icon: _type?.icon ?? Icons.label_outline,
                label: item.contentTypeLabel,
                color: _accent,
              ),
              if (subcategory != null && subcategory.isNotEmpty) ...[
                const SizedBox(width: 8),
                _pill(label: _humanize(subcategory), color: Colors.white24),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.12,
              letterSpacing: -0.5,
            ),
          ),
          if ((item.communityName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.groups_outlined,
                    size: 14, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  item.communityName!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final rows = _buildTypeDataWidgets();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description.trim().isNotEmpty) ...[
              Text(
                item.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 14.5,
                  height: 1.6,
                ),
              ),
              if (rows.isNotEmpty)
                Divider(color: Colors.white.withOpacity(0.12), height: 28),
            ],
            ...rows,
            if (item.description.trim().isEmpty && rows.isEmpty)
              Text(
                'Details for this entry are still being documented.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 6),
            _metaRow(),
          ],
        ),
      ),
    );
  }

  /// Generic renderer for `type_data` — paragraphs, chip lists, true-booleans.
  List<Widget> _buildTypeDataWidgets() {
    final data = item.typeData;
    final widgets = <Widget>[];

    // 1) Priority long-text paragraphs.
    for (final key in _paragraphKeys) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) {
        widgets.add(_labeledParagraph(_humanize(key), v.trim()));
      }
    }

    // 2) Remaining fields in insertion order.
    final boolBadges = <String>[];
    data.forEach((key, v) {
      if (_skipKeys.contains(key) || _paragraphKeys.contains(key)) return;
      if (v == null) return;
      if (v is bool) {
        if (v) boolBadges.add(_humanize(key));
      } else if (v is List) {
        final items = v.whereType<Object>().map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
        if (items.isNotEmpty) widgets.add(_chipList(_humanize(key), items));
      } else {
        final s = v.toString().trim();
        if (s.isNotEmpty) widgets.add(_labeledLine(_humanize(key), s));
      }
    });

    if (boolBadges.isNotEmpty) widgets.add(_badges(boolBadges));
    return widgets;
  }

  // ── building blocks ──────────────────────────────────────────────────────

  Widget _labeledParagraph(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(label),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.62,
              ),
            ),
          ],
        ),
      );

  Widget _labeledLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45)),
            ),
          ],
        ),
      );

  Widget _chipList(String label, List<String> items) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _accent.withOpacity(0.4)),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _badges(List<String> labels) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels
              .map((s) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag_outlined,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 5),
                        Text(s,
                            style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _fieldLabel(String label) => Text(
        label.toUpperCase(),
        style: TextStyle(
          color: _accent.withOpacity(0.95),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      );

  Widget _metaRow() {
    final bits = <Widget>[];
    void add(IconData i, String t) => bits.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 13, color: Colors.white.withOpacity(0.45)),
            const SizedBox(width: 4),
            Text(t,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11.5)),
          ],
        ));
    if (item.viewCount > 0) add(Icons.visibility_outlined, '${item.viewCount}');
    if (item.commentCount > 0) {
      add(Icons.forum_outlined, '${item.commentCount}');
    }
    if (item.relationCount > 0) {
      add(Icons.hub_outlined, '${item.relationCount}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Wrap(spacing: 16, runSpacing: 6, children: bits),
          ),
        if (item.isSeekingContributors)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volunteer_activism_outlined,
                    size: 14, color: _accent),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'This entry is open for contributions',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pill({IconData? icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color == Colors.white24 ? color : color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  static String _humanize(String key) {
    if (key.isEmpty) return key;
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
