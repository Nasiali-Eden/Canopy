enum CreditType {
  plasticRecovery,
  dumpsiteTransformation,
  urbanGreening,
  waterwayClearance,
  fairCollector;

  String get firestoreKey {
    switch (this) {
      case CreditType.plasticRecovery:
        return 'plastic_recovery';
      case CreditType.dumpsiteTransformation:
        return 'dumpsite_transformation';
      case CreditType.urbanGreening:
        return 'urban_greening';
      case CreditType.waterwayClearance:
        return 'waterway_clearance';
      case CreditType.fairCollector:
        return 'fair_collector';
    }
  }

  String get displayLabel {
    switch (this) {
      case CreditType.plasticRecovery:
        return 'Plastic Recovery Credits';
      case CreditType.dumpsiteTransformation:
        return 'Dumpsite Transformation Credits';
      case CreditType.urbanGreening:
        return 'Urban Greening Credits';
      case CreditType.waterwayClearance:
        return 'Waterway Clearance Credits';
      case CreditType.fairCollector:
        return 'Fair Collector Credits';
    }
  }

  static CreditType fromFirestoreKey(String key) {
    return CreditType.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => CreditType.plasticRecovery,
    );
  }
}
