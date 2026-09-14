// lib/Shared/widgets/image_caption_overlay.dart
//
// Roadmap Phase 1.3 ("Image treatment — gradient overlay, org name, Est.
// year"): every image used as a card/hero — post cards, org detail hero,
// marketplace listing photos — gets a bottom-up black gradient, tall enough
// to carry two lines of white text and no taller: the org/creator name, and
// a date line (or "Est. <year founded>" where that applies).
//
// Overlay text uses DM Sans at a semibold weight per the roadmap's font
// recommendation (small, high-contrast, over a photo — holds up better than
// Playfair Display at thumbnail size; keeps continuity with Canopy's other
// documents rather than introducing a fourth typeface).
//
// NOTE: 'DM Sans' isn't currently bundled as an app asset font or pulled in
// via google_fonts (pubspec has no font declarations) — this uses the
// fontFamily string knowing it may fall back to the theme default (Roboto)
// until that's wired up. See IMPLEMENTATION_NOTES_PHASE1_UI.md.

import 'package:flutter/material.dart';

const String kOverlayFontFamily = 'DM Sans';

/// Bottom-up gradient scrim, sized to legibly carry [name] and an optional
/// [dateLabel] (already-formatted — e.g. from `timeAgo()`, or "Est. 2019").
/// Tap the whole caption via [onTap] (e.g. to open an org profile).
class ImageCaptionOverlay extends StatelessWidget {
  final String name;
  final String? dateLabel;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const ImageCaptionOverlay({
    super.key,
    required this.name,
    this.dateLabel,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(12, 24, 12, 10),
  });

  @override
  Widget build(BuildContext context) {
    if (name.trim().isEmpty) return const SizedBox.shrink();
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.62),
          ],
          stops: const [0.0, 0.85],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kOverlayFontFamily,
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
          ),
          if (dateLabel != null && dateLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dateLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kOverlayFontFamily,
                color: Colors.white.withOpacity(0.82),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: content)
          : content,
    );
  }
}
