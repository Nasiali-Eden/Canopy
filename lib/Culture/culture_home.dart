import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/floating_nav_bar.dart';
import 'Heritage/Archive/heritage_archive_screen.dart';
import 'Heritage/Create/create_entry_screen.dart';
import 'Heritage/Feedback/heritage_feedback_screen.dart';
import 'Heritage/Profile/cultural_org_profile_page.dart';
import 'Heritage/heritage_theme.dart';
import 'Heritage/Services/heritage_providers.dart';

/// CultureHomeScreen — Layer 4 Cultural Archive
/// 4-tab layout: Archive | Add Entry | Feedback | Profile
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
  // 0=Archive  2=Feedback  3=Profile  (index 1 = Add → pushes CreateEntryScreen)
  int _selectedNavIndex = 0;

  void _handleNavTap(int navIndex) {
    if (navIndex == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateEntryScreen(orgId: widget.orgId),
        ),
      );
      return;
    }
    setState(() => _selectedNavIndex = navIndex);
  }

  Widget _buildCurrentPage() {
    switch (_selectedNavIndex) {
      case 2:
        return HeritageFeedbackScreen(orgId: widget.orgId);
      case 3:
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

  @override
  Widget build(BuildContext context) {
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
          currentIndex: _selectedNavIndex,
          onTap: _handleNavTap,
          destinations: const [
            FloatingNavDestination(
                icon: Icons.archive_outlined,
                activeIcon: Icons.archive,
                label: 'Archive'),
            FloatingNavDestination(
                icon: Icons.add_circle_outline,
                activeIcon: Icons.add_circle,
                label: 'Add Entry'),
            FloatingNavDestination(
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum,
                label: 'Feedback'),
            FloatingNavDestination(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
