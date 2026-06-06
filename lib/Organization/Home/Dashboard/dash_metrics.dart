import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Shared/theme/app_theme.dart';
import 'dash_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashMetrics — Overview grid: events, programmes, volunteers, verified count
// ─────────────────────────────────────────────────────────────────────────────

class DashMetrics extends StatelessWidget {
  final String? orgId;
  final FirebaseFirestore firestore;
  final VoidCallback onViewReport;

  const DashMetrics({
    super.key,
    required this.orgId,
    required this.firestore,
    required this.onViewReport,
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
            title: 'Overview',
            actionLabel: 'Full report →',
            onAction: onViewReport,
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('activities')
              .where('orgId', isEqualTo: orgId)
              .snapshots(),
          builder: (context, actSnap) {
            final actDocs = actSnap.data?.docs ?? [];
            final totalEvents = actDocs.length;
            final verified = actDocs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['impactStatus'] ==
                    'confirmed')
                .length;

            return StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('programmes')
                  .where('orgId', isEqualTo: orgId)
                  .snapshots(),
              builder: (context, progSnap) {
                final activeProgrammes = (progSnap.data?.docs ?? []).where((d) {
                  final s = (d.data() as Map)['status'] as String? ?? '';
                  return s == 'active' || s == 'upcoming';
                }).length;

                return StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('OrgMembers')
                      .where('orgId', isEqualTo: orgId)
                      .snapshots(),
                  builder: (context, membSnap) {
                    final volunteers = membSnap.data?.docs.length ?? 0;

                    // Show loading skeleton if any stream is loading and has no data
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    value: actSnap.hasData ? '$totalEvents' : '—',
                                    label: 'Events run',
                                    icon: Icons.event_available,
                                    color: AppTheme.darkGreen,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    value: progSnap.hasData ? '$activeProgrammes' : '—',
                                    label: 'Programmes',
                                    icon: Icons.layers_outlined,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    value: membSnap.hasData ? '$volunteers' : '—',
                                    label: 'Volunteers',
                                    icon: Icons.volunteer_activism,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    value: actSnap.hasData ? '$verified' : '—',
                                    label: 'Verified',
                                    icon: Icons.verified,
                                    color: AppTheme.tertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric card tile
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -14,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color.withOpacity(0.08)),
              ),
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color.withOpacity(0.11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 10, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1,
                              letterSpacing: -1)),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, size: 13, color: color),
                      ),
                    ],
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen.withOpacity(0.55),
                          letterSpacing: 0.1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
