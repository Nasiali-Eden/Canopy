// lib/Community/Recognition/badges_screen.dart
//
// Badges (v2): earned count, then a grid of badges — earned (gold ring) and
// locked with a progress ring toward the requirement. Gold only here, on
// recognition. Computed from verified contributions and points.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Models/badge.dart' as m;
import '../../Models/contribution.dart';
import '../../Services/Impact/impact_service.dart';
import '../../Services/Recognition/recognition_service.dart';
import '../../theme/canopy_components.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  double? _progress(m.Badge b, int points, int verified) {
    if (b.earned) return null;
    if (b.requiredPoints != null && b.requiredPoints! > 0) return (points / b.requiredPoints!).clamp(0, 1).toDouble();
    if (b.requiredContributions != null && b.requiredContributions! > 0) return (verified / b.requiredContributions!).clamp(0, 1).toDouble();
    return 0;
  }

  String _need(m.Badge b, int points, int verified) {
    if (b.earned) return 'Earned';
    if (b.requiredPoints != null) return '${(b.requiredPoints! - points).clamp(0, 1 << 30)} more points';
    if (b.requiredContributions != null) {
      final n = (b.requiredContributions! - verified).clamp(0, 1 << 30);
      return '$n more verified contribution${n == 1 ? '' : 's'}';
    }
    return 'Locked';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final user = FirebaseAuth.instance.currentUser;
    final bar = canopyAppBar(context, title: 'Badges');
    if (user == null) return CanopyScaffold(appBar: bar, body: const CanopySignedOutState());
    return CanopyScaffold(
      appBar: bar,
      body: StreamBuilder<int>(
        stream: ImpactService().watchUserImpactPoints(userId: user.uid),
        builder: (context, pointsSnap) => StreamBuilder<List<Contribution>>(
          stream: ImpactService().watchUserContributions(userId: user.uid),
          builder: (context, cSnap) {
            if (pointsSnap.hasError || cSnap.hasError) return const CanopyErrorState(title: "Couldn't load your badges");
            if (!pointsSnap.hasData || !cSnap.hasData) return const Center(child: CircularProgressIndicator());
            final points = pointsSnap.data!;
            final verified = cSnap.data!.where((c) => c.isVerified).length;
            final badges = RecognitionService().computeBadges(impactPoints: points, contributionsCount: verified);
            final earned = badges.where((b) => b.earned).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
              children: [
                Text('$earned of ${badges.length}', style: CanopyType.display.copyWith(color: p.ink)),
                Text('badges earned', style: CanopyType.label.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.section),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: CanopySpace.s16,
                  crossAxisSpacing: CanopySpace.s12,
                  childAspectRatio: .62,
                  children: [
                    for (final b in badges)
                      Semantics(
                        label: '${b.title}. ${_need(b, points, verified)}',
                        child: Column(children: [
                          CanopyBadge(
                            icon: b.earned ? Icons.emoji_events_outlined : Icons.lock_outline,
                            earned: b.earned,
                            progress: _progress(b, points, verified),
                          ),
                          const SizedBox(height: CanopySpace.s8),
                          Text(b.title, textAlign: TextAlign.center, maxLines: 2, style: CanopyType.label.copyWith(color: p.ink)),
                          Text(_need(b, points, verified),
                              textAlign: TextAlign.center, maxLines: 2, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                        ]),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
