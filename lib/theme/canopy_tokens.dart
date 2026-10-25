// lib/theme/canopy_tokens.dart — CORE (community app + shared foundations)
//
// v2 tokens from the design hand-off. NOT the same file as the v1
// lib/Shared/theme/canopy_tokens.dart: CanopyRadius / CanopySpace / CanopyType
// exist in both with different members, so a file imports one or the other.
// CanopyPalette is registered as a ThemeExtension in AppTheme.light()/dark().
//
// Area tokens live in tokens/: heritage_tokens.dart, services_tokens.dart,
// org_tokens.dart, envops_tokens.dart, archive_tokens.dart (each imports this file).
// Generated from the Canopy design canvas (theme v1 + v2 "de-template" pass,
// Heritage sub-theme, Services additions). Every value a screen uses should
// resolve to a name in this file — no raw hex/px in widgets.
//
// Fonts (bundle, don't fetch at runtime):
//   BricolageGrotesque  — display, titles, every number (tabular figures)
//   PublicSans          — UI and body
//   SourceSerif4        — article body + all Heritage titles/reading text
// All three are OFL on Google Fonts; add the variable .ttf files to
// pubspec.yaml under these family names.

import 'package:flutter/material.dart';

// ───────────────────────────────────────────────────────────── Colour

@immutable
class CanopyPalette extends ThemeExtension<CanopyPalette> {
  const CanopyPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceBrand,
    required this.frost,
    required this.scrim,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.outline,
    required this.outlineStrong,
    required this.focus,
    required this.primary,
    required this.primaryDeep,
    required this.primaryDim,
    required this.primarySoft,
    required this.primaryInk,
    required this.onPrimary,
    required this.accent,
    required this.gold,
    required this.goldInk,
    required this.goldSoft,
    required this.medalSilver,
    required this.medalBronze,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.viz,
    required this.seq,
    required this.map,
    required this.gradientCanopy,
    required this.gradientScrim,
  });

  // Surfaces
  final Color canvas; // page background — warm paper / deep forest
  final Color surface; // cards, sheets, nav
  final Color surfaceMuted; // recessed: inputs off, segmented track, skeleton
  final Color surfaceBrand; // selected nav indicator, date block
  final Color frost; // scrolled app bar, sticky bar (+ blur 16)
  final Color scrim; // behind sheets and dialogs

  // Ink & lines
  final Color ink; // primary text AND primary button fill (v2)
  final Color inkMuted; // secondary text, pressed primary button
  final Color inkFaint; // hints, disabled — never body copy
  final Color outline; // card borders, dividers
  final Color outlineStrong; // inputs, secondary buttons, label dividers
  final Color focus; // 3px focus ring, 2px offset

  // Brand
  final Color primary; // brand green: heroes, progress, timeline, map
  final Color primaryDeep; // gradient start
  final Color primaryDim;
  final Color primarySoft; // scan sweep line, tints
  final Color primaryInk; // brand-coloured TEXT/icons (never use `primary` as text)
  final Color onPrimary;
  final Color accent; // teal: gradient end, recycling marker

  // Recognition — gold appears ONLY on points, rank, medals, badges, check-in burst
  final Color gold; // medal fill, badge ring — never text
  final Color goldInk; // points numbers
  final Color goldSoft; // earned badge well
  final Color medalSilver;
  final Color medalBronze;

  // Status (text colour + soft background)
  final Color success, successSoft;
  final Color warning, warningSoft;
  final Color danger, dangerSoft;
  final Color info, infoSoft;

  // Data viz
  final List<Color> viz; // categorical: cleanups, tree planting, recycling, workshops, other
  final List<Color> seq; // sequential seq1..seq5 (more = more contrast)
  final CanopyMapColors map;

  // The only two sanctioned gradients
  final LinearGradient gradientCanopy; // Home hero, Log Work points hero, Profile header — nowhere else
  final LinearGradient gradientScrim; // under any text/chip on a photo

  static const light = CanopyPalette(
    canvas: Color(0xFFF6F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0EEE7),
    surfaceBrand: Color(0xFFEAF1EB),
    frost: Color(0xD6F6F3EC), // 84%
    scrim: Color(0x8C0A1F14), // 55%
    ink: Color(0xFF173728),
    inkMuted: Color(0xFF607067),
    inkFaint: Color(0xFF8A938C),
    outline: Color(0xFFDDE2DC),
    outlineStrong: Color(0xFFB9C4BC),
    focus: Color(0xFF2F6690),
    primary: Color(0xFF2D7A4F),
    primaryDeep: Color(0xFF1F5C3B),
    primaryDim: Color(0xFF4A9B6E),
    primarySoft: Color(0xFF86BC9E),
    primaryInk: Color(0xFF2D7A4F),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF3B8A7A),
    gold: Color(0xFFC4A961),
    goldInk: Color(0xFF7A6224),
    goldSoft: Color(0xFFF6EFDB),
    medalSilver: Color(0xFF9AA5A0),
    medalBronze: Color(0xFFB5835A),
    success: Color(0xFF2E7D5E),
    successSoft: Color(0xFFE6F2EC),
    warning: Color(0xFF946519), // darkened from #B07A24 to pass AA
    warningSoft: Color(0xFFFAF1E0),
    danger: Color(0xFFA33E3E),
    dangerSoft: Color(0xFFF7E9E9),
    info: Color(0xFF2F6690),
    infoSoft: Color(0xFFE8EFF5),
    viz: [Color(0xFF2D7A4F), Color(0xFF2F6690), Color(0xFFB07A24), Color(0xFF8A5A8C), Color(0xFF7E8A83)],
    seq: [Color(0xFFE6F2EC), Color(0xFFB9D9C5), Color(0xFF86BC9E), Color(0xFF4A9B6E), Color(0xFF1F5C3B)],
    map: CanopyMapColors.light,
    gradientCanopy: LinearGradient(
      begin: Alignment(-0.5, -1), end: Alignment(0.5, 1),
      colors: [Color(0xFF1F5C3B), Color(0xFF2D7A4F), Color(0xFF3B8A7A)],
      stops: [0, 0.58, 1],
    ),
    gradientScrim: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0x000A1F14), Color(0xBD0A1F14)], // 0 → 74%
    ),
  );

  static const dark = CanopyPalette(
    canvas: Color(0xFF0A1F14),
    surface: Color(0xFF143525),
    surfaceMuted: Color(0xFF0F2A1A),
    surfaceBrand: Color(0xFF17402C),
    frost: Color(0xCC0A1F14), // 80%
    scrim: Color(0x9E040E09), // 62%
    ink: Color(0xFFE8F0EA),
    inkMuted: Color(0xFF9DB3A6),
    inkFaint: Color(0xFF6F8779),
    outline: Color(0xFF2A4A38),
    outlineStrong: Color(0xFF3D6150),
    focus: Color(0xFF8BB9E0),
    primary: Color(0xFF5FB585),
    primaryDeep: Color(0xFF0E3A24),
    primaryDim: Color(0xFF3E8A60),
    primarySoft: Color(0xFF86BC9E),
    primaryInk: Color(0xFF8DCBA6),
    onPrimary: Color(0xFF062414),
    accent: Color(0xFF6DBFAE),
    gold: Color(0xFFD9BE72),
    goldInk: Color(0xFFE6CD85),
    goldSoft: Color(0xFF2E2914),
    medalSilver: Color(0xFFB7C1BC),
    medalBronze: Color(0xFFCE9C72),
    success: Color(0xFF6CC49A),
    successSoft: Color(0xFF133A28),
    warning: Color(0xFFE0AE5C),
    warningSoft: Color(0xFF3A2D14),
    danger: Color(0xFFEC8F8F),
    dangerSoft: Color(0xFF3E1C1C),
    info: Color(0xFF8BB9E0),
    infoSoft: Color(0xFF152C3E),
    viz: [Color(0xFF5FB585), Color(0xFF7FB0DC), Color(0xFFE0AE5C), Color(0xFFC394C6), Color(0xFF9DB3A6)],
    seq: [Color(0xFF16402B), Color(0xFF23603F), Color(0xFF3E8A60), Color(0xFF5FB585), Color(0xFFA9DDBE)],
    map: CanopyMapColors.dark,
    gradientCanopy: LinearGradient(
      begin: Alignment(-0.5, -1), end: Alignment(0.5, 1),
      colors: [Color(0xFF0C3320), Color(0xFF17503A), Color(0xFF1B5A50)],
      stops: [0, 0.58, 1],
    ),
    gradientScrim: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0x00040E09), Color(0xCC040E09)], // 0 → 80%
    ),
  );

  // Text on gradientCanopy heroes
  static const onHero = Color(0xFFFFFFFF);
  static const onHeroMuted = Color(0xC2FFFFFF); // 76%
  static const onHeroPoints = Color(0xFFE6CD85); // gold numerals on the hero

  @override
  CanopyPalette copyWith() => this;

  @override
  CanopyPalette lerp(ThemeExtension<CanopyPalette>? other, double t) =>
      (other is CanopyPalette && t >= 0.5) ? other : this;
}

