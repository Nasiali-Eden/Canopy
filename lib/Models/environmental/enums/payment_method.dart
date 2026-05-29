enum PaymentMethod {
  mpesa,
  cash,
  cardano,
  stripe;

  String get firestoreKey {
    switch (this) {
      case PaymentMethod.mpesa:
        return 'mpesa';
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.cardano:
        return 'cardano';
      case PaymentMethod.stripe:
        return 'stripe';
    }
  }

  String get displayLabel {
    switch (this) {
      case PaymentMethod.mpesa:
        return 'M-Pesa';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.cardano:
        return 'Cardano';
      case PaymentMethod.stripe:
        return 'Card';
    }
  }

  static PaymentMethod fromFirestoreKey(String key) {
    return PaymentMethod.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => PaymentMethod.mpesa,
    );
  }
}
