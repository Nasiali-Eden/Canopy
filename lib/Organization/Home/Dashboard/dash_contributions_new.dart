import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Shared/theme/app_theme.dart';
import '../../../Community/Contributions/contribution_card.dart';
import 'dash_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashContributions — recent contributions logged by user (simplified FutureBuilder)
// ─────────────────────────────────────────────────────────────────────────────

class DashContributions extends StatelessWidget {
  final String? userId;

  const DashContributions({super.key, required this.userId});

  Future<List<Map<String, dynamic>>> _fetchContributions() async {
    if (userId == null) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .get();

      // Sort by createdAt descending, take first 5
      final sorted = snap.docs.toList()
        ..sort((a, b) {
          final at = (a.data() as Map)['createdAt'];
          final bt = (b.data() as Map)['createdAt'];
          if (at is Timestamp && bt is Timestamp) {
            return bt.compareTo(at); // Descending
          }
          return 0;
        });

      return sorted
          .take(5)
          .map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id})
          .toList();
    } catch (e) {
      debugPrint('[DashContributions] Error: $e');
      return [];
    }
  }

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
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchContributions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final contributions = snapshot.data ?? [];

              if (contributions.isEmpty) {
                return DashEmptyCard(
                  icon: Icons.volunteer_activism_outlined,
                  iconColor: AppTheme.primary,
                  title: 'No contributions yet',
                  subtitle: 'Tap "Log Work" above to record your first one',
                );
              }

              return Column(
                children: contributions
                    .map(
                      (data) => ContributionCard(contribution: data),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
