// lib/Organization/Home/Programmes/programme_detail.dart
//
// Programme detail (ORG_HANDOFF §3.6 T / §3.8). One page for both audiences:
//   repView — the org's own preview, with an "as members see it" callout
//     and Edit instead of the member actions.
//   public  — ImmersiveHeader cover, labels, facts group, "Ask a question"
//     (enquiry sheet) and/or the external link.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../Models/programme.dart';
import '../../../Shared/widgets/immersive_header.dart';
import '../../../theme/canopy_components.dart';
import 'programme_editor.dart';
import 'programme_enquiry_sheet.dart';

class ProgrammeDetail extends StatelessWidget {
  final Programme programme;
  final String orgName;
  final bool repView;

  const ProgrammeDetail({super.key, required this.programme, required this.orgName, this.repView = false});

  Programme get p => programme;

  Future<void> _openLink(BuildContext context) async {
    final raw = p.contact.externalLink?.trim() ?? '';
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showCanopySnack(context, "Couldn't open the link.", error: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.canopy;
    final s = p.schedule;
    final d = p.details;
    final df = DateFormat('EEE d MMM yyyy');
    final place = s.isOnline
        ? 'Online'
        : [s.location?.venue, s.location?.area, s.location?.city]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toSet()
            .join(', ');
    final hasLink = p.contact.externalLink?.isNotEmpty ?? false;
    final photos = p.supportingImageUrls;

    final facts = <Widget>[
      if (s.startDate != null)
        CanopyFactRow(
          icon: Icons.calendar_today_outlined,
          label: 'When',
          value: [
            df.format(s.startDate!),
            if (s.endDate != null) 'to ${df.format(s.endDate!)}',
          ].join(' '),
        ),
      CanopyFactRow(icon: Icons.repeat, label: 'How often', value: s.recurrence.label),
      if (d.duration.isNotEmpty) CanopyFactRow(icon: Icons.schedule, label: 'Duration', value: d.duration),
      if (place.isNotEmpty)
        CanopyFactRow(icon: s.isOnline ? Icons.laptop_outlined : Icons.place_outlined, label: 'Where', value: place),
      CanopyFactRow(icon: Icons.payments_outlined, label: 'Cost', value: programmePrice(p)),
      if (d.capacity != null) CanopyFactRow(icon: Icons.group_outlined, label: 'Spaces', value: '${d.capacity}'),
      if (d.eligibility.isNotEmpty)
        CanopyFactRow(icon: Icons.how_to_reg_outlined, label: 'Who can join', value: d.eligibility),
      if (d.certificateOffered)
        const CanopyFactRow(icon: Icons.workspace_premium_outlined, label: 'Certificate', value: 'On completion'),
    ];

    return CanopyScaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: ImmersiveHeader(imageUrl: p.coverImageUrl, fallbackIcon: programmeTypeIcon(p.type)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
          sliver: SliverList.list(children: [
            if (repView) ...[
              const CanopyCallout(icon: Icons.visibility_outlined, text: 'This is your programme as members see it.'),
              const SizedBox(height: CanopySpace.s16),
            ],
            LabelRow(children: [
              StatusLabel(p.type.label, color: c.inkMuted, icon: programmeTypeIcon(p.type)),
              switch (p.status) {
                ProgrammeStatus.active => StatusLabel('Running', color: c.success),
                ProgrammeStatus.upcoming => StatusLabel('Upcoming', color: c.info),
                ProgrammeStatus.completed => StatusLabel('Finished', color: c.inkMuted),
                _ => StatusLabel(p.status.label, color: c.inkMuted),
              },
            ]),
            const SizedBox(height: CanopySpace.s4),
            Text(p.title, style: CanopyType.display.copyWith(color: c.ink)),
            const SizedBox(height: CanopySpace.s4),
            Text('By $orgName', style: CanopyType.label.copyWith(color: c.inkMuted)),
            if (p.summary.isNotEmpty) ...[
              const SizedBox(height: CanopySpace.s12),
              Text(p.summary, style: CanopyType.body.copyWith(fontSize: 16, height: 1.5, color: c.ink)),
            ],
            const SizedBox(height: CanopySpace.section),
            CanopyListGroup(children: facts),
            if (p.description.isNotEmpty) ...[
              const CanopySectionHeader(title: 'About', padding: EdgeInsets.only(top: CanopySpace.section)),
              Text(p.description, style: CanopyType.body.copyWith(color: c.ink, height: 1.55)),
            ],
            if (photos.isNotEmpty) ...[
              const CanopySectionHeader(title: 'Photos', padding: EdgeInsets.only(top: CanopySpace.section)),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: CanopySpace.s8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(CanopyRadius.sm),
                    child: SizedBox(width: 160, child: CanopyImage(url: photos[i])),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
      sticky: repView
          ? StickyActionBar(children: [
              CanopyButton.secondary(
                label: 'Edit programme',
                expand: true,
                onPressed: () => Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (_) => ProgrammeEditor(orgId: p.orgId, existing: p))),
              ),
            ])
          : (p.isCompleted || (!p.canEnquire && !hasLink))
              ? null
              : StickyActionBar(children: [
                  Row(children: [
                    if (p.canEnquire)
                      Expanded(
                        child: CanopyButton(
                            label: 'Ask a question',
                            expand: true,
                            onPressed: () => showProgrammeEnquirySheet(context, p, orgName: orgName)),
                      ),
                    if (p.canEnquire && hasLink) const SizedBox(width: CanopySpace.s12),
                    if (hasLink)
                      Expanded(
                        child: p.canEnquire
                            ? CanopyButton.secondary(
                                label: 'Open link', expand: true, onPressed: () => _openLink(context))
                            : CanopyButton(
                                label: p.type == ProgrammeType.onlineCourse ? 'Go to course' : 'Sign up',
                                expand: true,
                                onPressed: () => _openLink(context)),
                      ),
                  ]),
                ]),
    );
  }
}
