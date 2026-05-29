enum TreeUpdateStatus {
  alive,
  dead,
  missing;

  String get firestoreKey {
    switch (this) {
      case TreeUpdateStatus.alive:
        return 'alive';
      case TreeUpdateStatus.dead:
        return 'dead';
      case TreeUpdateStatus.missing:
        return 'missing';
    }
  }

  String get displayLabel {
    switch (this) {
      case TreeUpdateStatus.alive:
        return 'Alive';
      case TreeUpdateStatus.dead:
        return 'Dead';
      case TreeUpdateStatus.missing:
        return 'Missing';
    }
  }

  static TreeUpdateStatus fromFirestoreKey(String key) {
    return TreeUpdateStatus.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => TreeUpdateStatus.alive,
    );
  }
}
