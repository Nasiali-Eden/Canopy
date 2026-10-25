// lib/Organization/Home/org_home.dart
//
// Organisation workspace shell (ORG_HANDOFF §1): Dashboard · People ·
// Operations · Programmes · Profile. [OrgShellScope] lets any screen in the
// workspace jump to a tab (and a sub-tab, e.g. Operations → Partners) —
// the dashboard's "Needs you" rows use it.

import 'package:flutter/material.dart';

import '../../Shared/widgets/canopy_bottom_bar.dart';
import '../../theme/canopy_components.dart';
import 'Dashboard/org_dashboard.dart';
import 'Operations/org_operations.dart';
import 'People/org_people.dart';
import 'Profile/org_profile.dart';
import 'Programmes/org_programmes.dart';

class OrgTab {
  static const dashboard = 0, people = 1, operations = 2, programmes = 3, profile = 4;
}

class OrgShellScope extends InheritedWidget {
  final void Function(int tab, {String? sub}) goTo;
  final ValueNotifier<String?> subTab;
  const OrgShellScope({super.key, required this.goTo, required this.subTab, required super.child});

  static OrgShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrgShellScope>();

  @override
  bool updateShouldNotify(OrgShellScope old) => false;
}

class OrganizationHome extends StatefulWidget {
  const OrganizationHome({super.key});

  @override
  State<OrganizationHome> createState() => _OrganizationHomeState();
}

class _OrganizationHomeState extends State<OrganizationHome> {
  int _index = 0;
  final _subTab = ValueNotifier<String?>(null);

  static const _destinations = [
    CanopyNavDestination(
        icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard, label: 'Dashboard'),
    CanopyNavDestination(icon: Icons.people_outline, activeIcon: Icons.people, label: 'People'),
    CanopyNavDestination(icon: Icons.bolt_outlined, activeIcon: Icons.bolt, label: 'Operations'),
    CanopyNavDestination(
        icon: Icons.pending_actions_outlined, activeIcon: Icons.pending_actions, label: 'Programmes'),
    CanopyNavDestination(icon: Icons.apartment_outlined, activeIcon: Icons.apartment, label: 'Profile'),
  ];

  @override
  void dispose() {
    _subTab.dispose();
    super.dispose();
  }

  void _goTo(int tab, {String? sub}) {
    setState(() => _index = tab);
    _subTab.value = sub;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OrgDashboard(),
      const OrgPeopleScreen(),
      const OrgOperations(),
      const OrgProgrammes(),
      OrgProfile(orgHomeBuilder: (_) => const OrganizationHome()),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _goTo(0);
      },
      child: OrgShellScope(
        goTo: _goTo,
        subTab: _subTab,
        child: Scaffold(
          backgroundColor: context.canopy.canvas,
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: CanopyBottomBar(
            currentIndex: _index,
            destinations: _destinations,
            onTap: (i) => _goTo(i),
          ),
        ),
      ),
    );
  }
}
