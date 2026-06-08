// lib/Organization/Explorer/view_commons.dart
//
// Shared building blocks for the immersive, "cover-image-as-background"
// organisation / programme / event view screens.
//
// Design language (mirrors the concept):
//   • Full-bleed cover image as an ambient background, darkened with a vertical
//     gradient so white text and frosted-glass cards read cleanly over it.
//   • Translucent BackdropFilter "glass" cards float over that background.
//   • Floating pill controls (back / actions), echoing the org_home nav bar.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTOR COLOR (public — shared across explorer + view screens)
// ─────────────────────────────────────────────────────────────────────────────

Color sectorColorOf(String sectorId) {
  const map = {
    'sector_env': Color(0xFF2E7D32),
    'sector_social': Color(0xFFC62828),
    'sector_health': Color(0xFF00695C),
    'sector_education': Color(0xFF1565C0),
    'sector_economic': Color(0xFFE65100),
    'sector_community': Color(0xFF5C6BC0),
    'sector_faith': Color(0xFF4E342E),
    'sector_legal': Color(0xFF455A64),
  };
  return map[sectorId] ?? AppTheme.primary;
}

String sectorLabelOf(String sectorId) {
  const map = {
    'sector_env': 'Environmental',
    'sector_social': 'Social Services',
    'sector_health': 'Health & Medical',
    'sector_education': 'Education',
    'sector_economic': 'Economic',
    'sector_legal': 'Legal Aid',
    'sector_faith': 'Faith-Based',
    'sector_community': 'Community',
  };
  return map[sectorId] ?? 'Organisation';
}

// ─────────────────────────────────────────────────────────────────────────────
// IMMERSIVE BACKGROUND — cover image filling the screen + dark gradient
// ─────────────────────────────────────────────────────────────────────────────

class ImmersiveBackground extends StatelessWidget {
  final String? imageUrl;
  final Color tint;

  const ImmersiveBackground({super.key, this.imageUrl, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base cover image (or gradient fallback)
          if (imageUrl != null && imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _GradientFill(tint: tint),
              placeholder: (_, __) => _GradientFill(tint: tint),
            )
          else
            _GradientFill(tint: tint),

          // Soft blur over the whole ambient layer for depth
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: const SizedBox.expand(),
          ),

          // Dark vertical scrim — keeps the top crisp, body legible
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.55),
                  const Color(0xFF0B0F0D).withOpacity(0.92),
                  const Color(0xFF0B0F0D),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(tint, Colors.black, 0.25)!,
            const Color(0xFF0B0F0D),
          ],
        ),
      ),
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
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.blur = 18,
    this.color,
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
            color: color ?? Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
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
// SECTION TITLE — white heading with optional trailing action
// ─────────────────────────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? count;
  final Color accent;
  final VoidCallback? onSeeAll;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.count,
    required this.accent,
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
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
              child: Text(
                'See all',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CATEGORY PLACEHOLDER — frosted card shown when a section has no items
// ─────────────────────────────────────────────────────────────────────────────

class EmptyCategoryCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyCategoryCard({super.key, required this.icon, required this.message});

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

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING CIRCLE BUTTON — back / share / etc. over the cover
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

// ─────────────────────────────────────────────────────────────────────────────
// HORIZONTAL MEDIA CARD — image + text, used for programmes / events
// ─────────────────────────────────────────────────────────────────────────────

class MediaPosterCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String? badge;
  final Color accent;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const MediaPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.accent,
    required this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 116,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _posterFallback(accent, fallbackIcon),
                      placeholder: (_, __) =>
                          _posterFallback(accent, fallbackIcon),
                    )
                  else
                    _posterFallback(accent, fallbackIcon),
                  if (badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Text
            Expanded(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    color: Colors.white.withOpacity(0.08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _posterFallback(Color accent, IconData icon) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.black, 0.1)!,
            Color.lerp(accent, Colors.black, 0.5)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withOpacity(0.55), size: 34),
      ),
    );
  }
}
