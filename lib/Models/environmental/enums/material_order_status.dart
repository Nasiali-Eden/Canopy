enum MaterialOrderStatus {
  active,
  paused,
  fulfilled,
  expired,
  draft;

  String get firestoreKey {
    switch (this) {
      case MaterialOrderStatus.active:
        return 'active';
      case MaterialOrderStatus.paused:
        return 'paused';
      case MaterialOrderStatus.fulfilled:
        return 'fulfilled';
      case MaterialOrderStatus.expired:
        return 'expired';
      case MaterialOrderStatus.draft:
        return 'draft';
    }
  }

  String get displayLabel {
    switch (this) {
      case MaterialOrderStatus.active:
        return 'Active';
      case MaterialOrderStatus.paused:
        return 'Paused';
      case MaterialOrderStatus.fulfilled:
        return 'Fulfilled';
      case MaterialOrderStatus.expired:
        return 'Expired';
      case MaterialOrderStatus.draft:
        return 'Draft';
    }
  }

  static MaterialOrderStatus fromFirestoreKey(String key) {
    return MaterialOrderStatus.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => MaterialOrderStatus.draft,
    );
  }
}
