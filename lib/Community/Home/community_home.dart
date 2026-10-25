// lib/Community/Home/community_home.dart
//
// Routing-only shell for the Community experience: it owns the bottom nav and
// switches between the five tabs (Home / Activities / Map / Heritage / Profile).
// The Home tab UI lives in home_feed.dart; other tabs are their own screens.
// The nav bar mirrors the Organization shell (org_home.dart).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../theme/canopy_components.dart';
import '../../Shared/widgets/canopy_bottom_bar.dart';
import '../../Shared/Activities/activity_home_logic.dart';
import '../../Shared/Activities/activity_filter_sheet.dart';
import '../../Services/Contributions/contribution_service.dart';
import '../Heritage/community_heritage_tab.dart';
import '../Profile/profile_screen.dart';
import '../Map/map.dart';
import '../Map/org_logo_cache.dart';
import '../Communication/announcements_list.dart';
import '../Articles/articles_list_screen.dart';
import '../Contributions/all_contributions_screen.dart';
import '../Events/log_work_event_screen.dart';
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

  // Phase 1.4 — the Heritage tab (index 3) is the one screen whose bottom
  // bar should go transparent while scrolling down and opaque at rest/on
  // scroll-up. Every other tab always gets the solid white bar.
  bool _heritageBarTransparent = false;

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

  void _openLogWork() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogWorkEventScreen()),
    );
  }

  PreferredSizeWidget _buildActivitiesAppBar(BuildContext context) {
    final hasFilter = !_activityFilter.isDefault;
    return canopyAppBar(
      context,
      title: 'Activities',
      showBack: false,
      actions: [
        CanopyIconButton(
          icon: Icons.tune_outlined,
          tooltip: hasFilter ? 'Filters (active)' : 'Filters',
          dot: hasFilter,
          onPressed: () async {
            final result = await showCanopySheet<ActivityFilter>(
              context,
              tall: true,
              builder: (_) => ActivityFilterSheet(current: _activityFilter),
            );
            if (result != null && mounted) {
              setState(() => _activityFilter = result);
            }
          },
        ),
      ],
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
        onBrowseActivities: () => setState(() => _index = 1),
        onLogWork: _openLogWork,
        onViewAnnouncements: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnnouncementsListScreen()),
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
      CommunityHeritageTab(
        // The bar stays visible while scrolling so there is always a way out.
        onScrollDirectionChanged: (_) {},
      ),
      const ProfileScreen(),
    ];

    // Back never exits the app: from any tab it returns to Home, and on Home it
    // stays put. Screens pushed on top of this still pop normally.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: context.canopy.canvas,
        extendBody: _index == 3,
        appBar: _index == 1 ? _buildActivitiesAppBar(context) : null,
        body: IndexedStack(index: _index, children: pages),
        floatingActionButton: _index == 1
            ? ActivityHomeLogic.buildFloatingActionButton(context, user)
            : null,
        bottomNavigationBar: CanopyBottomBar(
          currentIndex: _index,
          destinations: _destinations,
          onTap: (i) => setState(() {
            _index = i;
            // Reset so re-entering Heritage always starts opaque, and other
            // tabs never inherit a stale transparent state.
            if (i != 3) _heritageBarTransparent = false;
          }),
          frosted: _index == 3,
          transparent: _index == 3 && _heritageBarTransparent,
        ),
      ),
    );
  }
}
