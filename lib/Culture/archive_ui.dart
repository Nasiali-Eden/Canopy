// lib/Culture/archive_ui.dart
//
// Cultural Archive components (ARCHIVE_HANDOFF §2). Standard workspace
// (light/dark) + Heritage category colours — the parchment theme is retired.
// Visibility is always glyph + UPPERCASE word + colour, never colour alone,
// and every change is confirmed. Content-type colours come only from
// HeritageCategory.text() (afternoon in light, dusk in dark).

import 'package:flutter/material.dart';

import '../Community/Heritage/heritage_item_screen.dart';
import '../theme/canopy_components.dart';
import 'Heritage/Services/heritage_data_service.dart';
import '../theme/tokens/archive_tokens.dart';
import 'Heritage/Services/heritage_content_types.dart';

export '../theme/tokens/archive_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VISIBILITY
// ─────────────────────────────────────────────────────────────────────────────

/// Firestore value ↔ ArchiveVisibility. Drafts are stored as 'draft' so the
/// public Heritage queries (visibility == 'public') never see them.
ArchiveVisibility? visibilityFrom(String? v) => switch (v) {
      'public' => ArchiveVisibility.public,
      'community' || 'community_only' => ArchiveVisibility.communityOnly,
      'restricted' => ArchiveVisibility.restricted,
      'sealed' => ArchiveVisibility.sealed,
      _ => null,
    };

String visibilityKey(ArchiveVisibility v) => switch (v) {
      ArchiveVisibility.public => 'public',
      ArchiveVisibility.communityOnly => 'community_only',
      ArchiveVisibility.restricted => 'restricted',
      ArchiveVisibility.sealed => 'sealed',
    };

String visibilityWord(ArchiveVisibility v) => switch (v) {
      ArchiveVisibility.public => 'Public',
      ArchiveVisibility.communityOnly => 'Community only',
      ArchiveVisibility.restricted => 'Restricted',
      ArchiveVisibility.sealed => 'Sealed',
    };

IconData visibilityIcon(ArchiveVisibility v) => switch (v) {
      ArchiveVisibility.public => Icons.visibility_outlined,
      ArchiveVisibility.communityOnly => Icons.groups_outlined,
      ArchiveVisibility.restricted => Icons.shield_outlined,
      ArchiveVisibility.sealed => Icons.lock_outline,
    };

/// Who can see it — the one-line explanation used in the selector and
/// the confirm dialog. (Wording to confirm against enforcement, §4.)
String visibilityWho(ArchiveVisibility v) => switch (v) {
      ArchiveVisibility.public => 'Anyone on Canopy can find and read it on Heritage.',
      ArchiveVisibility.communityOnly => 'Only members of the community it belongs to.',
      ArchiveVisibility.restricted => 'Only people your organisation approves. It never appears in browse.',
      ArchiveVisibility.sealed => 'Kept in the record but hidden from everyone outside your archive team.',
    };

class VisibilityLabel extends StatelessWidget {
  final ArchiveVisibility? visibility; // null = draft
  const VisibilityLabel(this.visibility, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final v = visibility;
    if (v == null) return StatusLabel('DRAFT', color: p.inkMuted, icon: Icons.edit_note);
    return StatusLabel(visibilityWord(v).toUpperCase(), color: CanopyArchive.visibilityColor(v, p), icon: visibilityIcon(v));
  }
}

