// lib/Shared/Activities/activity_home_logic.dart
//
// Glue for the Activities tab inside the community shell.

import 'package:flutter/material.dart';

import '../../Models/user.dart';
import 'activities_list.dart';
import 'activity_filter_sheet.dart';

class ActivityHomeLogic {
  /// Organiser-only "New activity" FAB.
  static Widget? buildFloatingActionButton(BuildContext context, F_User? user) =>
      user == null ? null : OrganizerFab(user: user);

  static Widget buildActivityTab({ActivityFilter? filter}) {
    return ActivitiesListScreen(
      embedded: true,
      filter: filter ?? const ActivityFilter(),
    );
  }
}
