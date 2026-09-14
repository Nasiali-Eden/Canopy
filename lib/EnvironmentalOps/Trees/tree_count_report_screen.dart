// lib/EnvironmentalOps/Trees/tree_count_report_screen.dart
//
// Phase 7.1 of the Minimal Release Roadmap — a monthly tree-count report:
// trees planted this month, and how many have been confirmed alive at each
// survival checkpoint reached so far. Deliberately NOT a carbon report — see
// monthly_tree_report.dart for why that conversion is out of scope here.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Models/environmental/models/monthly_tree_report.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../Shared/theme/app_theme.dart';

class TreeCountReportScreen extends StatefulWidget {
  final String orgId;

  const TreeCountReportScreen({super.key, required this.orgId});

  @override
  State<TreeCountReportScreen> createState() => _TreeCountReportScreenState();
}

class _TreeCountReportScreenState extends State<TreeCountReportScreen> {
  late Future<MonthlyTreeCountReport> _future;

  @override
  void initState() {
    super.initState();
    _future = EnvironmentOpsService.instance
        .fetchMonthlyTreeCountReport(orgId: widget.orgId);
  }

  void _refresh() {
    setState(() {
      _future = EnvironmentOpsService.instance
          .fetchMonthlyTreeCountReport(orgId: widget.orgId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Tree-Count Report',
            style: TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<MonthlyTreeCountReport>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Could not load the report. Pull to refresh or try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.darkGreen.withOpacity(0.6)),
                ),
              ),
            );
          }
          final report = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(report.month),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                ),
                const SizedBox(height: 12),
                _MonthCard(report: report),
                const SizedBox(height: 16),
                const Text(
                  'Survival checkpoints (all-time)',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen),
                ),
                const SizedBox(height: 4),
                Text(
                  'How many trees are confirmed alive by the time each check-in comes due.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.55)),
                ),
                const SizedBox(height: 12),
                for (final cp in report.checkpoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CheckpointRow(checkpoint: cp),
                  ),
                const SizedBox(height: 8),
                _DisclaimerCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final MonthlyTreeCountReport report;
  const _MonthCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.darkGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stat('${report.treesPlantedThisMonth}', 'Planted this month'),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          Expanded(
            child: _stat('${report.totalTreesAllTime}', 'Total planted'),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          Expanded(
            child: _stat(
                '${report.treesConfirmedAlive90DayAllTime}', 'Confirmed at 90d'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10.5),
        ),
      ],
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  final TreeCheckpointCount checkpoint;
  const _CheckpointRow({required this.checkpoint});

  @override
  Widget build(BuildContext context) {
    final rate = checkpoint.survivalRate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${checkpoint.daysApprox}d',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${checkpoint.confirmedAlive} of ${checkpoint.reachedCheckpoint} confirmed alive',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.darkGreen),
                ),
                const SizedBox(height: 2),
                Text(
                  rate == null
                      ? 'No trees have reached this checkpoint yet'
                      : '${(rate * 100).toStringAsFixed(0)}% survival at this check-in',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.darkGreen.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.tertiary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: AppTheme.darkGreen.withOpacity(0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a survival count, not a carbon report. A tree confirmed '
              'alive is operational evidence — it is not a quantified carbon '
              'removal. That conversion needs an accredited methodology and a '
              'registry partner, and isn\'t part of this figure.',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppTheme.darkGreen.withOpacity(0.65)),
            ),
          ),
        ],
      ),
    );
  }
}
