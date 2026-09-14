// lib/Community/Incidents/incidents_feed_screen.dart
//
// "Where do reported issues actually show up" — answers that gap: a live
// feed reading the Incidents collection back (post_incident.dart only wrote
// it before; nothing displayed it). Map tab is left as a visible "Soon" —
// no pin-map exists yet and building a fake one would misrepresent what's
// real, same call as the Organisations leaderboard tab.

import 'package:flutter/material.dart';
import '../../Services/Incidents/incidents_service.dart';
import '../../Shared/theme/app_theme.dart';

class IncidentsFeedScreen extends StatefulWidget {
  const IncidentsFeedScreen({super.key});

  @override
  State<IncidentsFeedScreen> createState() => _IncidentsFeedScreenState();
}

class _IncidentsFeedScreenState extends State<IncidentsFeedScreen> {
  final _service = IncidentsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Reported Issues',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4),
                        ],
                      ),
                      child: const Text('List',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text('Map · Soon',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen.withOpacity(0.35))),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<IncidentReport>>(
              stream: _service.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load reports.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.darkGreen.withOpacity(0.6))),
                  );
                }
                final reports = snapshot.data ?? const [];
                if (reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No reports yet. Reports submitted from "Report an Issue" show up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.5)),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => _ReportCard(report: reports[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IncidentReport report;
  const _ReportCard({required this.report});

  Color get _statusColor {
    switch (report.status) {
      case IncidentStatus.pending:
        return const Color(0xFF7A6329);
      case IncidentStatus.verifying:
        return AppTheme.accent;
      case IncidentStatus.confirmed:
        return AppTheme.primary;
      case IncidentStatus.resolved:
        return AppTheme.darkGreen;
    }
  }

  Color get _statusBg {
    switch (report.status) {
      case IncidentStatus.pending:
        return const Color(0x2EC4A961);
      case IncidentStatus.verifying:
        return AppTheme.accent.withOpacity(0.15);
      case IncidentStatus.confirmed:
        return AppTheme.primary.withOpacity(0.14);
      case IncidentStatus.resolved:
        return AppTheme.darkGreen.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = report.images.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 88,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(report.images.first),
                      fit: BoxFit.cover)
                  : null,
              gradient: hasImage
                  ? null
                  : LinearGradient(
                      colors: [
                        AppTheme.accent.withOpacity(0.4),
                        AppTheme.lightGreen.withOpacity(0.55),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(report.headline,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(report.statusLabel,
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${report.type} · ${report.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(4, (i) {
                      final done = i < report.stepsDone;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i == 3 ? 0 : 3),
                          decoration: BoxDecoration(
                            color: done
                                ? AppTheme.primary
                                : AppTheme.darkGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
