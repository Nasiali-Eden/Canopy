import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/Activities/create_activity.dart';
import '../../../Shared/Activities/create_article.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kHeaderGradientStart = Color(0xFF102A1B);
const _kHeaderGradientEnd   = Color(0xFF1F5539);
const _kPageBg              = Color(0xFFF0F3EE);

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum _AttentionType { action, info }

class _AttentionItem {
  final _AttentionType type;
  final IconData icon;
  final String message;
  final String actionLabel;
  final String route;
  const _AttentionItem({
    required this.type,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.route,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Router
// ─────────────────────────────────────────────────────────────────────────────

class OrgDashboard extends StatefulWidget {
  const OrgDashboard({super.key});
  @override
  OrgDashboardState createState() => OrgDashboardState();
}

class OrgDashboardState extends State<OrgDashboard> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void popToRoot() =>
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        WidgetBuilder builder;
        switch (settings.name) {
        // ── Existing routes ──────────────────────────────────────────────
          case '/createActivity':
            builder = (_) => const CreateActivityScreen();
            break;
          case '/createPost':
            builder = (_) => const CreateArticleScreen();
            break;
        // ── Stub routes ──────────────────────────────────────────────────
          case '/activityDetails':
            builder = (_) => const _PlaceholderScreen(title: 'Activity details', icon: Icons.event_note_outlined);
            break;
          case '/allActivities':
            builder = (_) => const _PlaceholderScreen(title: 'All activities', icon: Icons.calendar_month_outlined);
            break;
          case '/volunteerManagement':
            builder = (_) => const _PlaceholderScreen(title: 'Volunteer management', icon: Icons.volunteer_activism_outlined);
            break;
          case '/impactReport':
            builder = (_) => const _PlaceholderScreen(title: 'Impact report', icon: Icons.bar_chart_outlined);
            break;
          case '/sponsorBounties':
            builder = (_) => const _PlaceholderScreen(title: 'Sponsor bounties', icon: Icons.savings_outlined);
            break;
          case '/partnerOrgs':
            builder = (_) => const _PlaceholderScreen(title: 'Partner organisations', icon: Icons.handshake_outlined);
            break;
          case '/notifications':
            builder = (_) => const _PlaceholderScreen(title: 'Notifications', icon: Icons.notifications_outlined);
            break;
          case '/programmes':
            builder = (_) => const _PlaceholderScreen(title: 'Programmes', icon: Icons.workspaces_outlined);
            break;
          case '/memberRecruitment':
            builder = (_) => const _PlaceholderScreen(title: 'Member recruitment', icon: Icons.group_add_outlined);
            break;
          case '/announcementBroadcast':
            builder = (_) => const _PlaceholderScreen(title: 'Broadcast announcement', icon: Icons.campaign_outlined);
            break;
          default:
            builder = (_) => _DashboardContent(firestore: FirebaseFirestore.instance);
        }
        return MaterialPageRoute(builder: builder, settings: settings);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard content
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardContent extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _DashboardContent({required this.firestore});
  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>?> _orgDataFuture;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _orgDataFuture = _fetchOrgData();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchOrgData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final userDoc =
      await widget.firestore.collection('Users').doc(user.uid).get();
      if (!userDoc.exists) return null;
      final orgId =
      (userDoc.data() as Map<String, dynamic>)['orgId'] as String?;
      if (orgId == null) return null;
      if (mounted) setState(() => _orgId = orgId);
      final orgDoc =
      await widget.firestore.collection('organizations').doc(orgId).get();
      if (!orgDoc.exists) return null;
      return orgDoc.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error: $e');
      return null;
    }
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final w = name.trim().split(' ');
    return w.length == 1
        ? w[0][0].toUpperCase()
        : (w[0][0] + w[w.length - 1][0]).toUpperCase();
  }

