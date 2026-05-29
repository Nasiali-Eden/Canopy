enum FleetCollectorStatus {
  active,
  offShift,
  uncontactable,
  inactive,
  suspended;

  String get firestoreKey {
    switch (this) {
      case FleetCollectorStatus.active:
        return 'active';
      case FleetCollectorStatus.offShift:
        return 'off_shift';
      case FleetCollectorStatus.uncontactable:
        return 'uncontactable';
      case FleetCollectorStatus.inactive:
        return 'inactive';
      case FleetCollectorStatus.suspended:
        return 'suspended';
    }
  }

  String get displayLabel {
    switch (this) {
      case FleetCollectorStatus.active:
        return 'Active';
      case FleetCollectorStatus.offShift:
        return 'Off Shift';
      case FleetCollectorStatus.uncontactable:
        return 'Uncontactable';
      case FleetCollectorStatus.inactive:
        return 'Inactive';
      case FleetCollectorStatus.suspended:
        return 'Suspended';
    }
  }

  static FleetCollectorStatus fromFirestoreKey(String key) {
    return FleetCollectorStatus.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => FleetCollectorStatus.inactive,
    );
  }
}
