// lib/Community/Incidents/incidents_feed_screen.dart
//
// Reported issues (v2): Everyone / Mine, one row per report (thumb, headline,
// type · where · when, status label). Tap opens a detail sheet with photos,
// the 4-step status timeline and "Open in Maps". Nothing advances status
// yet, so the timeline says who would do each step without claiming it.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Services/Incidents/incidents_service.dart';
import '../../Shared/Inputs/post_incident.dart' show incidentTypeIcon;
import '../../theme/canopy_components.dart';

class IncidentsFeedScreen extends StatefulWidget {
  final bool initialMine;
  const IncidentsFeedScreen({super.key, this.initialMine = false});

  @override
  State<IncidentsFeedScreen> createState() => _IncidentsFeedScreenState();
}

class _IncidentsFeedScreenState extends State<IncidentsFeedScreen> {
  final _service = IncidentsService();
  late bool _mine = widget.initialMine;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  int _retry = 0;

  @override
  Widget build(BuildContext context) {
    final bar = canopyAppBar(context, title: 'Reported issues', actions: [
      CanopyIconButton(icon: Icons.add, tooltip: 'Report an issue', onPressed: () => Navigator.pushNamed(context, '/report-incident')),
    ]);
    if (_uid == null) return CanopyScaffold(appBar: bar, body: const CanopySignedOutState());
    return CanopyScaffold(
      appBar: bar,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s8),
          child: CanopySegmented<bool>(
            options: const [(false, 'Everyone'), (true, 'Mine')],
            value: _mine,
            onChanged: (v) => setState(() => _mine = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<IncidentReport>>(
            key: ValueKey('$_mine$_retry'),
            stream: _mine ? _service.watchMine(_uid) : _service.watchAll(),
            builder: (context, snap) {
              if (snap.hasError) {
                return CanopyErrorState(title: "Couldn't load reports", onRetry: () => setState(() => _retry++));
              }
              if (!snap.hasData) return const CanopyListSkeleton();
              final reports = snap.data!;
              if (reports.isEmpty) {
                return CanopyEmptyState(
                  icon: Icons.report_outlined,
                  title: _mine ? "You haven't reported anything" : 'No reports yet',
                  line: 'Seen dumping, burning or a blocked drain? Report it so organisations nearby know.',
                  actionLabel: 'Report an issue',
                  primaryAction: true,
                  onAction: () => Navigator.pushNamed(context, '/report-incident'),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
                children: [
                  CanopyListGroup(children: [for (final r in reports) _ReportRow(report: r)]),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

(String, Color) incidentStatus(IncidentStatus s, CanopyPalette p) => switch (s) {
      IncidentStatus.pending => ('Pending', p.warning),
      IncidentStatus.verifying => ('Being checked', p.info),
      IncidentStatus.confirmed => ('Confirmed', p.primaryInk),
      IncidentStatus.resolved => ('Resolved', p.success),
    };

String _when(DateTime? d) {
  if (d == null) return 'Just now';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(d);
}

class _ReportRow extends StatelessWidget {
  final IncidentReport report;
  const _ReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final (label, color) = incidentStatus(report.status, p);
    return CanopyListRow(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(CanopyRadius.xs),
        child: SizedBox(
          width: 56,
          height: 56,
          child: CanopyImage(url: report.images.isEmpty ? null : report.images.first, fallbackIcon: incidentTypeIcon(report.type)),
        ),
      ),
      title: report.headline,
      subtitle: '${report.type} · ${report.whereLabel} · ${_when(report.timestamp)}',
      below: Padding(padding: const EdgeInsets.only(top: CanopySpace.s4), child: StatusLabel(label, color: color)),
      onTap: () => showCanopySheet(context, tall: true, builder: (_) => _ReportSheet(report: report)),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  final IncidentReport report;
  const _ReportSheet({required this.report});

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't open Maps.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final (label, color) = incidentStatus(report.status, p);
    final step = report.stepsDone;
    TimelineState st(int i) => i < step ? TimelineState.done : (i == step ? TimelineState.now : TimelineState.todo);
    return CanopySheetBody(
      title: report.headline,
      caption: '${report.type} · ${_when(report.timestamp)}',
      children: [
        StatusLabel(label, color: color),
        if (report.images.isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: report.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: CanopySpace.s8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(CanopyRadius.sm),
                child: SizedBox(width: 180, child: CanopyImage(url: report.images[i])),
              ),
            ),
          ),
        ],
        if (report.description.trim().isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s12),
          Text(report.description.trim(), style: CanopyType.body.copyWith(color: p.ink)),
        ],
        const SizedBox(height: CanopySpace.s16),
        CanopyListGroup(children: [
          CanopyListRow(
            icon: Icons.place_outlined,
            title: report.whereLabel,
            subtitle: report.hasPosition ? 'Open in Maps' : null,
            onTap: report.hasPosition ? () => _openMaps(context) : null,
            chevron: report.hasPosition,
          ),
        ]),
        const SizedBox(height: CanopySpace.s16),
        CanopyTimeline(steps: [
          TimelineStep('Reported', state: st(0)),
          TimelineStep('Being checked by an organisation', state: st(1)),
          TimelineStep('Confirmed', state: st(2)),
          TimelineStep('Resolved', state: st(3)),
        ]),
        const SizedBox(height: CanopySpace.s12),
        Text('Organisations can see every report. Checking and resolving are not tracked in the app yet.',
            style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
    );
  }
}
