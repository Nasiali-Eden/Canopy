import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Shared/theme/app_theme.dart';
import 'Heritage/Archive/heritage_archive_screen.dart';
import 'Heritage/Feedback/heritage_feedback_screen.dart';
import 'Heritage/Disputes/heritage_disputes_screen.dart';
import 'Heritage/Connections/heritage_connections_screen.dart';
import 'Heritage/Media/heritage_media_screen.dart';
import 'Heritage/heritage_theme.dart';
import 'Heritage/Services/heritage_providers.dart';

/// CultureHomeScreen — Main entry point for Cultural Archive (Layer 4)
/// Contains the five Heritage screens accessed via bottom navigation bar
class CultureHomeScreen extends StatefulWidget {
  final String orgId;

  const CultureHomeScreen({
    required this.orgId,
    Key? key,
  }) : super(key: key);

  @override
  State<CultureHomeScreen> createState() => _CultureHomeScreenState();
}

class _CultureHomeScreenState extends State<CultureHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HeritageArchiveScreen(orgId: widget.orgId),
      HeritageFeedbackScreen(orgId: widget.orgId),
      HeritageDisputesScreen(orgId: widget.orgId),
      HeritageConnectionsScreen(orgId: widget.orgId),
      HeritageMediaScreen(orgId: widget.orgId),
    ];

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
          backgroundColor: HeritageTheme.heritageBackground,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppTheme.darkGreen,
          centerTitle: true,
        ),
        body: pages[_currentIndex],
        floatingActionButton: _currentIndex == 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  // TODO: Open contribute entry flow
                },
                backgroundColor: AppTheme.tertiary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Add to Archive'),
              )
            : null,
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
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) =>
                  setState(() => _currentIndex = index),
              indicatorColor: AppTheme.primary.withOpacity(0.15),
              height: 70,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.archive_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.50)),
                  selectedIcon: Icon(Icons.archive, color: AppTheme.primary),
                  label: 'Archive',
                ),
                NavigationDestination(
                  icon: Icon(Icons.feedback_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.50)),
                  selectedIcon: Icon(Icons.feedback, color: AppTheme.primary),
                  label: 'Feedback',
                ),
                NavigationDestination(
                  icon: Icon(Icons.gavel_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.50)),
                  selectedIcon: Icon(Icons.gavel, color: AppTheme.primary),
                  label: 'Disputes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.link_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.50)),
                  selectedIcon: Icon(Icons.link, color: AppTheme.primary),
                  label: 'Connections',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined,
                      color: AppTheme.darkGreen.withOpacity(0.50)),
                  selectedIcon:
                      Icon(Icons.photo_library, color: AppTheme.primary),
                  label: 'Media',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
