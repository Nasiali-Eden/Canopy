enum VerificationTier {
  registered,
  verified,
  impactPartner,
  creditIssuer;

  String get firestoreKey {
    switch (this) {
      case VerificationTier.registered:
        return 'registered';
      case VerificationTier.verified:
        return 'verified';
      case VerificationTier.impactPartner:
        return 'impact_partner';
      case VerificationTier.creditIssuer:
        return 'credit_issuer';
    }
  }

  String get displayLabel {
    switch (this) {
      case VerificationTier.registered:
        return 'Registered';
      case VerificationTier.verified:
        return 'Verified';
      case VerificationTier.impactPartner:
        return 'Impact Partner';
      case VerificationTier.creditIssuer:
        return 'Credit Issuer';
    }
  }

  static VerificationTier fromFirestoreKey(String key) {
    return VerificationTier.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => VerificationTier.registered,
    );
  }
}
