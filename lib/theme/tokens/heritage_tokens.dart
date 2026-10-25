// heritage_tokens.dart — Heritage tab (member-facing)
// Builds on ../canopy_tokens.dart. Every value used by this area's screens resolves here or in core.

import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature, FontVariation;
import '../canopy_tokens.dart';

// ───────────────────────────────────────────────────────────── Heritage sub-theme

/// Heritage follows the app theme: `dusk` in dark mode, `afternoon` in light.
/// Buttons/chips/nav reuse CanopyPalette.dark (dusk) or .light (afternoon)
/// with `canvas/surface/ink*` swapped for the values below.
@immutable
class HeritagePalette {
  const HeritagePalette({
    required this.base, required this.raised, required this.raisedHi,
    required this.outline, required this.outlineStrong,
    required this.ink, required this.inkMuted, required this.inkFaint,
    required this.glass, required this.glassLine,
    required this.scrimTop, required this.scrimBottom, required this.scrimFull,
    required this.isDusk,
  });

  final Color base; // page + the sheet that scrolls over the backdrop
  final Color raised; // cards (solid — never glass)
  final Color raisedHi; // pressed card
  final Color outline, outlineStrong;
  final Color ink, inkMuted, inkFaint;
  final Color glass; // ONLY chrome floating over a photo: app-bar buttons, nav, search over photo
  final Color glassLine; // 1px inner line on glass
  final LinearGradient scrimTop; // 120px, keeps glass buttons readable
  final LinearGradient scrimBottom; // fades photo into base behind the title
  final Color scrimFull; // text mid-photo (empty country state) only
  final bool isDusk;

  static const glassBlur = 20.0; // + saturate 1.2
  static const backdropParallax = 0.4; // photo moves at 40% of scroll, then locks
  static const backdropBlur = 0.0; // never blur backdrops

  static const dusk = HeritagePalette(
    base: Color(0xFF0B0F0D),
    raised: Color(0xFF151C18),
    raisedHi: Color(0xFF1C2520),
    outline: Color(0xFF26302A),
    outlineStrong: Color(0xFF3A463F),
    ink: Color(0xFFEEF2EC), // 17.0:1 on base
    inkMuted: Color(0xFFA9B5AD), // 9.1:1
    inkFaint: Color(0xFF7D8A82), // 5.4:1 — labels only
    glass: Color(0xAD0E1310), // 68% — ink on glass ≥ 5.7:1 even over pure white
    glassLine: Color(0x24EEF2EC),
    scrimTop: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xB80B0F0D), Color(0x000B0F0D)]),
    scrimBottom: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x000B0F0D), Color(0x8C0B0F0D), Color(0xFF0B0F0D)], stops: [0, 0.45, 1]),
    scrimFull: Color(0x9E0B0F0D),
    isDusk: true,
  );

  static const afternoon = HeritagePalette(
    base: Color(0xFFEFEAE0), // parchment
    raised: Color(0xFFF8F5EE),
    raisedHi: Color(0xFFFFFFFF),
    outline: Color(0xFFD9D2C4),
    outlineStrong: Color(0xFFBDB4A3),
    ink: Color(0xFF1B211D),
    inkMuted: Color(0xFF555E58),
    inkFaint: Color(0xFF6A716B),
    glass: Color(0xC2F8F5EE), // 76%
    glassLine: Color(0x1A1B211D),
    scrimTop: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x660B0F0D), Color(0x000B0F0D)]), // stays dark so glass reads
    scrimBottom: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x00EFEAE0), Color(0xB3EFEAE0), Color(0xFFEFEAE0)], stops: [0, 0.5, 1]),
    scrimFull: Color(0xC7EFEAE0),
    isDusk: false,
  );

  static HeritagePalette of(Brightness b) => b == Brightness.dark ? dusk : afternoon;
}

enum HeritageCardShape { poster, tile, banner, row } // poster 2:3 · tile 1:1 · banner 2:1 · row 56px

