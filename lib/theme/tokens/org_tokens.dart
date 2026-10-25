// org_tokens.dart — Organisation workspace
// Builds on ../canopy_tokens.dart. Every value used by this area's screens resolves here or in core.

import 'package:flutter/material.dart';
import '../canopy_tokens.dart';

// ───────────────────────────────────────────────────────────── Organisation workspace density

class CanopyWorkspace {
  static const rowMinHeight = 52.0; // dense list rows (members, partners, enquiries)
  static const rowPaddingV = 10.0, rowPaddingH = 14.0;
  static const cardPadding = 14.0;
  static const sectionGap = 20.0;
  static const attentionRowHeight = 56.0; // attention strip rows; 1.5px ink border, radius 14
  static const metricRule = 2.0; // ink top rule on metric tiles
  static const metricValue = TextStyle(fontFamily: CanopyFonts.display, fontSize: 26, height: 30 / 26, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  static const attentionCount = metricValue;

  /// Event check-in QR: never themed.
  static const qrForeground = Color(0xFF000000);
  static const qrBackground = Color(0xFFFFFFFF);
  static const qrSize = 300.0; // on a 390dp-wide phone; min 240
  static const qrQuietZone = 18.0;
}

enum MembershipStatus { active, inactive, pending, invited }
enum PartnershipState { invitedByYou, awaitingYourResponse, active }
enum ContentState { draft, published, scheduled }
enum CapabilityState { notApplied, underReview, enabled }

class OrgStatusColors {
  static Color membership(MembershipStatus s, CanopyPalette p) => switch (s) {
        MembershipStatus.active => p.success,
        MembershipStatus.inactive => p.inkMuted,
        MembershipStatus.pending => p.warning,
        MembershipStatus.invited => p.info,
      };
  static Color content(ContentState s, CanopyPalette p) => switch (s) {
        ContentState.draft => p.inkMuted,
        ContentState.published => p.success,
        ContentState.scheduled => p.info,
      };
  static Color capability(CapabilityState s, CanopyPalette p) => switch (s) {
        CapabilityState.notApplied => p.inkMuted,
        CapabilityState.underReview => p.warning,
        CapabilityState.enabled => p.success,
      };
}

/// Dashboard masthead (redesigned header)
class OrgMasthead {
  static const coverHeight = 150.0; // cover photo band; empty = surfaceMuted + dashed bottom rule + "Add a cover photo"
  static const logoSize = 72.0; // squircle (30%), overlaps cover by 34, 4px canvas ring
  static const coverScrim = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0x8C0A1F14), Color(0x000A1F14)]); // top 90px, keeps switcher + bell readable
  static const statValue = TextStyle(fontFamily: CanopyFonts.display, fontSize: 20, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
}
