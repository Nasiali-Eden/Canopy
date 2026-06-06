import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Shared/theme/app_theme.dart';
import 'dash_widgets.dart';

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

  Future<Map<String, int>> _fetchMetrics() async {
    if (orgId == null) {
      return {'events': 0, 'programmes': 0, 'volunteers': 0, 'verified': 0};
    }

    try {
      final activitiesSnap = await firestore
          .collection('activities')
          .where('orgId', isEqualTo: orgId)
          .get();

      final programmesSnap = await firestore
          .collection('programmes')
          .where('orgId', isEqualTo: orgId)
          .get();

      final membersSnap = await firestore
          .collection('OrgMembers')
          .where('orgId', isEqualTo: orgId)
          .get();

      final verified = activitiesSnap.docs
          .where((d) => (d.data() as Map)['impactStatus'] == 'confirmed')
          .length;

      final activeProgrammes = programmesSnap.docs.where((d) {
        final s = (d.data() as Map)['status'] as String? ?? '';
        return s == 'active' || s == 'upcoming';
      }).length;

      return {
        'events': activitiesSnap.docs.length,
        'programmes': activeProgrammes,
        'volunteers': membersSnap.docs.length,
        'verified': verified,
      };
    } catch (e) {
      debugPrint('[DashMetrics] Error: $e');
      return {'events': 0, 'programmes': 0, 'volunteers': 0, 'verified': 0};
    }
  }

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
        const SizedBox(height: 12),
        FutureBuilder<Map<String, int>>(
          future: _fetchMetrics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final data = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  _MetricCard(
                    value: '${data['events']}',
                    label: 'Events run',
                    icon: Icons.event_available,
                    color: AppTheme.darkGreen,
                  ),
                  _MetricCard(
                    value: '${data['programmes']}',
                    label: 'Programmes',
                    icon: Icons.layers_outlined,
                    color: AppTheme.accent,
                  ),
                  _MetricCard(
                    value: '${data['volunteers']}',
                    label: 'Volunteers',
                    icon: Icons.volunteer_activism,
                    color: AppTheme.primary,
                  ),
                  _MetricCard(
                    value: '${data['verified']}',
                    label: 'Verified',
                    icon: Icons.verified,
                    color: AppTheme.tertiary,
                  ),
                ],
              ),
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
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
