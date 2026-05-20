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
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
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

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomPadding + 16,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.darkGreen,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGreen.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(destinations.length, (i) {
            final dest = destinations[i];
            final isSelected = i == currentIndex;
            return Expanded(
              child: _NavItem(
                icon: dest.icon,
                activeIcon: dest.activeIcon,
                label: dest.label,
                isSelected: isSelected,
                onTap: () => onTap(i),
              ),
            );
          }),
        ),
      ),
    );
  }
}

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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 0,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: isSelected
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(activeIcon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        )
            : Center(
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.55),
            size: 22,
          ),
        ),
      ),
    );
  }
}