/// Four option rows; selected is a 2px ink border + radio. [suggested] marks
/// the option recommended by a restriction note.
class VisibilitySelector extends StatelessWidget {
  final ArchiveVisibility? value;
  final ValueChanged<ArchiveVisibility> onChanged;
  final ArchiveVisibility? suggested;
  const VisibilitySelector({super.key, required this.value, required this.onChanged, this.suggested});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Column(children: [
      for (final v in ArchiveVisibility.values) ...[
        Semantics(
          selected: value == v,
          button: true,
          label: '${visibilityWord(v)}. ${visibilityWho(v)}',
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              side: BorderSide(color: value == v ? p.ink : p.outline, width: value == v ? 2 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              onTap: () => onChanged(v),
              child: Padding(
                padding: const EdgeInsets.all(CanopySpace.s12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CanopyRadio(selected: value == v),
                  const SizedBox(width: CanopySpace.s12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        VisibilityLabel(v),
                        if (suggested == v) ...[
                          const SizedBox(width: CanopySpace.s8),
                          StatusLabel('Suggested', color: p.inkMuted),
                        ],
                      ]),
                      const SizedBox(height: CanopySpace.s2),
                      Text(visibilityWho(v), style: CanopyType.caption.copyWith(color: p.inkMuted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: CanopySpace.s8),
      ],
    ]);
  }
}

/// "Make this entry [level]?" — old → new, consequence, and a consent
/// checkbox when access widens. Returns true to apply.
Future<bool> showVisibilityConfirm(BuildContext context, {required ArchiveVisibility? from, required ArchiveVisibility to}) async {
  final widening = from != null && to.index < from.index;
  final ok = await showCanopySheet<bool>(context, builder: (_) => _VisibilityConfirm(from: from, to: to, widening: widening));
  return ok == true;
}

class _VisibilityConfirm extends StatefulWidget {
  final ArchiveVisibility? from;
  final ArchiveVisibility to;
  final bool widening;
  const _VisibilityConfirm({required this.from, required this.to, required this.widening});

  @override
  State<_VisibilityConfirm> createState() => _VisibilityConfirmState();
}

class _VisibilityConfirmState extends State<_VisibilityConfirm> {
  bool _consent = false;

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: 'Make this entry ${visibilityWord(widget.to).toLowerCase()}?',
      children: [
        Row(children: [
          VisibilityLabel(widget.from),
          Padding(padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s8), child: Icon(Icons.arrow_forward, size: 16, color: p.inkMuted)),
          VisibilityLabel(widget.to),
        ]),
        const SizedBox(height: CanopySpace.s12),
        Text(visibilityWho(widget.to), style: CanopyType.body.copyWith(color: p.ink)),
        if (widget.widening) ...[
          const SizedBox(height: CanopySpace.s16),
          CanopyCheckRow(
            label: 'The community agreed this can be seen more widely',
            value: _consent,
            onChanged: (v) => setState(() => _consent = v),
          ),
        ],
      ],
      actions: [
        CanopyButton(
          label: 'Make it ${visibilityWord(widget.to).toLowerCase()}',
          expand: true,
          onPressed: widget.widening && !_consent ? null : () => Navigator.pop(context, true),
        ),
        CanopyButton.quiet(label: 'Keep it ${widget.from == null ? 'as is' : visibilityWord(widget.from!).toLowerCase()}', expand: true, onPressed: () => Navigator.pop(context, false)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENT TYPE
// ─────────────────────────────────────────────────────────────────────────────

Color contentTypeColor(BuildContext context, String key) {
  final t = HeritageContentTypes.byKey(key);
  final palette = HeritagePalette.of(Theme.of(context).brightness);
  return t?.category.text(palette) ?? context.canopy.inkMuted;
}

class ContentTypeLabel extends StatelessWidget {
  final String typeKey;
  final String? suffix;
  const ContentTypeLabel(this.typeKey, {super.key, this.suffix});

  @override
  Widget build(BuildContext context) {
    final label = HeritageContentTypes.labelFor(typeKey).toUpperCase();
    return Text(
      [label, if (suffix != null && suffix!.isNotEmpty) suffix!.toUpperCase()].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .4, color: contentTypeColor(context, typeKey)),
    );
  }
}

/// Category fallback for a missing cover: radial fill → deep + glyph.
class CategoryThumb extends StatelessWidget {
  final String typeKey;
  final String? url;
  final double size;
  const CategoryThumb({super.key, required this.typeKey, this.url, this.size = 60});

  @override
  Widget build(BuildContext context) {
    final t = HeritageContentTypes.byKey(typeKey);
    return ClipRRect(
      borderRadius: BorderRadius.circular(CanopyRadius.xs),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url!.isNotEmpty
            ? CanopyImage(url: url, fallbackIcon: t?.icon ?? Icons.auto_stories_outlined)
            : DecoratedBox(
                decoration: BoxDecoration(gradient: t?.category.fallback),
                child: Icon(t?.icon ?? Icons.auto_stories_outlined, color: const Color(0xB8FFFFFF), size: size * .42),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROWS & CARDS
// ─────────────────────────────────────────────────────────────────────────────

/// 60 thumb · TYPE · COMMUNITY · title · visibility + status · ⋯
class ArchiveEntryRow extends StatelessWidget {
  final String typeKey;
  final String? community;
  final String title;
  final String? coverUrl;
  final ArchiveVisibility? visibility; // null = draft
  final bool seekingContributors;
  final bool disputed;

  /// True when the entry has no pin on the culture map yet.
  final bool missingLocation;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  const ArchiveEntryRow({
    super.key,
    required this.typeKey,
    required this.title,
    this.community,
    this.coverUrl,
    this.visibility,
    this.seekingContributors = false,
    this.disputed = false,
    this.missingLocation = false,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s16, vertical: CanopySpace.s12),
        child: Row(children: [
          CategoryThumb(typeKey: typeKey, url: coverUrl),
          const SizedBox(width: CanopySpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ContentTypeLabel(typeKey, suffix: community),
              Text(title.isEmpty ? 'Untitled' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
              const SizedBox(height: CanopySpace.s2),
              LabelRow(children: [
                VisibilityLabel(visibility),
                if (visibility != null) StatusLabel('Published', color: p.success),
                if (seekingContributors) StatusLabel('Seeking contributors', color: p.info),
                if (disputed) StatusLabel('Disputed', color: p.danger),
                if (missingLocation) StatusLabel('Add a location', color: p.warning, icon: Icons.push_pin_outlined),
              ]),
            ]),
          ),
          if (onMore != null) CanopyIconButton(icon: Icons.more_horiz, tooltip: 'Actions for $title', onPressed: onMore),
        ]),
      ),
    );
  }
}

/// 1.5px warning inset field with a shield label.
class RestrictionNoteField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const RestrictionNoteField({super.key, required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      padding: const EdgeInsets.all(CanopySpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.warning, width: CanopyArchive.restrictionFieldBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_outlined, size: 16, color: p.warning),
          const SizedBox(width: CanopySpace.s4),
          Text('RESTRICTION NOTE', style: CanopyType.eyebrow.copyWith(color: p.ink)),
        ]),
        const SizedBox(height: CanopySpace.s8),
        CanopyTextField(
          hint: 'e.g. Only told by elders during initiation season',
          controller: controller,
          minLines: 2,
          maxLines: 4,
          onChanged: onChanged,
          helper: 'Shown to members under the title, verbatim.',
        ),
      ]),
    );
  }
}

