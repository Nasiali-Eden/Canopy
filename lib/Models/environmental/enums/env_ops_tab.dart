enum EnvOpsTab {
  market,
  territory,
  trees,
  fleet,
  verified;

  String get firestoreKey {
    switch (this) {
      case EnvOpsTab.market:
        return 'market';
      case EnvOpsTab.territory:
        return 'territory';
      case EnvOpsTab.trees:
        return 'trees';
      case EnvOpsTab.fleet:
        return 'fleet';
      case EnvOpsTab.verified:
        return 'verified';
    }
  }

  String get displayLabel {
    switch (this) {
      case EnvOpsTab.market:
        return 'Market';
      case EnvOpsTab.territory:
        return 'Territory';
      case EnvOpsTab.trees:
        return 'Trees';
      case EnvOpsTab.fleet:
        return 'Fleet';
      case EnvOpsTab.verified:
        return 'Verified';
    }
  }

  static EnvOpsTab fromFirestoreKey(String key) {
    return EnvOpsTab.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => EnvOpsTab.market,
    );
  }
}
