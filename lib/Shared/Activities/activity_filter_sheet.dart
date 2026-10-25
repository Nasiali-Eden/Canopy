// lib/Shared/Activities/activity_filter_sheet.dart
//
// Activities filter model + sheet (rendered inside showCanopySheet).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Providers/location_provider.dart';
import '../../theme/canopy_components.dart';
import '../widgets/location_switcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ActivityFilter {
  final String? type;       // null = all types
  final String? timeframe;  // 'today', 'this_week', 'this_month', null = any
  final bool showFull;      // include full events

  /// When true, activities are narrowed to the app-wide location scope. This
  /// dimension did not exist before — the sheet offered type and timeframe
  /// only, so a member in Kisumu saw cleanups in Mombasa with no way to say
  /// otherwise.
  final bool useLocationScope;

  const ActivityFilter({
    this.type,
    this.timeframe,
    this.showFull = false,
    this.useLocationScope = true,
  });

  bool get isDefault =>
      type == null && timeframe == null && !showFull && useLocationScope;

  ActivityFilter copyWith({
    Object? type = _sentinel,
    Object? timeframe = _sentinel,
    bool? showFull,
    bool? useLocationScope,
  }) {
    return ActivityFilter(
      type: type == _sentinel ? this.type : type as String?,
      timeframe: timeframe == _sentinel ? this.timeframe : timeframe as String?,
      showFull: showFull ?? this.showFull,
      useLocationScope: useLocationScope ?? this.useLocationScope,
    );
  }

  /// True when [location] passes this filter. Documents written before the geo
  /// migration have no canonical ids; they are KEPT rather than hidden, since
  /// silently dropping a community's existing activities would be worse than
  /// showing one that is slightly out of scope.
  bool matchesLocation(CanopyLocation location, LocationFilter scope) {
    if (!useLocationScope || scope.isEverywhere) return true;
    final wanted = scope.value;
    final field = scope.scope;
    if (wanted == null) return true;
    final actual = location.idForScope(field);
    if (actual == null) return true; // un-migrated document
    return actual == wanted;
  }

  @override
  bool operator ==(Object other) =>
      other is ActivityFilter &&
      other.type == type &&
      other.timeframe == timeframe &&
      other.showFull == showFull &&
      other.useLocationScope == useLocationScope;

  @override
  int get hashCode =>
      Object.hash(type, timeframe, showFull, useLocationScope);
}

// Sentinel for copyWith nullable params
const _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

const _typeLabels = <String?, String>{
  null: 'All types',
  'cleanup': 'Clean-up',
  'tree_planting': 'Tree planting',
  'awareness': 'Awareness',
  'training': 'Training',
  'monitoring': 'Monitoring',
  'other': 'Other',
};

const _timeframeLabels = <String?, String>{
  null: 'Any time',
  'today': 'Today',
  'this_week': 'This week',
  'this_month': 'This month',
};

class ActivityFilterSheet extends StatefulWidget {
  final ActivityFilter current;

  const ActivityFilterSheet({super.key, required this.current});

  @override
  State<ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<ActivityFilterSheet> {
  late String? _type = widget.current.type;
  late String? _timeframe = widget.current.timeframe;
  late bool _showFull = widget.current.showFull;
  late bool _useLocationScope = widget.current.useLocationScope;

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: CanopySpace.s16, bottom: CanopySpace.s4),
        child: Text(text.toUpperCase(),
            style: CanopyType.eyebrow.copyWith(color: context.canopy.inkMuted)),
      );

  @override
  Widget build(BuildContext context) {
    return CanopySheetBody(
      title: 'Filter activities',
      children: [
        // The location scope is app-wide: changing it here changes it on the
        // feed and in the marketplace too.
        _label(context, 'Where'),
        const LocationSwitcher(padding: EdgeInsets.symmetric(vertical: 4)),
        CanopySwitchRow(
          title: 'Limit to my location',
          caption: _useLocationScope
              ? 'Only activities in ${context.watch<LocationProvider>().filter.label}'
              : 'Activities everywhere',
          value: _useLocationScope,
          onChanged: (v) => setState(() => _useLocationScope = v),
        ),
        _label(context, 'Type'),
        Wrap(
          spacing: CanopySpace.s8,
          children: [
            for (final e in _typeLabels.entries)
              CanopyFilterChip(
                label: e.value,
                selected: _type == e.key,
                onTap: () => setState(() => _type = e.key),
              ),
          ],
        ),
        _label(context, 'When'),
        Wrap(
          spacing: CanopySpace.s8,
          children: [
            for (final e in _timeframeLabels.entries)
              CanopyFilterChip(
                label: e.value,
                selected: _timeframe == e.key,
                onTap: () => setState(() => _timeframe = e.key),
              ),
          ],
        ),
        _label(context, 'Availability'),
        CanopySwitchRow(
          title: 'Include full activities',
          caption: 'Show activities that have reached capacity',
          value: _showFull,
          onChanged: (v) => setState(() => _showFull = v),
        ),
      ],
      actions: [
        CanopyButton(
          label: 'Apply filters',
          expand: true,
          onPressed: () => Navigator.pop(
            context,
            ActivityFilter(
              type: _type,
              timeframe: _timeframe,
              showFull: _showFull,
              useLocationScope: _useLocationScope,
            ),
          ),
        ),
        CanopyButton.quiet(
          label: 'Clear all',
          expand: true,
          onPressed: () => setState(() {
            _type = null;
            _timeframe = null;
            _showFull = false;
            _useLocationScope = true;
          }),
        ),
      ],
    );
  }
}
