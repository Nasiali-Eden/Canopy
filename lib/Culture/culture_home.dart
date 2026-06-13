import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/floating_nav_bar.dart';
import 'Heritage/Archive/heritage_archive_screen.dart';
import 'Heritage/Create/create_entry_screen.dart';
import 'Heritage/Feedback/heritage_feedback_screen.dart';
import 'Heritage/Profile/cultural_org_profile_page.dart';
import 'Heritage/heritage_theme.dart';
import 'Heritage/Services/heritage_providers.dart';

/// CultureHomeScreen — Layer 4 Cultural Archive
///
/// Tabs: Archive | (Add Entry) | Feedback | Profile.
/// The "Add Entry" tab — the only upload entry point — is shown ONLY to the
/// organisation's representative (Q3: uploads are org-only). Regular viewers
/// see a read-only 3-tab shell. Org-rep status is resolved from the org doc's
/// `org_rep_uid` against the signed-in uid.
class CultureHomeScreen extends StatefulWidget {
  final String orgId;
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? envOpsContextBuilder;
  final bool hasEnvOps;

  const CultureHomeScreen({
    required this.orgId,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.envOpsContextBuilder,
    this.hasEnvOps = false,
    Key? key,
  }) : super(key: key);

  @override
  State<CultureHomeScreen> createState() => _CultureHomeScreenState();
}

class _CultureHomeScreenState extends State<CultureHomeScreen> {
  // Selected tab tracked by stable key, since the available tabs depend on
  // whether the current user may upload.
  String _selectedKey = 'archive';

  // null = still resolving; gates the Add Entry tab.
  bool? _isOrgRep;

  @override
  void initState() {
    super.initState();
    _resolveOrgRep();
  }

  Future<void> _resolveOrgRep() async {
    bool isRep = false;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .get();
        final repUid = doc.data()?['org_rep_uid'] as String?;
        isRep = repUid != null && repUid == uid;
      }
    } catch (e) {
      debugPrint('CultureHome org-rep resolve error: $e');
    }
    if (mounted) setState(() => _isOrgRep = isRep);
  }

  /// Keys present in the bottom bar, in display order.
  List<String> get _navKeys =>
      (_isOrgRep ?? false)
          ? const ['archive', 'add', 'feedback', 'profile']
          : const ['archive', 'feedback', 'profile'];

  void _handleNavTap(int navIndex) {
    final key = _navKeys[navIndex];
    if (key == 'add') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateEntryScreen(orgId: widget.orgId),
        ),
      );
      return;
    }
    setState(() => _selectedKey = key);
  }

  Widget _buildCurrentPage() {
    switch (_selectedKey) {
      case 'feedback':
        return HeritageFeedbackScreen(orgId: widget.orgId);
      case 'profile':
        return CulturalOrgProfilePage(
          orgId: widget.orgId,
          orgContextBuilder: widget.orgContextBuilder,
          memberContextBuilder: widget.memberContextBuilder,
          envOpsContextBuilder: widget.envOpsContextBuilder,
          hasEnvOps: widget.hasEnvOps,
        );
      default:
        return HeritageArchiveScreen(orgId: widget.orgId);
    }
  }

  FloatingNavDestination _destFor(String key) {
    switch (key) {
      case 'add':
        return const FloatingNavDestination(
            icon: Icons.add_circle_outline,
            activeIcon: Icons.add_circle,
            label: 'Add Entry');
      case 'feedback':
        return const FloatingNavDestination(
            icon: Icons.forum_outlined,
            activeIcon: Icons.forum,
            label: 'Feedback');
      case 'profile':
        return const FloatingNavDestination(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile');
      case 'archive':
      default:
        return const FloatingNavDestination(
            icon: Icons.archive_outlined,
            activeIcon: Icons.archive,
            label: 'Archive');
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _navKeys;
    // 'add' is an action, never a "current" page, so map selection onto the
    // nearest content tab for the highlight.
    final currentIndex = keys.indexOf(_selectedKey).clamp(0, keys.length - 1);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HeritageEntriesProvider()),
        ChangeNotifierProvider(create: (_) => HeritageCommentsProvider()),
        ChangeNotifierProvider(create: (_) => HeritageCommentsListProvider()),
        ChangeNotifierProvider(create: (_) => HeritageRelationsProvider()),
        ChangeNotifierProvider(create: (_) => HeritageMediaProvider()),
        ChangeNotifierProvider(create: (_) => OrgEntryIdsProvider()),
      ],
      child: Scaffold(
        backgroundColor: HeritageTheme.heritageBackground,
        appBar: AppBar(
          backgroundColor: HeritageTheme.heritageBackground,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppTheme.darkGreen,
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cultural Archive',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cormorant Garamond',
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                'Layer 4 · Heritage',
                style: TextStyle(
                  color: AppTheme.tertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        extendBody: true,
        body: _buildCurrentPage(),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: currentIndex,
          onTap: _handleNavTap,
          destinations: keys.map(_destFor).toList(),
        ),
      ),
    );
  }
}
