enum MaterialCategory {
  plastics,
  metals,
  glass,
  paperCardboard,
  rubberComposites,
  reclaimedWood,
  textiles,
  electronics;

  String get firestoreKey {
    switch (this) {
      case MaterialCategory.plastics:
        return 'plastics';
      case MaterialCategory.metals:
        return 'metals';
      case MaterialCategory.glass:
        return 'glass';
      case MaterialCategory.paperCardboard:
        return 'paper_cardboard';
      case MaterialCategory.rubberComposites:
        return 'rubber_composites';
      case MaterialCategory.reclaimedWood:
        return 'reclaimed_wood';
      case MaterialCategory.textiles:
        return 'textiles';
      case MaterialCategory.electronics:
        return 'electronics';
    }
  }

  String get displayLabel {
    switch (this) {
      case MaterialCategory.plastics:
        return 'Plastics';
      case MaterialCategory.metals:
        return 'Metals';
      case MaterialCategory.glass:
        return 'Glass';
      case MaterialCategory.paperCardboard:
        return 'Paper & Cardboard';
      case MaterialCategory.rubberComposites:
        return 'Rubber & Composites';
      case MaterialCategory.reclaimedWood:
        return 'Reclaimed Wood';
      case MaterialCategory.textiles:
        return 'Textiles';
      case MaterialCategory.electronics:
        return 'Electronics';
    }
  }

  static MaterialCategory fromFirestoreKey(String key) {
    return MaterialCategory.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => MaterialCategory.plastics,
    );
  }
}
