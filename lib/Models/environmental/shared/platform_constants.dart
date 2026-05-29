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

  // UI
  static const int scaffoldBackgroundColor = 0xFFF7F5F0;
}
