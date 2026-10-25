// lib/Shared/Activities/activity_card.dart
//
// ActivityCard (DESIGN_HANDOFF.md §2):
//   full    — 16:9 landscape cover on top (org's image; no cover → contour
//             placeholder, same height), date block overlapping the cover's
//             bottom-left by 22 (surface bg + outline ring), labels row
//             (status · points) right of the date block, then title,
//             "Org · Place · Time", avatar stack + "N going · N spots left".
//   compact — date block left, no cover (Log Work "Earn points now", Map sheet).
//
// Also the shared activity helpers (type labels/icons, dates, capacity bar,
// skeleton) used by the list, detail and registration sheet.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Services/Community/community_service.dart';
import '../../theme/canopy_components.dart';
import 'activity_detail_screen.dart';

const _kRegistrations = 'activity_registrations';

// ─────────────────────────────────────────────────────────────────────────────
// TYPE + STATUS
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, IconData> kTypeIcons = {
  'cleanup': Icons.delete_sweep_outlined,
  'tree_planting': Icons.park_outlined,
  'awareness': Icons.campaign_outlined,
  'training': Icons.school_outlined,
  'monitoring': Icons.monitor_heart_outlined,
  'other': Icons.event_outlined,
};

const Map<String, String> kTypeLabels = {
  'cleanup': 'Clean-up',
  'tree_planting': 'Tree planting',
  'awareness': 'Awareness',
  'training': 'Training',
  'monitoring': 'Monitoring',
  'other': 'Other',
};

IconData activityTypeIcon(String type) => kTypeIcons[type] ?? Icons.event_outlined;
String activityTypeLabel(String type) => kTypeLabels[type] ?? type;

/// Status label for an activity: Live (today & open) · Upcoming · Full ·
/// Ended · Cancelled. Returns (text, colour, live-dot).
(String, Color, bool) activityStatus(CanopyPalette p, Map<String, dynamic> a) {
  final status = a['status'] as String? ?? 'open';
  if (status == 'cancelled') return ('Cancelled', p.danger, false);
  if (CommunityService.hasEnded(a) || status == 'completed') {
    return ('Ended', p.inkMuted, false);
  }
  if (status == 'full') return ('Full', p.warning, false);
  final at = (a['scheduledAt'] as Timestamp?)?.toDate();
  final now = DateTime.now();
  if (at != null &&
      at.year == now.year &&
      at.month == now.month &&
      at.day == now.day) {
    return ('Today', p.danger, true);
  }
  return ('Upcoming', p.info, false);
}

String activityLocationName(Map<String, dynamic> a) {
  final name = a['locationName'];
  if (name is String && name.trim().isNotEmpty) return name.trim();
  final loc = a['location'];
  if (loc is Map) {
    final area = loc['area'] as String? ?? '';
    final city = loc['city'] as String? ?? '';
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    return area.isNotEmpty ? area : city;
  }
  if (loc is String) return loc;
  return '';
}

// ─────────────────────────────────────────────────────────────────────────────
// DATES
// ─────────────────────────────────────────────────────────────────────────────

String formatActivityDate(Timestamp t) {
  final d = t.toDate();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final time = DateFormat('HH:mm').format(d);
  if (diff == 0) return 'Today · $time';
  if (diff == 1) return 'Tomorrow · $time';
  if (diff > 1 && diff < 7) return '${DateFormat('EEEE').format(d)} · $time';
  return '${DateFormat('d MMM').format(d)} · $time';
}

String formatActivityFullDate(Timestamp t) =>
    DateFormat('EEEE d MMMM yyyy · HH:mm').format(t.toDate());

// ─────────────────────────────────────────────────────────────────────────────
// CAPACITY
// ─────────────────────────────────────────────────────────────────────────────

/// Capacity bar — always routed through CommunityService.getCapacityStatus.
class ActivityCapacityBar extends StatelessWidget {
  final int registeredCount;
  final int maxParticipants;

  const ActivityCapacityBar({
    super.key,
    required this.registeredCount,
    required this.maxParticipants,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final s = CommunityService().getCapacityStatus(
      registeredCount: registeredCount,
      maxParticipants: maxParticipants,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!s.isUnlimited) ...[
          CanopyProgressBar(value: s.fillRatio),
          const SizedBox(height: CanopySpace.s4 + 2),
        ],
        Text(s.displayLabel,
            style: CanopyType.caption
                .copyWith(color: s.isFull ? p.warning : p.inkMuted)),
      ],
    );
  }
}

