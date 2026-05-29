enum TreeSpecies {
  grevilleaRobusta,
  azadirachtaIndica,
  acaciaXanthophloea,
  markhamiaLutea,
  crotonMacrostachyus,
  erythrinaAbyssinica,
  ficusThonningii,
  prunusAfricana,
  sennaSiamea,
  casuarinaEquisetifolia,
  eucalyptusGrandis,
  cupressusLusitanica,
  mangiferaIndica,
  perseaAmericana,
  other;

  String get firestoreKey {
    switch (this) {
      case TreeSpecies.grevilleaRobusta:
        return 'grevillea_robusta';
      case TreeSpecies.azadirachtaIndica:
        return 'azadirachta_indica';
      case TreeSpecies.acaciaXanthophloea:
        return 'acacia_xanthophloea';
      case TreeSpecies.markhamiaLutea:
        return 'markhamia_lutea';
      case TreeSpecies.crotonMacrostachyus:
        return 'croton_macrostachyus';
      case TreeSpecies.erythrinaAbyssinica:
        return 'erythrina_abyssinica';
      case TreeSpecies.ficusThonningii:
        return 'ficus_thonningii';
      case TreeSpecies.prunusAfricana:
        return 'prunus_africana';
      case TreeSpecies.sennaSiamea:
        return 'senna_siamea';
      case TreeSpecies.casuarinaEquisetifolia:
        return 'casuarina_equisetifolia';
      case TreeSpecies.eucalyptusGrandis:
        return 'eucalyptus_grandis';
      case TreeSpecies.cupressusLusitanica:
        return 'cupressus_lusitanica';
      case TreeSpecies.mangiferaIndica:
        return 'mangifera_indica';
      case TreeSpecies.perseaAmericana:
        return 'persea_americana';
      case TreeSpecies.other:
        return 'other';
    }
  }

  String get displayLabel {
    switch (this) {
      case TreeSpecies.grevilleaRobusta:
        return 'Grevillea (Silky Oak)';
      case TreeSpecies.azadirachtaIndica:
        return 'Neem';
      case TreeSpecies.acaciaXanthophloea:
        return 'Fever Tree';
      case TreeSpecies.markhamiaLutea:
        return 'Markhamia';
      case TreeSpecies.crotonMacrostachyus:
        return 'Croton';
      case TreeSpecies.erythrinaAbyssinica:
        return 'Flame Tree';
      case TreeSpecies.ficusThonningii:
        return 'Wild Fig';
      case TreeSpecies.prunusAfricana:
        return 'Red Stinkwood';
      case TreeSpecies.sennaSiamea:
        return 'Siamese Senna';
      case TreeSpecies.casuarinaEquisetifolia:
        return 'Casuarina';
      case TreeSpecies.eucalyptusGrandis:
        return 'Eucalyptus';
      case TreeSpecies.cupressusLusitanica:
        return 'Cypress';
      case TreeSpecies.mangiferaIndica:
        return 'Mango';
      case TreeSpecies.perseaAmericana:
        return 'Avocado';
      case TreeSpecies.other:
        return 'Other';
    }
  }

  static TreeSpecies fromFirestoreKey(String key) {
    return TreeSpecies.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => TreeSpecies.other,
    );
  }
}
