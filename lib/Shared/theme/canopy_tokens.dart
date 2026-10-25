// lib/Shared/theme/canopy_tokens.dart
//
// The single source of truth for Canopy's visual primitives: radii, spacing,
// icon sizing, elevation and semantic colour.
//
// WHY THIS EXISTS
// ---------------
// Before this file the app had 20 distinct corner radii across ~1,070 uses,
// 15+ icon sizes (including 11, 13 and 15), 388 hardcoded `Color(0x...)`
// literals — ~50 of which were just re-declarations of a colour AppTheme
// already exported — and two competing theme classes, one of which silently
// overrode the other in light mode only. Screens drifted because there was
// nothing to drift *from*.
//
// HOW TO USE IT
// -------------
// `app_theme.dart` re-exports this file, so anything that already does
// `import '.../Shared/theme/app_theme.dart';` gets these tokens for free —
// no new import needed.
//
//   BorderRadius.circular(CanopyRadius.md)     // not 14, 15, 16 or 18
//   Icon(Icons.bolt_outlined, size: CanopyIcon.md)
//   EdgeInsets.all(CanopySpace.lg)
//   color: CanopyColor.inkMuted
//
// THE RULES
// ---------
// 1. Never write a raw `Color(0x...)` in a screen. If a colour isn't here and
//    genuinely needs to exist, add it here first with a name that says what it
//    MEANS, not what it looks like (`danger`, not `red`).
// 2. Never write a bare number for a radius, an icon size or padding. Pick the
//    nearest token. If nothing is close the design is probably wrong, not the
//    scale.
// 3. Icons are the **outlined** family. See [CanopyIcon] for why and for the
//    two exceptions.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR
// ─────────────────────────────────────────────────────────────────────────────

/// Semantic colour tokens.
///
/// Brand values are the same greens/golds `AppTheme` has always exported —
/// this adds the *semantic* layer (surface vs canvas vs ink vs outline) that
/// was missing, and which screens were improvising with raw hex.
abstract final class CanopyColor {
  // ── Brand ──────────────────────────────────────────────────────────────
  /// Forest green. The primary action colour.
  static const Color primary = Color(0xFF2D7A4F);
  static const Color primaryDim = Color(0xFF4A9B6E);
  static const Color primarySoft = Color(0xFF86BC9E);

  /// Teal. Secondary accent — used for supporting stats and input affordances.
  static const Color accent = Color(0xFF3B8A7A);

  /// Gold. Reserved for recognition, rank and achievement. Using it for
  /// ordinary UI chrome is what made "points" stop reading as special.
  static const Color gold = Color(0xFFC4A961);

  // ── Surfaces ───────────────────────────────────────────────────────────
  /// The page background. Warm paper, not white — cards need something to sit
  /// on, and an all-white page makes a white card invisible.
  static const Color canvas = Color(0xFFF6F3EC);

  /// Cards, sheets, dialogs, app bars.
  static const Color surface = Color(0xFFFFFFFF);

  /// A recessed surface on top of [surface] — search fields, code-ish blocks,
  /// disabled tiles.
  static const Color surfaceMuted = Color(0xFFF0EEE7);

  /// A tinted surface for "this belongs to the brand" blocks that aren't
  /// strong enough to be [primary]-filled.
  static const Color surfaceBrand = Color(0xFFEAF1EB);

  // ── Ink ────────────────────────────────────────────────────────────────
  /// Primary text. A very dark green rather than black — black on the warm
  /// canvas reads cold.
  static const Color ink = Color(0xFF173728);

  /// Secondary text, captions, inactive labels.
  static const Color inkMuted = Color(0xFF607067);

  /// Placeholder and disabled text. Do not use for anything a user must read.
  static const Color inkFaint = Color(0xFF9AA0A6);

  /// Text/icons on top of [primary] or any strong fill.
  static const Color onFill = Color(0xFFFFFFFF);

  // ── Lines ──────────────────────────────────────────────────────────────
  /// Card borders, dividers, input outlines.
  static const Color outline = Color(0xFFDDE2DC);

  /// A stronger line for focused/selected states.
  static const Color outlineStrong = Color(0xFFB9C4BC);

  // ── Status ─────────────────────────────────────────────────────────────
  // These replace the scattered Material palette references (Colors.red,
  // Colors.orange, 0xFFE65100, 0xFF1565C0 …) that never agreed with each
  // other. Each has a `soft` variant for backgrounds behind the solid colour.
  static const Color success = Color(0xFF2E7D5E);
  static const Color successSoft = Color(0xFFE6F2EC);
  static const Color warning = Color(0xFFB07A24);
  static const Color warningSoft = Color(0xFFFAF1E0);
  static const Color danger = Color(0xFFA33E3E);
  static const Color dangerSoft = Color(0xFFF7E9E9);
  static const Color info = Color(0xFF2F6690);
  static const Color infoSoft = Color(0xFFE8EFF5);

  // ── Dark mode ──────────────────────────────────────────────────────────
  // Dark mode is user-selectable in Settings, so every token above needs a
  // counterpart. These are the values AppTheme.dark() was already using,
  // named rather than inlined.
  static const Color canvasDark = Color(0xFF0A1F14);
  static const Color surfaceDark = Color(0xFF143525);
  static const Color surfaceMutedDark = Color(0xFF0F2A1A);
  static const Color inkDark = Color(0xFFE8F0EA);
  static const Color inkMutedDark = Color(0xFF9DB3A6);
  static const Color outlineDark = Color(0xFF2A4A38);

