// lib/Shared/widgets/canopy_bottom_bar.dart
//
// The single bottom navigation bar for every shell (community, org, market,
// culture, env-ops). v2 (DESIGN_HANDOFF.md §2 BottomNav):
//   solid   — surface, 1px top outline, e1; selected item = surfaceBrand
//             56×32 indicator + filled icon in primaryInk, label in ink.
//   frosted — Heritage glass: `HeritagePalette.glass` + 1px glassLine, blur 20,
//             for chrome floating over a photograph. [transparent] hides it
//             (slides away) while the Heritage page scrolls down.
//
// Solid is flush to the bottom edge; frosted floats (the Heritage shell sets
// extendBody so the photo runs under it).

import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';
import '../../theme/heritage_tone.dart';
import '../../theme/tokens/heritage_tokens.dart';

@immutable
class CanopyNavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Optional count badge (unanswered buy orders, unread notifications).
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

  /// Kept for call-site compatibility; v2 always uses the palette's
  /// primaryInk-on-surfaceBrand selection, so this is ignored.
  final Color? selectedColor;

  /// Heritage glass bar (chrome over a photo).
  final bool frosted;

  /// With [frosted]: hide the bar while the page scrolls down.
  final bool transparent;

  const CanopyBottomBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    this.selectedColor,
    this.frosted = false,
    this.transparent = false,
  });

  static const double contentHeight = 64;

  static double heightFor(BuildContext context) =>
      contentHeight + MediaQuery.of(context).padding.bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    Widget rowFor(HeritageGlass? g) => SizedBox(
          height: contentHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    frosted: frosted,
                    glass: g,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        );

    if (frosted) {
      // Heritage GlassBottomNav: floating, inset 12, radius 22, glass; hides
      // on scroll down, returns on scroll up.
      final hidden = transparent;
      return AnimatedSlide(
        duration: context.reduceMotion ? CanopyMotion.reduced : HeritageMotion.navHide,
        curve: CanopyMotion.standard,
        offset: hidden ? const Offset(0, 1.4) : Offset.zero,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          // Follows the photo behind it: dark glass + light icons over a dark
          // photo, light glass + dark icons over a bright one.
          child: ValueListenableBuilder<bool>(
            valueListenable: HeritageTone.photoDark,
            builder: (context, photoDark, _) {
              final g = HeritageGlass.of(photoDark ? Brightness.dark : Brightness.light);
              final tint = photoDark ? const Color(0xB30E1210) : const Color(0xD9FFFFFF);
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: canopyGlassBlur,
                  child: Container(
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: g.glassBorder),
                    ),
                    child: rowFor(g),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.outline)),
        boxShadow: CanopyElevation.e1(context.brightness),
      ),
      child: SafeArea(top: false, child: rowFor(null)),
    );
  }
}

class _NavItem extends StatelessWidget {
  final CanopyNavDestination destination;
  final bool selected;
  final bool frosted;
  final HeritageGlass? glass;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.frosted,
    required this.onTap,
    this.glass,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final hp = HeritagePalette.of(context.brightness);
    final g = glass;
    final muted = frosted ? (g?.inkMuted ?? hp.inkMuted) : p.inkMuted;
    final ink = frosted ? (g?.ink ?? hp.ink) : p.ink;
    final count = destination.badgeCount ?? 0;

    return Semantics(
      button: true,
      selected: selected,
      label: count > 0 ? '${destination.label}, $count new' : destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: CanopyMotion.tabSwitch,
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? (frosted ? (g?.chipSelected ?? hp.raisedHi) : p.surfaceBrand)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? destination.activeIcon : destination.icon,
                    size: CanopyIconSize.nav,
                    color: selected ? (frosted ? (g?.onChipSelected ?? ink) : p.primaryInk) : muted,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: -2,
                      child: CountBadge(count: count),
                    ),
                ],
              ),
            ),
            const SizedBox(height: CanopySpace.s4),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CanopyType.micro.copyWith(
                fontSize: 11.5,
                color: selected ? ink : muted,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
