// lib/Shared/widgets/floating_nav_bar.dart
//
// Shared floating "pill" bottom navigation — the same design used by the
// Organization home shell. Reused across Env-Ops and Cultural shells so the
// app has one consistent bottom bar.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

@immutable
class FloatingNavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const FloatingNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<FloatingNavDestination> destinations;
  final ValueChanged<int> onTap;

  /// Colour of the selected icon. Defaults to the brand gold accent so it
  /// matches the Organization home bar.
  final Color selectedColor;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    this.selectedColor = AppTheme.tertiary,
  });

  @override
  Widget build(BuildContext context) {
    // NOTE: no Align/Expanded wrapper here — in the Scaffold.bottomNavigationBar
    // slot that would stretch the bar to full height, pushing floating
    // SnackBars off screen. This sizes to its own content instead.
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(999),
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
                  selectedColor: selectedColor,
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
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
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected
                  ? selectedColor
                  : AppTheme.darkGreen.withOpacity(0.65),
            ),
            const SizedBox(height: 3),
            if (isSelected)
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                  letterSpacing: -0.1,
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
