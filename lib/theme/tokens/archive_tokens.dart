// archive_tokens.dart — Cultural Archive (org side)
// Builds on ../canopy_tokens.dart. Every value used by this area's screens resolves here or in core.

import 'package:flutter/material.dart';
import '../canopy_tokens.dart';

// ───────────────────────────────────────────────────────────── Cultural Archive (org side)

/// Workspace uses CanopyPalette (light/dark) — the parchment theme is retired.
/// Content-type colours come ONLY from HeritageCategory.text(afternoon in light, dusk in dark).
enum ArchiveVisibility { public, communityOnly, restricted, sealed }

class CanopyArchive {
  /// Glyph + word + colour, never colour alone. Icons: visibility, groups, shield, lock (Material Symbols Outlined).
  static Color visibilityColor(ArchiveVisibility v, CanopyPalette p) {
    switch (v) {
      case ArchiveVisibility.public: return p.success;
      case ArchiveVisibility.communityOnly: return p.info;
      case ArchiveVisibility.restricted: return p.warning;
      case ArchiveVisibility.sealed: return p.ink;
    }
  }
  static const restrictionFieldBorder = 1.5; // warning inset border, radius 14
  static const coverRing = 2.5; // ink ring on the cover image in the media grid
  static const creatorSteps = ['Type', 'Locality', 'Name', 'Knowledge', 'Media', 'Visibility'];
}
