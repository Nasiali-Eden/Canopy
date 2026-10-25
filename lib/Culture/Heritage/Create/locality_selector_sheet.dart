// lib/Culture/Heritage/Create/locality_selector_sheet.dart
//
// Community picker (ARCHIVE_HANDOFF §2 LocalitySheet). Searches the
// heritage_hierarchy communities (names and variants). Returns the chosen
// community, CommunitySelection.unknown when the person can't say, or null
// when the sheet is dismissed — dismissing never changes the entry.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';

class CommunitySelection {
  final String id;
  final String name;

  const CommunitySelection({required this.id, required this.name});

  static const unknown = CommunitySelection(id: '', name: '');
  bool get isUnknown => id.isEmpty;
}

class LocalitySelectorSheet extends StatefulWidget {
  const LocalitySelectorSheet({super.key});

  @override
  State<LocalitySelectorSheet> createState() => _LocalitySelectorSheetState();
}

class _Community {
  final String id;
  final String name;
  final List<String> variants;
  const _Community(this.id, this.name, this.variants);
}

class _LocalitySelectorSheetState extends State<LocalitySelectorSheet> {
  String _q = '';
  late Future<List<_Community>> _all = _load();

  // Single equality filter; ordered client-side (index-free).
  Future<List<_Community>> _load() async {
    final snap = await FirebaseFirestore.instance.collection('heritage_hierarchy').where('node_type', isEqualTo: 'community').get();
    return snap.docs
        .map((d) => _Community(d.id, (d.data()['name'] as String?) ?? d.id, (d.data()['name_variants'] as List?)?.cast<String>() ?? const []))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: 'Community',
      caption: 'Kenya',
      children: [
        CanopyTextField.search(hint: 'Search communities and other names', autofocus: true, onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
        const SizedBox(height: CanopySpace.s12),
        FutureBuilder<List<_Community>>(
          future: _all,
          builder: (context, snap) {
            if (snap.hasError) {
              return CanopyErrorState(inline: true, title: "Couldn't load communities.", onRetry: () => setState(() => _all = _load()));
            }
            if (!snap.hasData) return const CanopyListSkeleton(rows: 5);
            final list = snap.data!
                .where((c) => _q.isEmpty || c.name.toLowerCase().contains(_q) || c.variants.any((v) => v.toLowerCase().contains(_q)))
                .take(80)
                .toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: CanopySpace.s12),
                  child: Text('No community matches "$_q".', style: CanopyType.body.copyWith(color: p.inkMuted)),
                )
              else
                CanopyListGroup(children: [
                  for (final c in list)
                    CanopyListRow(
                      title: c.name,
                      subtitle: c.variants.isEmpty ? null : 'Also: ${c.variants.take(3).join(', ')}',
                      chevron: false,
                      onTap: () => Navigator.pop(context, CommunitySelection(id: c.id, name: c.name)),
                    ),
                ]),
              const SizedBox(height: CanopySpace.s12),
              CanopyButton.quiet(
                label: "I can't say which community",
                expand: true,
                onPressed: () => Navigator.pop(context, CommunitySelection.unknown),
              ),
            ]);
          },
        ),
      ],
    );
  }
}