  static const List<_AttentionItem> _attentionItems = [
    _AttentionItem(
      type: _AttentionType.action,
      icon: Icons.how_to_reg_outlined,
      message: '4 volunteer RSVPs pending review',
      actionLabel: 'Review',
      route: '/volunteerManagement',
    ),
    _AttentionItem(
      type: _AttentionType.action,
      icon: Icons.task_alt,
      message: '2 events awaiting verification',
      actionLabel: 'Verify',
      route: '/allActivities',
    ),
    _AttentionItem(
      type: _AttentionType.info,
      icon: Icons.savings_outlined,
      message: 'Sponsor bounty 68% reached · 4 days left',
      actionLabel: 'Track',
      route: '/sponsorBounties',
    ),
    _AttentionItem(
      type: _AttentionType.info,
      icon: Icons.handshake_outlined,
      message: 'Partner request from GreenKibera CBO',
      actionLabel: 'Respond',
      route: '/partnerOrgs',
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _orgDataFuture,
      builder: (context, snapshot) {
        final orgData = snapshot.data;
        return Scaffold(
          backgroundColor: _kPageBg,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRichHeader(context, orgData),
                      const SizedBox(height: 28),
                      _buildAttentionStrip(context),
                      const SizedBox(height: 28),
                      _buildMetricsSection(context),
                      const SizedBox(height: 28),
                      _buildActivitiesSection(context),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              // Floating notification button
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 16,
                child: _FloatingNotificationButton(
                  onTap: () =>
                      Navigator.of(context).pushNamed('/notifications'),
                ),
              ),
            ],
          ),
          floatingActionButton: _buildFAB(context),
        );
      },
    );
  }

  // ── Rich header ────────────────────────────────────────────────────────────

  Widget _buildRichHeader(
      BuildContext context, Map<String, dynamic>? orgData) {
    final orgName     = orgData?['org_name']       as String? ?? 'Organisation';
    final designation = orgData?['orgDesignation'] as String?;
    final city        = orgData?['city']           as String? ?? 'Kenya';
    final isVerified  = orgData?['verified']       as bool?   ?? false;
    final logoUrl     = orgData?['logoUrl']        as String?;
    final memberCount = orgData?['memberCount']    as int?;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kHeaderGradientStart, _kHeaderGradientEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeaderDecorPainter())),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 72, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _OrgAvatar(
                              initials: _initials(orgName), logoUrl: logoUrl),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (designation != null) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 5),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.tertiary.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppTheme.tertiary.withOpacity(0.3),
                                          width: 0.5),
                                    ),
                                    child: Text(
                                      designation.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.tertiary,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                                Text(
                                  orgName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (isVerified) ...[
                                      const Icon(Icons.verified,
                                          size: 12, color: AppTheme.tertiary),
                                      const SizedBox(width: 4),
                                      const Text('Verified · ',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.tertiary,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                    Icon(Icons.location_on_outlined,
                                        size: 11,
                                        color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(width: 2),
                                    Text(city,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.55),
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Frosted stats bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 0.5),
                        ),
                        child: Row(
                          children: [
                            _HeaderStat(
                              value: memberCount != null ? '$memberCount' : '—',
                              label: 'Members',
                              icon: Icons.people_outline,
                            ),
                            _headerDivider(),
                            const _HeaderStat(
                              value: '—', // TODO: partners count
                              label: 'Partners',
                              icon: Icons.handshake_outlined,
                            ),
                            _headerDivider(),
                            const _HeaderStat(
                              value: '—', // TODO: active since date
                              label: 'Active since',
                              icon: Icons.eco_outlined,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 28,
                decoration: const BoxDecoration(
                  color: _kPageBg,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerDivider() => Container(
    width: 1,
    height: 30,
    color: Colors.white.withOpacity(0.12),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  // ── Attention strip ────────────────────────────────────────────────────────

  Widget _buildAttentionStrip(BuildContext context) {
    final actionCount =
        _attentionItems.where((i) => i.type == _AttentionType.action).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Needs attention',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                    letterSpacing: 0.2,
                  )),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$actionCount',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _attentionItems.length,
            itemBuilder: (context, i) => _AttentionCard(
              item: _attentionItems[i],
              onTap: () =>
                  Navigator.of(context).pushNamed(_attentionItems[i].route),
            ),
          ),
        ),
      ],
    );
  }

  // ── Metrics ────────────────────────────────────────────────────────────────

  Widget _buildMetricsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(
            title: 'This month',
            actionLabel: 'Full report →',
            onAction: () =>
                Navigator.of(context).pushNamed('/impactReport'),
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: _orgId != null
              ? widget.firestore
              .collection('Activities')
              .where('orgId', isEqualTo: _orgId)
              .snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final totalEvents = docs.length;
            final verified = docs
                .where((d) =>
            (d.data() as Map<String, dynamic>)['impactStatus'] ==
                'confirmed')
                .length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _MetricCard(
                    value: '—', // TODO: aggregate kg from transactions
                    label: 'Kg diverted',
                    icon: Icons.recycling,
                    color: AppTheme.primary,
                    bgSeed: 42,
                  ),
                  _MetricCard(
                    value: '—', // TODO: aggregate volunteer hours
                    label: 'Volunteer hours',
                    icon: Icons.volunteer_activism,
                    color: AppTheme.accent,
                    bgSeed: 17,
                  ),
                  _MetricCard(
                    value: snapshot.hasData ? '$totalEvents' : '—',
                    label: 'Events run',
                    icon: Icons.event_available,
                    color: AppTheme.darkGreen,
                    bgSeed: 88,
                  ),
                  _MetricCard(
                    value: snapshot.hasData ? '$verified' : '—',
                    label: 'Verified on-chain',
                    icon: Icons.verified,
                    color: AppTheme.tertiary,
                    bgSeed: 55,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Activities ─────────────────────────────────────────────────────────────

  Widget _buildActivitiesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(
            title: 'Upcoming & active',
            actionLabel: 'View all →',
            onAction: () =>
                Navigator.of(context).pushNamed('/allActivities'),
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: _orgId != null
              ? widget.firestore
              .collection('Activities')
              .where('orgId', isEqualTo: _orgId)
              .where('status', whereIn: ['upcoming', 'ongoing'])
              .orderBy('date', descending: false)
              .limit(8)
              .snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2)),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return _buildEmptyActivities(context);
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                return _ActivityTile(
                  activity: data,
                  imageSeed: i,
                  onTap: () => Navigator.of(context)
                      .pushNamed('/activityDetails', arguments: data),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyActivities(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.event_note_outlined,
                  size: 30, color: AppTheme.lightGreen),
            ),
            const SizedBox(height: 14),
            Text('No upcoming activities',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.6))),
            const SizedBox(height: 5),
            Text('Tap + to create your first event',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGreen.withOpacity(0.35))),
          ],
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'org_dashboard_fab',
      onPressed: () => _showCreateSheet(context),
      backgroundColor: AppTheme.primary,
      elevation: 4,
      child: const Icon(Icons.add, color: Colors.white, size: 26),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.lightGreen.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Text('Create',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen))
                ]),
              ),
              const SizedBox(height: 12),
              _CreateSheetOption(
                icon: Icons.event_available_outlined,
                title: 'Activity',
                subtitle: 'Cleanup, planting, awareness, training',
                color: AppTheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/createActivity');
                },
              ),
              _CreateSheetOption(
                icon: Icons.campaign_outlined,
                title: 'Announcement',
                subtitle: 'Broadcast to followers and nearby members',
                color: AppTheme.tertiary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/announcementBroadcast');
                },
              ),
              _CreateSheetOption(
                icon: Icons.savings_outlined,
                title: 'Bounty application',
                subtitle: 'Connect your project to sponsor funding',
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/sponsorBounties');
                },
              ),
              _CreateSheetOption(
                icon: Icons.group_add_outlined,
                title: 'Member intake',
                subtitle: 'Open a new membership round',
                color: AppTheme.secondary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/memberRecruitment');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header decorator painter
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    p
      ..color = const Color(0xFF4A9B6E).withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1),
        size.width * 0.38, p);

    p
      ..color = const Color(0xFF3B8A7A).withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.75),
        size.width * 0.25, p);

    p
      ..color = const Color(0xFFC4A961).withOpacity(0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.45),
        size.width * 0.15, p);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = null;
    ring.color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.6), 80, ring);
    ring.color = Colors.white.withOpacity(0.03);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.6), 130, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Org avatar
