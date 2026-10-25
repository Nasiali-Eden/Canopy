// lib/Culture/Heritage/Connections/heritage_connections_screen.dart
//
// Connections (ARCHIVE_HANDOFF §3.5, T). Suggested / Confirmed tabs.
// ConnectionCard: two entries (type labels) joined by a link glyph, the
// reason, and Confirm / Reject for suggestions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Models/cultural_entry.dart';
import '../Models/cultural_relation.dart';
import '../Services/archive_feedback_service.dart';
import '../Services/heritage_providers.dart';

class HeritageConnectionsScreen extends StatefulWidget {
  final String orgId;
  const HeritageConnectionsScreen({required this.orgId, super.key});

  @override
  State<HeritageConnectionsScreen> createState() => _HeritageConnectionsScreenState();
}

class _HeritageConnectionsScreenState extends State<HeritageConnectionsScreen> {
  int _tab = 0;
  Stream<List<CulturalRelation>>? _stream;

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final entries = context.watch<HeritageEntriesProvider>().entries;
    _stream ??= ArchiveFeedbackService.instance.relations(entries.map((e) => e.id).toList());
    final byId = {for (final e in entries) e.id: e};
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Connections'),
      body: StreamBuilder<List<CulturalRelation>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(title: "Couldn't load connections");
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final suggested = snap.data!.where((r) => r.status == 'suggested').toList();
          final confirmed = snap.data!.where((r) => r.status == 'confirmed').toList();
          final list = _tab == 0 ? suggested : confirmed;
          return Column(children: [
            CanopyUnderlineTabs(
              tabs: const ['Suggested', 'Confirmed'],
              index: _tab,
              badges: {0: suggested.length},
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: list.isEmpty
                  ? CanopyEmptyState(
                      icon: Icons.link,
                      title: _tab == 0 ? 'No suggestions' : 'No confirmed connections',
                      line: 'Connections link entries that belong together — a song and its ceremony, a dish and its ingredient.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: CanopySpace.s12),
                      itemBuilder: (_, i) => _card(context, list[i], byId, p),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _side(CulturalEntry? e, String fallbackId, CanopyPalette p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (e != null) ContentTypeLabel(e.contentType),
        Text(e?.title ?? 'Another archive\'s entry', maxLines: 2, overflow: TextOverflow.ellipsis, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
      ]);

  Widget _card(BuildContext context, CulturalRelation r, Map<String, CulturalEntry> byId, CanopyPalette p) {
    Future<void> set(bool confirm) async {
      try {
        await ArchiveFeedbackService.instance.setRelationStatus(r.id, confirm: confirm, orgId: widget.orgId);
      } catch (_) {
        if (context.mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
      }
    }

    return CanopyCard(
      padding: const EdgeInsets.all(CanopySpace.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _side(byId[r.fromEntryId], r.fromEntryId, p),
        Padding(padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8), child: Icon(Icons.link, color: p.inkMuted)),
        _side(byId[r.toEntryId], r.toEntryId, p),
        const SizedBox(height: CanopySpace.s8),
        Text(
          [
            r.relationshipType.replaceAll('_', ' '),
            if ((r.suggestedByName ?? '').isNotEmpty) 'suggested by ${r.suggestedByName}',
            if (r.status == 'confirmed' && (r.confirmedByName ?? '').isNotEmpty) 'confirmed by ${r.confirmedByName}',
          ].where((s) => s.isNotEmpty).join(' · '),
          style: CanopyType.caption.copyWith(color: p.inkMuted),
        ),
        if (r.status == 'suggested') ...[
          const SizedBox(height: CanopySpace.s12),
          Row(children: [
            Expanded(child: CanopyButton(label: 'Confirm', expand: true, onPressed: () => set(true))),
            const SizedBox(width: CanopySpace.s8),
            CanopyButton.quiet(label: 'Reject', onPressed: () => set(false)),
          ]),
        ],
      ]),
    );
  }
}