@immutable
class CanopyMapColors {
  const CanopyMapColors({
    required this.land, required this.water, required this.park, required this.road,
    required this.roadMajor, required this.label, required this.built,
  });
  final Color land, water, park, road, roadMajor, label, built;

  static const light = CanopyMapColors(
    land: Color(0xFFECE8DD), water: Color(0xFFBCD4D6), park: Color(0xFFD3E3CB),
    road: Color(0xFFFFFFFF), roadMajor: Color(0xFFE6DCC4), label: Color(0xFF607067), built: Color(0xFFE3DED1),
  );
  static const dark = CanopyMapColors(
    land: Color(0xFF0F2419), water: Color(0xFF0B3340), park: Color(0xFF143A25),
    road: Color(0xFF1F3D2D), roadMajor: Color(0xFF2C4C38), label: Color(0xFF9DB3A6), built: Color(0xFF132C1F),
  );
  // Ship as Google Maps JSON styles `mapStyleLight` / `mapStyleDark`:
  // POI icons, transit and business labels off; parks and water on.
}

/// Map marker fills (white glyph, 2.5px `surface` ring, e1 shadow).
class CanopyMarkers {
  static Color waterPoint(CanopyPalette p) => p.info;
  static Color recycling(CanopyPalette p) => p.accent;
  static Color dumpsite(CanopyPalette p) => p.danger;
  static Color canopyHub(CanopyPalette p) => p.primaryDeep;
  static Color cleanupEvent(CanopyPalette p) => p.warning;
  static Color treeSite(CanopyPalette p) => p.primaryDim;
  static const you = Color(0xFF2F6690);
}

