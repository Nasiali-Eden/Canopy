import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Shared/theme/app_theme.dart';
import 'dash_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashActivities — upcoming & ongoing events for this org
// ─────────────────────────────────────────────────────────────────────────────

class DashActivities extends StatelessWidget {
  final String? orgId;
  final FirebaseFirestore firestore;
  final VoidCallback onViewAll;
  final void Function(Map<String, dynamic>) onActivityTap;

  const DashActivities({
    super.key,
    required this.orgId,
    required this.firestore,
    required this.onViewAll,
    required this.onActivityTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DashSectionHeader(
            title: 'Upcoming & active',
            actionLabel: 'View all →',
            onAction: onViewAll,
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          // No orderBy — avoids composite index. Filter + sort client-side.
          stream: firestore
              .collection('activities')
              .where('orgId', isEqualTo: orgId)
              .snapshots(),
          builder: (context, snapshot) {
            debugPrint('[DashActivities] state=${snapshot.connectionState} '
                'docs=${snapshot.data?.docs.length} '
                'error=${snapshot.error} orgId=$orgId');
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            if (snapshot.hasError) {
              debugPrint('[DashActivities] ERROR: ${snapshot.error}');
            }
            final all = snapshot.data?.docs ?? [];
            final docs = all.where((d) {
              final s =
                  (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
              return s == 'upcoming' || s == 'ongoing';
            }).toList()
              ..sort((a, b) {
                dynamic da = (a.data() as Map)['date'];
                dynamic db = (b.data() as Map)['date'];
                DateTime? ta, tb;
                if (da is Timestamp) ta = da.toDate();
                if (db is Timestamp) tb = db.toDate();
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return ta.compareTo(tb);
              });

            final visible = docs.take(8).toList();
            if (visible.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DashEmptyCard(
                  icon: Icons.event_note_outlined,
                  iconColor: AppTheme.lightGreen,
                  title: 'No upcoming activities',
                  subtitle: 'Create an event from the Activities tab',
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: visible.indexed.map((entry) {
                  final i    = entry.$1;
                  final data = entry.$2.data() as Map<String, dynamic>;
                  return _ActivityTile(
                    activity: data,
                    imageSeed: i,
                    onTap: () => onActivityTap(data),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final int imageSeed;
  final VoidCallback onTap;
  const _ActivityTile(
      {required this.activity, required this.imageSeed, required this.onTap});

  static _DateParts _parseDate(dynamic raw) {
    if (raw == null) return const _DateParts('—', '');
    if (raw is Timestamp) {
      final dt = raw.toDate();
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return _DateParts('${dt.day}', m[dt.month - 1]);
    }
    if (raw is String && raw.isNotEmpty) {
      final p = raw.trim().split(RegExp(r'[\s/\-]+'));
      final mon =
          p.length > 1 ? (p[1].length > 3 ? p[1].substring(0, 3) : p[1]) : '';
      return _DateParts(p.isNotEmpty ? p[0] : '—', mon);
    }
    return const _DateParts('—', '');
  }

  @override
  Widget build(BuildContext context) {
    final status = activity['status'] as String? ?? 'upcoming';
    final impactStatus = activity['impactStatus'] as String? ?? 'unverified';
    final name = activity['name'] as String? ?? 'Untitled activity';
    final location = activity['location'] as String? ?? '';
    final participants = activity['participants'] as int? ?? 0;
    final maxParticipants = activity['maxParticipants'] as int? ?? 0;
    final date = _parseDate(activity['date']);
    final isOngoing = status == 'ongoing';

    late Color opColor;
    late String opLabel;
    switch (status) {
      case 'ongoing':
        opColor = AppTheme.tertiary;
        opLabel = 'Ongoing';
        break;
      case 'completed':
        opColor = AppTheme.accent;
        opLabel = 'Completed';
        break;
      default:
        opColor = AppTheme.secondary;
        opLabel = 'Upcoming';
    }

    late Color impactColor;
    late String impactLabel;
    switch (impactStatus) {
      case 'pending':
        impactColor = AppTheme.tertiary;
        impactLabel = 'Pending';
        break;
      case 'confirmed':
        impactColor = AppTheme.primary;
        impactLabel = 'Verified ✓';
        break;
      default:
        impactColor = AppTheme.lightGreen;
        impactLabel = 'Unverified';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isOngoing
              ? Border.all(color: AppTheme.tertiary.withOpacity(0.25))
              : null,
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    'https://picsum.photos/seed/${(name.hashCode.abs() % 100) + imageSeed * 7}/76/82',
                    width: 76,
                    height: 82,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, prog) => prog == null
                        ? child
                        : Container(
                            width: 76,
                            height: 82,
                            color: AppTheme.lightGreen.withOpacity(0.15)),
                    errorBuilder: (_, __, ___) => Container(
                      width: 76,
                      height: 82,
                      color: AppTheme.lightGreen.withOpacity(0.12),
                      child: Icon(Icons.eco_outlined,
                          color: AppTheme.lightGreen.withOpacity(0.5),
                          size: 26),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6)
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(date.day,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1),
                              textAlign: TextAlign.center),
                          if (date.month.isNotEmpty)
                            Text(date.month,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.8)),
                                textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 10,
                              color: AppTheme.darkGreen.withOpacity(0.38)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(location,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.darkGreen.withOpacity(0.4)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _StatusPill(
                            label: opLabel, color: opColor, filled: isOngoing),
                        const SizedBox(width: 5),
                        _StatusPill(
                            label: impactLabel,
                            color: impactColor,
                            filled: impactStatus == 'confirmed'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$participants',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          height: 1)),
                  Text('/ $maxParticipants',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.darkGreen.withOpacity(0.35),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Icon(Icons.arrow_forward_ios,
                      size: 10, color: AppTheme.lightGreen.withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateParts {
  final String day;
  final String month;
  const _DateParts(this.day, this.month);
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _StatusPill(
      {required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: filled ? Colors.transparent : color.withOpacity(0.3),
            width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
