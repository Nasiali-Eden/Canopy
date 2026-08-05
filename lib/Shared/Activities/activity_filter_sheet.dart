import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/geo/canopy_location.dart';
import '../../Providers/location_provider.dart';
import '../theme/app_theme.dart';
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
// TYPE DISPLAY LABELS
// ─────────────────────────────────────────────────────────────────────────────

const _typeLabels = {
  'cleanup': 'Cleanup',
  'tree_planting': 'Tree Planting',
  'awareness': 'Awareness',
  'training': 'Training',
  'monitoring': 'Monitoring',
  'other': 'Other',
};

const _timeframeLabels = {
  null: 'Any Time',
  'today': 'Today',
  'this_week': 'This Week',
  'this_month': 'This Month',
};

// ─────────────────────────────────────────────────────────────────────────────
// FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class ActivityFilterSheet extends StatefulWidget {
  final ActivityFilter current;

  const ActivityFilterSheet({super.key, required this.current});

  @override
  State<ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<ActivityFilterSheet> {
  late String? _type;
  late String? _timeframe;
  late bool _showFull;
  late bool _useLocationScope;

  @override
  void initState() {
    super.initState();
    _type = widget.current.type;
    _timeframe = widget.current.timeframe;
    _showFull = widget.current.showFull;
    _useLocationScope = widget.current.useLocationScope;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text(
              'Filter Activities',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen),
            ),

            const SizedBox(height: 20),

            // ── Where section ─────────────────────────────────────────────
            // The location scope is app-wide, not per-sheet: changing it here
            // changes it on the feed and in the marketplace too. The switch is
            // embedded rather than duplicated so there is exactly one notion
            // of "where am I looking".
            _SectionLabel('Where'),
            const SizedBox(height: 6),
            const LocationSwitcher(padding: EdgeInsets.symmetric(vertical: 4)),
            SwitchListTile(
              title: const Text(
                'Limit to my location',
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _useLocationScope
                    ? 'Only activities in ${context.watch<LocationProvider>().filter.label}'
                    : 'Activities everywhere, ignoring the location switch',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGreen.withOpacity(0.55)),
              ),
              value: _useLocationScope,
              onChanged: (v) => setState(() => _useLocationScope = v),
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 12),

            // ── Type section ──────────────────────────────────────────────
            _SectionLabel('Type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All Types',
                  selected: _type == null,
                  onTap: () => setState(() => _type = null),
                ),
                ..._typeLabels.entries.map((e) => _FilterChip(
                      label: e.value,
                      selected: _type == e.key,
                      onTap: () => setState(() => _type = e.key),
                    )),
              ],
            ),

            const SizedBox(height: 20),

            // ── When section ──────────────────────────────────────────────
            _SectionLabel('When'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _timeframeLabels.entries.map((e) {
                  final val = e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: e.value,
                      selected: _timeframe == val,
                      onTap: () => setState(() => _timeframe = val),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Availability ──────────────────────────────────────────────
            _SectionLabel('Availability'),
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text(
                'Include full events',
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Show activities that have reached max capacity',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGreen.withOpacity(0.55)),
              ),
              value: _showFull,
              onChanged: (v) => setState(() => _showFull = v),
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 24),

            // ── Actions ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    ActivityFilter(
                      type: _type,
                      timeframe: _timeframe,
                      showFull: _showFull,
                      useLocationScope: _useLocationScope,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() {
                  _type = null;
                  _timeframe = null;
                  _showFull = false;
                  _useLocationScope = true;
                }),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                      color: AppTheme.darkGreen.withOpacity(0.55),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.darkGreen.withOpacity(0.55),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : AppTheme.lightGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(
                  color: AppTheme.lightGreen.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppTheme.darkGreen.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}
