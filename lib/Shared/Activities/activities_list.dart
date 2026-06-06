import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Community/community_service.dart';
import '../theme/app_theme.dart';
import 'activity_card.dart';
import 'activity_filter_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TYPE CHIP CONFIGURATION  (new schema types)
// ─────────────────────────────────────────────────────────────────────────────

class _TypeOption {
  final String? value; // null = all
  final String label;
  final IconData icon;

  const _TypeOption({required this.value, required this.label, required this.icon});
}

const List<_TypeOption> _typeOptions = [
  _TypeOption(value: null, label: 'All', icon: Icons.grid_view_rounded),
  _TypeOption(value: 'cleanup', label: 'Cleanup', icon: Icons.delete_sweep_outlined),
  _TypeOption(value: 'tree_planting', label: 'Planting', icon: Icons.park_outlined),
  _TypeOption(value: 'awareness', label: 'Awareness', icon: Icons.campaign_outlined),
  _TypeOption(value: 'training', label: 'Training', icon: Icons.school_outlined),
  _TypeOption(value: 'monitoring', label: 'Monitoring', icon: Icons.monitor_heart_outlined),
  _TypeOption(value: 'other', label: 'Other', icon: Icons.event_outlined),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ActivitiesListScreen extends StatefulWidget {
  final bool embedded;
  final ActivityFilter filter;

  const ActivitiesListScreen({
    super.key,
    this.embedded = false,
    this.filter = const ActivityFilter(),
  });

  @override
  State<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen> {
  // Local type selection overrides filter.type from the parent AppBar filter
  late String? _localType;

  @override
  void initState() {
    super.initState();
    _localType = widget.filter.type;
  }

  @override
  void didUpdateWidget(ActivitiesListScreen old) {
    super.didUpdateWidget(old);
    // Sync local type when parent filter changes (e.g. user cleared the filter)
    if (old.filter.type != widget.filter.type) {
      setState(() => _localType = widget.filter.type);
    }
  }

  // Client-side timeframe filter applied after Firestore fetch
  List<QueryDocumentSnapshot> _applyTimeframe(List<QueryDocumentSnapshot> docs) {
    final tf = widget.filter.timeframe;
    if (tf == null) return docs;
    final now = DateTime.now();
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['scheduledAt'] as Timestamp?;
      if (ts == null) return false;
      final dt = ts.toDate();
      return switch (tf) {
        'today' => dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day,
        'this_week' =>
          dt.isAfter(now) &&
              dt.isBefore(now.add(Duration(days: 7 - now.weekday + 1))),
        'this_month' =>
          dt.year == now.year && dt.month == now.month,
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Type chip bar ──────────────────────────────────────────────
        _TypeChipBar(
          selected: _localType,
          onSelect: (v) => setState(() => _localType = v),
        ),

        // ── List ────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Firestore: activities — real-time stream of open/full upcoming activities
            stream: CommunityService().getActivitiesStream(
              type: _localType,
              includeFull: widget.filter.showFull,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _ShimmerList();
              }

              if (snap.hasError) {
                return _ErrorCard(
                  message: 'Failed to load activities. Check your connection.',
                  onRetry: () => setState(() {}),
                );
              }

              final allDocs = snap.data?.docs ?? [];
              final docs = _applyTimeframe(allDocs);

              if (docs.isEmpty) {
                return _EmptyState(hasFilter: !widget.filter.isDefault || _localType != null);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  return ActivityCard(
                    activityId: doc.id,
                    activity: doc.data() as Map<String, dynamic>,
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('Activities',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
        ),
      ),
      floatingActionButton: _OrganizerFab(user: user),
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE CHIP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TypeChipBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _TypeChipBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: _typeOptions.map((opt) {
            final isSelected = selected == opt.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(opt.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.lightGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: AppTheme.lightGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt.icon,
                        size: 13,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.darkGreen.withOpacity(0.65),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.darkGreen.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER LOADING
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: const [
        ActivityShimmerCard(),
        ActivityShimmerCard(),
        ActivityShimmerCard(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.red.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined,
                size: 40, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen.withOpacity(0.75)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter
                  ? Icons.filter_list_off_outlined
                  : Icons.event_note_outlined,
              size: 32,
              color: AppTheme.primary.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'No activities match your filters'
                : 'No upcoming activities',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Try adjusting the type or time filter'
                : 'Activities will appear here once organisers create them',
            style: TextStyle(
                fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.55)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORGANIZER FAB  (kept from original)
// ─────────────────────────────────────────────────────────────────────────────

class _OrganizerFab extends StatelessWidget {
  final F_User? user;
  const _OrganizerFab({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<String?>(
      future: CommunityService().getUserRole(userId: user!.uid),
      builder: (context, snapshot) {
        if (snapshot.data?.toLowerCase() != 'organizer') {
          return const SizedBox.shrink();
        }
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.darkGreen, AppTheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () =>
                  Navigator.pushNamed(context, '/activities/create'),
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('New Activity',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
