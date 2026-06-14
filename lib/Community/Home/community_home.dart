// lib/Community/Home/community_home.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../MarketPlace/The Market/eco_shop.dart';
import '../../Models/user.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/Activities/activity_home_logic.dart';
import '../../Shared/Activities/activity_filter_sheet.dart';
import '../Heritage/community_heritage_tab.dart';
import '../Profile/profile_screen.dart';
import '../Map/map.dart';
import '../Map/org_logo_cache.dart';
import '../Contributions/contribution_card.dart';
import '../Contributions/contribution_detail_sheet.dart';
import '../Contributions/all_contributions_screen.dart';
import '../Communication/notification_center.dart';
import '../Announcements/announcements_tab.dart';
import '../Articles/articles_list_screen.dart';

// ── Firestore collection paths ─────────────────────────────────────────────────
const _kContributions = 'contributions';
const _kArticles = 'articles';
const _kAnnouncements = 'announcements';
const _kUsers = 'users';

// ── Time helper — exported for reuse in sibling screens ───────────────────────
String timeAgo(Timestamp timestamp) {
  final diff = DateTime.now().difference(timestamp.toDate());
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return DateFormat('d MMM yyyy').format(timestamp.toDate());
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  int _index = 0;
  ActivityFilter _activityFilter = const ActivityFilter();

  bool get _isDarkTab => _index == 2 || _index == 3;

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

  AppBar _buildHomeAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      toolbarHeight: 62,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.eco_outlined, color: AppTheme.primary, size: 20),
        ),
      ),
      title: Text(
        'Canopy',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
      ),
      actions: [
        // Marketplace moved to a full-width Quick Action below (Phase 6).
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen()),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_outlined,
                  color: AppTheme.darkGreen, size: 24),
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
        child: Container(
            height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
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
              builder: (_) =>
                  ActivityFilterSheet(current: _activityFilter),
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
        child: Container(
            height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);

    final pages = [
      _HomeTab(
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
        appBar: _index == 0
            ? _buildHomeAppBar(context)
            : _index == 1
                ? _buildActivitiesAppBar(context)
                : null,
        extendBody: true,
        body: pages[_index],
        floatingActionButton: _index == 1
            ? ActivityHomeLogic.buildFloatingActionButton(context, user)
            : null,
        bottomNavigationBar: _FloatingNavBar(
          currentIndex: _index,
          isDark: _isDarkTab,
          onTap: (i) => setState(() => _index = i),
          destinations: const [
            _NavDestination(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home'),
            _NavDestination(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note_rounded,
                label: 'Activities'),
            _NavDestination(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map'),
            _NavDestination(
                icon: Icons.auto_stories_outlined,
                activeIcon: Icons.auto_stories_rounded,
                label: 'Heritage'),
            _NavDestination(
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING NAV BAR — pill / glass style (mirrors org_home), theme-aware so it
// reads cleanly over the dark Map & Heritage tabs.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class _NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavDestination(
      {required this.icon, required this.activeIcon, required this.label});
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.isDark,
    required this.destinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14201A).withOpacity(0.92)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.6),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppTheme.darkGreen.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (i) {
              final dest = destinations[i];
              return Expanded(
                child: _NavItem(
                  icon: dest.icon,
                  activeIcon: dest.activeIcon,
                  label: dest.label,
                  isSelected: i == currentIndex,
                  isDark: isDark,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselected =
        isDark ? Colors.white.withOpacity(0.6) : AppTheme.darkGreen.withOpacity(0.65);
    final labelColor = isDark ? Colors.white : AppTheme.darkGreen;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected ? AppTheme.tertiary : unselected,
            ),
            const SizedBox(height: 3),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  letterSpacing: -0.1,
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final String? userId;
  final VoidCallback onJoinActivity;
  final VoidCallback onLogContributionComingSoon;
  final VoidCallback onViewAnnouncements;
  final VoidCallback onViewAllArticles;
  final VoidCallback onViewAllContributions;

  const _HomeTab({
    this.userId,
    required this.onJoinActivity,
    required this.onLogContributionComingSoon,
    required this.onViewAnnouncements,
    required this.onViewAllArticles,
    required this.onViewAllContributions,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.lightGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Building a Better',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 26,
                                    height: 1.2,
                                  )),
                          Text('Community Together',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 20,
                                    height: 1.2,
                                  )),
                          const SizedBox(height: 12),
                          Text('Every action counts. Track your impact.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 14,
                                  )),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco,
                          size: 40, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (userId != null)
                  StreamBuilder<DocumentSnapshot>(
                    // Firestore: users/{userId}
                    stream: FirebaseFirestore.instance
                        .collection(_kUsers)
                        .doc(userId)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) return const SizedBox.shrink();
                      final data =
                          snap.data?.data() as Map<String, dynamic>?;
                      final points = data?['totalPoints'] ?? 0;
                      final contributions = data?['contributions'] ?? 0;
                      final rank = data?['rank'] ?? '0';
                      return Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                                  label: 'Points',
                                  value: points.toString(),
                                  icon: Icons.bolt)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _StatCard(
                                  label: 'Contributions',
                                  value: contributions.toString(),
                                  icon: Icons.volunteer_activism)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _StatCard(
                                  label: 'Rank',
                                  value: rank.toString(),
                                  icon: Icons.emoji_events)),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),

          // ── Quick Actions ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen,
                          fontSize: 18,
                        )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Log Work — locked with coming-soon overlay
                    Expanded(
                      child: Stack(
                        children: [
                          _QuickActionCard(
                            title: 'Log Work',
                            icon: Icons.add_circle_outline,
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primary,
                                AppTheme.lightGreen
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: onLogContributionComingSoon,
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: false,
                              child: GestureDetector(
                                onTap: onLogContributionComingSoon,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock_outline,
                                          color: Colors.white, size: 20),
                                      SizedBox(height: 6),
                                      Text(
                                        'Coming Soon',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Join Event
                    Expanded(
                      child: _QuickActionCard(
                        title: 'Join Event',
                        icon: Icons.event,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: onJoinActivity,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Marketplace — full-width (relocated from the app bar).
                _MarketplaceAction(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EcoShopScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Announcements ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.campaign_outlined,
                        color: AppTheme.darkGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Announcements',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen,
                                fontSize: 18,
                              )),
                    ),
                    TextButton(
                      onPressed: onViewAnnouncements,
                      child: const Text('See All',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  // Firestore: announcements — 3 most recent, client-side expiry filter
                  stream: FirebaseFirestore.instance
                      .collection(_kAnnouncements)
                      .orderBy('createdAt', descending: true)
                      .limit(6)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const _ErrorCard(onRetry: null);
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Column(
                        children: List.generate(
                            2, (_) => const _AnnouncementPlaceholder()),
                      );
                    }
                    final now = DateTime.now();
                    final docs = (snap.data?.docs ?? []).where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final exp = data['expiresAt'] as Timestamp?;
                      return exp == null || exp.toDate().isAfter(now);
                    }).take(3).toList();

                    if (docs.isEmpty) {
                      return _quietEmptyCard(
                        icon: Icons.notifications_none,
                        label: 'No announcements yet',
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AnnouncementCard(
                              data: d.data() as Map<String, dynamic>),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Community Updates ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article_outlined,
                        color: AppTheme.darkGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Community Updates',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen,
                                fontSize: 18,
                              )),
                    ),
                    TextButton(
                      onPressed: onViewAllArticles,
                      child: const Text('See All',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<QuerySnapshot>(
                  // Firestore: articles — published, newest first, limit 3
                  stream: FirebaseFirestore.instance
                      .collection(_kArticles)
                      .where('isPublished', isEqualTo: true)
                      .orderBy('publishedAt', descending: true)
                      .limit(3)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _ErrorCard(onRetry: () => setState(() {}));
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Column(
                        children: [
                          const _ArticlePlaceholderCard(),
                          const SizedBox(height: 12),
                          const _ArticlePlaceholderCard(),
                        ],
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  AppTheme.lightGreen.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.article_outlined,
                                size: 48, color: AppTheme.lightGreen),
                            const SizedBox(height: 12),
                            Text('No community updates yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        color: AppTheme.darkGreen)),
                            const SizedBox(height: 4),
                            Text(
                              'Check back soon for news from organisations in your area.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.darkGreen
                                        .withOpacity(0.6),
                                  ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: docs.asMap().entries.map((e) {
                        final data =
                            e.value.data() as Map<String, dynamic>;
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: e.key < docs.length - 1 ? 12 : 0),
                          child: _CommunityNewsCard(data: data),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Recent Activity ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Recent Activity',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen,
                                fontSize: 18,
                              )),
                    ),
                    TextButton(
                      onPressed: onViewAllContributions,
                      child: const Text('View All',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (userId != null)
                  StreamBuilder<QuerySnapshot>(
                    // Firestore: contributions — current user, newest first
                    stream: FirebaseFirestore.instance
                        .collection(_kContributions)
                        .where('userId', isEqualTo: userId)
                        .orderBy('createdAt', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return _ErrorCard(
                            onRetry: () => setState(() {}));
                      }
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                                color: AppTheme.primary),
                          ),
                        );
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _ContributionsEmptyState(
                            onLogTap: onLogContributionComingSoon);
                      }
                      return Column(
                        children: docs.map((doc) {
                          final contribution = {
                            ...(doc.data() as Map<String, dynamic>),
                            'id': doc.id,
                          };
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              backgroundColor: Colors.transparent,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              builder: (_) => ContributionDetailSheet(
                                  contribution: contribution),
                            ),
                            child: ContributionCard(
                                contribution: contribution),
                          );
                        }).toList(),
                      );
                    },
                  )
                else
                  _ContributionsEmptyState(
                      onLogTap: onLogContributionComingSoon),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ignore: unused_element
  void setState(VoidCallback fn) => fn();
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

Widget _quietEmptyCard({required IconData icon, required String label}) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.lightGreen.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 36, color: AppTheme.lightGreen),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.6),
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback? onRetry;
  const _ErrorCard({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Something went wrong',
                  style: TextStyle(color: Colors.red.shade700))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Shimmer box ───────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.15),
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}

