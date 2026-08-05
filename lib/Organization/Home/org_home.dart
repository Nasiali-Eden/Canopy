import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/widgets/canopy_bottom_bar.dart';
import 'Dashboard/org_dashboard.dart';
import 'People/org_people.dart';
import 'Operations/org_operations.dart';
import 'Programmes/org_programmes.dart';
import 'Profile/org_profile.dart';

class OrganizationHome extends StatefulWidget {
  const OrganizationHome({super.key});

  @override
  State<OrganizationHome> createState() => _OrganizationHomeState();
}

class _OrganizationHomeState extends State<OrganizationHome> {
  int _index = 0;

  static const _destinations = [
    CanopyNavDestination(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    CanopyNavDestination(
      icon: Icons.people_outline,
      activeIcon: Icons.people_rounded,
      label: 'People',
    ),
    CanopyNavDestination(
      icon: Icons.bolt_outlined,
      activeIcon: Icons.bolt_rounded,
      label: 'Operations',
    ),
    CanopyNavDestination(
      icon: Icons.pending_actions,
      activeIcon: Icons.pending_actions_rounded,
      label: 'Programmes',
    ),
    CanopyNavDestination(
      icon: Icons.business_outlined,
      activeIcon: Icons.business_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OrgDashboard(),
      const OrgPeopleScreen(),
      const OrgOperations(),
      const OrgProgrammes(),
      OrgProfile(orgHomeBuilder: (_) => const OrganizationHome()),
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        bottomNavigationBar: CanopyBottomBar(
          currentIndex: _index,
          destinations: _destinations,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