// ───────────────────────────────────────────────────────────── Scale

class CanopySpace {
  static const s2 = 2.0, s4 = 4.0, s8 = 8.0, s12 = 12.0, s16 = 16.0, s20 = 20.0, s24 = 24.0, s32 = 32.0;
  static const gutter = 20.0; // page side padding
  static const section = 24.0; // gap between sections
  static const cardPadding = 16.0;
  static const rowMinHeight = 56.0;
  static const minTouch = 48.0;
  static const stickyBarBottom = 30.0; // + safe area
}

class CanopyRadius {
  static const xs = 8.0; // filter chips, thumbs, PRIMARY BUTTONS (v2)
  static const buttonCompact = 7.0;
  static const sm = 12.0; // inputs, image tiles
  static const md = 16.0; // cards, list groups
  static const lg = 20.0; // feed & activity cards
  static const xl = 24.0; // hero, sheet top
  static const heritageCard = 14.0;
  static const heritageSheet = 28.0;
  static const pill = 999.0;
}

class CanopyIconSize {
  static const s14 = 14.0, s16 = 16.0, s18 = 18.0; // 18 = default
  static const button = 20.0, appBar = 20.0, nav = 24.0, s32 = 32.0, empty = 48.0;
  // Material Symbols Outlined, weight 400. Filled only for the selected nav item.
  // v2: icons are never placed on a tinted square/circle background.
}

class CanopyElevation {
  // e0 = 1px outline, no shadow (cards, groups, tiles)
  static List<BoxShadow> e1(Brightness b) => b == Brightness.light
      ? const [BoxShadow(color: Color(0x0F173728), blurRadius: 2, offset: Offset(0, 1)),
               BoxShadow(color: Color(0x1A173728), blurRadius: 24, offset: Offset(0, 8))]
      : const [BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
               BoxShadow(color: Color(0x61000000), blurRadius: 24, offset: Offset(0, 8))];
  // bottom nav, map search, map buttons, snackbar

  static List<BoxShadow> e2(Brightness b) => [
        BoxShadow(color: b == Brightness.light ? const Color(0x29173728) : const Color(0x80000000),
            blurRadius: 32, offset: const Offset(0, -8)),
      ]; // sheets, dialogs (+ scrim)

  static List<BoxShadow> e3(Brightness b) => [
        BoxShadow(color: b == Brightness.light ? const Color(0x521F5C3B) : const Color(0x80000000),
            blurRadius: 20, offset: const Offset(0, 8)),
      ]; // scan button, organiser FAB
}

// ───────────────────────────────────────────────────────────── Type

class CanopyFonts {
  static const display = 'BricolageGrotesque';
  static const ui = 'PublicSans';
  static const serif = 'SourceSerif4';
}

class CanopyType {
  static const _tab = [FontFeature.tabularFigures()];

