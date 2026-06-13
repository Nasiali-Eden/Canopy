// lib/Shared/widgets/floating_nav_bar.dart
//
// Shared floating "pill" bottom navigation — the same design used by the
// Organization home shell. Reused across Env-Ops and Cultural shells so the
// app has one consistent bottom bar.
//
// Two looks, one widget:
//   • default  — solid white pill (Home / Org / Env-Ops).
//   • frosted  — translucent BackdropFilter glass pill, for the immersive
//     Heritage / Culture surfaces that float over a full-screen background.

import 'dart:ui' as ui;

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

  /// When true, render a translucent frosted-glass pill (BackdropFilter) with
  /// light-on-dark icons instead of the solid white pill. Used by the immersive
  /// Heritage / Culture shells so the bar reads over a full-screen background.
  final bool frosted;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    this.selectedColor = AppTheme.tertiary,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    // NOTE: no Align/Expanded wrapper here — in the Scaffold.bottomNavigationBar
    // slot that would stretch the bar to full height, pushing floating
    // SnackBars off screen. This sizes to its own content instead.
    final row = Row(
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
            frosted: frosted,
            onTap: () => onTap(i),
          ),
        );
      }),
    );

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: frosted ? _frostedShell(row) : _solidShell(row),
      ),
    );
  }

  Widget _solidShell(Widget child) {
    return Container(
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
      child: child,
    );
  }

  Widget _frostedShell(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.30),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
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
  final bool frosted;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.frosted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color unselectedIcon = frosted
        ? Colors.white.withOpacity(0.7)
        : AppTheme.darkGreen.withOpacity(0.65);
    final Color labelColor = frosted ? Colors.white : AppTheme.darkGreen;

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
              color: isSelected ? selectedColor : unselectedIcon,
            ),
            const SizedBox(height: 3),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
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