// ─────────────────────────────────────────────────────────────────────────────

class _OrgAvatar extends StatelessWidget {
  final String initials;
  final String? logoUrl;
  const _OrgAvatar({required this.initials, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: AppTheme.tertiary.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
              color: AppTheme.tertiary.withOpacity(0.2),
              blurRadius: 16,
              spreadRadius: 0)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? Image.network(logoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2D7A4F), Color(0xFF3B8A7A)],
      ),
    ),
    alignment: Alignment.center,
    child: Text(initials,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingNotificationButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingNotificationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: Colors.white.withOpacity(0.18), width: 0.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 20),
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: AppTheme.tertiary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _HeaderStat(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1)),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 9, color: Colors.white.withOpacity(0.45)),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader(
      {required this.title,
        required this.actionLabel,
        required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkGreen,
                letterSpacing: -0.2)),
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final _AttentionItem item;
  final VoidCallback onTap;
  const _AttentionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAction = item.type == _AttentionType.action;
    final accent = isAction ? AppTheme.tertiary : AppTheme.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
                color: accent.withOpacity(0.09),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 17, color: accent),
                ),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isAction ? accent : accent.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.message,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                        height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${item.actionLabel} →',
                    style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final int bgSeed;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgSeed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Nature-themed background image
            Positioned(
              right: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.08,
                child: Image.network(
                  'https://picsum.photos/seed/$bgSeed/100/100',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              right: -18,
              bottom: -18,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.07)),
              ),
            ),
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1)),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1,
                              letterSpacing: -1)),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(9)),
                        child: Icon(icon, size: 14, color: color),
                      ),
                    ],
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.45),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final int imageSeed;
  final VoidCallback onTap;
  const _ActivityTile(
      {required this.activity, required this.imageSeed, required this.onTap});

  static _DateParts _parseDate(dynamic raw) {
    if (raw == null) return const _DateParts('—', '');
    if (raw is Timestamp) {
      final dt = raw.toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return _DateParts('${dt.day}', m[dt.month - 1]);
    }
    if (raw is String && raw.isNotEmpty) {
      final p = raw.trim().split(RegExp(r'[\s/\-]+'));
      final mon = p.length > 1
          ? (p[1].length > 3 ? p[1].substring(0, 3) : p[1])
          : '';
      return _DateParts(p.isNotEmpty ? p[0] : '—', mon);
    }
    return const _DateParts('—', '');
  }

  @override
  Widget build(BuildContext context) {
    final status       = activity['status']         as String? ?? 'upcoming';
    final impactStatus = activity['impactStatus']   as String? ?? 'unverified';
    final name         = activity['name']           as String? ?? 'Untitled activity';
    final location     = activity['location']       as String? ?? '';
    final participants    = activity['participants']    as int? ?? 0;
    final maxParticipants = activity['maxParticipants'] as int? ?? 0;
    final date = _parseDate(activity['date']);
    final isOngoing = status == 'ongoing';

    late Color opColor; late String opLabel;
    switch (status) {
      case 'ongoing':   opColor = AppTheme.tertiary;  opLabel = 'Ongoing';   break;
      case 'completed': opColor = AppTheme.accent;    opLabel = 'Completed'; break;
      default:          opColor = AppTheme.secondary; opLabel = 'Upcoming';
    }
    late Color impactColor; late String impactLabel;
    switch (impactStatus) {
      case 'pending':   impactColor = AppTheme.tertiary;   impactLabel = 'Pending';    break;
      case 'confirmed': impactColor = AppTheme.primary;    impactLabel = 'Verified ✓'; break;
      default:          impactColor = AppTheme.lightGreen; impactLabel = 'Unverified';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isOngoing
              ? Border.all(color: AppTheme.tertiary.withOpacity(0.25))
              : null,
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            // Thumbnail with date overlay
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  Image.network(
                    'https://picsum.photos/seed/${(name.hashCode.abs() % 100) + imageSeed * 7}/80/100',
                    width: 80,
                    height: 100,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, prog) => prog == null
                        ? child
                        : Container(
                        width: 80,
                        height: 100,
                        color: AppTheme.lightGreen.withOpacity(0.15)),
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 100,
                      color: AppTheme.lightGreen.withOpacity(0.12),
                      child: Icon(Icons.eco_outlined,
                          color: AppTheme.lightGreen.withOpacity(0.5),
                          size: 28),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6)
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(date.day,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1),
                              textAlign: TextAlign.center),
                          if (date.month.isNotEmpty)
                            Text(date.month,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.8)),
                                textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 10,
                              color: AppTheme.darkGreen.withOpacity(0.38)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(location,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.darkGreen.withOpacity(0.4)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatusPill(
                            label: opLabel,
                            color: opColor,
                            filled: isOngoing),
                        const SizedBox(width: 5),
                        _StatusPill(
                            label: impactLabel,
                            color: impactColor,
                            filled: impactStatus == 'confirmed'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Volunteer count
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$participants',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          height: 1)),
                  Text('/ $maxParticipants',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.darkGreen.withOpacity(0.35),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Icon(Icons.arrow_forward_ios,
                      size: 11,
                      color: AppTheme.lightGreen.withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateParts {
  final String day;
  final String month;
  const _DateParts(this.day, this.month);
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _StatusPill(
      {required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: filled ? Colors.transparent : color.withOpacity(0.3),
            width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _CreateSheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _CreateSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.07)
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.45))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: AppTheme.lightGreen.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder screen
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.darkGreen,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1, color: AppTheme.lightGreen.withOpacity(0.2)),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.lightGreen.withOpacity(0.18),
                    AppTheme.accent.withOpacity(0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon,
                  size: 34, color: AppTheme.lightGreen.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen)),
            const SizedBox(height: 5),
            Text('Coming soon',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkGreen.withOpacity(0.38))),
          ],
        ),
      ),
    );
  }
}