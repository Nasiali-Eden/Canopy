import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Models/organization.dart';
import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/Activities/create_activity.dart';
import '../../../Shared/Activities/create_article.dart';
import '../../../Community/Contributions/log_contribution.dart';
import '../../../Community/Contributions/contribution_card.dart';
import '../../../Community/Contributions/contribution_placeholders.dart';
import '../Programmes/programme_editor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kHeaderGradientStart = Color(0xFF102A1B);
const _kHeaderGradientEnd   = Color(0xFF1F5539);
const _kPageBg              = Color(0xFFF0F3EE);

// ─────────────────────────────────────────────────────────────────────────────
// Attention item model
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
// OrgDashboard – nested Navigator for in-tab routing
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
      onGenerateRoute: (settings) {
        WidgetBuilder builder;
        switch (settings.name) {
          case '/logWork':
            builder = (_) => const LogContributionScreen();
            break;
          case '/createPost':
            builder = (_) => const CreateArticleScreen();
            break;
          case '/createActivity':
            builder = (_) => const CreateActivityScreen();
            break;
          case '/createProgramme':
            final orgId = settings.arguments as String? ?? '';
            builder = (_) => ProgrammeEditor(orgId: orgId, existing: null);
            break;
          case '/activityDetails':
            builder = (_) => const _PlaceholderScreen(
                title: 'Activity details', icon: Icons.event_note_outlined);
            break;
          case '/allActivities':
            builder = (_) => const _PlaceholderScreen(
                title: 'All activities', icon: Icons.calendar_month_outlined);
            break;
          case '/volunteerManagement':
            builder = (_) => const _PlaceholderScreen(
                title: 'Volunteer management',
                icon: Icons.volunteer_activism_outlined);
            break;
          case '/impactReport':
            builder = (_) => const _PlaceholderScreen(
                title: 'Impact report', icon: Icons.bar_chart_outlined);
            break;
          case '/partnerOrgs':
            builder = (_) => const _PlaceholderScreen(
                title: 'Partner organisations',
                icon: Icons.handshake_outlined);
            break;
          case '/notifications':
            builder = (_) => const _PlaceholderScreen(
                title: 'Notifications', icon: Icons.notifications_outlined);
            break;
          case '/memberRecruitment':
            builder = (_) => const _PlaceholderScreen(
                title: 'Member recruitment', icon: Icons.group_add_outlined);
            break;
          default:
            builder =
                (_) => _DashboardContent(firestore: FirebaseFirestore.instance);
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
  Organization? _org;
  String?       _orgId;
  String?       _userId;
  bool _loading   = true;
  bool _uploading = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await widget.firestore
          .collection('Users')
          .doc(user.uid)
          .get();
      if (!mounted || !userDoc.exists) return;

      final orgId =
          (userDoc.data() as Map<String, dynamic>)['orgId'] as String?;
      if (orgId == null) return;

      final orgDoc = await widget.firestore
          .collection('organizations')
          .doc(orgId)
          .get();
      if (!mounted || !orgDoc.exists) return;

      Organization org = Organization.fromFirestore(orgDoc);

      // Lazy backfill: capabilities missing from older registrations.
      if (org.capabilities.isEmpty) {
        final caps = capabilitiesForDesignation(org.designation);
        await widget.firestore
            .collection('organizations')
            .doc(orgId)
            .update({'capabilities': caps.map((c) => c.name).toList()});
        org = org.copyWith(capabilities: caps);
      }

      if (!mounted) return;
      setState(() {
        _userId  = user.uid;
        _orgId   = orgId;
        _org     = org;
        _loading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadImage({
    required String fieldName,
    required String storagePath,
  }) async {
    if (_orgId == null) return;
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();

      await widget.firestore
          .collection('organizations')
          .doc(_orgId!)
          .update({fieldName: url});

      if (mounted) {
        setState(() {
          _org = _org?.copyWith(
            coverImageUrl:
                fieldName == 'coverImageUrl' ? url : _org?.coverImageUrl,
            logoUrl: fieldName == 'logoUrl' ? url : _org?.logoUrl,
          );
        });
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final w = name.trim().split(' ');
    return w.length == 1
        ? w[0][0].toUpperCase()
        : (w[0][0] + w[w.length - 1][0]).toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: Stack(
        children: [
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2),
            )
          else
            FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRichHeader(context),
                    const SizedBox(height: 16),
                    if (_orgId != null && _org != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _LiveAttentionStrip(
                            orgId: _orgId!, org: _org!),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildQuickActions(context),
                    const SizedBox(height: 14),
                    _buildMetricsSection(context),
                    const SizedBox(height: 14),
                    _buildActivitiesSection(context),
                    const SizedBox(height: 14),
                    _buildContributionsSection(context),
                    SizedBox(
                        height:
                            MediaQuery.of(context).padding.bottom + 90),
                  ],
                ),
              ),
            ),

          // Upload overlay
          if (_uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.tertiary, strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Rich header ────────────────────────────────────────────────────────────

  Widget _buildRichHeader(BuildContext context) {
    final org         = _org;
    final orgName     = org?.name       ?? 'Organisation';
    final designation = org?.designation;
    final city        = org?.city       ?? 'Kenya';
    final isVerified  = org?.verified   ?? false;
    final memberCount = org?.memberCount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kHeaderGradientStart,
            _kHeaderGradientEnd
                .withOpacity(org?.hasCover == true ? 0.6 : 1.0),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Cover image
          if (org?.hasCover == true)
            Positioned.fill(
              child: Image.network(
                org!.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Scrim over cover
          if (org?.hasCover == true)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.68),
                    ],
                  ),
                ),
              ),
            ),

          // Decorative painter (no cover)
          if (org?.hasCover != true)
            Positioned.fill(
                child: CustomPaint(painter: _HeaderDecorPainter())),

          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: avatar + name + notification icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _OrgAvatar(
                            initials: _initials(orgName),
                            logoUrl: org?.logoUrl,
                            onAddLogo: org?.hasLogo == false
                                ? () => _uploadImage(
                                      fieldName: 'logoUrl',
                                      storagePath:
                                          'organizations/$_orgId/logo.jpg',
                                    )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (designation != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.tertiary.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              AppTheme.tertiary.withOpacity(0.3),
                                          width: 0.5),
                                    ),
                                    child: Text(
                                      designation.toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.tertiary,
                                          letterSpacing: 0.8),
                                    ),
                                  ),
                                Text(
                                  orgName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isVerified) ...[
                                      const Icon(Icons.verified,
                                          size: 11,
                                          color: AppTheme.tertiary),
                                      const SizedBox(width: 3),
                                      const Text('Verified · ',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.tertiary,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                    Icon(Icons.location_on_outlined,
                                        size: 10,
                                        color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(width: 2),
                                    Text(city,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                Colors.white.withOpacity(0.55),
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _NotifButton(
                            onTap: () => Navigator.of(context)
                                .pushNamed('/notifications'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Add cover (only when no cover)
                      if (org?.hasCover == false)
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _uploadImage(
                              fieldName: 'coverImageUrl',
                              storagePath:
                                  'organizations/$_orgId/cover.jpg',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 12,
                                      color: Colors.white.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text('Add cover',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Stats bar (Partners live)
                      StreamBuilder<QuerySnapshot>(
                        stream: widget.firestore
                            .collection('orgPartners')
                            .where('orgId', isEqualTo: _orgId)
                            .where('status', isEqualTo: 'active')
                            .snapshots(),
                        builder: (context, partnerSnap) {
                          final partnerCount =
                              partnerSnap.data?.docs.length ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.5),
                            ),
                            child: Row(
                              children: [
                                _HeaderStat(
                                  value: memberCount != null
                                      ? '$memberCount'
                                      : '—',
                                  label: 'Members',
                                  icon: Icons.people_outline,
                                ),
                                _headerDivider(),
                                _HeaderStat(
                                  value: partnerSnap.hasData
                                      ? '$partnerCount'
                                      : '—',
                                  label: 'Partners',
                                  icon: Icons.handshake_outlined,
                                ),
                                _headerDivider(),
                                _HeaderStat(
                                  value: org?.activeSinceLabel ?? '—',
                                  label: 'Active since',
                                  icon: Icons.eco_outlined,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Curved page-background transition
              const SizedBox(height: 10),
              Container(
                height: 22,
                decoration: const BoxDecoration(
                  color: _kPageBg,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
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
        height: 28,
        color: Colors.white.withOpacity(0.12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  // ── Quick actions ──────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkGreen,
                letterSpacing: -0.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DashQuickAction(
                  title: 'Log Work',
                  icon: Icons.add_circle_outline,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                        builder: (_) => const LogContributionScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashQuickAction(
                  title: 'Write Article',
                  icon: Icons.article_outlined,
                  gradient: LinearGradient(
                    colors: [AppTheme.darkGreen, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/createPost'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Metrics ────────────────────────────────────────────────────────────────

  Widget _buildMetricsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionHeader(
            title: 'Overview',
            actionLabel: 'Full report →',
            onAction: () =>
                Navigator.of(context).pushNamed('/impactReport'),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: widget.firestore
              .collection('activities')
              .where('orgId', isEqualTo: _orgId)
              .snapshots(),
          builder: (context, actSnap) {
            final actDocs     = actSnap.data?.docs ?? [];
            final totalEvents = actDocs.length;
            final verified    = actDocs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['impactStatus'] ==
                    'confirmed')
                .length;

            return StreamBuilder<QuerySnapshot>(
              stream: widget.firestore
                  .collection('programmes')
                  .where('orgId', isEqualTo: _orgId)
                  .snapshots(),
              builder: (context, progSnap) {
                final activeProgrammes =
                    (progSnap.data?.docs ?? []).where((d) {
                  final s =
                      (d.data() as Map)['status'] as String? ?? '';
                  return s == 'active' || s == 'upcoming';
                }).length;

                return StreamBuilder<QuerySnapshot>(
                  stream: widget.firestore
                      .collection('OrgMembers')
                      .where('orgId', isEqualTo: _orgId)
                      .snapshots(),
                  builder: (context, membSnap) {
                    final volunteers =
                        membSnap.data?.docs.length ?? 0;

                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.1,
                        children: [
                          _MetricCard(
                            value: actSnap.hasData
                                ? '$totalEvents'
                                : '—',
                            label: 'Events run',
                            icon: Icons.event_available,
                            color: AppTheme.darkGreen,
                            bgSeed: 88,
                          ),
                          _MetricCard(
                            value: progSnap.hasData
                                ? '$activeProgrammes'
                                : '—',
                            label: 'Programmes',
                            icon: Icons.layers_outlined,
                            color: AppTheme.accent,
                            bgSeed: 17,
                          ),
                          _MetricCard(
                            value: membSnap.hasData
                                ? '$volunteers'
                                : '—',
                            label: 'Volunteers',
                            icon: Icons.volunteer_activism,
                            color: AppTheme.primary,
                            bgSeed: 42,
                          ),
                          _MetricCard(
                            value: actSnap.hasData ? '$verified' : '—',
                            label: 'Verified',
                            icon: Icons.verified,
                            color: AppTheme.tertiary,
                            bgSeed: 55,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionHeader(
            title: 'Upcoming & active',
            actionLabel: 'View all →',
            onAction: () =>
                Navigator.of(context).pushNamed('/allActivities'),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          // No orderBy/whereIn — avoids composite index requirement.
          // Filter and sort client-side; small per-org dataset.
          stream: widget.firestore
              .collection('activities')
              .where('orgId', isEqualTo: _orgId)
              .snapshots(),
          builder: (context, snapshot) {
            debugPrint('[Dash activities] state=${snapshot.connectionState} '
                'hasData=${snapshot.hasData} '
                'docs=${snapshot.data?.docs.length} '
                'error=${snapshot.error} '
                'orgId=$_orgId');
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2),
                ),
              );
            }
            if (snapshot.hasError) {
              debugPrint('[Dash activities] ERROR: ${snapshot.error}');
            }
            final all = snapshot.data?.docs ?? [];
            final docs = all.where((d) {
              final s = (d.data() as Map<String, dynamic>)['status']
                      as String? ??
                  '';
              return s == 'upcoming' || s == 'ongoing';
            }).toList()
              ..sort((a, b) {
                dynamic da = (a.data() as Map)['date'];
                dynamic db = (b.data() as Map)['date'];
                DateTime? ta, tb;
                if (da is Timestamp) ta = da.toDate();
                if (db is Timestamp) tb = db.toDate();
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return ta.compareTo(tb);
              });
            final visible = docs.take(8).toList();
            if (visible.isEmpty) return _buildEmptyActivities(context);
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final data = visible[i].data() as Map<String, dynamic>;
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.event_note_outlined,
                  size: 24, color: AppTheme.lightGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No upcoming activities',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen.withOpacity(0.7))),
                  const SizedBox(height: 2),
                  Text('Create an event from the Activities tab',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.38))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent contributions ────────────────────────────────────────────────────

  Widget _buildContributionsSection(BuildContext context) {
    if (_userId == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionHeader(
            title: 'My contributions',
            actionLabel: 'View all →',
            onAction: () {},
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<QuerySnapshot>(
            // No orderBy — avoids composite index. Sort client-side.
                stream: FirebaseFirestore.instance
                .collection('contributions')
                .where('userId', isEqualTo: _userId)
                .snapshots(),
            builder: (context, snapshot) {
              debugPrint('[Dash contributions] state=${snapshot.connectionState} '
                  'hasData=${snapshot.hasData} '
                  'docs=${snapshot.data?.docs.length} '
                  'error=${snapshot.error}');
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Column(
                  children: List.generate(
                    3,
                    (i) => ContributionPlaceholders.buildPlaceholderCard(
                        context, i),
                  ),
                );
              }
              if (snapshot.hasError) {
                debugPrint('[Dash contributions] ERROR: ${snapshot.error}');
                return _buildEmptyContributions(context);
              }
              final allDocs = snapshot.data?.docs ?? [];
              final sorted = List.of(allDocs)
                ..sort((a, b) {
                  final at = (a.data() as Map)['createdAt'];
                  final bt = (b.data() as Map)['createdAt'];
                  if (at is Timestamp && bt is Timestamp) {
                    return bt.compareTo(at);
                  }
                  return 0;
                });
              final visible = sorted.take(5).toList();
              if (visible.isEmpty) return _buildEmptyContributions(context);
              return Column(
                children: visible.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ContributionCard(
                      contribution: {...data, 'id': doc.id});
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyContributions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.volunteer_activism_outlined,
                size: 24, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No contributions yet',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen.withOpacity(0.7))),
                const SizedBox(height: 2),
                Text('Tap "Log Work" above to record your first one',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.38))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live attention strip
// ─────────────────────────────────────────────────────────────────────────────

class _LiveAttentionStrip extends StatefulWidget {
  final String orgId;
  final Organization org;
  const _LiveAttentionStrip({required this.orgId, required this.org});

  @override
  State<_LiveAttentionStrip> createState() => _LiveAttentionStripState();
}

class _LiveAttentionStripState extends State<_LiveAttentionStrip> {
  final _db = FirebaseFirestore.instance;

  int _pendingRsvps              = 0;
  int _eventsAwaitingVerification = 0;
  int _unreadEnquiries           = 0;
  int _pendingPartners           = 0;

  final List<dynamic> _subs = [];

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final orgId = widget.orgId;
    final caps  = widget.org.capabilities;

    if (caps.contains(OrgCapability.volunteers)) {
      _subs.add(_db
          .collection('volunteerRsvps')
          .where('orgId', isEqualTo: orgId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
              (s) { if (mounted) setState(() => _pendingRsvps = s.docs.length); }));
    }

    if (caps.contains(OrgCapability.events)) {
      _subs.add(_db
          .collection('activities')
          .where('orgId', isEqualTo: orgId)
          .snapshots()
          .listen((s) {
        final count = s.docs
            .where((d) =>
                (d.data() as Map)['impactStatus'] == 'pending')
            .length;
        if (mounted) setState(() => _eventsAwaitingVerification = count);
      }));
    }

    if (caps.contains(OrgCapability.programmes)) {
      _subs.add(_db
          .collection('programme_enquiries')
          .where('orgId', isEqualTo: orgId)
          .where('status', isEqualTo: 'unread')
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _unreadEnquiries = s.docs.length);
      }));
    }

    if (caps.contains(OrgCapability.partners)) {
      _subs.add(_db
          .collection('orgPartners')
          .where('orgId', isEqualTo: orgId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _pendingPartners = s.docs.length);
      }));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  List<_AttentionItem> _buildItems() {
    final caps  = widget.org.capabilities;
    final items = <_AttentionItem>[];

    if (caps.contains(OrgCapability.volunteers) && _pendingRsvps > 0) {
      items.add(_AttentionItem(
        type: _AttentionType.action,
        icon: Icons.how_to_reg_outlined,
        message:
            '$_pendingRsvps volunteer RSVP${_pendingRsvps == 1 ? '' : 's'} pending review',
        actionLabel: 'Review',
        route: '/volunteerManagement',
      ));
    }
    if (caps.contains(OrgCapability.events) &&
        _eventsAwaitingVerification > 0) {
      items.add(_AttentionItem(
        type: _AttentionType.action,
        icon: Icons.task_alt,
        message:
            '$_eventsAwaitingVerification event${_eventsAwaitingVerification == 1 ? '' : 's'} awaiting verification',
        actionLabel: 'Verify',
        route: '/allActivities',
      ));
    }
    if (caps.contains(OrgCapability.programmes) && _unreadEnquiries > 0) {
      items.add(_AttentionItem(
        type: _AttentionType.action,
        icon: Icons.mark_email_unread_outlined,
        message:
            '$_unreadEnquiries unread programme enquir${_unreadEnquiries == 1 ? 'y' : 'ies'}',
        actionLabel: 'View',
        route: '/allActivities',
      ));
    }
    if (caps.contains(OrgCapability.partners) && _pendingPartners > 0) {
      items.add(_AttentionItem(
        type: _AttentionType.info,
        icon: Icons.handshake_outlined,
        message:
            '$_pendingPartners pending partner request${_pendingPartners == 1 ? '' : 's'}',
        actionLabel: 'Respond',
        route: '/partnerOrgs',
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppTheme.primary, size: 18),
            const SizedBox(width: 10),
            Text('All caught up',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
            const SizedBox(width: 4),
            Expanded(
              child: Text('· nothing needs your attention right now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.4))),
            ),
          ],
        ),
      );
    }

    final actionCount =
        items.where((i) => i.type == _AttentionType.action).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Needs attention',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                    letterSpacing: 0.2)),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppTheme.tertiary,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$actionCount',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            itemBuilder: (context, i) => _AttentionCard(
              item: items[i],
              onTap: () =>
                  Navigator.of(context).pushNamed(items[i].route),
            ),
          ),
        ),
      ],
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
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.1), size.width * 0.38, p);
    p
      ..color = const Color(0xFF3B8A7A).withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(
        Offset(size.width * 0.08, size.height * 0.75), size.width * 0.25, p);
    p
      ..color = const Color(0xFFC4A961).withOpacity(0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(
        Offset(size.width * 0.55, size.height * 0.45), size.width * 0.15, p);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = null;
    ring.color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.6), 80, ring);
    ring.color = Colors.white.withOpacity(0.03);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.6), 130, ring);
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
  final VoidCallback? onAddLogo;
  const _OrgAvatar({required this.initials, this.logoUrl, this.onAddLogo});

  bool get _hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: !_hasLogo ? onAddLogo : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppTheme.tertiary.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.tertiary.withOpacity(0.2),
                    blurRadius: 14)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _hasLogo
                  ? Image.network(logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback())
                  : _fallback(),
            ),
          ),
          if (!_hasLogo)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                    color: AppTheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)),
                child: const Icon(Icons.add, size: 11, color: Colors.white),
              ),
            ),
        ],
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NotifButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
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
                width: 6,
                height: 6,
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
                  fontSize: 16,
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
                      fontSize: 9,
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
                fontSize: 16,
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
    final accent   = isAction ? AppTheme.tertiary : AppTheme.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
                color: accent.withOpacity(0.09),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(item.icon, size: 15, color: accent),
                ),
                const Spacer(),
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: isAction ? accent : accent.withOpacity(0.3),
                        shape: BoxShape.circle)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.message,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text('${item.actionLabel} →',
                      style: TextStyle(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w700)),
                ],
              ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -14,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.08)),
              ),
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1,
                              letterSpacing: -1)),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, size: 13, color: color),
                      ),
                    ],
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen.withOpacity(0.55),
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
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
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
    final status         = activity['status']          as String? ?? 'upcoming';
    final impactStatus   = activity['impactStatus']    as String? ?? 'unverified';
    final name           = activity['name']            as String? ?? 'Untitled activity';
    final location       = activity['location']        as String? ?? '';
    final participants   = activity['participants']    as int?    ?? 0;
    final maxParticipants= activity['maxParticipants'] as int?    ?? 0;
    final date           = _parseDate(activity['date']);
    final isOngoing      = status == 'ongoing';

    late Color opColor;
    late String opLabel;
    switch (status) {
      case 'ongoing':
        opColor = AppTheme.tertiary; opLabel = 'Ongoing';
        break;
      case 'completed':
        opColor = AppTheme.accent;   opLabel = 'Completed';
        break;
      default:
        opColor = AppTheme.secondary; opLabel = 'Upcoming';
    }

    late Color impactColor;
    late String impactLabel;
    switch (impactStatus) {
      case 'pending':
        impactColor = AppTheme.tertiary; impactLabel = 'Pending';
        break;
      case 'confirmed':
        impactColor = AppTheme.primary;  impactLabel = 'Verified ✓';
        break;
      default:
        impactColor = AppTheme.lightGreen; impactLabel = 'Unverified';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isOngoing
              ? Border.all(color: AppTheme.tertiary.withOpacity(0.25))
              : null,
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Thumbnail with date overlay
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    'https://picsum.photos/seed/${(name.hashCode.abs() % 100) + imageSeed * 7}/76/82',
                    width: 76,
                    height: 82,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, prog) => prog == null
                        ? child
                        : Container(
                            width: 76,
                            height: 82,
                            color: AppTheme.lightGreen.withOpacity(0.15)),
                    errorBuilder: (_, __, ___) => Container(
                      width: 76,
                      height: 82,
                      color: AppTheme.lightGreen.withOpacity(0.12),
                      child: Icon(Icons.eco_outlined,
                          color: AppTheme.lightGreen.withOpacity(0.5),
                          size: 26),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
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
                                  fontSize: 15,
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
                padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 10,
                              color: AppTheme.darkGreen.withOpacity(0.38)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(location,
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        AppTheme.darkGreen.withOpacity(0.4)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
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
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$participants',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          height: 1)),
                  Text('/ $maxParticipants',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.darkGreen.withOpacity(0.35),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Icon(Icons.arrow_forward_ios,
                      size: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: filled ? Colors.transparent : color.withOpacity(0.3),
            width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick action card — same visual language as community home
// ─────────────────────────────────────────────────────────────────────────────

class _DashQuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _DashQuickAction({
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
        height: 90,
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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 13),
              ),
            ],
          ),
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
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.lightGreen.withOpacity(0.18),
                    AppTheme.accent.withOpacity(0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon,
                  size: 32, color: AppTheme.lightGreen.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            Text('Coming soon',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.6))),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkGreen.withOpacity(0.35))),
          ],
        ),
      ),
    );
  }
}