/// The 12 content types + communities. Order and shapes are fixed product decisions.
enum HeritageCategory {
  communities(HeritageCardShape.banner, Color(0xFF6E7F76), Color(0xFF1E2622), 0x29, Color(0xFFB9C6BE), Color(0xFF5A6860)),
  stories(HeritageCardShape.poster, Color(0xFFB87333), Color(0xFF3A2211), 0x29, Color(0xFFE3A56E), Color(0xFF8F5927)),
  food(HeritageCardShape.tile, Color(0xFFD29A36), Color(0xFF3D2B0C), 0x29, Color(0xFFEDC271), Color(0xFF825F21)),
  ingredients(HeritageCardShape.tile, Color(0xFF7F9A3E), Color(0xFF242E10), 0x29, Color(0xFFB9D07A), Color(0xFF586B2B)),
  music(HeritageCardShape.tile, Color(0xFF3B8A7A), Color(0xFF0F2B25), 0x2E, Color(0xFF78C9B6), Color(0xFF2F6E61)),
  instruments(HeritageCardShape.tile, Color(0xFF2F7299), Color(0xFF0C2433), 0x2E, Color(0xFF86BEE0), Color(0xFF2C6B8F)),
  ceremonies(HeritageCardShape.banner, Color(0xFFA8506E), Color(0xFF351522), 0x2E, Color(0xFFE596B2), Color(0xFF9D4B67)),
  crafts(HeritageCardShape.tile, Color(0xFF2D7A4F), Color(0xFF0C2818), 0x2E, Color(0xFF7CC79B), Color(0xFF2A724A)),
  dress(HeritageCardShape.tile, Color(0xFF8E5BA6), Color(0xFF2B1934), 0x2E, Color(0xFFCBA2E0), Color(0xFF825398)),
  language(HeritageCardShape.row, Color(0xFF4A6FC0), Color(0xFF141F3A), 0x2E, Color(0xFF9DB6EE), Color(0xFF4263AC)),
  places(HeritageCardShape.banner, Color(0xFF7A9E6B), Color(0xFF212D1C), 0x29, Color(0xFFB3CFA6), Color(0xFF526B48)),
  medicine(HeritageCardShape.tile, Color(0xFF5D62B0), Color(0xFF1A1B3A), 0x2E, Color(0xFFAEB1EE), Color(0xFF595EA8)),
  knowledgeHolders(HeritageCardShape.tile, Color(0xFFC9BBA0), Color(0xFF35302A), 0x24, Color(0xFFDDD1BA), Color(0xFF6C6456));

  const HeritageCategory(this.shape, this.fill, this.deep, this.tintAlpha, this.textDusk, this.textAfternoon);

  final HeritageCardShape shape;
  final Color fill; // marker dots, fallback gradient start
  final Color deep; // fallback gradient end
  final int tintAlpha; // card wash = fill at this alpha
  final Color textDusk; // AA on heritage dusk base
  final Color textAfternoon; // AA on heritage afternoon base

  Color get tint => fill.withAlpha(tintAlpha);
  Color text(HeritagePalette p) => p.isDusk ? textDusk : textAfternoon;

  /// Missing-image fallback: radial fill → deep, fine 3px grain, category icon at 32 (white 72%).
  RadialGradient get fallback => RadialGradient(
        center: const Alignment(-0.5, -0.7), radius: 1.2,
        colors: [fill, deep], stops: const [0, 0.78],
      );
}

/// Card sizes per shape (phone, 20dp gutter). Titles always sit BELOW media on `raised`.
class HeritageCardSize {
  static const poster = Size(148, 222); // 2:3
  static const tile = Size(150, 150); // 1:1
  static const banner = Size(300, 150); // 2:1 (single entry → full width)
  static const rowThumb = 52.0; // language rows, search results
  static const communityBanner = Size(220, 110);
  static const railPreviewMax = 4; // "Show all [N]" only when count > 4
  static const radius = 14.0;
}

class HeritageMotion {
  static const enter = Duration(milliseconds: 420); // base fades from previous canvas (180) → photo settles from 1.04 scale
  static const exit = Duration(milliseconds: 240);
  static const parallax = 0.4;
  static const cardPress = Duration(milliseconds: 90); // scale 0.98 + raisedHi
  static const imageFade = Duration(milliseconds: 240);
  static const navHide = Duration(milliseconds: 200); // glass nav hides on scroll down, returns on scroll up
}

/// Restriction note block on the item screen (directly under the title).
class HeritageRestriction {
  static const duskFill = Color(0xFF2B2419), duskLine = Color(0xFF5A4B30), duskLabel = Color(0xFFE6CFA0);
  static const afternoonFill = Color(0xFFF3E8D2), afternoonLine = Color(0xFFC9B48A), afternoonLabel = Color(0xFF6B5425);
  static const radius = 18.0;
}
// Heritage type styles live in core: CanopyType.heritageDisplay / heritageTitle / heritageSection /
// heritageCardTitle / heritageLede / heritageRead / heritageFieldLabel.

