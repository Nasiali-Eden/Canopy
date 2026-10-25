// lib/Community/Heritage/heritage_item_screen.dart
//
// Item template (HERITAGE_HANDOFF §3.6) — renders ANY of the 12 content types
// from the fields present only:
//   hero (cover 440, or category fallback 340; knowledge-holder portraits
//   crop top-anchored) → labels (type · community · country) → title
//   (heritageTitle) → subcategory → restriction note (directly under the
//   title) → language switch (only languages the entry holds; remembered) →
//   long fields as paragraphs in priority order (heritageRead 18/30, 16 gap,
//   never truncated) → short fields (label/value rows) → list fields (middots)
//   → boolean badges → "Published by [organisation]" → Talk to the archive.
// Nothing depicts culture the archive doesn't hold.

import 'package:flutter/material.dart';

import '../../Culture/Heritage/Services/heritage_bundled_images.dart';
import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../theme/canopy_components.dart';
import 'archive_feedback_sheet.dart';
import 'category_browse_screen.dart';
import 'heritage_ui.dart';

class HeritageItemScreen extends StatefulWidget {
  final HeritageItem item;
  const HeritageItemScreen({super.key, required this.item});

  @override
  State<HeritageItemScreen> createState() => _HeritageItemScreenState();
}

class _HeritageItemScreenState extends State<HeritageItemScreen> {
  final _service = HeritageDataService();
  late final Stream<HeritageItem?> _live = _service.streamItem(widget.item.id);
  // "Eden from SHIELD" — the person who recorded it, then their organisation.
  late final Future<String?> _org = _service.byline(widget.item.authorUid, widget.item.orgId);
  late final Stream<List<PublicComment>> _comments = _service.streamPublicComments(widget.item.id);
  late final Future<List<HeritageCountry>> _countries = _service.loadCountries();
  String? _lang;

  // Bilingual families: base key = Original, _english, _swahili.
  static const _bilingual = ['body', 'lyrics'];
  static const _langSuffix = {'English': '_english', 'Kiswahili': '_swahili', 'Original': ''};

  // Long-text keys, in the brief's priority order.
  static const _paragraphKeys = <String>[
    'bio', 'cultural_significance', 'moral_or_meaning',
    'preparation_notes', 'technique_steps', 'construction_notes',
    'rhythm_notes', 'harvesting_knowledge', 'pattern_meaning',
    'what_is_being_lost', 'what_has_changed',
  ];

  static const _skipKeys = {'subcategory', 'restriction_note'};

  @override
  void initState() {
    super.initState();
    LanguageSwitch.load().then((v) {
      if (mounted && v != null) setState(() => _lang = v);
    });
  }

