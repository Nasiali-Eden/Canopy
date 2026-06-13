// lib/Shared/theme/glass.dart
//
// Reusable "glass" design system shared across Home, Heritage and Culture.
//
// Design language (generalised from Organization/Explorer/view_commons.dart so
// it lives in Shared and carries no dependency on the Explorer module):
//   • A full-bleed ambient background (cover image, darkened with a vertical
//     gradient, or an elegant gradient when no image is present — NEVER an emoji
//     stand-in, per the overhaul's no-placeholder principle).
//   • Translucent BackdropFilter "glass" cards / panels float over it.
//   • Tasteful empty states ("nothing yet — check back later") instead of
//     invented filler.
//
// This file is the single source of truth for the glass look. New Heritage /
// Culture screens import THIS, not view_commons.dart.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE — accents tuned for the cultural/glass surfaces
// ─────────────────────────────────────────────────────────────────────────────

class GlassPalette {
  GlassPalette._();

  /// Deep base used behind ambient backgrounds and as the scrim floor.
  static const Color base = Color(0xFF0B0F0D);

  /// Default warm gold accent (matches AppTheme.tertiary brand gold).
  static const Color accent = AppTheme.tertiary;

  /// Neutral translucent fills for cards on top of the ambient layer.
  static Color cardFill([double opacity = 0.09]) =>
      Colors.white.withOpacity(opacity);

  static Color cardBorder([double opacity = 0.16]) =>
      Colors.white.withOpacity(opacity);

  /// A two-stop gradient derived from a tint — used when an image is absent.
  static LinearGradient tintedGradient(Color tint) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(tint, Colors.black, 0.25)!,
          base,
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS BACKGROUND — full-screen ambient layer (image + scrim, or gradient)
// ─────────────────────────────────────────────────────────────────────────────

/// A full-screen ambient backdrop. If [imageUrl] resolves it is shown full-bleed
/// (blurred + darkened for legibility); otherwise an elegant [tint] gradient is
/// used. No emoji / decorative stand-ins are ever rendered here.
class GlassBackground extends StatelessWidget {
  final String? imageUrl;
  final Color tint;

  /// How strongly the lower portion is darkened (0..1). Higher = darker floor.
  final double scrim;

  /// Ambient blur applied over the whole image layer.
  final double blur;

  const GlassBackground({
    super.key,
    this.imageUrl,
    this.tint = GlassPalette.accent,
    this.scrim = 0.92,
    this.blur = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _GradientFill(tint: tint),
              placeholder: (_, __) => _GradientFill(tint: tint),
            )
          else
            _GradientFill(tint: tint),
          if (blur > 0)
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: const SizedBox.expand(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.55),
                  GlassPalette.base.withOpacity(scrim),
                  GlassPalette.base,
                ],
                stops: const [0.0, 0.32, 0.66, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientFill extends StatelessWidget {
  final Color tint;
  const _GradientFill({required this.tint});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: GlassPalette.tintedGradient(tint)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS CARD — frosted translucent container
// ─────────────────────────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.blur = 18,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? GlassPalette.cardFill(),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? GlassPalette.cardBorder()),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS PANEL — titled section wrapped in a glass card (used by upload steps)
// ─────────────────────────────────────────────────────────────────────────────

class GlassPanel extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color accent;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassPanel({
    super.key,
    this.title,
    this.icon,
    this.accent = GlassPalette.accent,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withOpacity(0.4)),
                    ),
                    child: Icon(icon, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION TITLE — white heading with optional count + "See all"
// ─────────────────────────────────────────────────────────────────────────────

class GlassSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? count;
  final Color accent;
  final VoidCallback? onSeeAll;

  const GlassSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.count,
    this.accent = GlassPalette.accent,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Show all',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 16, color: Colors.white.withOpacity(0.72)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE — tasteful "nothing yet" message (NEVER invented content)
// ─────────────────────────────────────────────────────────────────────────────

/// Inline empty state for a single section (a glass row).
class GlassEmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const GlassEmptyCard({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        color: Colors.white.withOpacity(0.05),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen / large empty state shown when a whole screen has no data.
class GlassEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const GlassEmptyState({
    super.key,
    this.icon = Icons.hourglass_empty_rounded,
    this.title = 'Nothing here yet',
    this.message = 'Check back later — new content appears as soon as it\'s added.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Icon(icon, color: Colors.white.withOpacity(0.6), size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRCLE GLASS BUTTON — floating back / action control over a background
// ─────────────────────────────────────────────────────────────────────────────

class CircleGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const CircleGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.30),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}
