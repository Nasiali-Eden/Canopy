// lib/EnvironmentalOps/Trees/tree_count_report_screen.dart
//
// Monthly count report (ENVOPS_HANDOFF §3.4, T): trees planted this month,
// and how many are alive at each survival checkpoint (checked / total).
// Checkpoint intervals come from the data model. Export copies a CSV.
// Deliberately NOT a carbon estimate — it says so.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../Models/environmental/models/monthly_tree_report.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../theme/canopy_components.dart';
import '../envops_ui.dart';

class TreeCountReportScreen extends StatefulWidget {
  final String orgId;

  const TreeCountReportScreen({super.key, required this.orgId});

  @override
  State<TreeCountReportScreen> createState() => _TreeCountReportScreenState();
}

class _TreeCountReportScreenState extends State<TreeCountReportScreen> {
  late Future<MonthlyTreeCountReport> _future = _fetch();

  Future<MonthlyTreeCountReport> _fetch() => EnvironmentOpsService.instance.fetchMonthlyTreeCountReport(orgId: widget.orgId);

  Future<void> _export(MonthlyTreeCountReport r) async {
    final rows = <String>[
      'month,trees_planted_this_month,trees_all_time,confirmed_alive_90_day',
      '${DateFormat('yyyy-MM').format(r.month)},${r.treesPlantedThisMonth},${r.totalTreesAllTime},${r.treesConfirmedAlive90DayAllTime}',
      '',
      'checkpoint,days_approx,reached,confirmed_alive',
      for (final c in r.checkpoints) '${c.checkpointNumber},${c.daysApprox},${c.reachedCheckpoint},${c.confirmedAlive}',
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (mounted) showCanopySnack(context, 'Report CSV copied. Paste it into a spreadsheet.');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return FutureBuilder<MonthlyTreeCountReport>(
      future: _future,
      builder: (context, snap) {
        final r = snap.data;
        return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Tree count report', actions: [
            if (r != null) CanopyIconButton(icon: Icons.file_download_outlined, tooltip: 'Export CSV', onPressed: () => _export(r)),
          ]),
          body: snap.hasError
              ? CanopyErrorState(title: "Couldn't load the report", onRetry: () => setState(() => _future = _fetch()))
              : r == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _future = _fetch());
                        await _future;
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
                        children: [
                          Text(DateFormat('MMMM yyyy').format(r.month), style: CanopyType.title.copyWith(color: p.ink)),
                          const SizedBox(height: CanopySpace.s16),
                          SignalGrid(signals: [
                            SignalCard(value: '${r.treesPlantedThisMonth}', caption: 'Planted this month'),
                            SignalCard(value: '${r.totalTreesAllTime}', caption: 'Planted all time'),
                          ]),
                          const FieldEyebrow('Alive at each check'),
                          if (r.totalTreesAllTime == 0)
                            Text('No trees recorded yet.', style: CanopyType.body.copyWith(color: p.inkMuted))
                          else
                            CanopyListGroup(children: [
                              for (final c in r.checkpoints)
                                CanopyListRow(
                                  title: 'Check ${c.checkpointNumber} · about ${c.daysApprox} days',
                                  subtitle: c.reachedCheckpoint == 0
                                      ? 'No trees have reached this check yet'
                                      : '${c.confirmedAlive} of ${c.reachedCheckpoint} checked are alive',
                                  trailing: c.survivalRate == null
                                      ? null
                                      : Text('${(c.survivalRate! * 100).round()}%',
                                          style: CanopyField.signalValue.copyWith(fontSize: 22, color: p.ink)),
                                  chevron: false,
                                ),
                            ]),
                          const SizedBox(height: CanopySpace.section),
                          const CanopyCallout(
                            text: 'This counts living trees. It is not a carbon estimate — no carbon figure is calculated anywhere in Canopy.',
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}
