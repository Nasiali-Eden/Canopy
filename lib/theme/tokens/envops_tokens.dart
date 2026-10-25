// envops_tokens.dart — Environmental Operations shell
// Builds on ../canopy_tokens.dart. Every value used by this area's screens resolves here or in core.

import 'package:flutter/material.dart';
import '../canopy_tokens.dart';

// ───────────────────────────────────────────────────────────── Environmental Ops field mode

class CanopyField {
  static const minTarget = 56.0; // every field control
  static const captureSize = 96.0; // 120 on the walk-the-boundary screen
  static const buttonHeight = 56.0;
  static const buttonRadius = 10.0;
  static const buttonText = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 16.5, fontWeight: FontWeight.w600);
  static const keypadKeyHeight = 56.0;
  static const bigNumber = TextStyle(fontFamily: CanopyFonts.display, fontSize: 56, height: 60 / 56, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  static const signalValue = TextStyle(fontFamily: CanopyFonts.display, fontSize: 30, height: 34 / 30, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  static const signalRule = 2.0; // ink
  static const fieldEyebrow = TextStyle(fontFamily: CanopyFonts.ui, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w700, letterSpacing: 1.32); // UPPERCASE + hairline rule
  static const fieldNoteTime = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 18 / 12, fontWeight: FontWeight.w600);

  // GPS thresholds (metres)
  static const gpsGood = 10.0; // ≤ good
  static const gpsWeakMax = 25.0; // ≤ weak (allowed, flagged); > blocked
  static const gpsTimeout = Duration(seconds: 30); // no fix → failed
  static const walkMinPoints = 10;

  // Map overlays (use with CanopyPalette)
  static Color zoneFill(CanopyPalette p) => p.primary.withAlpha(0x38); // 22%
  static Color zoneStroke(CanopyPalette p) => p.primary; // 2.5
  static Color zoneSelectedStroke(CanopyPalette p) => p.ink; // 3.5
  static Color zoneDraftStroke(CanopyPalette p) => p.warning; // 2.5, dashed 8/6
  static const accuracyFill = Color(0x242F6690); // 14%
  static const accuracyStroke = Color(0x802F6690);
}
