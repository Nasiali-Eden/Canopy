import 'package:flutter/material.dart';

import '../../Models/user.dart';
import '../../Services/Community/community_service.dart';
import '../theme/app_theme.dart';
import 'activities_list.dart';
import 'create_activity.dart';

class ActivityHomeLogic {
  // Builds the floating action button for creating activities (only for organizers)
  static Widget? buildFloatingActionButton(BuildContext context, F_User? user) {
    if (user == null) return null;

    return FutureBuilder<String?>(
      future: CommunityService().getUserRole(userId: user.uid),
      builder: (context, snapshot) {
        final role = snapshot.data ?? 'Member';
        final isOrganizer = role == 'Organizer';
        if (!isOrganizer) return const SizedBox.shrink();

        return FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateActivityScreen()),
          ),
          backgroundColor: AppTheme.tertiary,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.add, size: 28),
        );
      },
    );
  }

  // The activity tab widget
  static Widget buildActivityTab() {
    return const ActivitiesListScreen(embedded: true);
  }
}
