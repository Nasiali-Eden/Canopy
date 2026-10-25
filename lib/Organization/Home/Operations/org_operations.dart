// lib/Organization/Home/Operations/org_operations.dart
//
// Operations (ORG_HANDOFF §3.5). Tabs Events · Broadcast · Partners (badge) ·
// Impact.
//   Events: Upcoming / Past / Drafts; check-in events (QR) with Live / Ended;
//     a past-date card carries "Your turn · Date has passed" + Close out /
//     Verify check-ins.
//   Broadcast: New announcement + sent list (Urgent label, audience, expiry).
//   Partners: Awaiting your response · Active · Invitations sent; "Find
//     organisations nearby" → send a partnership request.
//   Impact: records In review / In verification / Verified, plus one dashed
//     "Permanent public records — on the roadmap" note. No chain links or
//     "anchored" claims.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../Services/Events/events_service.dart';
import '../../../Shared/Activities/activity_detail_screen.dart';
import '../../../Shared/Activities/create_activity.dart';
import '../../../Shared/utils/rich_body.dart';
import '../../../theme/canopy_components.dart';
import '../../Events/create_event_screen.dart';
import '../../org_ui.dart';
import '../Dashboard/contribution_review_screen.dart';
import '../org_home.dart';
import 'broadcast_composer.dart';
import 'send_partnership_request.dart';

class OrgOperations extends StatefulWidget {
  const OrgOperations({super.key});

  @override
  State<OrgOperations> createState() => _OrgOperationsState();
}

