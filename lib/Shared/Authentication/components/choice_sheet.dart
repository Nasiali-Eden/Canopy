// lib/Shared/Authentication/components/choice_sheet.dart
//
// A searchable single-choice sheet for long lists (counties, areas, sectors).
// Returns the picked option or null.

import 'package:flutter/material.dart';

import '../../../theme/canopy_components.dart';

Future<String?> showChoiceSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
}) {
  return showCanopySheet<String>(
    context,
    tall: true,
    builder: (_) => _ChoiceSheet(title: title, options: options, selected: selected),
  );
}

class _ChoiceSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  const _ChoiceSheet({required this.title, required this.options, this.selected});

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final list = widget.options.where((o) => o.toLowerCase().contains(_q.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s8),
          child: Align(alignment: Alignment.centerLeft, child: Text(widget.title, style: CanopyType.title.copyWith(color: p.ink))),
        ),
        if (widget.options.length > 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s8),
            child: CanopyTextField(hint: 'Search', prefixIcon: Icons.search, onChanged: (v) => setState(() => _q = v.trim())),
          ),
        Expanded(
          child: list.isEmpty
              ? CanopyEmptyState(icon: Icons.search_off, title: 'Nothing matches "$_q"')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
                  children: [
                    CanopyListGroup(children: [
                      for (final o in list)
                        CanopyListRow(
                          title: o,
                          trailing: o == widget.selected ? Icon(Icons.check, color: p.primaryInk) : null,
                          chevron: false,
                          onTap: () => Navigator.pop(context, o),
                        ),
                    ]),
                  ],
                ),
        ),
      ]),
    );
  }
}
