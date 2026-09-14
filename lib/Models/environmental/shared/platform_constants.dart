abstract class PlatformConstants {
  // Trees
  static const int urbanGreeningCreditThresholdTrees = 50;
  static const int treeUpdateIntervalDays = 30;
  static const int treeOverdueThresholdDays = 30;
  static const int treeCriticalThresholdDays = 60;
  static const double treeGpsProximityToleranceMeters = 100;

  // Credits
  static const double plasticRecoveryCreditThresholdKg = 500;
  static const int dumpsiteTransformation30DayDays = 30;
  static const int dumpsiteTransformation90DayDays = 90;
  static const int zoneActivityCreditEligibilityMonths = 6;

  // Verification
  static const int verifierConsensusMinimum = 3;
  static const int crowdsourcedBaselineMinimum = 3;

  // Financials
  static const double collectorRoyaltyDefaultPct = 4;
  static const double collectorRoyaltyMaxPct = 5;
  static const double platformCommissionDefaultPct = 8;

  // Marketplace
  static const int storyFieldMinimumChars = 80;
  static const int marketOrderDefaultExpiryDays = 30;

  // Home Services
  //
  // Reconciles the two commission figures that existed in this codebase
  // before Services: marketplace_checkout.dart hardcodes a 5% cut on goods
  // (`_platformFee = priceKes * 0.05`) while this file separately declared
  // `platformCommissionDefaultPct = 8` without anything ever reading it.
  // Services adopts the latter, declared figure rather than inventing a
  // third number — goods keep their existing 5% (out of scope to change
  // here), Services launches at 8%.
  //
  // Both sides of a job are charged, mirroring how the goods Marketplace
  // already works: a platform commission comes out of what the PROVIDER is
  // paid (like the seller's 5%), and a flat booking fee is added to what the
  // REQUESTER pays (like the buyer's KSh 150 delivery-fee placeholder). See
  // ServiceBooking.computeFees in lib/Models/services/service_booking.dart.
  static const double serviceCommissionDefaultPct = platformCommissionDefaultPct;

  /// Flat fee added to the requester's total per one-off booking. Waived
  /// when the booking is recurring (a standing trash-collection pickup) —
  /// charging this on every weekly pickup would make the fee cost more than
  /// some collection tiers themselves.
  static const double serviceBookingFeeKes = 150;

  // UI
  static const int scaffoldBackgroundColor = 0xFFF7F5F0;
}
