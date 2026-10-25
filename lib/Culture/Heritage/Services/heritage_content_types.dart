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

import '../../../theme/tokens/heritage_tokens.dart';

// Card silhouettes and category colours come from the design tokens
// (lib/theme/tokens/heritage_tokens.dart) — Ceremonies madder rose, Knowledge
// Holders bone (not recognition gold). Re-exported so existing imports work.
export '../../../theme/tokens/heritage_tokens.dart'
    show HeritageCardShape, HeritageCategory, HeritagePalette, HeritageCardSize,
        HeritageMotion, HeritageRestriction, HeritageGlass;

@immutable
class HeritageContentType {
  final String key; // content_type value in Firestore
  final String label; // human display
  final String plural; // used in empty states ("No Food entries yet")
  final IconData icon;
  final HeritageCategory category;

  const HeritageContentType({
    required this.key,
    required this.label,
    required this.plural,
    required this.icon,
    required this.category,
  });

  /// Fill colour (marker dots, fallback gradient start).
  Color get accent => category.fill;
  HeritageCardShape get shape => category.shape;
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
      category: HeritageCategory.stories,
    ),
    HeritageContentType(
      key: 'food_tradition',
      label: 'Food',
      plural: 'Food',
      icon: Icons.restaurant_outlined,
      category: HeritageCategory.food,
    ),
    HeritageContentType(
      key: 'ingredient',
      label: 'Ingredients',
      plural: 'Ingredients',
      icon: Icons.eco_outlined,
      category: HeritageCategory.ingredients,
    ),
    HeritageContentType(
      key: 'music_tradition',
      label: 'Music',
      plural: 'Music',
      icon: Icons.music_note_outlined,
      category: HeritageCategory.music,
    ),
    HeritageContentType(
      key: 'instrument',
      label: 'Instruments',
      plural: 'Instruments',
      icon: Icons.piano_outlined,
      category: HeritageCategory.instruments,
    ),
    HeritageContentType(
      key: 'ceremony',
      label: 'Ceremonies',
      plural: 'Ceremonies',
      icon: Icons.celebration_outlined,
      category: HeritageCategory.ceremonies,
    ),
    HeritageContentType(
      key: 'craft_technique',
      label: 'Crafts',
      plural: 'Crafts',
      icon: Icons.handyman_outlined,
      category: HeritageCategory.crafts,
    ),
    HeritageContentType(
      key: 'clothing_tradition',
      label: 'Dress',
      plural: 'Dress',
      icon: Icons.checkroom_outlined,
      category: HeritageCategory.dress,
    ),
    HeritageContentType(
      key: 'language_entry',
      label: 'Language',
      plural: 'Language',
      icon: Icons.translate_outlined,
      category: HeritageCategory.language,
    ),
    HeritageContentType(
      key: 'place_knowledge',
      label: 'Places',
      plural: 'Places',
      icon: Icons.place_outlined,
      category: HeritageCategory.places,
    ),
    HeritageContentType(
      key: 'medicine_knowledge',
      label: 'Medicine',
      plural: 'Medicine',
      icon: Icons.healing_outlined,
      category: HeritageCategory.medicine,
    ),
    HeritageContentType(
      key: 'person',
      label: 'Knowledge Holders',
      plural: 'Knowledge Holders',
      icon: Icons.person_outline,
      category: HeritageCategory.knowledgeHolders,
    ),
  ];

  static final Map<String, HeritageContentType> _byKey = {
    for (final t in ordered) t.key: t,
  };

  static HeritageContentType? byKey(String key) => _byKey[key];

  static String labelFor(String key) => _byKey[key]?.label ?? key;

  /// Accent colour used for the dedicated "Communities" card / surfaces.
  static const Color communitiesAccent = Color(0xFF6E7F76); // HeritageCategory.communities.fill
}
