enum TreeStatus {
  current,
  overdue,
  critical,
  unconfirmed,
  dead,
  removed;

  String get firestoreKey {
    switch (this) {
      case TreeStatus.current:
        return 'current';
      case TreeStatus.overdue:
        return 'overdue';
      case TreeStatus.critical:
        return 'critical';
      case TreeStatus.unconfirmed:
        return 'unconfirmed';
      case TreeStatus.dead:
        return 'dead';
      case TreeStatus.removed:
        return 'removed';
    }
  }

  String get displayLabel {
    switch (this) {
      case TreeStatus.current:
        return 'Current';
      case TreeStatus.overdue:
        return 'Overdue';
      case TreeStatus.critical:
        return 'Critical';
      case TreeStatus.unconfirmed:
        return 'Unconfirmed';
      case TreeStatus.dead:
        return 'Dead';
      case TreeStatus.removed:
        return 'Removed';
    }
  }

  static TreeStatus fromFirestoreKey(String key) {
    return TreeStatus.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => TreeStatus.unconfirmed,
    );
  }
}
