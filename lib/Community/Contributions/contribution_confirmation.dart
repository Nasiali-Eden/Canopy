// lib/Community/Contributions/contribution_confirmation.dart
//
// Log Contribution confirmation (DESIGN_HANDOFF.md §3). Says what happens
// next, honestly: points are estimated and count after verification. A
// transformation project shows its month timeline and when the first
// reminder lands.

import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';
import '../Impact/impact_dashboard.dart';
import 'log_contribution.dart';

class ContributionConfirmationScreen extends StatelessWidget {
  final int points;
  final bool transformation;
  final String? linkedActivity;

  const ContributionConfirmationScreen({
    super.key,
    required this.points,
    this.transformation = false,
    this.linkedActivity,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final reminder = DateTime.now().add(const Duration(days: 30));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return CanopyScaffold(
      appBar: canopyAppBar(
        context,
        showBack: false,
        actions: [
          CanopyIconButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
        children: [
          Icon(Icons.check_circle_outline,
              size: CanopyIconSize.empty, color: p.success),
          const SizedBox(height: CanopySpace.s12),
          Text('Contribution sent',
              style: CanopyType.display.copyWith(color: p.ink)),
          const SizedBox(height: CanopySpace.s8),
          LabelRow(children: [
            StatusLabel('Pending verification', color: p.warning),
            PointsLabel(points),
          ]),
          const SizedBox(height: CanopySpace.s12),
          Text(
            linkedActivity != null
                ? '$linkedActivity\'s organisation will review it. Your $points estimated points count toward your total and the leaderboard once it\'s verified.'
                : 'Your $points estimated points count toward your total once an organisation verifies the work. Link an organisation activity next time to get it reviewed.',
            style: CanopyType.body.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: CanopySpace.section),
          CanopySectionHeader(title: 'What happens next', padding: EdgeInsets.zero),
          CanopyCard(
            child: CanopyTimeline(steps: [
              const TimelineStep('Sent',
                  line: 'Photos and details saved to your profile.',
                  state: TimelineState.done),
              TimelineStep('Verification',
                  line: linkedActivity != null
                      ? 'The organisation checks the work.'
                      : 'Waiting for an organisation to review it.',
                  state: TimelineState.now),
              if (transformation) ...[
                TimelineStep(
                    'Month 1 · ${reminder.day} ${months[reminder.month - 1]}',
                    line: "We'll remind you to add progress photos."),
                const TimelineStep('Each month after',
                    line: 'Add photos so the change over time is visible.'),
              ] else
                const TimelineStep('Points added',
                    line: 'Your total and rank update.'),
            ]),
          ),
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'View my impact',
          expand: true,
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ImpactDashboardScreen()),
          ),
        ),
        CanopyButton.quiet(
          label: 'Log another',
          expand: true,
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LogContributionScreen()),
          ),
        ),
      ]),
    );
  }
}
