import 'package:flutter/material.dart';
import 'package:impact_trail/Community/Contributions/eco_shop.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Models/user.dart';
import '../../Services/Community/community_service.dart';
import '../../Shared/theme/app_theme.dart';
import '../Activities/activities_list.dart';
import '../Impact/impact_dashboard.dart';
import '../Profile/profile_screen.dart';
import '../Map/map.dart';
import '../Contributions/log_contribution.dart';
import '../Contributions/contribution_card.dart';
import '../Contributions/contribution_placeholders.dart';
import '../Communication/notification_center.dart';
import '../Activities/create_activity.dart';

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  int _index = 0;

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final trimmed = name.trim();
    final words = trimmed.split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return (words[0][0] + words[words.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = Provider.of<F_User?>(context);

    final pages = [
      _HomeTab(
        userId: user?.uid,
        onJoinActivity: () => setState(() => _index = 1),
        onLogContribution: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const LogContributionScreen()),
          );
        },
        onViewImpact: () => setState(() => _index = 2),
      ),
      const ActivitiesListScreen(embedded: true),
      const ImpactDashboardScreen(embedded: true),
      const MapScreen(),
      const ProfileScreen(),
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 68,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.eco_outlined,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
          ),
          title: Text(
            'Canopy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
          ),
          actions: [
            // Shop Icon with label
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EcoShopScreen(),
                      ),
                    );
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -8),
                  child: Text(
                    'Shop',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationCenterScreen()),
                );
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.darkGreen,
                    size: 24,
                  ),
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
           
     ],
        ),
        body: pages[_index],
        floatingActionButton: _index != 1 || user == null
            ? null
            : FutureBuilder<String?>(
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
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: NavigationBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              indicatorColor: AppTheme.primary.withOpacity(0.15),
              height: 70,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                  selectedIcon: Icon(Icons.home, color: AppTheme.primary),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                  selectedIcon: Icon(Icons.event_note, color: AppTheme.primary),
                  label: 'Activities',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                  selectedIcon: Icon(Icons.analytics, color: AppTheme.primary),
                  label: 'Impact',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                  selectedIcon: Icon(Icons.map, color: AppTheme.primary),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                  selectedIcon: Icon(Icons.person, color: AppTheme.primary),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String? userId;
  final VoidCallback onJoinActivity;
  final VoidCallback onLogContribution;
  final VoidCallback onViewImpact;

  const _HomeTab({
    this.userId,
    required this.onJoinActivity,
    required this.onLogContribution,
    required this.onViewImpact,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
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
                          Text(
                            'Building a Better',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  height: 1.2,
                                ),
                          ),
                          Text(
                            'Community Together',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Every action counts. Track your impact.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 14,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats Row
                if (userId != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final data =
                          snapshot.data?.data() as Map<String, dynamic>?;
                      final points = data?['totalPoints'] ?? 0;
                      final contributions = data?['contributions'] ?? 0;
                      final rank = data?['rank'] ?? 'Member';

                      return Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Points',
                              value: points.toString(),
                              icon: Icons.bolt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Contributions',
                              value: contributions.toString(),
                              icon: Icons.volunteer_activism,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Rank',
                              value: rank.toString(),
                              icon: Icons.emoji_events,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                        fontSize: 18,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        title: 'Log Work',
                        icon: Icons.add_circle_outline,
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.lightGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: onLogContribution,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                _QuickActionCard(
                  title: 'View My Impact',
                  icon: Icons.analytics,
                  gradient: LinearGradient(
                    colors: [AppTheme.tertiary, const Color(0xFFFF8E53)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: onViewImpact,
                  expanded: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Community Updates Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.campaign, color: AppTheme.darkGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Community Updates',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            fontSize: 18,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CommunityNewsCard(
                  title: 'New Recycling Center Opens in Kibera',
                  description:
                      'Community members can now drop off sorted materials at the new facility on Olympic Estate Road.',
                  imageUrl:
                      'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400',
                  date: '2 days ago',
                ),
                const SizedBox(height: 12),
                _CommunityNewsCard(
                  title: 'Beach Cleanup Collects 2 Tons of Waste',
                  description:
                      'Volunteers gathered last weekend for the largest coastal cleanup event this year.',
                  imageUrl:
                      'https://images.unsplash.com/photo-1618477461853-cf6ed80faba5?w=400',
                  date: '1 week ago',
                ),
                const SizedBox(height: 12),
                _CommunityNewsCard(
                  title: 'Blockchain Rewards Program Launches',
                  description:
                      'Earn ADA tokens for verified environmental contributions through our new platform.',
                  imageUrl:
                      'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=400',
                  date: '2 weeks ago',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Recent Activity Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen,
                              fontSize: 18,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to all contributions
                      },
                      child: Text(
                        'View All',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (userId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('contributions')
                        .where('userId', isEqualTo: userId)
                        .orderBy('createdAt', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          ),
                        );
                      }

                      // Always show placeholders (no empty state)
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Column(
                          children: List.generate(
                            3,
                            (index) => ContributionPlaceholders
                                .buildPlaceholderCard(context, index),
                          ),
                        );
                      }

                      // Show actual contributions
                      final contributions = snapshot.data!.docs;
                      return Column(
                        children: contributions.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return ContributionCard(
                            contribution: {
                              ...data,
                              'id': doc.id,
                            },
                          );
                        }).toList(),
                      );
                    },
                  )
                else
                  Column(
                    children: List.generate(
                      3,
                      (index) => ContributionPlaceholders
                          .buildPlaceholderCard(context, index),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool expanded;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: expanded ? 70 : 95,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: expanded
              ? Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 18),
                  ],
                )
              : Column(
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
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

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
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 19,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CommunityNewsCard extends StatelessWidget {
  final String title;
  final String description;
  final String imageUrl;
  final String date;

  const _CommunityNewsCard({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.lightGreen.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: Image.network(
              imageUrl,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 90,
                  height: 90,
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  child: Icon(
                    Icons.image_outlined,
                    color: AppTheme.primary.withOpacity(0.5),
                    size: 32,
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 90,
                  height: 90,
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen,
                          fontSize: 14,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.darkGreen.withOpacity(0.6),
                          fontSize: 12,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
}