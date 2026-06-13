// lib/Culture/Heritage/Services/heritage_content_types.dart
//
// SINGLE SOURCE OF TRUTH for the 12 cultural content types.
//
// Defines, once, for every taxonomy key:
//   • display label              (e.g. 'Stories')
//   • icon + accent colour
//   • card shape on the Country screen (poster / tile / banner / row)
//   • canonical display order
//
// Every screen (Country hub, Category browse, Item, upload checklist) derives
// its ordering, labels, icons and shapes from here so they stay consistent
// across countries. Keys match `content_type` as written by the Create flow
// (`type_data_form_builder.dart` _schemas).

import 'package:flutter/material.dart';

/// Card silhouettes used on the Country category hub (Phase 2.3).
enum HeritageCardShape { poster, tile, banner, row }

@immutable
class HeritageContentType {
  final String key; // content_type value in Firestore
  final String label; // human display
  final String plural; // used in empty states ("No Food entries yet")
  final IconData icon;
  final Color accent;
  final HeritageCardShape shape;

  const HeritageContentType({
    required this.key,
    required this.label,
    required this.plural,
    required this.icon,
    required this.accent,
    required this.shape,
  });
}

class HeritageContentTypes {
  HeritageContentTypes._();

  /// Canonical order (matches the overhaul spec, Phase 2.3).
  static const List<HeritageContentType> ordered = [
    HeritageContentType(
      key: 'oral_tradition',
      label: 'Stories',
      plural: 'Stories',
      icon: Icons.auto_stories_outlined,
      accent: Color(0xFFB87333), // copper-amber
      shape: HeritageCardShape.poster,
    ),
    HeritageContentType(
      key: 'food_tradition',
      label: 'Food',
      plural: 'Food',
      icon: Icons.restaurant_outlined,
      accent: Color(0xFFD4873A), // warm orange
      shape: HeritageCardShape.tile,
    ),
    HeritageContentType(
      key: 'ingredient',
      label: 'Ingredients',
      plural: 'Ingredients',
      icon: Icons.eco_outlined,
      accent: Color(0xFF6B8C3A), // olive
      shape: HeritageCardShape.tile,
    ),
    HeritageContentType(
      key: 'music_tradition',
      label: 'Music',
      plural: 'Music',
      icon: Icons.music_note_outlined,
      accent: Color(0xFF3B8A7A), // teal
      shape: HeritageCardShape.tile,
    ),
    HeritageContentType(
      key: 'instrument',
      label: 'Instruments',
      plural: 'Instruments',
      icon: Icons.piano_outlined,
      accent: Color(0xFF2E7D74), // deep teal
      shape: HeritageCardShape.tile,
    ),
    HeritageContentType(
      key: 'ceremony',
      label: 'Ceremonies',
      plural: 'Ceremonies',
      icon: Icons.celebration_outlined,
      accent: Color(0xFFC0573A), // terracotta
      shape: HeritageCardShape.banner,
    ),
    HeritageContentType(
      key: 'craft_technique',
      label: 'Crafts',
      plural: 'Crafts',
      icon: Icons.handyman_outlined,
      accent: Color(0xFF2D7A4F), // green
      shape: HeritageCardShape.tile,
    ),
    HeritageContentType(
      key: 'clothing_tradition',
      label: 'Dress',
      plural: 'Dress',
      icon: Icons.checkroom_outlined,
      accent: Color(0xFF8E5BA6), // plum
      shape: HeritageCardShape.tile,
    ),
    HeritageContentType(
      key: 'language_entry',
      label: 'Language',
      plural: 'Language',
      icon: Icons.translate_outlined,
      accent: Color(0xFF3F7CAC), // blue
      shape: HeritageCardShape.row,
    ),
    HeritageContentType(
      key: 'place_knowledge',
      label: 'Places',
      plural: 'Places',
      icon: Icons.place_outlined,
      accent: Color(0xFF7A9E6B), // sage
      shape: HeritageCardShape.banner,
    ),
    HeritageContentType(
      key: 'medicine_knowledge',
      label: 'Medicine',
      plural: 'Medicine',
      icon: Icons.healing_outlined,
      accent: Color(0xFF1F6F5C), // deep green
      shape: HeritageCardShape.tile,
    ),
    HeritageContentType(
      key: 'person',
      label: 'Knowledge Holders',
      plural: 'Knowledge Holders',
      icon: Icons.person_pin_outlined,
      accent: Color(0xFFC4A961), // gold
      shape: HeritageCardShape.tile,
    ),
  ];

  static final Map<String, HeritageContentType> _byKey = {
    for (final t in ordered) t.key: t,
  };

  static HeritageContentType? byKey(String key) => _byKey[key];

  static String labelFor(String key) => _byKey[key]?.label ?? key;

  /// Accent colour used for the dedicated "Communities" card / surfaces.
  static const Color communitiesAccent = Color(0xFF5C6BC0);
}
