enum MarkerType {
  processingHub,
  dropOffPoint,
  activeCollectionSite;

  String get firestoreKey {
    switch (this) {
      case MarkerType.processingHub:
        return 'processing_hub';
      case MarkerType.dropOffPoint:
        return 'drop_off_point';
      case MarkerType.activeCollectionSite:
        return 'active_collection_site';
    }
  }

  String get displayLabel {
    switch (this) {
      case MarkerType.processingHub:
        return 'Processing Hub';
      case MarkerType.dropOffPoint:
        return 'Drop-off Point';
      case MarkerType.activeCollectionSite:
        return 'Active Collection Site';
    }
  }

  static MarkerType fromFirestoreKey(String key) {
    return MarkerType.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => MarkerType.activeCollectionSite,
    );
  }
}