/// Ink bar "Preview · not published" above real Heritage components.
class MemberPreviewBar extends StatelessWidget {
  final String text;
  const MemberPreviewBar({super.key, this.text = 'Preview · not published'});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      width: double.infinity,
      color: p.ink,
      padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter, vertical: CanopySpace.s8),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          Icon(Icons.visibility_outlined, size: 16, color: p.canvas),
          const SizedBox(width: CanopySpace.s8),
          Expanded(child: Text(text, style: CanopyType.label.copyWith(color: p.canvas))),
        ]),
      ),
    );
  }
}

/// "[Country] page is N of 8 ready" + ink progress + rows with Add.
class CompletenessCard extends StatelessWidget {
  final String country;
  final List<(String, bool, VoidCallback?)> items;
  const CompletenessCard({super.key, required this.country, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final done = items.where((i) => i.$2).length;
    return CanopyCard(
      padding: const EdgeInsets.all(CanopySpace.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$country page is $done of ${items.length} ready', style: CanopyType.subhead.copyWith(color: p.ink)),
        const SizedBox(height: CanopySpace.s8),
        CanopyProgressBar(value: items.isEmpty ? 0 : done / items.length, ink: true),
        const SizedBox(height: CanopySpace.s8),
        for (final i in items)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(children: [
              Icon(i.$2 ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: i.$2 ? p.success : p.inkFaint),
              const SizedBox(width: CanopySpace.s8),
              Expanded(child: Text(i.$1, style: CanopyType.body.copyWith(color: p.ink))),
              if (!i.$2 && i.$3 != null) CanopyButton.quiet(label: 'Add', size: CanopyButtonSize.compact, onPressed: i.$3),
            ]),
          ),
      ]),
    );
  }
}

/// Opens an entry (draft or published) in the real member Heritage screen
/// under a "Preview · not published" bar. Drafts are readable by their org.
Future<void> openEntryPreview(BuildContext context, String entryId, {bool published = false}) async {
  final item = await HeritageDataService().getItem(entryId);
  if (!context.mounted) return;
  if (item == null) {
    showCanopySnack(context, "Couldn't open the preview. Try again.", error: true);
    return;
  }
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      body: Column(children: [
        MemberPreviewBar(text: published ? 'Preview · as members see it' : 'Preview · not published'),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: HeritageItemScreen(item: item))),
      ]),
    ),
  ));
}
