// lib/Shared/widgets/canopy_bottom_bar.dart
//
// The single bottom navigation bar for every shell in the app.
//
// It replaces four separate implementations that had drifted apart:
//   • _FloatingNavBar in community_home.dart  — floating pill, white @80%
//   • _FloatingNavBar in org_home.dart        — floating pill, white @85%, 2 shadows
//   • FloatingNavBar in Shared/widgets/       — solid + frosted variants
//   • NavigationBar (Material 3) in market_home.dart — different height, different metrics
//
// All four floated clear of the bottom edge, which forced `extendBody: true`
// on each shell and hand-tuned `bottom: 78` / `bottom: 90` offsets on every FAB
// and scroll view underneath them. Those offsets were maintained by hand and
// were already inconsistent between screens.
//
// This bar is FIXED: full width, flush to the bottom edge, seated inside the
// scaffold's own bottom inset. Shells no longer set extendBody, and content
// underneath no longer needs to dodge anything.
//
// The frosted variant survives for the immersive Heritage / Culture surfaces
// that render over a full-bleed background — but it is now flush too, a
// translucent bar rather than a floating pill.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

@immutable
class CanopyNavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Optional count rendered as a badge — unanswered buy orders, unread
  /// notifications. Null or 0 renders nothing.
  final int? badgeCount;

  const CanopyNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

class CanopyBottomBar extends StatelessWidget {
  final int currentIndex;
  final List<CanopyNavDestination> destinations;
  final ValueChanged<int> onTap;

  /// Colour of the selected icon. Defaults to the brand gold accent.
  final Color selectedColor;

  /// Translucent bar for immersive surfaces that render over a full-screen
  /// background. Still flush to the bottom edge — not a floating pill.
  final bool frosted;

  const CanopyBottomBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    this.selectedColor = AppTheme.tertiary,
    this.frosted = false,
  });

  /// Height of the bar's content, excluding the device's bottom safe-area
  /// inset. Screens that need to reserve space for it (a sticky action row,
  /// say) should use `CanopyBottomBar.heightFor(context)`.
  static const double contentHeight = 60;

  static double heightFor(BuildContext context) =>
      contentHeight + MediaQuery.of(context).padding.bottom;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: contentHeight,
      child: Row(
        children: List.generate(destinations.length, (i) {
          final dest = destinations[i];
          return Expanded(
            child: _NavItem(
              destination: dest,
              isSelected: i == currentIndex,
              selectedColor: selectedColor,
              frosted: frosted,
              onTap: () => onTap(i),
            ),
          );
        }),
      ),
    );

    return frosted ? _frostedShell(row) : _solidShell(context, row);
  }

  Widget _solidShell(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final bg = theme.brightness == Brightness.dark
        ? theme.scaffoldBackgroundColor
        : Colors.white;

    return Material(
      color: bg,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(
              color: AppTheme.darkGreen.withOpacity(0.10),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(top: false, child: child),
      ),
    );
  }

  Widget _frostedShell(Widget child) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.42),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.16), width: 0.8),
            ),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final CanopyNavDestination destination;
  final bool isSelected;
  final Color selectedColor;
  final bool frosted;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.selectedColor,
    required this.frosted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color unselectedIcon = frosted
        ? Colors.white.withOpacity(0.68)
        : AppTheme.darkGreen.withOpacity(0.55);
    final Color labelColor =
        frosted ? Colors.white : AppTheme.darkGreen.withOpacity(0.9);
    final count = destination.badgeCount ?? 0;

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: InkResponse(
        onTap: onTap,
        radius: 42,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    isSelected ? destination.activeIcon : destination.icon,
                    key: ValueKey(isSelected),
                    size: 24,
                    color: isSelected ? selectedColor : unselectedIcon,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -3,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: frosted ? Colors.black26 : Colors.white,
                            width: 1.4),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8.5,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? labelColor : unselectedIcon,
                letterSpacing: -0.1,
              ),
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
