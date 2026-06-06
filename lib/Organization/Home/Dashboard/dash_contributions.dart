import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Shared/theme/app_theme.dart';
import '../../../Community/Contributions/contribution_card.dart';
import 'dash_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashContributions — recent contributions logged by the current user
// ─────────────────────────────────────────────────────────────────────────────

class DashContributions extends StatelessWidget {
  final String? userId;

  const DashContributions({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DashSectionHeader(
            title: 'My contributions',
            actionLabel: 'View all →',
            onAction: () {},
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<QuerySnapshot>(
            // No orderBy — avoids composite index. Sort client-side.
            stream: FirebaseFirestore.instance
                .collection('contributions')
                .where('userId', isEqualTo: userId)
                .snapshots(),
            builder: (context, snapshot) {
              debugPrint(
                  '[DashContributions] state=${snapshot.connectionState} '
                  'docs=${snapshot.data?.docs.length} '
                  'error=${snapshot.error}');

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SizedBox.shrink();
              }

              if (snapshot.hasError) {
                debugPrint('[DashContributions] ERROR: ${snapshot.error}');
                return _emptyState();
              }

              final allDocs = snapshot.data?.docs ?? [];
              final sorted = List.of(allDocs)
                ..sort((a, b) {
                  final at = (a.data() as Map)['createdAt'];
                  final bt = (b.data() as Map)['createdAt'];
                  if (at is Timestamp && bt is Timestamp) {
                    return bt.compareTo(at);
                  }
                  return 0;
                });
              final visible = sorted.take(5).toList();

              if (visible.isEmpty) return _emptyState();

              return Column(
                children: visible.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ContributionCard(
                      contribution: {...data, 'id': doc.id});
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => DashEmptyCard(
        icon: Icons.volunteer_activism_outlined,
        iconColor: AppTheme.primary,
        title: 'No contributions yet',
        subtitle: 'Tap "Log Work" above to record your first one',
      );
}
