import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';

import '../../Models/badge.dart';
import '../../Models/contribution.dart';
import '../../Models/user.dart';
import '../../Services/Impact/impact_service.dart';
import '../../Services/Recognition/recognition_service.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Badges')),
        body: const Center(child: Text('Sign in to view your badges')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Badges')),
      body: StreamBuilder<int>(
        stream: ImpactService().watchUserImpactPoints(userId: user.uid),
        builder: (context, pointsSnap) {
          final points = pointsSnap.data ?? 0;

          return StreamBuilder<List<Contribution>>(
            stream: ImpactService().watchUserContributions(userId: user.uid),
            builder: (context, contribSnap) {
              final contribs = contribSnap.data ?? const [];
              final badges = RecognitionService().computeBadges(
                impactPoints: points,
                contributionsCount: contribs.where((c) => c.isVerified).length,
              );

              final earned = badges.where((b) => b.earned).toList();
              final locked = badges.where((b) => !b.earned).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recognition',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${earned.length}/${badges.length} badges earned',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Earned',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (earned.isEmpty)
                    Text(
                      'No badges yet. Log a contribution to get started.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...earned.map((b) => _BadgeTile(badge: b)),
                  const SizedBox(height: 18),
                  Text(
                    'Next Badges',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...locked.map((b) => _BadgeTile(badge: b)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Badge badge;

  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: badge.earned
              ? colorScheme.primary.withAlpha((0.12 * 255).toInt())
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            badge.earned ? Icons.emoji_events : Icons.lock_outline,
            color: badge.earned
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(badge.title),
        subtitle: Text(badge.description),
        trailing: badge.earned
            ? const Icon(Icons.check_circle_outline)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