  List<String> _languagesFor(Map<String, dynamic> d, String base) => [
        for (final e in _langSuffix.entries)
          if ((d['$base${e.value}'] as String?)?.trim().isNotEmpty ?? false) e.key,
      ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HeritageItem?>(
      stream: _live,
      initialData: widget.item,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return HeritagePlainPage(
            body: const CheckBackLater(line: 'This entry is no longer public.'),
          );
        }
        return _page(item);
      },
    );
  }

  Widget _page(HeritageItem item) {
    final type = HeritageContentTypes.byKey(item.contentType);
    final cat = type?.category ?? HeritageCategory.communities;
    final hasCover = (item.coverImageUrl ?? '').isNotEmpty;
    final d = item.typeData;
    final subcategory = (d['subcategory'] as String?)?.trim();
    final restriction = (d['restriction_note'] as String?)?.trim();

    // Language switch across bilingual families present on this entry.
    final langs = <String>{
      for (final b in _bilingual) ..._languagesFor(d, b),
    }.toList()
      ..sort((a, b) => _langSuffix.keys.toList().indexOf(a).compareTo(_langSuffix.keys.toList().indexOf(b)));
    final lang = langs.contains(_lang) ? _lang! : (langs.isEmpty ? null : langs.first);

    return HeritageBackdropPage(
      backdropHeight: hasCover ? 440 : 340,
      backdrop: HeritageMedia(
        url: hasCover ? item.coverImageUrl : HeritageBundledImages.forContentType(item.contentType),
        category: cat,
        icon: hasCover ? null : type?.icon,
        alignment: item.contentType == 'person' ? Alignment.topCenter : Alignment.center,
      ),
      // On the photo (top third): chips, title, subcategory.
      titleBlock: Builder(builder: (context) {
        final h = context.heritage;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<List<HeritageCountry>>(
              future: _countries,
              builder: (_, cs) {
                final country = (cs.data ?? const <HeritageCountry>[])
                    .where((c) => c.id == item.countryId)
                    .map((c) => c.name)
                    .firstOrNull;
                return HeritageLabelRow(labels: [
                  (item.contentTypeLabel, cat),
                  if ((item.communityName ?? '').isNotEmpty) (item.communityName!, null),
                  if (country != null) (country, null),
                ]);
              },
            ),
            const SizedBox(height: CanopySpace.s8),
            Semantics(
              header: true,
              child: Text(item.title, style: CanopyType.heritageTitle.copyWith(color: h.ink)),
            ),
            if (subcategory != null && subcategory.isNotEmpty)
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HeritageBrowseScreen(
                      countryId: item.countryId.isEmpty ? null : item.countryId,
                      contentType: item.contentType,
                      subcategory: subcategory,
                      title: type?.label ?? item.contentTypeLabel,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
                  child: Text(heritageHumanize(subcategory),
                      style: CanopyType.heritageLede.copyWith(color: h.ink)),
                ),
              ),
          ],
        );
      }),
      // Everything else floats in one reading glass, restriction note first.
      sheetChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, 0),
          child: Builder(builder: (context) {
            final h = context.heritage;
            return ReadingGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (restriction != null && restriction.isNotEmpty) ...[
                    RestrictionNote(restriction),
                    const SizedBox(height: CanopySpace.s16),
                  ],
                  if (langs.length > 1) ...[
                    LanguageSwitch(
                        languages: langs, value: lang, onChanged: (l) => setState(() => _lang = l)),
                    const SizedBox(height: CanopySpace.s16),
                  ],
                  ..._body(item, lang, h),
                  const SizedBox(height: CanopySpace.s8),
                  FutureBuilder<String?>(
                    future: _org,
                    builder: (_, org) {
                      if ((org.data ?? '').isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.only(top: CanopySpace.s16),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: h.outline))),
                        child: Row(children: [
                          CanopyAvatar(name: org.data!, size: 32, org: true),
                          const SizedBox(width: CanopySpace.s12),
                          Expanded(
                            child: Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: 'RECORDED BY  ',
                                  style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
                              TextSpan(
                                  text: org.data!,
                                  style: CanopyType.bodyStrong.copyWith(color: h.ink)),
                            ])),
                          ),
                        ]),
                      );
                    },
                  ),
                  const SizedBox(height: CanopySpace.s16),
                  CanopyButton.secondary(
                    label: 'Talk to the archive',
                    expand: true,
                    onPressed: () => showArchiveFeedbackSheet(context, entryId: item.id, orgId: item.orgId, entryTitle: item.title),
                  ),
                ],
              ),
            );
          }),
        ),
        // Public discussion under the content.
        StreamBuilder<List<PublicComment>>(
          stream: _comments,
          builder: (context, snap) {
            final list = snap.data ?? const <PublicComment>[];
            if (list.isEmpty) return const SizedBox.shrink();
            final h = context.heritage;
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
              child: GlassSurface(
                radius: HeritageGlass.radiusReading,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DISCUSSION  ·  ${list.length}',
                        style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
                    for (final c in list) ...[
                      const SizedBox(height: CanopySpace.s16),
                      Text(c.name.isEmpty ? 'A member' : c.name,
                          style: CanopyType.bodyStrong.copyWith(color: h.ink)),
                      const SizedBox(height: CanopySpace.s2),
                      Text(c.body, style: CanopyType.body.copyWith(color: h.ink, height: 22 / 14)),
                      if ((c.reply ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: CanopySpace.s8),
                          child: Container(
                            padding: const EdgeInsets.only(left: CanopySpace.s12),
                            decoration: BoxDecoration(border: Border(left: BorderSide(color: h.outlineStrong, width: 2))),
                            child: Text('Archive: ${c.reply}',
                                style: CanopyType.body.copyWith(color: h.inkMuted, height: 22 / 14)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _body(HeritageItem item, String? lang, HeritagePalette h) {
    final d = item.typeData;
    final out = <Widget>[];
    Widget para(String text) => Padding(
          padding: const EdgeInsets.only(bottom: CanopySpace.s16),
          child: Text(text, style: CanopyType.heritageRead.copyWith(color: h.ink)),
        );
    Widget labelled(String label, String text) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
            const SizedBox(height: CanopySpace.s8),
            para(text),
          ],
        );

    // Description (lede) first.
    if (item.description.trim().isNotEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: CanopySpace.s16),
        child: Text(item.description.trim(), style: CanopyType.heritageLede.copyWith(color: h.inkMuted)),
      ));
    }

    // Bilingual families in the chosen language.
    final used = <String>{};
    for (final base in _bilingual) {
      final keys = [for (final s in _langSuffix.values) '$base$s'];
      used.addAll(keys);
      final key = '$base${_langSuffix[lang] ?? ''}';
      final v = (d[key] as String?)?.trim();
      final fallback = keys.map((k) => (d[k] as String?)?.trim()).firstWhere(
          (t) => t != null && t.isNotEmpty,
          orElse: () => null);
      final text = (v != null && v.isNotEmpty) ? v : fallback;
      if (text != null && text.isNotEmpty) {
        out.add(base == 'body' ? para(text) : labelled('Lyrics', text));
      }
    }

    // Long fields in priority order.
    for (final k in _paragraphKeys) {
      final v = (d[k] as String?)?.trim();
      if (v != null && v.isNotEmpty) out.add(labelled(heritageHumanize(k), v));
      used.add(k);
    }

    final shortRows = <Widget>[];
    final lists = <Widget>[];
    final badges = <Widget>[];
    d.forEach((k, v) {
      if (used.contains(k) || _skipKeys.contains(k) || v == null) return;
      if (v is bool) {
        if (v) badges.add(FieldBadge(heritageHumanize(k)));
      } else if (v is List) {
        final items = v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
        if (items.isNotEmpty) {
          lists.add(Padding(
            padding: const EdgeInsets.only(bottom: CanopySpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heritageHumanize(k).toUpperCase(),
                    style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
                const SizedBox(height: CanopySpace.s4),
                Text(items.join(' · '), style: CanopyType.body.copyWith(color: h.ink, height: 22 / 14)),
              ],
            ),
          ));
        }
      } else {
        final s = v.toString().trim();
        if (s.isEmpty) return;
        if (s.length > 140) {
          out.add(labelled(heritageHumanize(k), s));
        } else {
          shortRows.add(ShortFieldRow(label: heritageHumanize(k), value: s));
        }
      }
    });

    if (shortRows.isNotEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: CanopySpace.s16),
        child: Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: h.outline))),
          child: Column(children: shortRows),
        ),
      ));
    }
    out.addAll(lists);
    if (badges.isNotEmpty) {
      out.add(Wrap(spacing: CanopySpace.s16, runSpacing: CanopySpace.s8, children: badges));
    }
    if (item.isSeekingContributors) {
      out.add(const Padding(
        padding: EdgeInsets.only(top: CanopySpace.s16),
        child: FieldBadge('Open for contributions', icon: Icons.volunteer_activism_outlined),
      ));
    }
    if (out.isEmpty) {
      out.add(Text('Details for this entry are still being documented.',
          style: CanopyType.body.copyWith(color: h.inkMuted)));
    }
    return out;
  }
}
