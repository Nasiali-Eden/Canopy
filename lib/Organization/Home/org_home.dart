import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';
import 'Dashboard/org_dashboard.dart';
import 'Profile/org_profile.dart';
import 'OurTeam/org_team.dart';
import 'Volunteers/org_volunteers.dart';
import 'Map/org_map.dart';

class OrganizationHome extends StatefulWidget {
  const OrganizationHome({super.key});

  @override
  State<OrganizationHome> createState() => _OrganizationHomeState();
}

class _OrganizationHomeState extends State<OrganizationHome> {
  int _index = 0;

  void _showCreateTeamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Team'),
          content: const Text('Team creation functionality will be implemented here.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement team creation logic
                Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OrgDashboard(),
      const OrgTeam(),
      const OrgVolunteers(),
      const OrgMap(),
      const OrgProfile(),
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
      body: IndexedStack(
          index: _index,
          children: pages,
        ),
        floatingActionButton: _index == 1
            ? FloatingActionButton.extended(
                onPressed: () => _showCreateTeamDialog(context),
                backgroundColor: AppTheme.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Team',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
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
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelTextStyle: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    );
                  }
                  return TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  );
                }),
              ),
              child: NavigationBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  setState(() => _index = i);
                },
                indicatorColor: AppTheme.primary.withOpacity(0.15),
                height: 70,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon: Icon(Icons.dashboard, color: AppTheme.primary),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.groups_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon: Icon(Icons.groups, color: AppTheme.primary),
                    label: 'Team',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.volunteer_activism_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon:
                        Icon(Icons.volunteer_activism, color: AppTheme.primary),
                    label: 'Volunteers',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon: Icon(Icons.map, color: AppTheme.primary),
                    label: 'Map',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.business_outlined,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    selectedIcon: Icon(Icons.business, color: AppTheme.primary),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}