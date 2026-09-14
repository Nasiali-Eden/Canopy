// lib/Models/environmental/models/monthly_tree_report.dart
//
// Phase 7.1 of the Minimal Release Roadmap ("Tree-Count Accounting — count
// survival, not carbon"). The carbon-credit readiness assessment is explicit
// that "a tree surviving 90 days is valuable operational evidence, but it
// does not establish a quantified [carbon] removal." This model intentionally
// carries only counts — no carbon-equivalent figure is derived anywhere in
// this file or its consumers. That conversion is a later, separate
// methodology + registry-partner decision (see the roadmap's Blockchain
// Integration Path, Stage 4), not something to infer here.

class TreeCheckpointCount {
  /// 1 = the ~30-day check, 2 = ~60-day, 3 = ~90-day, matching
  /// TreeUpdateSchedule's default 30-day update interval.
  final int checkpointNumber;
  final int daysApprox;

  /// Trees that have reached this checkpoint (have at least this many
  /// monthly updates recorded) and whose update at that checkpoint was
  /// marked alive.
  final int confirmedAlive;

  /// Trees that have reached this checkpoint at all (alive, dead, or
  /// missing) — the denominator for a survival rate.
  final int reachedCheckpoint;

  const TreeCheckpointCount({
    required this.checkpointNumber,
    required this.daysApprox,
    required this.confirmedAlive,
    required this.reachedCheckpoint,
  });

  double? get survivalRate =>
      reachedCheckpoint == 0 ? null : confirmedAlive / reachedCheckpoint;
}

class MonthlyTreeCountReport {
  final DateTime month;
  final int treesPlantedThisMonth;

  /// All-time total, for context alongside the monthly figure — not itself
  /// "this month's" number.
  final int totalTreesAllTime;

  /// The 90-day checkpoint mirrors TreeSurvival.survivalConfirmed90Day
  /// directly (the field EnvironmentOpsService.fetchVerificationSnapshot
  /// already treats as authoritative) rather than re-deriving it from
  /// monthlyUpdates, so this report never disagrees with that dashboard.
  final int treesConfirmedAlive90DayAllTime;

  final List<TreeCheckpointCount> checkpoints;

  const MonthlyTreeCountReport({
    required this.month,
    required this.treesPlantedThisMonth,
    required this.totalTreesAllTime,
    required this.treesConfirmedAlive90DayAllTime,
    required this.checkpoints,
  });
}
