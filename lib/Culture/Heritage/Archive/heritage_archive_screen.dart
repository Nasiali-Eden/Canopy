// lib/Culture/Heritage/Archive/heritage_archive_screen.dart
//
// Archive (ARCHIVE_HANDOFF §3.1, F). Title + count → search → chips (All ·
// Drafts · types present) → ArchiveEntryRows, each showing visibility → ⋯
// opens the EntryActionsSheet: Edit content · Edit locality · Manage media ·
// Preview as a member · Change visibility (confirmed) · Delete draft (drafts
// only — published entries are sealed instead, never deleted from the app).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Create/create_entry_screen.dart';
import '../Create/edit_entry_screen.dart';
import '../Create/locality_selector_sheet.dart';
import 'heritage_post_screen.dart';
import '../Media/heritage_media_screen.dart';
import '../Models/cultural_entry.dart';
import '../Services/heritage_content_types.dart';
import '../Services/heritage_providers.dart';

class HeritageArchiveScreen extends StatefulWidget {
  final String orgId;
  final bool canEdit;
  const HeritageArchiveScreen({required this.orgId, this.canEdit = true, super.key});

  @override
  State<HeritageArchiveScreen> createState() => _HeritageArchiveScreenState();
}

class _HeritageArchiveScreenState extends State<HeritageArchiveScreen> {
  String _q = '';
  String? _filter; // null all · 'drafts' · a content type key

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HeritageEntriesProvider>().fetchEntries(widget.orgId);
    });
  }

  void _add([String? type]) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateEntryScreen(orgId: widget.orgId)));

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final prov = context.watch<HeritageEntriesProvider>();
    final all = prov.entries;
    final q = _q.toLowerCase();
    final shown = all.where((e) {
      if (_filter == 'drafts' && !e.isDraft) return false;
      if (_filter != null && _filter != 'drafts' && e.contentType != _filter) return false;
      if (q.isEmpty) return true;
      return '${e.title} ${e.description ?? ''} ${e.locality ?? ''}'.toLowerCase().contains(q);
    }).toList();
    final types = [for (final t in HeritageContentTypes.ordered) if (all.any((e) => e.contentType == t.key)) t];
    final drafts = all.where((e) => e.isDraft).length;

    return CanopyScaffold(
      body: prov.isLoading && all.isEmpty
          ? ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 5, leadingSize: 60)])
          : CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
                sliver: SliverList.list(children: [
                  Text('Archive', style: CanopyType.display.copyWith(color: p.ink)),
                  Text('${all.length - drafts} entr${all.length - drafts == 1 ? 'y' : 'ies'}${drafts > 0 ? ' · $drafts draft${drafts == 1 ? '' : 's'}' : ''}',
                      style: CanopyType.label.copyWith(color: p.inkMuted)),
                  const SizedBox(height: CanopySpace.s12),
                  CanopyTextField.search(hint: 'Search the archive', onChanged: (v) => setState(() => _q = v.trim())),
                ]),
              ),
              SliverToBoxAdapter(
                child: CanopyChipRail(chips: [
                  CanopyFilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                  if (drafts > 0) CanopyFilterChip(label: 'Drafts', count: drafts, selected: _filter == 'drafts', onTap: () => setState(() => _filter = 'drafts')),
                  for (final t in types)
                    CanopyFilterChip(label: t.label, selected: _filter == t.key, onTap: () => setState(() => _filter = _filter == t.key ? null : t.key)),
                ]),
              ),
              if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: CanopyEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Your archive is empty',
                    line: 'Record a story, a dish, a ceremony or a person who holds knowledge.',
                    actionLabel: widget.canEdit ? 'Add an entry' : null,
                    primaryAction: true,
                    onAction: widget.canEdit ? _add : null,
                  ),
                )
              else if (shown.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CanopyEmptyState(
                      icon: Icons.search_off,
                      title: _filter != null && _filter != 'drafts'
                          ? 'No ${HeritageContentTypes.labelFor(_filter!)} entries${_q.isEmpty ? '' : ' match "$_q"'}'
                          : 'Nothing matches "$_q"',
                      actionLabel: 'Clear filters',
                      onAction: () => setState(() {
                        _filter = null;
                        _q = '';
                      }),
                    ),
                    if (widget.canEdit && _filter != null && _filter != 'drafts')
                      CanopyButton(label: 'Add a ${HeritageContentTypes.labelFor(_filter!)} entry', onPressed: () => _add(_filter)),
                  ]),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
                  sliver: SliverToBoxAdapter(
                    child: CanopyCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.outline),
                          ArchiveEntryRow(
                            typeKey: shown[i].contentType,
                            community: shown[i].locality,
                            title: shown[i].title,
                            coverUrl: shown[i].imageUrl,
                            visibility: visibilityFrom(shown[i].visibility),
                            seekingContributors: shown[i].isSeekingContributors,
                            disputed: shown[i].hasActiveDispute,
                            missingLocation: !shown[i].isDraft && !shown[i].hasMapPoint,
                            onTap: shown[i].isDraft && widget.canEdit
                                ? () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => CreateEntryScreen(orgId: widget.orgId, draftId: shown[i].id)))
                                : () => widget.canEdit
                                    ? Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => HeritagePostScreen(entryId: shown[i].id, orgId: widget.orgId)))
                                    : openEntryPreview(context, shown[i].id, published: true),
                            onMore: widget.canEdit ? () => showEntryActions(context, shown[i]) : null,
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showEntryActions(BuildContext context, CulturalEntry e) async {
  final v = visibilityFrom(e.visibility);
  final action = await showCanopySheet<String>(context, builder: (ctx) {
    return CanopySheetBody(
      title: e.title.isEmpty ? 'Untitled' : e.title,
      children: [
        Row(children: [ContentTypeLabel(e.contentType), const SizedBox(width: CanopySpace.s8), VisibilityLabel(v)]),
        const SizedBox(height: CanopySpace.s12),
        CanopyListGroup(children: [
          CanopyListRow(icon: Icons.edit_outlined, title: e.isDraft ? 'Continue draft' : 'Edit content', onTap: () => Navigator.pop(ctx, 'edit')),
          CanopyListRow(icon: Icons.place_outlined, title: 'Edit locality', subtitle: e.locality, onTap: () => Navigator.pop(ctx, 'locality')),
          if (!e.isDraft) CanopyListRow(icon: Icons.photo_library_outlined, title: 'Manage media', onTap: () => Navigator.pop(ctx, 'media')),
          CanopyListRow(icon: Icons.visibility_outlined, title: 'Preview as a member', onTap: () => Navigator.pop(ctx, 'preview')),
          if (!e.isDraft) CanopyListRow(icon: Icons.shield_outlined, title: 'Change visibility', onTap: () => Navigator.pop(ctx, 'visibility')),
          if (e.isDraft)
            CanopyListRow(icon: Icons.delete_outline, title: 'Delete draft', titleColor: ctx.canopy.danger, onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
        if (!e.isDraft) ...[
          const SizedBox(height: CanopySpace.s8),
          Text('Published entries are sealed rather than deleted, so nothing disappears from a community\'s record.',
              style: CanopyType.caption.copyWith(color: ctx.canopy.inkMuted)),
        ],
      ],
    );
  });
  if (action == null || !context.mounted) return;
  final ref = FirebaseFirestore.instance.collection('cultural_entries').doc(e.id);
  switch (action) {
    case 'edit':
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => e.isDraft ? CreateEntryScreen(orgId: e.orgId, draftId: e.id) : HeritageEntryEditScreen(entryId: e.id),
      ));
    case 'locality':
      final r = await showCanopySheet<CommunitySelection>(context, tall: true, builder: (_) => const LocalitySelectorSheet());
      if (r == null) return;
      try {
        await ref.update({
          'locality.community_id': r.isUnknown ? null : r.id,
          'locality.community_name': r.isUnknown ? null : r.name,
          'locality.community_unknown': r.isUnknown,
          'updated_at': FieldValue.serverTimestamp(),
        });
        if (context.mounted) showCanopySnack(context, 'Locality updated.');
      } catch (_) {
        if (context.mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
      }
    case 'media':
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeritageMediaScreen(orgId: e.orgId, entryId: e.id, entryTitle: e.title)));
    case 'preview':
      openEntryPreview(context, e.id, published: !e.isDraft);
    case 'visibility':
      await changeEntryVisibility(context, e.id, v);
    case 'delete':
      final ok = await showCanopyConfirm(context,
          title: 'Delete this draft?', message: 'It is removed for good. This can\'t be undone.', confirmLabel: 'Delete draft', danger: true);
      if (!ok) return;
      try {
        await ref.delete();
      } catch (_) {
        if (context.mounted) showCanopySnack(context, "Couldn't delete. Try again.", error: true);
      }
  }
}

/// Selector → confirm (old → new, consent when widening) → save.
Future<void> changeEntryVisibility(BuildContext context, String entryId, ArchiveVisibility? current) async {
  final picked = await showCanopySheet<ArchiveVisibility>(context, builder: (ctx) {
    return CanopySheetBody(title: 'Who can see it?', children: [
      VisibilitySelector(value: current, onChanged: (v) => Navigator.pop(ctx, v)),
    ]);
  });
  if (picked == null || picked == current || !context.mounted) return;
  final ok = await showVisibilityConfirm(context, from: current, to: picked);
  if (!ok) return;
  try {
    await FirebaseFirestore.instance.collection('cultural_entries').doc(entryId).update({
      'visibility': visibilityKey(picked),
      'updated_at': FieldValue.serverTimestamp(),
      'last_activity_at': FieldValue.serverTimestamp(),
    });
    if (context.mounted) showCanopySnack(context, 'Now ${visibilityWord(picked).toLowerCase()}.');
  } catch (_) {
    if (context.mounted) showCanopySnack(context, "Couldn't change visibility. Try again.", error: true);
  }
}
