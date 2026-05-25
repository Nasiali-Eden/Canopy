import 'package:flutter/material.dart';

/// Heritage Layer 4 Theme Constants
/// Defines warm, archival colour palette distinct from marketplace and community layers
class HeritageTheme {
  // Layer 4 Background Colours
  static const Color heritageBackground = Color(0xFFF5EDE0); // Warm parchment
  static const Color heritageCardBackground =
      Color(0xFFFDF7F0); // Very slightly warm white

  // Visibility indicator colours
  static const Color visibilityPublic = Color(0xFF2D7A4F); // Green
  static const Color visibilityCommunitOnly = Color(0xFFFFC107); // Amber
  static const Color visibilityRestricted = Color(0xFFFF6F00); // Deep orange
  static const Color visibilitySealed = Color(0xFF212121); // Near-black

  // Content type pill colours
  static const Map<String, Color> contentTypePillColours = {
    'Stories': Color(0xFFB87333), // Copper-amber
    'Food': Color(0xFFD4873A), // Warm orange
    'Music': Color(0xFF3B8A7A), // Teal
    'Ceremony': Color(0xFFC0573A), // Terracotta
    'Craft': Color(0xFF2D7A4F), // Green
    'Place': Color(0xFF7A9E6B), // Sage
    'Language': Color(0xFF3B8A7A), // Accent/Teal
    'Ingredients': Color(0xFF6B8C3A), // Olive
  };

  // Dispute status border colours
  static const Color disputePendingBorder = Color(0xFFFFC107); // Amber
  static const Color disputeUnderReviewBorder = Color(0xFF3B8A7A); // Teal
  static const Color disputeResolvedRecommendedBorder =
      Color(0xFF2D7A4F); // Green

  // Shadow configuration for heritage cards
  static BoxShadow get heritageCardShadow => BoxShadow(
        color: Color(0xFFC4A961).withOpacity(0.10), // Gold-tinted
        blurRadius: 12,
        offset: const Offset(0, 3),
      );

  // Border radius constants
  static const double cardBorderRadius = 16;
  static const double pillBorderRadius = 20;
}