class _OrgOperationsState extends State<OrgOperations> {
  static const _tabs = ['events', 'broadcast', 'partners', 'impact'];
  String? _orgId;
  String _orgName = '';
  String? _orgLogo;
  bool _loaded = false;
  int _tab = 0;
  ValueNotifier<String?>? _sub;

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
          final o = await FirebaseFirestore.instance.collection('organizations').doc(_orgId).get();
          _orgName = ((o.data()?['org_name'] ?? o.data()?['name']) as String?) ?? '';
          _orgLogo = (o.data()?['logoUrl'] ?? o.data()?['profilePhoto']) as String?;
          _adoptOrphans(uid, _orgId!);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  /// Self-heal: activities created while the org id couldn't be resolved
  /// were written with an empty orgId — reclaim them for this org.
  Future<void> _adoptOrphans(String uid, String orgId) async {
    try {
      final mine =
          await FirebaseFirestore.instance.collection('activities').where('createdBy', isEqualTo: uid).get();
      final orphans = mine.docs.where((d) {
        final v = d.data()['orgId'];
        return v == null || (v is String && v.isEmpty);
      });
      if (orphans.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in orphans) {
        batch.update(d.reference, {'orgId': orgId});
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Operations', showBack: false),
          body: const Center(child: CircularProgressIndicator()));
    }
    final orgId = _orgId;
    if (orgId == null) {
      return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Operations', showBack: false),
          body: const CanopyEmptyState(icon: Icons.apartment_outlined, title: 'No organisation is linked to this account'));
    }
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Operations', showBack: false),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orgPartners').where('orgId', isEqualTo: orgId).snapshots(),
        builder: (context, snap) {
          final awaiting = (snap.data?.docs ?? const []).where((d) => d.data()['status'] == 'pending').length;
          return Column(children: [
            CanopyUnderlineTabs(
              tabs: const ['Events', 'Broadcast', 'Partners', 'Impact'],
              index: _tab,
              badges: {2: awaiting},
              scrollable: true,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _EventsTab(orgId: orgId, orgName: _orgName),
                1 => _BroadcastTab(orgId: orgId, orgName: _orgName, orgLogo: _orgLogo),
                2 => _PartnersTab(orgId: orgId, docs: snap.data?.docs, error: snap.hasError),
                _ => _ImpactTab(orgId: orgId),
              },
            ),
          ]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _when(Map<String, dynamic> d) {
  final raw = d['scheduledAt'] ?? d['dateTime'] ?? d['date'];
  return raw is Timestamp ? raw.toDate() : null;
}

class _EventsTab extends StatefulWidget {
  final String orgId;
  final String orgName;
  const _EventsTab({required this.orgId, required this.orgName});

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  int _view = 0; // 0 upcoming · 1 past · 2 drafts

  Future<void> _closeOut(String id, String title) async {
    final ok = await showCanopyConfirm(context,
        title: 'Close out "$title"?',
        message: 'It moves to Past as completed. Members can still link contributions for you to confirm.',
        confirmLabel: 'Close out');
    if (!ok) return;
    try {
      await FirebaseFirestore.instance.collection('activities').doc(id).update({
        'status': 'completed',
        'impactStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) showCanopySnack(context, 'Closed out.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't close it out. Try again.", error: true);
    }
  }

  void _create() => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => CreateActivityScreen(returnOnSuccess: true, orgId: widget.orgId)));

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('activities').where('orgId', isEqualTo: widget.orgId).snapshots(),
      builder: (context, act) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('Events').where('orgId', isEqualTo: widget.orgId).snapshots(),
        builder: (context, ev) {
          if (act.hasError) return const CanopyErrorState(title: "Couldn't load events");
          if (!act.hasData) {
            return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 4, leadingSize: 56)]);
          }
          final now = DateTime.now();
          final docs = act.data!.docs;
          bool draft(Map<String, dynamic> d) =>
              (d['status'] as String? ?? '') == 'draft' || ((d['status'] ?? '') == '' && _when(d) == null);
          final drafts = docs.where((d) => draft(d.data())).toList();
          final past = docs.where((d) => !draft(d.data()) && (_when(d.data())?.isBefore(now) ?? false)).toList()
            ..sort((a, b) => _when(b.data())!.compareTo(_when(a.data())!));
          final upcoming = docs.where((d) => !draft(d.data()) && !(_when(d.data())?.isBefore(now) ?? true)).toList()
            ..sort((a, b) => _when(a.data())!.compareTo(_when(b.data())!));
          final checkins = (ev.data?.docs ?? const []).map(CanopyEvent.fromDoc).toList()
            ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

          final list = switch (_view) { 1 => past, 2 => drafts, _ => upcoming };
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
            children: [
              CanopySegmented<int>(
                options: const [(0, 'Upcoming'), (1, 'Past'), (2, 'Drafts')],
                value: _view,
                counts: {1: past.where((d) => d.data()['status'] != 'completed' && d.data()['status'] != 'cancelled').length},
                onChanged: (v) => setState(() => _view = v),
              ),
              const SizedBox(height: CanopySpace.s16),
              if (_view == 0 && checkins.any((e) => e.active)) ...[
                Text('CHECK-IN OPEN', style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s8),
                CanopyListGroup(children: [
                  for (final e in checkins.where((e) => e.active))
                    DenseRow(
                      title: e.title,
                      subtitle: e.meetingPoint,
                      status: LabelRow(children: [StatusLabel('Live', color: p.danger, live: true), PointsLabel(e.pointsPerCheckin)]),
                      trailing: CanopyButton.secondary(
                          label: 'Show QR',
                          size: CanopyButtonSize.compact,
                          onPressed: () => Navigator.of(context, rootNavigator: true)
                              .push(MaterialPageRoute(builder: (_) => EventLiveScreen(eventId: e.id)))),
                    ),
                ]),
                const SizedBox(height: CanopySpace.s16),
              ],
              if (list.isEmpty)
                CanopyEmptyState(
                  boxed: true,
                  icon: Icons.event_note_outlined,
                  title: switch (_view) { 1 => 'Nothing in the past yet', 2 => 'No drafts', _ => 'No upcoming events' },
                  actionLabel: _view == 0 ? 'Create an event' : null,
                  onAction: _view == 0 ? _create : null,
                )
              else
                for (final d in list) ...[
                  _eventCard(d.id, d.data(), p, pastDate: _view == 1),
                  const SizedBox(height: CanopySpace.s12),
                ],
              if (_view == 1 && checkins.any((e) => !e.active)) ...[
                const SizedBox(height: CanopySpace.s8),
                Text('CHECK-IN EVENTS', style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s8),
                CanopyListGroup(children: [
                  for (final e in checkins.where((e) => !e.active))
                    DenseRow(
                      title: e.title,
                      subtitle: e.endedAt == null ? 'Ended' : 'Ended ${DateFormat('d MMM').format(e.endedAt!)}',
                      trailing: Icon(Icons.chevron_right, color: p.inkFaint),
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(builder: (_) => EventLiveScreen(eventId: e.id))),
                    ),
                ]),
              ],
              const SizedBox(height: CanopySpace.s16),
              Row(children: [
                Expanded(child: CanopyButton.secondary(label: 'New activity', onPressed: _create)),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: CanopyButton.secondary(
                    label: 'Host check-in event',
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                        builder: (_) => CreateEventScreen(orgId: widget.orgId, orgName: widget.orgName))),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _eventCard(String id, Map<String, dynamic> d, CanopyPalette p, {required bool pastDate}) {
    final title = (d['title'] ?? d['name'] ?? 'Untitled') as String;
    final at = _when(d);
    final status = d['status'] as String? ?? 'open';
    final open = status != 'completed' && status != 'cancelled';
    final going = d['registeredCount'] as int? ?? d['participants'] as int? ?? 0;
    final max = d['maxParticipants'] as int? ?? 0;
    final needsCloseOut = pastDate && open;
    return CanopyCard(
      borderColor: needsCloseOut ? p.primary : null,
      borderWidth: needsCloseOut ? 1.5 : 1,
      padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
      onTap: () => Navigator.of(context, rootNavigator: true)
          .push(MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: id, activity: d))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (at != null) ...[CanopyDateBlock(date: at), const SizedBox(width: CanopySpace.s12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LabelRow(children: [
                if (needsCloseOut) const YourTurnLabel(text: 'Date has passed'),
                StatusLabel(
                    switch (status) {
                      'completed' => 'Completed',
                      'cancelled' => 'Cancelled',
                      'draft' => 'Draft',
                      'full' => 'Full',
                      _ => pastDate ? 'Ended' : 'Upcoming',
                    },
                    color: switch (status) {
                      'completed' => p.success,
                      'cancelled' => p.danger,
                      'draft' => p.inkMuted,
                      'full' => p.warning,
                      _ => pastDate ? p.inkMuted : p.info,
                    }),
              ]),
              const SizedBox(height: CanopySpace.s2),
              Text(title, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
              Text(
                [
                  if (at != null) DateFormat('HH:mm').format(at),
                  max > 0 ? '$going of $max going' : '$going going',
                ].join(' · '),
                style: CanopyType.caption.copyWith(color: p.inkMuted),
              ),
            ]),
          ),
        ]),
        if (max > 0 && !pastDate) ...[
          const SizedBox(height: CanopySpace.s8),
          CanopyProgressBar(value: going / max, ink: true),
        ],
        if (needsCloseOut) ...[
          const SizedBox(height: CanopySpace.s8),
          Row(children: [
            CanopyButton.secondary(label: 'Close out', size: CanopyButtonSize.compact, onPressed: () => _closeOut(id, title)),
            const SizedBox(width: CanopySpace.s8),
            CanopyButton.quiet(
              label: 'Verify check-ins',
              size: CanopyButtonSize.compact,
              onPressed: () => Navigator.of(context, rootNavigator: true)
                  .push(MaterialPageRoute(builder: (_) => ContributionReviewScreen(orgId: widget.orgId))),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BROADCAST
// ─────────────────────────────────────────────────────────────────────────────

class _BroadcastTab extends StatelessWidget {
  final String orgId;
  final String orgName;
  final String? orgLogo;
  const _BroadcastTab({required this.orgId, required this.orgName, this.orgLogo});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('announcements').where('orgId', isEqualTo: orgId).snapshots(),
      builder: (context, snap) {
        final docs = [...(snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])]
          ..sort((a, b) {
            final ta = (a.data()['createdAt'] ?? a.data()['sentAt']) as Timestamp?;
            final tb = (b.data()['createdAt'] ?? b.data()['sentAt']) as Timestamp?;
            return (tb?.millisecondsSinceEpoch ?? 0).compareTo(ta?.millisecondsSinceEpoch ?? 0);
          });
        return ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
          children: [
            CanopyButton(
              label: 'New announcement',
              expand: true,
              onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => BroadcastComposerScreen(orgId: orgId, orgName: orgName, orgLogoUrl: orgLogo))),
            ),
            const SizedBox(height: CanopySpace.section),
            const CanopySectionHeader(title: 'Sent', padding: EdgeInsets.zero),
            if (snap.hasError)
              const CanopyErrorState(inline: true, title: "Couldn't load sent announcements.")
            else if (!snap.hasData)
              const CanopyListSkeleton(rows: 2)
            else if (docs.isEmpty)
              const CanopyEmptyState(
                  boxed: true, icon: Icons.campaign_outlined, title: 'Nothing sent yet', line: 'Announcements reach members on their Home feed.')
            else
              CanopyListGroup(children: [
                for (final d in docs)
                  Builder(builder: (_) {
                    final a = d.data();
                    final sent = ((a['createdAt'] ?? a['sentAt']) as Timestamp?)?.toDate();
                    final exp = (a['expiresAt'] as Timestamp?)?.toDate();
                    final expired = exp != null && exp.isBefore(DateTime.now());
                    final audience = switch (a['audience'] ?? a['reach']) {
                      'team' => 'A team',
                      'partners' => 'Partners',
                      'nearby' => 'Nearby',
                      _ => 'All members',
                    };
                    final title = (a['title'] as String?)?.trim();
                    return DenseRow(
                      title: title?.isNotEmpty == true ? title! : richBodyToPlainText(a['body']),
                      subtitle: [
                        audience,
                        if (sent != null) DateFormat('d MMM').format(sent),
                        if (exp != null) expired ? 'Expired' : 'Until ${DateFormat('d MMM').format(exp)}',
                      ].join(' · '),
                      status: a['isUrgent'] == true ? StatusLabel('Urgent', color: p.danger) : null,
                    );
                  }),
              ]),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTNERS
// ─────────────────────────────────────────────────────────────────────────────

class _PartnersTab extends StatelessWidget {
  final String orgId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs;
  final bool error;
  const _PartnersTab({required this.orgId, required this.docs, required this.error});

  void _find(BuildContext context) => Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute(builder: (_) => SendPartnershipRequestScreen(orgId: orgId)));

  /// Both halves of a partnership (ours + the mirror in the other org).
  Future<List<DocumentReference<Map<String, dynamic>>>> _halves(String id) async {
    final col = FirebaseFirestore.instance.collection('orgPartners');
    final doc = await col.doc(id).get();
    final pair = doc.data()?['pairId'] as String?;
    if (pair == null) return [col.doc(id)];
    final s = await col.where('pairId', isEqualTo: pair).get();
    return {col.doc(id), ...s.docs.map((d) => d.reference)}.toList();
  }

  Future<void> _set(BuildContext context, String id, String status) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final r in await _halves(id)) {
        batch.update(r, {'status': status, 'respondedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      if (context.mounted) showCanopySnack(context, status == 'active' ? 'Partnership accepted.' : 'Updated.');
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    }
  }

  Future<void> _remove(BuildContext context, String id, String title, String confirm) async {
    final ok = await showCanopyConfirm(context, title: title, message: 'The other organisation is no longer shown as a partner.', confirmLabel: confirm, danger: true);
    if (!ok) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final r in await _halves(id)) {
        batch.delete(r);
      }
      await batch.commit();
    } catch (_) {
      if (context.mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (error) return const CanopyErrorState(title: "Couldn't load partners");
    if (docs == null) {
      return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 3)]);
    }
    final pending = docs!.where((d) => d.data()['status'] == 'pending').toList();
    final active = docs!.where((d) => d.data()['status'] == 'active').toList();
    final invited = docs!.where((d) => d.data()['status'] == 'invited').toList();

    Widget card(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final a = d.data();
      final name = (a['partnerName'] as String?) ?? 'Organisation';
      final status = a['status'] as String? ?? 'invited';
      final msg = (a['message'] as String?)?.trim() ?? '';
      return CanopyCard(
        borderColor: status == 'pending' ? p.primary : null,
        borderWidth: status == 'pending' ? 1.5 : 1,
        padding: const EdgeInsets.all(CanopyWorkspace.cardPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CanopyAvatar(url: a['partnerLogoUrl'] as String?, name: name, size: 40, org: true),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                LabelRow(children: [
                  if (status == 'pending') const YourTurnLabel(text: 'Awaiting your response'),
                  if (status == 'active') StatusLabel('Active', color: p.success),
                  if (status == 'invited') StatusLabel('Invited', color: p.info),
                  if ((a['partnerSector'] as String?)?.isNotEmpty ?? false) StatusLabel(a['partnerSector'] as String, color: p.inkMuted),
                ]),
              ]),
            ),
          ]),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: CanopySpace.s8),
            Container(
              padding: const EdgeInsets.only(left: CanopySpace.s12),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: p.outlineStrong, width: 2))),
              child: Text('"$msg"', style: CanopyType.body.copyWith(color: p.ink)),
            ),
          ],
          const SizedBox(height: CanopySpace.s8),
          if (status == 'pending')
            Row(children: [
              CanopyButton(label: 'Accept', size: CanopyButtonSize.compact, onPressed: () => _set(context, d.id, 'active')),
              const SizedBox(width: CanopySpace.s8),
              CanopyButton.quiet(
                  label: 'Decline',
                  size: CanopyButtonSize.compact,
                  onPressed: () => _remove(context, d.id, 'Decline $name?', 'Decline')),
            ])
          else if (status == 'active')
            CanopyButton.secondary(
              label: 'Contact',
              size: CanopyButtonSize.compact,
              onPressed: () => showCanopySheet(context,
                  builder: (ctx) => CanopySheetBody(title: name, children: [
                        CanopyListGroup(children: [
                          if ((a['partnerEmail'] as String?)?.isNotEmpty ?? false)
                            CanopyListRow(icon: Icons.mail_outline, title: a['partnerEmail'] as String, subtitle: 'Email'),
                          if ((a['partnerPhone'] as String?)?.isNotEmpty ?? false)
                            CanopyListRow(icon: Icons.phone_outlined, title: a['partnerPhone'] as String, subtitle: 'Phone'),
                          if (!((a['partnerEmail'] as String?)?.isNotEmpty ?? false) &&
                              !((a['partnerPhone'] as String?)?.isNotEmpty ?? false))
                            const CanopyListRow(
                                icon: Icons.info_outline, title: 'No contact details shared', subtitle: 'Open their public page from Explore'),
                        ]),
                      ])),
            )
          else
            CanopyButton.quietDanger(
                label: 'Cancel invite',
                size: CanopyButtonSize.compact,
                onPressed: () => _remove(context, d.id, 'Cancel the invite to $name?', 'Cancel invite')),
        ]),
      );
    }

    Widget group(String title, List<QueryDocumentSnapshot<Map<String, dynamic>>> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CanopySectionHeader(title: '$title · ${list.length}', padding: EdgeInsets.zero),
            for (final d in list) ...[card(d), const SizedBox(height: CanopySpace.s12)],
          ],
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
      children: [
        if (docs!.isEmpty)
          CanopyEmptyState(
            boxed: true,
            icon: Icons.handshake_outlined,
            title: 'No partners yet',
            line: 'Work with other organisations on events and programmes.',
            actionLabel: 'Find organisations nearby',
            onAction: () => _find(context),
            primaryAction: true,
          )
        else ...[
          if (pending.isNotEmpty) group('Awaiting your response', pending),
          if (active.isNotEmpty) group('Active', active),
          if (invited.isNotEmpty) group('Invitations sent', invited),
          CanopyButton.secondary(label: 'Find organisations nearby', expand: true, onPressed: () => _find(context)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPACT
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactTab extends StatelessWidget {
  final String orgId;
  const _ImpactTab({required this.orgId});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('activities').where('orgId', isEqualTo: orgId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const CanopyErrorState(title: "Couldn't load impact records");
        if (!snap.hasData) {
          return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 3)]);
        }
        final docs = snap.data!.docs;
        final inReview = docs.where((d) => d.data()['status'] == 'completed' && (d.data()['impactStatus'] ?? 'pending') == 'pending').toList();
        final inVerification = docs.where((d) => d.data()['impactStatus'] == 'verifying').toList();
        final verified = docs.where((d) => d.data()['impactStatus'] == 'confirmed').toList();

        Widget row(QueryDocumentSnapshot<Map<String, dynamic>> d, String label, Color c) {
          final a = d.data();
          final metrics = (a['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
          return DenseRow(
            title: (a['title'] ?? a['name'] ?? 'Activity') as String,
            subtitle: [
              if (_when(a) != null) DateFormat('d MMM yyyy').format(_when(a)!),
              for (final e in metrics.entries) '${e.value} ${e.key}',
            ].join(' · '),
            status: StatusLabel(label, color: c),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
          children: [
            Row(children: [
              Expanded(child: MetricTile(value: '${inReview.length}', label: 'In review')),
              const SizedBox(width: CanopySpace.s16),
              Expanded(child: MetricTile(value: '${inVerification.length}', label: 'In verification')),
              const SizedBox(width: CanopySpace.s16),
              Expanded(child: MetricTile(value: '${verified.length}', label: 'Verified')),
            ]),
            const SizedBox(height: CanopySpace.section),
            if (inReview.isEmpty && inVerification.isEmpty && verified.isEmpty)
              const CanopyEmptyState(
                boxed: true,
                icon: Icons.fact_check_outlined,
                title: 'No impact records yet',
                line: 'Close out an event to start its record.',
              )
            else
              CanopyListGroup(children: [
                for (final d in inReview) row(d, 'In review', p.warning),
                for (final d in inVerification) row(d, 'In verification', p.info),
                for (final d in verified) row(d, 'Verified', p.success),
              ]),
            const SizedBox(height: CanopySpace.section),
            const CanopyComingSoon(
              boxed: true,
              icon: Icons.public_outlined,
              title: 'Permanent public records',
              line: 'Verified impact published as a record anyone can check. Not built yet — nothing here is recorded publicly today.',
            ),
          ],
        );
      },
    );
  }
}