  /// Resolves the page background for [brightness].
  static Color canvasOf(Brightness b) =>
      b == Brightness.dark ? canvasDark : canvas;

  /// Resolves the card surface for [brightness].
  static Color surfaceOf(Brightness b) =>
      b == Brightness.dark ? surfaceDark : surface;

  /// Resolves primary text colour for [brightness].
  static Color inkOf(Brightness b) => b == Brightness.dark ? inkDark : ink;

  /// Resolves secondary text colour for [brightness].
  static Color inkMutedOf(Brightness b) =>
      b == Brightness.dark ? inkMutedDark : inkMuted;

  /// Resolves the line colour for [brightness].
  static Color outlineOf(Brightness b) =>
      b == Brightness.dark ? outlineDark : outline;
}

// ─────────────────────────────────────────────────────────────────────────────
// RADIUS
// ─────────────────────────────────────────────────────────────────────────────

/// Corner radii. Five steps plus a pill.
///
/// The old spread (6,7,8,9,10,11,12,13,14,15,16,18,20,22,24,50,100,999) is
/// collapsed here. When migrating, round to the nearest token rather than
/// preserving the old number — the whole point is that 14 and 16 stop being
/// different things.
abstract final class CanopyRadius {
  /// Chips, badges, small tags, inline pills of text.
  static const double xs = 8;

  /// Inputs, buttons, small tiles. The most common radius in the app.
  static const double sm = 12;

  /// Cards, list rows, bottom-sheet content blocks.
  static const double md = 16;

  /// Feature cards, hero blocks, modal sheets.
  static const double lg = 20;

  /// Full-bleed hero imagery and the largest containers only.
  static const double xl = 24;

  /// Fully round. For avatars use a CircleBorder instead.
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);

  /// Top-only rounding, for bottom sheets.
  static BorderRadius top(double r) =>
      BorderRadius.vertical(top: Radius.circular(r));
}

// ─────────────────────────────────────────────────────────────────────────────
// SPACING
// ─────────────────────────────────────────────────────────────────────────────

/// A 4pt spacing scale.
abstract final class CanopySpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page padding. Every full-width screen uses this so content
  /// lines up when you move between tabs.
  static const double gutter = 20;

  /// Vertical gap between major sections of a page.
  static const double section = 24;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: gutter);
}

// ─────────────────────────────────────────────────────────────────────────────
// ICONS
// ─────────────────────────────────────────────────────────────────────────────

/// Icon sizing, and the house rule on icon family.
///
/// **Use the `_outlined` family.** The app already leans that way (770
/// outlined vs 601 filled vs 210 rounded), outlined reads better at the small
/// sizes most of this UI uses, and mixing families is the single most visible
/// inconsistency on a page. Two deliberate exceptions:
///
/// * **Selected/active state** in a nav bar or tab may use the filled variant
///   to mark selection — that's the pattern `canopy_bottom_bar.dart` uses and
///   it's meaningful contrast, not drift.
/// * **Brand/pictorial marks** with no outlined counterpart.
abstract final class CanopyIcon {
  /// Inline with small print, inside chips.
  static const double xs = 14;

  /// Inline with body text, secondary metadata rows.
  static const double sm = 16;

  /// The default. List-row leading icons, section headers.
  static const double md = 18;

  /// Buttons, app-bar actions, stat tiles.
  static const double lg = 20;

  /// Standard Material touch icon. Nav bars, prominent actions.
  static const double xl = 24;

  /// Feature tiles and quick actions.
  static const double xxl = 32;

  /// Empty states and illustrations.
  static const double hero = 48;
}

// ─────────────────────────────────────────────────────────────────────────────
// ELEVATION
// ─────────────────────────────────────────────────────────────────────────────

/// Shadows.
///
/// Canopy's light theme is an outlined system, not a shadowed one: a card gets
/// a 1px [CanopyColor.outline] border, not a drop shadow. Shadow is reserved
/// for things that genuinely float above the page.
abstract final class CanopyShadow {
  /// Nothing. The default for cards and list rows.
  static const List<BoxShadow> none = [];

  /// A card that needs to lift slightly off the canvas — the feed card, a
  /// selected item.
  static List<BoxShadow> get low => [
        BoxShadow(
          color: CanopyColor.ink.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  /// Floating chrome: nav bars, FABs, sheets over content.
  static List<BoxShadow> get high => [
        BoxShadow(
          color: CanopyColor.ink.withOpacity(0.12),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE
// ─────────────────────────────────────────────────────────────────────────────

/// Font sizes and weights, so screens stop inventing 13.5 and 14.5.
///
/// Prefer `Theme.of(context).textTheme.*` where a Material role fits. These
/// exist for the in-between cases the Material scale doesn't name well.
abstract final class CanopyType {
  static const double display = 26;
  static const double title = 20;
  static const double heading = 18;
  static const double subhead = 16;
  static const double body = 14;
  static const double caption = 12.5;
  static const double micro = 11;

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;

  /// The all-caps section eyebrow used above grouped content.
  static const TextStyle eyebrow = TextStyle(
    fontSize: micro,
    fontWeight: bold,
    letterSpacing: 1,
    color: CanopyColor.inkMuted,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TOUCH
// ─────────────────────────────────────────────────────────────────────────────

abstract final class CanopyTouch {
  /// Minimum tappable edge. Anything interactive must reach this in both
  /// axes, padding included.
  static const double minTarget = 48;
}
