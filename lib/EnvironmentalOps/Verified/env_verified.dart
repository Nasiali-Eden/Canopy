// lib/EnvironmentalOps/Verified/env_verified.dart
//
// Operations › Verified (ENVOPS_HANDOFF §3.6, D). Ships as the honest
// "Not built yet" screen: what independent verification will mean, and what
// to record now so it has evidence to work with. No credits, tiers, carbon
// or totals are shown before real verified data exists.
//
// The one live piece is recording evidence: transformed sites (e.g. a
// dumpsite cleared) with their follow-up checks — a record, not a claim.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Models/environmental/models/transformation_record_summary.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../theme/canopy_components.dart';
import '../envops_ui.dart';

class EnvVerifiedScreen extends StatefulWidget {
  const EnvVerifiedScreen({super.key});

  @override
  State<EnvVerifiedScreen> createState() => _EnvVerifiedScreenState();
}

class _EnvVerifiedScreenState extends State<EnvVerifiedScreen> {
  EnvironmentOpsContext? _ctx;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    EnvironmentOpsService.instance.resolveContext().then((c) {
      if (mounted) {
        setState(() {
          _ctx = c;
          _loading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _logSite() async {
    final c = _ctx;
    if (c == null) return;
    final r = await showCanopySheet<(String, String, DateTime)>(context, builder: (_) => _LogSiteSheet(area: c.area));
    if (r == null) return;
    try {
      await EnvironmentOpsService.instance.createTransformationRecord(orgId: c.orgId, siteLabel: r.$1, area: r.$2, interventionDate: r.$3);
      if (mounted) showCanopySnack(context, 'Site recorded. Follow-up check due in about 30 days.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't record the site. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
      children: [
        const CanopyComingSoon(
          boxed: true,
          icon: Icons.verified_outlined,
          label: 'Not built yet',
          title: 'Independent verification',
          line: 'Nothing here is verified by a third party today, and Canopy issues no credits.',
        ),
        const FieldEyebrow('What verification will mean'),
        for (final (t, l) in const [
          ('Someone outside your organisation checks the evidence', 'Photos, GPS points and follow-up visits — not just your own records.'),
          ('Survival and upkeep over time, not one-off claims', 'Trees counted alive at each check; cleared sites checked again later.'),
          ('A public record you can point funders to', 'Shared only once the checks are real.'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: CanopySpace.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
              Text(l, style: CanopyType.body.copyWith(color: p.inkMuted)),
            ]),
          ),
        const FieldEyebrow('What to record now'),
        const ReadinessChecklist(items: [
          ReadinessItem('Map the areas you work in', ReadinessState.todo, line: 'Territory — walk or tap the boundary'),
          ReadinessItem('Record plantings with 3 photos and a location', ReadinessState.todo, line: 'Trees'),
          ReadinessItem('Log every handoff in kg', ReadinessState.todo, line: 'Fleet'),
          ReadinessItem('Record sites you transform, then check them again', ReadinessState.todo, line: 'Below'),
        ]),
        FieldEyebrow('Transformed sites', actionLabel: _ctx == null ? null : 'Record a site', onAction: _logSite),
        if (_ctx == null)
          Text('Link an organisation to record sites.', style: CanopyType.body.copyWith(color: p.inkMuted))
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('transformation_records').where('orgId', isEqualTo: _ctx!.orgId).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return const CanopyErrorState(inline: true, title: "Couldn't load sites.");
              if (!snap.hasData) return const CanopyListSkeleton(rows: 2);
              final sites = snap.data!.docs.map(TransformationRecordSummary.fromFirestore).toList()
                ..sort((a, b) => (b.interventionDate ?? DateTime(0)).compareTo(a.interventionDate ?? DateTime(0)));
              if (sites.isEmpty) {
                return CanopyEmptyState(
                  boxed: true,
                  icon: Icons.cleaning_services_outlined,
                  title: 'No sites recorded',
                  line: 'Cleared a dumpsite or restored a patch of land? Record it, then check it again in 30 days.',
                  actionLabel: 'Record a site',
                  onAction: _logSite,
                );
              }
              return CanopyListGroup(children: [
                for (final s in sites)
                  CanopyListRow(
                    icon: Icons.cleaning_services_outlined,
                    title: s.siteLabel?.isNotEmpty == true ? s.siteLabel! : 'Site',
                    subtitle: [
                      s.locationArea,
                      if (s.interventionDate != null) 'Transformed ${DateFormat('d MMM yyyy').format(s.interventionDate!)}',
                    ].where((x) => x.isNotEmpty).join(' · '),
                    below: Padding(
                      padding: const EdgeInsets.only(top: CanopySpace.s4),
                      child: _followUp(s, p),
                    ),
                    chevron: false,
                  ),
              ]);
            },
          ),
      ],
    );
  }

  Widget _followUp(TransformationRecordSummary s, CanopyPalette p) {
    if (s.stage3.confirmed) {
      final held = s.stage3.siteHeld ?? false;
      return StatusLabel(held ? 'Checked again · still clear' : 'Checked again · did not hold', color: held ? p.success : p.danger);
    }
    final due = s.stage3.followUpDueAt;
    if (due == null) return StatusLabel('Recorded', color: p.inkMuted);
    final overdue = due.isBefore(DateTime.now());
    return overdue
        ? const YourTurnLabel(text: 'Follow-up check due')
        : StatusLabel('Follow-up ${DateFormat('d MMM').format(due)}', color: p.info);
  }
}

class _LogSiteSheet extends StatefulWidget {
  final String area;
  const _LogSiteSheet({required this.area});

  @override
  State<_LogSiteSheet> createState() => _LogSiteSheetState();
}

class _LogSiteSheetState extends State<_LogSiteSheet> {
  final _label = TextEditingController();
  late final _area = TextEditingController(text: widget.area);
  DateTime _date = DateTime.now();
  bool _showErrors = false;

  @override
  void dispose() {
    _label.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CanopySheetBody(
      title: 'Record a transformed site',
      caption: 'A place you cleared or restored. You check it again later.',
      children: [
        CanopyTextField(
          label: 'Site',
          hint: 'e.g. Gikomba river bank dumpsite',
          controller: _label,
          autofocus: true,
          error: _showErrors && _label.text.trim().isEmpty ? 'Name the site.' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Area', controller: _area),
        const SizedBox(height: CanopySpace.s16),
        CanopyPickerField(
          label: 'When it was transformed',
          value: DateFormat('EEE d MMM yyyy').format(_date),
          placeholder: 'Pick',
          icon: Icons.calendar_today_outlined,
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
        ),
      ],
      actions: [
        FieldButton(
          label: 'Record site',
          onPressed: () {
            if (_label.text.trim().isEmpty) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.pop(context, (_label.text.trim(), _area.text.trim(), _date));
          },
        ),
      ],
    );
  }
}
