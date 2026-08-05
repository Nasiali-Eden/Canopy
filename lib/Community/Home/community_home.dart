// lib/Community/Home/community_home.dart
//
// Routing-only shell for the Community experience: it owns the bottom nav and
// switches between the five tabs (Home / Activities / Map / Heritage / Profile).
// The Home tab UI lives in home_feed.dart; other tabs are their own screens.
// The nav bar mirrors the Organization shell (org_home.dart).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/widgets/canopy_bottom_bar.dart';
import '../../Shared/widgets/location_switcher.dart';
import '../../Shared/Activities/activity_home_logic.dart';
import '../../Shared/Activities/activity_filter_sheet.dart';
import '../../Services/Contributions/contribution_service.dart';
import '../Heritage/community_heritage_tab.dart';
import '../Profile/profile_screen.dart';
import '../Map/map.dart';
import '../Map/org_logo_cache.dart';
import '../Announcements/announcements_tab.dart';
import '../Articles/articles_list_screen.dart';
import '../Contributions/all_contributions_screen.dart';
import 'home_feed.dart';

// Keep `timeAgo` importable from this file for sibling screens that already do
// `import '../Home/community_home.dart' show timeAgo;`.
export 'home_feed.dart' show timeAgo;

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SHELL
// ─────────────────────────────────────────────────────────────────────────────

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  int _index = 0;
  bool _remindersChecked = false;
  ActivityFilter _activityFilter = const ActivityFilter();

  static const _destinations = [
    CanopyNavDestination(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home'),
    CanopyNavDestination(
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note_rounded,
        label: 'Activities'),
    CanopyNavDestination(
        icon: Icons.map_outlined,
        activeIcon: Icons.map_rounded,
        label: 'Map'),
    CanopyNavDestination(
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories_rounded,
        label: 'Heritage'),
    CanopyNavDestination(
        icon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    // Warm org logo images now (post-auth) so the Map tab's markers are ready.
    // No-op if the app-start warm-up already succeeded.
    OrgLogoCache.instance.warmUp();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Work logging will be available soon'),
        backgroundColor: AppTheme.darkGreen,
      ),
    );
  }

  AppBar _buildActivitiesAppBar(BuildContext context) {
    final hasFilter = !_activityFilter.isDefault;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      toolbarHeight: 62,
      centerTitle: true,
      title: const Text(
        'Activities',
        style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18),
      ),
      actions: [
        IconButton(
          onPressed: () async {
            final result = await showModalBottomSheet<ActivityFilter>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ActivityFilterSheet(current: _activityFilter),
            );
            if (result != null && mounted) {
              setState(() => _activityFilter = result);
            }
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: hasFilter
                      ? AppTheme.primary.withOpacity(0.12)
                      : AppTheme.lightGreen.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.tune_outlined,
                    color: hasFilter ? AppTheme.primary : AppTheme.darkGreen,
                    size: 20),
              ),
              if (hasFilter)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.tertiary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child:
            Container(height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    // Client-side transformation reminder check (this project has no backend
    // cron). Runs once per session, fire-and-forget, after auth resolves.
    if (user != null && !_remindersChecked) {
      _remindersChecked = true;
      ContributionService()
          .processDueTransformationReminders(userId: user.uid);
    }

    final pages = [
      HomeFeed(
        userId: user?.uid,
        onJoinActivity: () => setState(() => _index = 1),
        onLogContributionComingSoon: _showComingSoon,
        onViewAnnouncements: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
        ),
        onViewAllArticles: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArticlesListScreen()),
        ),
        onViewAllContributions: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AllContributionsScreen(userId: user?.uid)),
        ),
      ),
      ActivityHomeLogic.buildActivityTab(filter: _activityFilter),
      const MapScreen(),
      const CommunityHeritageTab(),
      const ProfileScreen(),
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _index == 1 ? _buildActivitiesAppBar(context) : null,
        body: IndexedStack(index: _index, children: pages),
        floatingActionButton: _index == 1
            ? ActivityHomeLogic.buildFloatingActionButton(context, user)
            : null,
        bottomNavigationBar: CanopyBottomBar(
          currentIndex: _index,
          destinations: _destinations,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
