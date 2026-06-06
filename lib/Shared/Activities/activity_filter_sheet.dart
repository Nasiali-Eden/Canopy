import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ActivityFilter {
  final String? type;       // null = all types
  final String? timeframe;  // 'today', 'this_week', 'this_month', null = any
  final bool showFull;      // include full events

  const ActivityFilter({
    this.type,
    this.timeframe,
    this.showFull = false,
  });

  bool get isDefault => type == null && timeframe == null && !showFull;

  ActivityFilter copyWith({
    Object? type = _sentinel,
    Object? timeframe = _sentinel,
    bool? showFull,
  }) {
    return ActivityFilter(
      type: type == _sentinel ? this.type : type as String?,
      timeframe: timeframe == _sentinel ? this.timeframe : timeframe as String?,
      showFull: showFull ?? this.showFull,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ActivityFilter &&
      other.type == type &&
      other.timeframe == timeframe &&
      other.showFull == showFull;

  @override
  int get hashCode => Object.hash(type, timeframe, showFull);
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

  @override
  void initState() {
    super.initState();
    _type = widget.current.type;
    _timeframe = widget.current.timeframe;
    _showFull = widget.current.showFull;
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
