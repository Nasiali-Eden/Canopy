// lib/Organization/Explorer/programme_view_screen.dart
//
// Public programme page (ORG_HANDOFF §3.8). The same page the org previews
// ("as members see it") — ProgrammeDetail in its public mode.

import 'package:flutter/material.dart';

import '../../Models/programme.dart';
import '../Home/Programmes/programme_detail.dart';

class ProgrammeViewScreen extends StatelessWidget {
  final Programme programme;
  final String orgName;

  /// Kept for call-site compatibility; v2 pages don't tint by org accent.
  final Color? accent;

  const ProgrammeViewScreen({super.key, required this.programme, required this.orgName, this.accent});

  @override
  Widget build(BuildContext context) => ProgrammeDetail(programme: programme, orgName: orgName);
}
