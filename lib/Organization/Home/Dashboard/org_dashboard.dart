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
import '../Programmes/programme_editor.dart';

import 'edit_org_details_screen.dart';
import 'dash_constants.dart';
import 'dash_header.dart';
import 'dash_attention_strip.dart';
import 'dash_widgets.dart';
import 'dash_metrics.dart';
import 'dash_activities.dart';
import 'dash_contributions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OrgDashboard — nested Navigator shell for in-tab routing
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
                title: 'Partner organisations', icon: Icons.handshake_outlined);
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
// Dashboard content — data loading + layout assembly
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
  String? _orgId;
  String? _userId;
  bool _loading = true;
  bool _uploading = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

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

      final userDoc =
          await widget.firestore.collection('Users').doc(user.uid).get();
      if (!mounted || !userDoc.exists) return;

      final orgId =
          (userDoc.data() as Map<String, dynamic>)['orgId'] as String?;
      if (orgId == null) return;

      final orgDoc =
          await widget.firestore.collection('organizations').doc(orgId).get();
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
        _userId = user.uid;
        _orgId = orgId;
        _org = org;
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

  Future<void> _openEditDetails() async {
    if (_orgId == null) return;
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditOrgDetailsScreen(orgId: _orgId!),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _loading = true);
      await _loadData();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: kDashPageBg,
          body: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 130),
            child: FadeTransition(
              opacity: _fadeAnim,
              child:
                  _loading ? _buildLoadingBody(context) : _buildBody(context),
            ),
          ),
        ),
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
    );
  }

  Widget _buildLoadingBody(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: const Center(
        child:
            CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashHeader(
          org: _org,
          orgId: _orgId,
          firestore: widget.firestore,
          onUploadImage: _uploadImage,
          onNotifications: () =>
              Navigator.of(context).pushNamed('/notifications'),
          onEdit: _orgId == null ? null : _openEditDetails,
        ),
        const SizedBox(height: 16),
        if (_orgId != null && _org != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DashAttentionStrip(orgId: _orgId!, org: _org!),
          ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    child: DashQuickAction(
                      title: 'Log Work',
                      icon: Icons.add_circle_outline,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.lightGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (_) => const LogContributionScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DashQuickAction(
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
        ),
        const SizedBox(height: 20),
        DashMetrics(
          orgId: _orgId,
          firestore: widget.firestore,
          onViewReport: () => Navigator.of(context).pushNamed('/impactReport'),
        ),
        const SizedBox(height: 20),
        DashActivities(
          orgId: _orgId,
          firestore: widget.firestore,
          onViewAll: () => Navigator.of(context).pushNamed('/allActivities'),
          onActivityTap: (data) => Navigator.of(context)
              .pushNamed('/activityDetails', arguments: data),
        ),
        const SizedBox(height: 20),
        DashContributions(userId: _userId),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder screen — used by not-yet-built routes
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDashPageBg,
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
          child:
              Divider(height: 1, color: AppTheme.lightGreen.withOpacity(0.2)),
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
                    AppTheme.accent.withOpacity(0.1),
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
                    fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.35))),
          ],
        ),
      ),
    );
  }
}