  // UI ramp
  static const hero = TextStyle(fontFamily: CanopyFonts.display, fontSize: 44, height: 48 / 44, fontWeight: FontWeight.w700, letterSpacing: -0.88, fontFeatures: _tab);
  static const display = TextStyle(fontFamily: CanopyFonts.display, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.42);
  static const title = TextStyle(fontFamily: CanopyFonts.display, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700, letterSpacing: -0.22);
  static const heading = TextStyle(fontFamily: CanopyFonts.display, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600);
  static const subhead = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 14, height: 21 / 14, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 14, height: 21 / 14, fontWeight: FontWeight.w600);
  static const label = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600);
  static const button = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, letterSpacing: 0.15);
  static const caption = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 12.5, height: 17 / 12.5, fontWeight: FontWeight.w400); // inkMuted
  static const micro = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600, letterSpacing: 0.22);
  static const eyebrow = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w700, letterSpacing: 1.0); // UPPERCASE

  // v2 labels (replace pills)
  static const statusLabel = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 11.5, height: 16 / 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8); // UPPERCASE, status colour
  static const points = TextStyle(fontFamily: CanopyFonts.display, fontSize: 13.5, height: 16 / 13.5, fontWeight: FontWeight.w700, fontFeatures: _tab); // goldInk
  static const money = TextStyle(fontFamily: CanopyFonts.display, fontWeight: FontWeight.w700, letterSpacing: -0.1, fontFeatures: _tab); // size per use; always "KSh", no decimals

  // Editorial ramp (articles only)
  static const artTitle = TextStyle(fontFamily: CanopyFonts.display, fontSize: 30, height: 36 / 30, fontWeight: FontWeight.w700, letterSpacing: -0.6);
  static const artLead = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 19, height: 29 / 19, fontWeight: FontWeight.w400);
  static const artH2 = TextStyle(fontFamily: CanopyFonts.display, fontSize: 21, height: 28 / 21, fontWeight: FontWeight.w700, letterSpacing: -0.21); // 28 above, 8 below
  static const artBody = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 17, height: 28 / 17, fontWeight: FontWeight.w400); // paragraph gap 16
  static const artQuote = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 21, height: 30 / 21, fontStyle: FontStyle.italic);

  // Heritage ramp — Source Serif 4 at display optical size
  static const heritageDisplay = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 48, height: 52 / 48, letterSpacing: -0.72,
      fontVariations: [FontVariation('opsz', 60), FontVariation('wght', 600)]);
  static const heritageTitle = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 34, height: 40 / 34, letterSpacing: -0.34,
      fontVariations: [FontVariation('opsz', 60), FontVariation('wght', 600)]);
  static const heritageSection = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 24, height: 30 / 24,
      fontVariations: [FontVariation('opsz', 40), FontVariation('wght', 600)]);
  static const heritageCardTitle = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 17, height: 22 / 17,
      fontVariations: [FontVariation('opsz', 24), FontVariation('wght', 600)]);
  static const heritageLede = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 19, height: 29 / 19, fontStyle: FontStyle.italic);
  static const heritageRead = TextStyle(fontFamily: CanopyFonts.serif, fontSize: 18, height: 30 / 18, fontWeight: FontWeight.w400);
  static const heritageFieldLabel = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w700, letterSpacing: 1.32); // UPPERCASE
}

// ───────────────────────────────────────────────────────────── Motion

class CanopyMotion {
  static const emphasised = Cubic(0.2, 0, 0, 1);
  static const standard = Cubic(0.2, 0, 0.1, 1);

  static const pagePush = Duration(milliseconds: 280); // emphasised, shared-axis X
  static const sheetOpen = Duration(milliseconds: 320); // emphasised
  static const sheetClose = Duration(milliseconds: 220);
  static const tabSwitch = Duration(milliseconds: 180); // fade-through
  static const press = Duration(milliseconds: 90); // cards scale 0.98
  static const shimmer = Duration(milliseconds: 1400); // linear, loop
  static const feedSlide = Duration(seconds: 6); // story segment fill per slide
  static const countUp = Duration(milliseconds: 900); // decelerate
  static const checkInBurst = Duration(milliseconds: 600); // once; no confetti
  static const navHide = Duration(milliseconds: 200); // Heritage nav hides on scroll down

  static const heritageEnter = Duration(milliseconds: 420); // base fades from previous canvas (180) then photo settles from 1.04
  static const heritageExit = Duration(milliseconds: 240);
  static const imageFade = Duration(milliseconds: 240);

  /// Reduced motion: every transition → 120ms fade; shimmer and count-up off.
  static const reduced = Duration(milliseconds: 120);
}
