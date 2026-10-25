// lib/Organization/Home/Programmes/org_programmes.dart
//
// Programmes (ORG_HANDOFF §3.6, F). Underline tabs Offerings · Enquiries ·
// Track record. Offerings: published cards with cover; drafts with a
// "4 of 6 sections" bar. Enquiries: rows with the question + Reply / Call;
// empty "Inbox is quiet". Track record: finished programmes.
// Listens to OrgShellScope.subTab 'enquiries' (from the dashboard).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../Models/programme.dart';
import '../../../Models/programme_enquiry.dart';
import '../../../theme/canopy_components.dart';
import '../../org_ui.dart';
import '../org_home.dart';
import 'programme_detail.dart';
import 'programme_editor.dart';
import 'programme_logic.dart';

class OrgProgrammes extends StatefulWidget {
  const OrgProgrammes({super.key});

  @override
  State<OrgProgrammes> createState() => _OrgProgrammesState();
}

class _OrgProgrammesState extends State<OrgProgrammes> {
  static const _tabs = ['offerings', 'enquiries', 'track'];
  String? _orgId;
  String _orgName = '';
  bool _loaded = false;
  int _tab = 0;
  ValueNotifier<String?>? _sub;
  late Stream<List<Programme>> _programmes;
  late Stream<List<ProgrammeEnquiry>> _enquiries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sub = OrgShellScope.of(context)?.subTab;
    if (sub != _sub) {
      _sub?.removeListener(_onSub);
      _sub = sub?..addListener(_onSub);
      _onSub();
    }
  }

  void _onSub() {
    final i = _tabs.indexOf(_sub?.value ?? '');
    if (i >= 0 && mounted) setState(() => _tab = i);
  }

  @override
  void dispose() {
    _sub?.removeListener(_onSub);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final u = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        _orgId = u.data()?['orgId'] as String?;
        if (_orgId != null) {
          _programmes = ProgrammeLogic.streamProgrammes(_orgId!);
          _enquiries = ProgrammeLogic.streamEnquiries(_orgId!);
          final o = await FirebaseFirestore.instance.collection('organizations').doc(_orgId).get();
          _orgName = ((o.data()?['org_name'] ?? o.data()?['name']) as String?) ?? '';
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  void _openEditor([Programme? p]) => Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute(builder: (_) => ProgrammeEditor(orgId: _orgId!, existing: p)));

  @override
  Widget build(BuildContext context) {
    final bar = canopyAppBar(context, title: 'Programmes', showBack: false);
    if (!_loaded) return CanopyScaffold(appBar: bar, body: const Center(child: CircularProgressIndicator()));
    if (_orgId == null) {
      return CanopyScaffold(
          appBar: bar,
          body: const CanopyEmptyState(icon: Icons.apartment_outlined, title: 'No organisation is linked to this account'));
    }
    return CanopyScaffold(
      appBar: bar,
      body: StreamBuilder<List<ProgrammeEnquiry>>(
        stream: _enquiries,
        builder: (context, enq) {
          final unread = (enq.data ?? const []).where((e) => e.status == EnquiryStatus.unread).length;
          return Column(children: [
            CanopyUnderlineTabs(
              tabs: const ['Offerings', 'Enquiries', 'Track record'],
              index: _tab,
              badges: {1: unread},
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: _tab == 1
                  ? _EnquiriesTab(snap: enq)
                  : StreamBuilder<List<Programme>>(
                      stream: _programmes,
                      builder: (context, snap) {
                        if (snap.hasError) return const CanopyErrorState(title: "Couldn't load programmes");
                        if (!snap.hasData) {
                          return ListView(
                              padding: const EdgeInsets.all(CanopySpace.gutter),
                              children: const [CanopyCardSkeleton(), SizedBox(height: CanopySpace.s12), CanopyCardSkeleton()]);
                        }
                        final all = snap.data!;
                        return _tab == 0
                            ? _offerings(all.where((p) => p.status != ProgrammeStatus.completed && p.status != ProgrammeStatus.archived).toList())
                            : _trackRecord(all.where((p) => p.status == ProgrammeStatus.completed).toList());
                      },
                    ),
            ),
          ]);
        },
      ),
      sticky: _tab == 0
          ? StickyActionBar(children: [CanopyButton(label: 'New programme', expand: true, onPressed: () => _openEditor())])
          : null,
    );
  }

  Widget _offerings(List<Programme> list) {
    final drafts = list.where((p) => p.status == ProgrammeStatus.draft).toList();
    final live = list.where((p) => p.status != ProgrammeStatus.draft).toList();
    if (list.isEmpty) {
      return const CanopyEmptyState(
        icon: Icons.layers_outlined,
        title: 'No programmes yet',
        line: 'Courses, workshops, mentorship or services you offer — members find them on your public page.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
      children: [
        for (final p in live) ...[_liveCard(p), const SizedBox(height: CanopySpace.s12)],
        if (drafts.isNotEmpty) ...[
          CanopySectionHeader(title: 'Drafts · ${drafts.length}', padding: EdgeInsets.zero),
          const Padding(
            padding: EdgeInsets.only(bottom: CanopySpace.s12),
            child: CanopyCallout(icon: Icons.lock_outline, text: 'Only your team sees drafts.'),
          ),
          for (final p in drafts) ...[_draftCard(p), const SizedBox(height: CanopySpace.s12)],
        ],
      ],
    );
  }

  Widget _liveCard(Programme p) {
    final c = context.canopy;
    return CanopyCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context, rootNavigator: true)
          .push(MaterialPageRoute(builder: (_) => ProgrammeDetail(programme: p, orgName: _orgName, repView: true))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(CanopyRadius.md - 1)),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: CanopyImage(url: p.coverImageUrl, fallbackIcon: programmeTypeIcon(p.type)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LabelRow(children: [
              StatusLabel(p.type.label, color: c.inkMuted, icon: programmeTypeIcon(p.type)),
              _statusLabel(p, c),
              StatusLabel(programmePrice(p), color: c.ink),
            ]),
            const SizedBox(height: CanopySpace.s4),
            Text(p.title, style: CanopyType.subhead.copyWith(color: c.ink)),
            if (p.summary.isNotEmpty)
              Text(p.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: CanopyType.body.copyWith(color: c.inkMuted)),
            const SizedBox(height: CanopySpace.s8),
            Row(children: [
              CanopyButton.secondary(label: 'Edit', size: CanopyButtonSize.compact, onPressed: () => _openEditor(p)),
              const Spacer(),
              Text('See as members do', style: CanopyType.label.copyWith(color: c.primaryInk)),
              Icon(Icons.chevron_right, size: CanopyIconSize.s18, color: c.primaryInk),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _draftCard(Programme p) {
    final c = context.canopy;
    final done = ProgrammeLogic.sectionsDone(p).where((d) => d).length;
    return CanopyCard(
      padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
      onTap: () => _openEditor(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LabelRow(children: [
          const ContentStateLabel(ContentState.draft),
          StatusLabel(p.type.label, color: c.inkMuted),
        ]),
        const SizedBox(height: CanopySpace.s2),
        Text(p.title.isEmpty ? 'Untitled programme' : p.title, style: CanopyType.bodyStrong.copyWith(color: c.ink)),
        const SizedBox(height: CanopySpace.s8),
        Row(children: [
          Text('$done of 6 sections', style: CanopyType.caption.copyWith(color: c.inkMuted)),
          const SizedBox(width: CanopySpace.s12),
          Expanded(child: CanopyProgressBar(value: done / 6, ink: true)),
          const SizedBox(width: CanopySpace.s12),
          Text('Continue', style: CanopyType.label.copyWith(color: c.primaryInk)),
        ]),
      ]),
    );
  }

  Widget _statusLabel(Programme p, CanopyPalette c) => switch (p.status) {
        ProgrammeStatus.active => StatusLabel('Running', color: c.success),
        ProgrammeStatus.upcoming => StatusLabel('Upcoming', color: c.info),
        ProgrammeStatus.completed => StatusLabel('Finished', color: c.inkMuted),
        ProgrammeStatus.archived => StatusLabel('Archived', color: c.inkMuted),
        ProgrammeStatus.draft => const ContentStateLabel(ContentState.draft),
      };

  Widget _trackRecord(List<Programme> list) {
    final c = context.canopy;
    if (list.isEmpty) {
      return const CanopyEmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'Nothing finished yet',
        line: 'Mark a programme Finished in its last section and it shows here — and on your public page.',
      );
    }
    list.sort((a, b) => (b.schedule.endDate ?? b.updatedAt ?? DateTime(0)).compareTo(a.schedule.endDate ?? a.updatedAt ?? DateTime(0)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
      children: [
        CanopyListGroup(children: [
          for (final p in list)
            DenseRow(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(CanopyRadius.xs),
                child: SizedBox(width: 40, height: 40, child: CanopyImage(url: p.coverImageUrl, fallbackIcon: programmeTypeIcon(p.type))),
              ),
              title: p.title,
              subtitle: [
                p.type.label,
                if (p.schedule.endDate != null) 'Ended ${DateFormat('MMM yyyy').format(p.schedule.endDate!)}',
                if (p.details.certificateOffered) 'Certificate',
              ].join(' · '),
              trailing: Icon(Icons.chevron_right, color: c.inkFaint),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => ProgrammeDetail(programme: p, orgName: _orgName, repView: true))),
            ),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENQUIRIES
// ─────────────────────────────────────────────────────────────────────────────

class _EnquiriesTab extends StatelessWidget {
  final AsyncSnapshot<List<ProgrammeEnquiry>> snap;
  const _EnquiriesTab({required this.snap});

  Future<void> _reply(BuildContext context, ProgrammeEnquiry e, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'no app';
      if (e.status != EnquiryStatus.responded) await ProgrammeLogic.markResponded(e.id);
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't open that. Try again.", error: true);
    }
  }

  void _open(BuildContext context, ProgrammeEnquiry e) {
    if (e.status == EnquiryStatus.unread) ProgrammeLogic.markRead(e.id);
    final c = context.canopy;
    showCanopySheet(context, builder: (ctx) {
      return CanopySheetBody(
        title: e.fromUserName.isEmpty ? 'Member' : e.fromUserName,
        caption: 'About ${e.programmeTitle}',
        children: [
          Container(
            padding: const EdgeInsets.only(left: CanopySpace.s12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: c.outlineStrong, width: 2))),
            child: Text(e.message, style: CanopyType.body.copyWith(fontSize: 16, height: 1.5, color: c.ink)),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyListGroup(children: [
            if (e.contactPhone?.isNotEmpty ?? false)
              CanopyListRow(icon: Icons.phone_outlined, title: e.contactPhone!, subtitle: 'Phone', chevron: false),
            if (e.contactEmail?.isNotEmpty ?? false)
              CanopyListRow(icon: Icons.mail_outline, title: e.contactEmail!, subtitle: 'Email', chevron: false),
            if (!(e.contactPhone?.isNotEmpty ?? false) && !(e.contactEmail?.isNotEmpty ?? false))
              const CanopyListRow(icon: Icons.info_outline, title: 'No contact details left', chevron: false),
          ]),
        ],
        actions: [
          if (e.contactEmail?.isNotEmpty ?? false)
            CanopyButton(
              label: 'Reply by email',
              expand: true,
              onPressed: () => _reply(ctx, e, Uri(scheme: 'mailto', path: e.contactEmail, query: 'subject=${Uri.encodeComponent('Re: ${e.programmeTitle}')}')),
            ),
          if (e.contactPhone?.isNotEmpty ?? false)
            CanopyButton.secondary(
              label: 'Call',
              expand: true,
              onPressed: () => _reply(ctx, e, Uri(scheme: 'tel', path: e.contactPhone)),
            ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.canopy;
    if (snap.hasError) return const CanopyErrorState(title: "Couldn't load enquiries");
    if (!snap.hasData) {
      return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 4)]);
    }
    final list = snap.data!.where((e) => e.status != EnquiryStatus.closed).toList();
    if (list.isEmpty) {
      return const CanopyEmptyState(
        icon: Icons.forum_outlined,
        title: 'Inbox is quiet',
        line: 'Questions members ask about your programmes land here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
      children: [
        CanopyListGroup(children: [
          for (final e in list)
            DenseRow(
              leading: CanopyAvatar(name: e.fromUserName.isEmpty ? 'Member' : e.fromUserName, size: 40),
              title: '"${e.message.replaceAll('\n', ' ')}"',
              subtitle: [
                e.fromUserName.isEmpty ? 'Member' : e.fromUserName,
                e.programmeTitle,
                if (e.createdAt != null) DateFormat('d MMM').format(e.createdAt!),
              ].join(' · '),
              status: switch (e.status) {
                EnquiryStatus.unread => const YourTurnLabel(text: 'New'),
                EnquiryStatus.responded => StatusLabel('Replied', color: c.success),
                _ => null,
              },
              trailing: (e.contactPhone?.isNotEmpty ?? false)
                  ? CanopyButton.secondary(
                      label: 'Call',
                      size: CanopyButtonSize.compact,
                      onPressed: () => _reply(context, e, Uri(scheme: 'tel', path: e.contactPhone)))
                  : CanopyButton.secondary(label: 'Reply', size: CanopyButtonSize.compact, onPressed: () => _open(context, e)),
              onTap: () => _open(context, e),
            ),
        ]),
      ],
    );
  }
}
