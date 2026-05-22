import 'package:flutter/material.dart';
import '../../Shared/theme/app_theme.dart';
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
    _NavDestination(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    _NavDestination(
      icon: Icons.people_outline,
      activeIcon: Icons.people_rounded,
      label: 'People',
    ),
    _NavDestination(
      icon: Icons.bolt_outlined,
      activeIcon: Icons.bolt_rounded,
      label: 'Operations',
    ),
    _NavDestination(
      icon: Icons.pending_actions,
      activeIcon: Icons.pending_actions_rounded,
      label: 'Programmes',
    ),
    _NavDestination(
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
      const OrgProfile(),
    ];

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        bottomNavigationBar: _FloatingNavBar(
          currentIndex: _index,
          destinations: _destinations,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

// NAV DESTINATION MODEL
@immutable
class _NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// FLOATING NAV BAR - Elegant & Minimal
// FLOATING NAV BAR - Clean White / Glass Style
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(999), // Fully pill shape
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppTheme.darkGreen.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (i) {
              final dest = destinations[i];
              return Expanded(
                child: _NavItem(
                  icon: dest.icon,
                  activeIcon: dest.activeIcon,
                  label: dest.label,
                  isSelected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// NAV ITEM - Elegant & Sharp
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected
                  ? AppTheme.tertiary
                  : AppTheme.darkGreen.withOpacity(0.65),
            ),

            const SizedBox(height: 3),

            // Label
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.65,
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.darkGreen
                      : AppTheme.darkGreen.withOpacity(0.7),
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