// ───────────────────────────────────────────────────────────── v3 GLASS (supersedes "solid cards, glass only on chrome")
/// Every Heritage page sits on a full-screen photo; cards, chips, buttons, nav and long text float on it in glass.
/// Readability: page scrim (≥45% from the first content row) + glass 42% ≈ 68% combined → ink ≥ 5.7:1 over any photo.
/// Text placed directly on the photo (top-third titles) gets `HeritageGlass.titleShadow` and must be ≥ 28dp.
class HeritageGlass {
  final Color ink, inkMuted;
  final LinearGradient pageScrim;
  final Color glass, glassBorder, glassHighlight;
  final Color readingGlass;
  final Color chip, chipBorder, chipSelected, onChipSelected;
  final Color cta, onCta;
  final Color nav;
  const HeritageGlass._({
    required this.ink, required this.inkMuted, required this.pageScrim,
    required this.glass, required this.glassBorder, required this.glassHighlight,
    required this.readingGlass, required this.chip, required this.chipBorder,
    required this.chipSelected, required this.onChipSelected, required this.cta, required this.onCta, required this.nav,
  });

  static const blurCard = 24.0, saturation = 1.4, blurReading = 28.0, blurChip = 18.0, blurButton = 20.0;
  static const radiusCard = 24.0, radiusMedia = 18.0, radiusReading = 28.0, radiusNav = 26.0, buttonSize = 44.0, ctaHeight = 54.0;
  static const searchListBackdropBlur = 6.0; // only behind search & lists; elsewhere the photo is sharp
  static const titleShadow = [Shadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 1))];

  static const dusk = HeritageGlass._(
    ink: Color(0xFFF4F6F2), inkMuted: Color(0xFFD2D9D4),
    pageScrim: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x2E060907), Color(0x73060907), Color(0x94060907), Color(0xA8060907)], stops: [0, .30, .70, 1]),
    glass: Color(0x6B0E1210), glassBorder: Color(0x29FFFFFF), glassHighlight: Color(0x24FFFFFF),
    readingGlass: Color(0x9E0A0D0B),
    chip: Color(0x1FFFFFFF), chipBorder: Color(0x33FFFFFF), chipSelected: Color(0xEBFFFFFF), onChipSelected: Color(0xFF121714),
    cta: Color(0xEBFFFFFF), onCta: Color(0xFF121714), nav: Color(0x800E1210),
  );

  static const afternoon = HeritageGlass._(
    ink: Color(0xFF1B211D), inkMuted: Color(0xFF46504A),
    pageScrim: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x00EFEAE0), Color(0x38EFEAE0), Color(0x61EFEAE0)], stops: [0, .35, 1]),
    glass: Color(0x94FFFFFF), glassBorder: Color(0xBFFFFFFF), glassHighlight: Color(0xE6FFFFFF),
    readingGlass: Color(0xC7FFFFFF),
    chip: Color(0x8CFFFFFF), chipBorder: Color(0xCCFFFFFF), chipSelected: Color(0xFF1B211D), onChipSelected: Color(0xFFF4F6F2),
    cta: Color(0xFF1B211D), onCta: Color(0xFFF4F6F2), nav: Color(0xA8FFFFFF),
  );

  static HeritageGlass of(Brightness b) => b == Brightness.dark ? dusk : afternoon;
}

/// Which photo backs each page. The chain always ends at BG.png, so a page never lacks a background.
enum HeritageBackdropSource { entryCover, category, community, country, heritageDefault }
const heritageBackdropChain = {
  'home': [HeritageBackdropSource.heritageDefault],
  'country': [HeritageBackdropSource.country, HeritageBackdropSource.heritageDefault],
  'community': [HeritageBackdropSource.community, HeritageBackdropSource.country, HeritageBackdropSource.heritageDefault],
  'categoryBrowse': [HeritageBackdropSource.category, HeritageBackdropSource.community, HeritageBackdropSource.country, HeritageBackdropSource.heritageDefault],
  'item': [HeritageBackdropSource.entryCover, HeritageBackdropSource.category, HeritageBackdropSource.community, HeritageBackdropSource.country, HeritageBackdropSource.heritageDefault],
};