// ── Article placeholder card ──────────────────────────────────────────────────

class _ArticlePlaceholderCard extends StatelessWidget {
  const _ArticlePlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: _ShimmerBox(
                width: 90,
                height: 90,
                borderRadius: BorderRadius.zero),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                      height: 14,
                      borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 8),
                  _ShimmerBox(
                      width: 120,
                      height: 11,
                      borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 8),
                  _ShimmerBox(
                      width: 60,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Announcement placeholder ──────────────────────────────────────────────────

class _AnnouncementPlaceholder extends StatelessWidget {
  const _AnnouncementPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                      height: 13, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  _ShimmerBox(
                      width: 160,
                      height: 11,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Announcement card ─────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnnouncementCard({required this.data});

  Color _accentFor(String type) {
    switch (type) {
      case 'alert':
        return Colors.red.shade600;
      case 'event':
        return AppTheme.tertiary;
      case 'update':
        return AppTheme.primary;
      case 'opportunity':
        return AppTheme.accent;
      default:
        return AppTheme.lightGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'general';
    final isUrgent = data['isUrgent'] as bool? ?? false;
    final orgLogoUrl = data['orgLogoUrl'] as String?;
    final orgName = data['orgName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final accent = _accentFor(type);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (orgLogoUrl != null)
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(orgLogoUrl),
                          onBackgroundImageError: (_, __) {},
                        )
                      else
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: accent.withOpacity(0.15),
                          child:
                              Icon(Icons.business, size: 14, color: accent),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(orgName,
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    AppTheme.darkGreen.withOpacity(0.65),
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('URGENT',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            fontSize: 13,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(body,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.6),
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(timeAgo(createdAt),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contributions empty state ──────────────────────────────────────────────────

class _ContributionsEmptyState extends StatelessWidget {
  final VoidCallback onLogTap;
  const _ContributionsEmptyState({required this.onLogTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.history_outlined,
            size: 48, color: AppTheme.lightGreen.withOpacity(0.6)),
        const SizedBox(height: 12),
        Text('No activity logged yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 4),
        Text(
          'Use the Log Work button to record your first contribution.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.darkGreen.withOpacity(0.55),
              ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onLogTap,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text('Start Contributing',
              style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 95,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 22, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 13,
                            )),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Marketplace full-width action (relocated from app bar) ─────────────────────

class _MarketplaceAction extends StatelessWidget {
  final VoidCallback onTap;
  const _MarketplaceAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront_outlined,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Marketplace',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Shop recycled goods & eco products',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.9), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 19,
                  )),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
        ],
      ),
    );
  }
}

// ── Community News Card ───────────────────────────────────────────────────────

class _CommunityNewsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CommunityNewsCard({required this.data});

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'news':
        return 'News';
      case 'announcement':
        return 'Announcement';
      case 'education':
        return 'Education';
      case 'impact_story':
        return 'Impact Story';
      case 'event_recap':
        return 'Event Recap';
      default:
        return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final imageUrl = data['coverImageUrl'] as String?;
    final publishedAt = data['publishedAt'] as Timestamp?;
    final category = data['category'] as String? ?? '';
    final dateStr = publishedAt != null ? timeAgo(publishedAt) : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgFallback(),
                    loadingBuilder: (_, child, prog) =>
                        prog == null ? child : _imgFallback(),
                  )
                : _imgFallback(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_categoryLabel(category),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3)),
                    ),
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            fontSize: 14,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppTheme.darkGreen.withOpacity(0.6),
                            fontSize: 12,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 12, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() => Container(
        width: 90,
        height: 90,
        color: AppTheme.lightGreen.withOpacity(0.2),
        child: Icon(Icons.broken_image_outlined,
            color: AppTheme.lightGreen, size: 32),
      );
}
