import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/Activities/create_activity.dart';
import '../../../Shared/Activities/create_article.dart';

class OrgDashboard extends StatefulWidget {
  const OrgDashboard({super.key});

  @override
  OrgDashboardState createState() => OrgDashboardState();
}

class OrgDashboardState extends State<OrgDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void popToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        WidgetBuilder builder;
        switch (settings.name) {
          case '/':
            builder =
                (BuildContext _) => _DashboardContent(firestore: _firestore);
            break;
          case '/createActivity':
            builder = (BuildContext _) => const CreateActivityScreen();
            break;
          case '/createPost':
            builder = (BuildContext _) => const CreateArticleScreen();
            break;
          default:
            builder =
                (BuildContext _) => _DashboardContent(firestore: _firestore);
        }
        return MaterialPageRoute(builder: builder, settings: settings);
      },
    );
  }
}

class _DashboardContent extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _DashboardContent({required this.firestore});

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  late Future<Map<String, dynamic>?> _orgDataFuture;

  @override
  void initState() {
    super.initState();
    _orgDataFuture = _fetchOrgData();
  }

  Future<Map<String, dynamic>?> _fetchOrgData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      // Get user's organization data from Users collection
      final userDoc =
          await widget.firestore.collection('Users').doc(currentUser.uid).get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final orgId = userData['orgId'] as String?;

      if (orgId == null) return null;

      // Get organization details from organizations collection
      final orgDoc =
          await widget.firestore.collection('organizations').doc(orgId).get();

      if (!orgDoc.exists) return null;

      return orgDoc.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching org data: $e');
      return null;
    }
  }

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _orgDataFuture,
        builder: (context, snapshot) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, snapshot.data),
                const SizedBox(height: 20),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildActivitySection(context),
                const SizedBox(height: 24),
                _buildPostsSection(context),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic>? orgData) {
    final orgName = orgData?['org_name'] as String? ?? 'Organization';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.secondary,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: AppTheme.tertiary, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              orgName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Kenya',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                if (orgData?['orgDesignation'] != null) ...[
                  Icon(Icons.category, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    orgData!['orgDesignation'] as String,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Activities',
                    value: '12',
                    icon: Icons.event_note,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Events',
                    value: '8',
                    icon: Icons.campaign,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Team',
                    value: '24',
                    icon: Icons.people,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  title: 'Create Event',
                  icon: Icons.event_available,
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                  ),
                  onTap: () {
                    Navigator.of(context).pushNamed('/createActivity');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  title: 'Publish Update',
                  icon: Icons.announcement,
                  gradient: LinearGradient(
                    colors: [AppTheme.tertiary, Color(0xFFE0B861)],
                  ),
                  onTap: () {
                    Navigator.of(context).pushNamed('/createPost');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activities',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('Activities')
                .orderBy('date', descending: false)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                );
              }

              final activities = snapshot.data!.docs;

              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy,
                          size: 48, color: AppTheme.lightGreen),
                      const SizedBox(height: 12),
                      Text(
                        'No activities yet',
                        style: TextStyle(
                            color: AppTheme.darkGreen.withOpacity(0.6)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity =
                      activities[index].data() as Map<String, dynamic>;
                  return _ActivityCard(
                    activity: activity,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/activityDetails',
                        arguments: activity,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Recent Posts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: widget.firestore
              .collection('Posts')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            final posts = snapshot.data!.docs;

            if (posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.post_add,
                            size: 48, color: AppTheme.lightGreen),
                        const SizedBox(height: 12),
                        Text(
                          'No posts yet',
                          style: TextStyle(
                              color: AppTheme.darkGreen.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index].data() as Map<String, dynamic>;
                return _PostCard(post: post);
              },
            );
          },
        ),
      ],
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
                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
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

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = activity['status'] ?? 'upcoming';
    final participants = activity['participants'] ?? 0;
    final maxParticipants = activity['maxParticipants'] ?? 0;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'ongoing':
        statusColor = AppTheme.tertiary;
        statusText = 'Ongoing';
        break;
      case 'completed':
        statusColor = AppTheme.accent;
        statusText = 'Completed';
        break;
      default:
        statusColor = AppTheme.primary;
        statusText = 'Upcoming';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activity['imageUrl'] != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  activity['imageUrl'],
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: AppTheme.lightGreen.withOpacity(0.2),
                    child:
                        Icon(Icons.image, size: 48, color: AppTheme.lightGreen),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(Icons.eco, size: 48, color: AppTheme.primary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity['name'] ?? 'Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: AppTheme.darkGreen.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity['date'] ?? 'TBD',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGreen.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: AppTheme.darkGreen.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity['location'] ?? 'Location TBD',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGreen.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$participants/$maxParticipants',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: AppTheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final type = post['type'] ?? 'news';
    IconData icon;
    Color color;

    switch (type) {
      case 'update':
        icon = Icons.update;
        color = AppTheme.accent;
        break;
      case 'announcement':
        icon = Icons.campaign;
        color = AppTheme.tertiary;
        break;
      default:
        icon = Icons.article;
        color = AppTheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  post['title'] ?? 'Post',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (post['content'] != null) ...[
            const SizedBox(height: 8),
            Text(
              post['content'],
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.darkGreen.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