/// "N going · N spots left" (or "N going · Full" / "N going").
String activityGoingLabel(Map<String, dynamic> a) {
  final going = a['registeredCount'] as int? ?? 0;
  final max = a['maxParticipants'] as int? ?? 0;
  if (max <= 0) return '$going going';
  final left = max - going;
  return left <= 0 ? '$going going · Full' : '$going going · $left spots left';
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String activityId;
  final bool compact;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.activityId,
    this.compact = false,
  });

  void _open(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ActivityDetailScreen(activityId: activityId, activity: activity),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final type = activity['type'] as String? ?? 'other';
    final title = (activity['title'] as String?)?.trim() ?? '';
    final cover = activity['coverImageUrl'] as String?;
    final at = activity['scheduledAt'] as Timestamp?;
    final place = activityLocationName(activity);
    final org = (activity['organizerName'] as String?)?.trim() ?? '';
    final points = (activity['pointsPerCheckin'] as num?)?.toInt();
    final (statusText, statusColor, live) = activityStatus(p, activity);
    final ended = statusText == 'Ended' || statusText == 'Cancelled';

    final labels = LabelRow(children: [
      StatusLabel(statusText, color: statusColor, live: live),
      if (points != null && points > 0) PointsLabel(points),
    ]);
    final meta = [
      if (org.isNotEmpty) org,
      if (place.isNotEmpty) place,
      if (at != null) DateFormat('HH:mm').format(at.toDate()),
    ].join(' · ');

    if (compact) {
      return CanopyCard(
        onTap: () => _open(context),
        padding: const EdgeInsets.all(CanopySpace.s12),
        child: Row(
          children: [
            CanopyDateBlock(date: at?.toDate() ?? DateTime.now()),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labels,
                  const SizedBox(height: CanopySpace.s2),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                  if (meta.isNotEmpty)
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Opacity(
      opacity: ended ? 0.72 : 1,
      child: CanopyCard(
        onTap: () => _open(context),
        padding: null,
        radius: CanopyRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CanopyImage(url: cover, fallbackIcon: Icons.eco_outlined),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  CanopySpace.cardPadding, 0, CanopySpace.cardPadding, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(CanopyRadius.sm + 3),
                        border: Border.all(color: p.outline),
                        color: p.surface,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: CanopyDateBlock(date: at?.toDate() ?? DateTime.now()),
                    ),
                  ),
                  const SizedBox(width: CanopySpace.s12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: CanopySpace.s12),
                      child: Row(
                        children: [
                          Expanded(child: labels),
                          Icon(activityTypeIcon(type),
                              size: CanopyIconSize.s18, color: p.inkMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: CanopySpace.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CanopyType.heading.copyWith(color: p.ink)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: CanopySpace.s2),
                      Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CanopyType.caption.copyWith(color: p.inkMuted)),
                    ],
                    const SizedBox(height: CanopySpace.s12),
                    Row(
                      children: [
                        _GoingStack(
                            activityId: activityId,
                            total: activity['registeredCount'] as int? ?? 0),
                        Expanded(
                          child: Text(activityGoingLabel(activity),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CanopyType.caption
                                  .copyWith(color: p.inkMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to three registrants' avatars (one small read per card, cached).
class _GoingStack extends StatefulWidget {
  final String activityId;
  final int total;
  const _GoingStack({required this.activityId, required this.total});

  @override
  State<_GoingStack> createState() => _GoingStackState();
}

class _GoingStackState extends State<_GoingStack> {
  static final Map<String, List<(String?, String)>> _cache = {};
  Future<List<(String?, String)>>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.total > 0) _future = _load();
  }

  Future<List<(String?, String)>> _load() async {
    final cached = _cache[widget.activityId];
    if (cached != null) return cached;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_kRegistrations)
          .where('activityId', isEqualTo: widget.activityId)
          .limit(3)
          .get();
      final people = [
        for (final d in snap.docs)
          if (d.data()['status'] == 'registered')
            (
              d.data()['userAvatarUrl'] as String?,
              (d.data()['userName'] as String?) ?? ''
            ),
      ];
      return _cache[widget.activityId] = people;
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return const SizedBox.shrink();
    return FutureBuilder<List<(String?, String)>>(
      future: _future,
      builder: (context, snap) {
        final people = snap.data ?? const [];
        if (people.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: CanopySpace.s8),
          child: CanopyAvatarStack(
              people: people, total: widget.total, max: 3, size: 24),
        );
      },
    );
  }
}

/// Skeleton shaped like the full ActivityCard.
class ActivityShimmerCard extends StatelessWidget {
  const ActivityShimmerCard({super.key});

  @override
  Widget build(BuildContext context) => const CanopyCardSkeleton();
}
