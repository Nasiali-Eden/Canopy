// lib/Community/Recognition/acknowledgements.dart
//
// Milestones (v2): steps reached from contributions you have logged, with how
// many are verified. Counts come from your own records only.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Models/contribution.dart';
import '../../Services/Impact/impact_service.dart';
import '../../theme/canopy_components.dart';

class AcknowledgementsScreen extends StatelessWidget {
  const AcknowledgementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final user = FirebaseAuth.instance.currentUser;
    final bar = canopyAppBar(context, title: 'Milestones');
    if (user == null) return CanopyScaffold(appBar: bar, body: const CanopySignedOutState());
    return CanopyScaffold(
      appBar: bar,
      body: StreamBuilder<List<Contribution>>(
        stream: ImpactService().watchUserContributions(userId: user.uid),
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(title: "Couldn't load your milestones");
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          final verified = list.where((c) => c.isVerified).length;
          final steps = <(String, String, bool)>[
            ('Joined', 'You joined Canopy and accepted the guidelines.', true),
            ('First contribution', 'You logged your first contribution.', list.isNotEmpty),
            ('First verified', 'An organisation verified one of your contributions.', verified >= 1),
            ('5 contributions', 'Five contributions logged.', list.length >= 5),
            ('10 contributions', 'Ten contributions logged.', list.length >= 10),
            ('10 verified', 'Ten contributions verified by organisations.', verified >= 10),
          ];
          final reached = steps.where((s) => s.$3).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
            children: [
              Text('$reached of ${steps.length}', style: CanopyType.display.copyWith(color: p.ink)),
              Text('milestones reached · ${list.length} logged, $verified verified',
                  style: CanopyType.label.copyWith(color: p.inkMuted)),
              const SizedBox(height: CanopySpace.section),
              CanopyListGroup(children: [
                for (final s in steps)
                  CanopyListRow(
                    leading: Icon(s.$3 ? Icons.check_circle : Icons.radio_button_unchecked, color: s.$3 ? p.success : p.inkFaint),
                    title: s.$1,
                    subtitle: s.$2,
                    trailing: s.$3 ? null : StatusLabel('Not yet', color: p.inkMuted),
                    chevron: false,
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
