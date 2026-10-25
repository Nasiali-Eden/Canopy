// lib/Organization/Home/Dashboard/org_dashboard.dart
//
// Organisation dashboard (ORG_HANDOFF §3.1). Pending actions before metrics:
//   Masthead → Needs you (enquiries · partnership requests · contributions to
//   confirm · events past their date) → quick actions (Host event · Log work
//   · Article · Broadcast) → Happening now & next (date-block rows; the live
//   one has "Show QR") → Contributions to confirm → Overview · all time
//   (Events · Programmes · Volunteers · Articles).
// New org: no-cover masthead + profile progress, "Nothing needs you yet",
// numbered 3-step start, primary "Host your first event".
// Removed (unbuilt): Impact report, Member recruitment, Volunteer management
// placeholders — no quick action or link dead-ends.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../Community/Contributions/log_contribution.dart';
import '../../../Models/organization.dart';
import '../../../Services/Events/events_service.dart';
import '../../../Shared/Activities/activity_detail_screen.dart';
import '../../../Shared/Activities/create_article.dart';
import '../../../Shared/widgets/workspace_switch.dart';
import '../../../theme/canopy_components.dart';
import '../../Events/create_event_screen.dart';
import '../../Explorer/org_view_screen.dart';
import '../../org_ui.dart';
import '../Articles/org_articles.dart';
import '../Operations/broadcast_composer.dart';
import '../org_home.dart';
import 'contribution_review_screen.dart';
import 'edit_org_details_screen.dart';

class OrgDashboard extends StatefulWidget {
  const OrgDashboard({super.key});

  @override
  State<OrgDashboard> createState() => _OrgDashboardState();
}

class _OrgDashboardState extends State<OrgDashboard> {
  final _db = FirebaseFirestore.instance;
  String? _orgId;
  Organization? _org;
  Map<String, dynamic> _raw = const {};
  bool _loading = true;
  bool _failed = false;
  bool _uploading = false;

  late Future<List<PendingContribution>> _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('signed out');
      final user = await _db.collection('Users').doc(uid).get();
      final orgId = user.data()?['orgId'] as String?;
      if (orgId == null) throw StateError('no org');
      final doc = await _db.collection('organizations').doc(orgId).get();
      if (!doc.exists) throw StateError('org missing');
      var org = Organization.fromFirestore(doc);
      // Lazy backfill: capabilities missing from older registrations.
      if (org.capabilities.isEmpty) {
        final caps = capabilitiesForDesignation(org.designation);
        await _db.collection('organizations').doc(orgId).update({'capabilities': caps.map((c) => c.name).toList()});
        org = org.copyWith(capabilities: caps);
      }
      final raw = doc.data()!;
      await _backfillCoordinates(orgId, raw);
      if (!mounted) return;
      setState(() {
        _orgId = orgId;
        _org = org;
        _raw = raw;
        _pending = loadPendingContributions(orgId);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Lazy backfill: orgs registered before coordinates were persisted have no
  /// location, so they never appear on the map. Resolve it from city/area the
  /// same way registration does. Best-effort — never blocks the dashboard.
  Future<void> _backfillCoordinates(String orgId, Map<String, dynamic> raw) async {
    try {
      final gp = raw['location'];
      if (gp is GeoPoint || (raw['lat'] is num && raw['lng'] is num)) return;
      final city = raw['city'] as String?;
      if (city == null || city.isEmpty) return;
      final data = json.decode(await rootBundle.loadString('assets/Cities/African/KenyaCities.json')) as Map<String, dynamic>;
      final entries = ((data['kenyaCitiesAndLocations'] as Map<String, dynamic>)[city] as List?)?.cast<Map<String, dynamic>>();
      if (entries == null || entries.isEmpty) return;
      final area = raw['area'];
      final match = entries.firstWhere((e) => (e['area'] ?? e['name']).toString() == area, orElse: () => entries.first);
      final c = match['coordinates'] as Map<String, dynamic>?;
      final lat = (c?['lat'] as num?)?.toDouble();
      final lng = (c?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      await _db.collection('organizations').doc(orgId).update({'location': GeoPoint(lat, lng), 'lat': lat, 'lng': lng});
      raw['location'] = GeoPoint(lat, lng);
    } catch (_) {}
  }

  Future<void> _upload(String field) async {
    final orgId = _orgId;
    if (orgId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance.ref('organizations/$orgId/${field}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(file.path));
      await _db.collection('organizations').doc(orgId).update({field: await ref.getDownloadURL()});
      await _load();
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't upload the photo.", error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _push(Widget screen) =>
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => screen));

  void _hostEvent() => _push(CreateEventScreen(orgId: _orgId!, orgName: _org?.name ?? 'Your organisation'));

  double get _profileProgress {
    final fields = [
      _org?.logoUrl,
      _org?.coverImageUrl,
      _org?.about,
      _org?.designation,
      _raw['phone'] as String?,
      _raw['website'] as String?,
    ];
    return fields.where((f) => f != null && f.trim().isNotEmpty).length / fields.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return CanopyScaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: const [
            CanopySkeleton(height: 190, radius: 0),
            Padding(
              padding: EdgeInsets.all(CanopySpace.gutter),
              child: Column(children: [
                CanopySkeleton(height: 30, width: 220),
                SizedBox(height: CanopySpace.s16),
                CanopySkeleton(height: 112, radius: 14),
                SizedBox(height: CanopySpace.s16),
                CanopyListSkeleton(rows: 3, leadingSize: 56),
              ]),
            ),
          ],
        ),
      );
    }
    if (_failed || _orgId == null || _org == null) {
      return CanopyScaffold(
        body: CanopyErrorState(title: "Couldn't load your organisation", onRetry: _load),
      );
    }
    final org = _org!;
    final orgId = _orgId!;

    return Stack(children: [
      CanopyScaffold(
        body: RefreshIndicator(
          onRefresh: _load,
          child: _DashboardBody(
            orgId: orgId,
            org: org,
            raw: _raw,
            pending: _pending,
            profileProgress: _profileProgress,
            onAddCover: () => _upload('coverImageUrl'),
            onEditLogo: () => _upload('logoUrl'),
            onEditDetails: () async {
              final saved = await Navigator.of(context, rootNavigator: true)
                  .push<bool>(MaterialPageRoute(builder: (_) => EditOrgDetailsScreen(orgId: orgId)));
              if (saved == true) _load();
            },
            push: _push,
            hostEvent: _hostEvent,
            refreshPending: () => setState(() => _pending = loadPendingContributions(orgId)),
          ),
        ),
      ),
      if (_uploading)
        Positioned.fill(
          child: ColoredBox(
            color: context.canopy.scrim,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
    ]);
  }
}

class _DashboardBody extends StatelessWidget {
  final String orgId;
  final Organization org;
  final Map<String, dynamic> raw;
  final Future<List<PendingContribution>> pending;
  final double profileProgress;
  final VoidCallback onAddCover;
  final VoidCallback onEditLogo;
  final VoidCallback onEditDetails;
  final void Function(Widget) push;
  final VoidCallback hostEvent;
  final VoidCallback refreshPending;

  const _DashboardBody({
    required this.orgId,
    required this.org,
    required this.raw,
    required this.pending,
    required this.profileProgress,
    required this.onAddCover,
    required this.onEditLogo,
    required this.onEditDetails,
    required this.push,
    required this.hostEvent,
    required this.refreshPending,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final shell = OrgShellScope.of(context);
    final p = context.canopy;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('activities').where('orgId', isEqualTo: orgId).snapshots(),
      builder: (context, actSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('Events').where('orgId', isEqualTo: orgId).snapshots(),
        builder: (context, evSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('orgPartners').where('orgId', isEqualTo: orgId).snapshots(),
          builder: (context, partSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('programme_enquiries')
                .where('orgId', isEqualTo: orgId)
                .snapshots(),
            builder: (context, enqSnap) => FutureBuilder<List<PendingContribution>>(
              future: pending,
              builder: (context, pendSnap) {
                final now = DateTime.now();
                final acts = actSnap.data?.docs ?? const [];
                final events = (evSnap.data?.docs ?? const []).map(CanopyEvent.fromDoc).toList();
                final liveEvents = events.where((e) => e.active).toList();
                final partners = partSnap.data?.docs ?? const [];
                final partnerRequests = partners.where((d) => d.data()['status'] == 'pending').length;
                final activePartners = partners.where((d) => d.data()['status'] == 'active').length;
                final unreadEnquiries =
                    (enqSnap.data?.docs ?? const []).where((d) => d.data()['status'] == 'unread').length;
                final pendingList = pendSnap.data ?? const <PendingContribution>[];
                final pastDate = acts.where((d) {
                  final at = (d.data()['scheduledAt'] as Timestamp?)?.toDate();
                  final s = d.data()['status'] as String? ?? 'open';
                  return at != null &&
                      at.isBefore(now.subtract(const Duration(hours: 6))) &&
                      (s == 'open' || s == 'full' || s == 'active');
                }).length;
                final upcoming = acts
                    .where((d) =>
                        ((d.data()['scheduledAt'] as Timestamp?)?.toDate().isAfter(now) ?? false) &&
                        d.data()['status'] != 'cancelled')
                    .toList()
                  ..sort((a, b) => (a.data()['scheduledAt'] as Timestamp)
                      .compareTo(b.data()['scheduledAt'] as Timestamp));
                final loadingCounts = !actSnap.hasData || !partSnap.hasData || !enqSnap.hasData || !pendSnap.hasData;
                final isNew = actSnap.hasData &&
                    evSnap.hasData &&
                    acts.isEmpty &&
                    events.isEmpty &&
                    !org.hasCover;

                final todayCount = upcoming.where((d) {
                  final at = (d.data()['scheduledAt'] as Timestamp).toDate();
                  return at.year == now.year && at.month == now.month && at.day == now.day;
                }).length;
                final today = liveEvents.isNotEmpty
                    ? '${liveEvents.length} event${liveEvents.length == 1 ? ' is' : 's are'} live now.'
                    : todayCount > 0
                        ? '$todayCount activit${todayCount == 1 ? 'y' : 'ies'} today.'
                        : upcoming.isNotEmpty
                            ? 'Next up: ${upcoming.first.data()['title']} on ${DateFormat('EEE d MMM').format((upcoming.first.data()['scheduledAt'] as Timestamp).toDate())}.'
                            : null;

                return ListView(
                  padding: const EdgeInsets.only(bottom: CanopySpace.s32),
                  children: [
                    OrgMastheadView(
                      name: org.name,
                      logoUrl: org.logoUrl,
                      coverUrl: org.coverImageUrl,
                      verified: org.verified,
                      designation: org.designation,
                      area: org.city,
                      profileProgress: profileProgress,
                      stats: [
                        ('${org.memberCount ?? 0}', 'members', () => shell?.goTo(OrgTab.people)),
                        ('$activePartners', 'partners', () => shell?.goTo(OrgTab.operations, sub: 'partners')),
                        (org.activeSinceLabel, 'active since', null),
                      ],
                      today: today,
                      onSwitchWorkspace: () =>
                          workspaceSwitcher(context, activeContext: 'org', orgId: orgId, org: raw)
                              .openSheet(context),
                      onNotifications: () => Navigator.of(context, rootNavigator: true)
                          .pushNamed('/notifications'),
                      onPublicPage: () => push(OrgViewScreen(orgId: orgId, orgData: raw)),
                      onAddCover: onAddCover,
                      onEditLogo: onEditLogo,
                    ),
                    if (profileProgress < 1 && org.hasCover)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, 0),
                        child: CanopyButton.quiet(
                            label: 'Finish your profile', onPressed: onEditDetails),
                      ),
                    WorkspaceSection(
                      title: 'Needs you',
                      child: isNew
                          ? Text('Nothing needs you yet.',
                              style: CanopyType.body.copyWith(color: p.inkMuted))
                          : AttentionStrip(
                              loading: loadingCounts,
                              items: [
                                AttentionItem(unreadEnquiries, 'programme enquir${unreadEnquiries == 1 ? 'y' : 'ies'}',
                                    () => shell?.goTo(OrgTab.programmes, sub: 'enquiries')),
                                AttentionItem(partnerRequests, 'partnership request${partnerRequests == 1 ? '' : 's'}',
                                    () => shell?.goTo(OrgTab.operations, sub: 'partners')),
                                AttentionItem(pendingList.length,
                                    'contribution${pendingList.length == 1 ? '' : 's'} to confirm', () async {
                                  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                                      builder: (_) => ContributionReviewScreen(orgId: orgId)));
                                  refreshPending();
                                }),
                                AttentionItem(pastDate, 'event${pastDate == 1 ? '' : 's'} past ${pastDate == 1 ? 'its' : 'their'} date',
                                    () => shell?.goTo(OrgTab.operations, sub: 'events')),
                              ],
                            ),
                    ),
                    if (isNew)
                      WorkspaceSection(
                        title: 'Get started',
                        child: Column(children: [
                          _StartStep(1, 'Complete your profile', 'Logo, cover and what you do.',
                              done: profileProgress >= 0.66, onTap: onEditDetails),
                          _StartStep(2, 'Host your first event', 'Members check in with a QR code and earn points.',
                              onTap: hostEvent),
                          _StartStep(3, 'Invite your team', 'Add the people who run things with you.',
                              onTap: () => shell?.goTo(OrgTab.people)),
                          const SizedBox(height: CanopySpace.s12),
                          CanopyButton(label: 'Host your first event', expand: true, onPressed: hostEvent),
                        ]),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            CanopySpace.gutter, CanopyWorkspace.sectionGap, CanopySpace.gutter, 0),
                        child: Row(children: [
                          Expanded(
                              child: WorkspaceQuickAction(
                                  icon: Icons.qr_code_2, label: 'Host event', onTap: hostEvent)),
                          const SizedBox(width: CanopySpace.s8),
                          Expanded(
                              child: WorkspaceQuickAction(
                                  icon: Icons.volunteer_activism_outlined,
                                  label: 'Log work',
                                  onTap: () => push(const LogContributionScreen()))),
                          const SizedBox(width: CanopySpace.s8),
                          Expanded(
                              child: WorkspaceQuickAction(
                                  icon: Icons.article_outlined,
                                  label: 'Article',
                                  onTap: () => push(const CreateArticleScreen()))),
                          const SizedBox(width: CanopySpace.s8),
                          Expanded(
                              child: WorkspaceQuickAction(
                                  icon: Icons.campaign_outlined,
                                  label: 'Broadcast',
                                  onTap: () => push(BroadcastComposerScreen(
                                      orgId: orgId, orgName: org.name, orgLogoUrl: org.logoUrl)))),
                        ]),
                      ),
                      WorkspaceSection(
                        title: 'Happening now & next',
                        actionLabel: 'All events',
                        onAction: () => shell?.goTo(OrgTab.operations, sub: 'events'),
                        child: liveEvents.isEmpty && upcoming.isEmpty
                            ? CanopyEmptyState(
                                boxed: true,
                                icon: Icons.event_outlined,
                                title: 'Nothing scheduled',
                                actionLabel: 'Host an event',
                                onAction: hostEvent,
                              )
                            : CanopyListGroup(children: [
                                for (final e in liveEvents)
                                  DenseRow(
                                    leading: CanopyDateBlock(date: e.scheduledAt ?? e.createdAt ?? now),
                                    title: e.title,
                                    subtitle: e.meetingPoint ?? 'Check-in open',
                                    status: LabelRow(children: [
                                      StatusLabel('Live', color: p.danger, live: true),
                                      PointsLabel(e.pointsPerCheckin),
                                    ]),
                                    trailing: CanopyButton.secondary(
                                      label: 'Show QR',
                                      size: CanopyButtonSize.compact,
                                      onPressed: () => push(EventLiveScreen(eventId: e.id)),
                                    ),
                                  ),
                                for (final d in upcoming.take(3))
                                  DenseRow(
                                    leading: CanopyDateBlock(
                                        date: (d.data()['scheduledAt'] as Timestamp).toDate()),
                                    title: (d.data()['title'] as String?) ?? 'Activity',
                                    subtitle:
                                        '${DateFormat('HH:mm').format((d.data()['scheduledAt'] as Timestamp).toDate())} · ${d.data()['registeredCount'] ?? 0} going',
                                    onTap: () => push(ActivityDetailScreen(activityId: d.id, activity: d.data())),
                                  ),
                              ]),
                      ),
                      if (pendingList.isNotEmpty)
                        WorkspaceSection(
                          title: 'Contributions to confirm',
                          onAction: () async {
                            await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                                builder: (_) => ContributionReviewScreen(orgId: orgId)));
                            refreshPending();
                          },
                          child: CanopyListGroup(children: [
                            for (final c in pendingList.take(3))
                              DenseRow(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(CanopyRadius.xs),
                                  child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CanopyImage(url: c.photo, fallbackIcon: Icons.photo_outlined)),
                                ),
                                title: c.title,
                                subtitle: c.activityTitle,
                                trailing: CanopyButton.quiet(
                                  label: 'Review',
                                  size: CanopyButtonSize.compact,
                                  onPressed: () async {
                                    await Navigator.of(context, rootNavigator: true).push(
                                        MaterialPageRoute(
                                            builder: (_) => ContributionReviewScreen(orgId: orgId)));
                                    refreshPending();
                                  },
                                ),
                              ),
                          ]),
                        ),
                    ],
                    WorkspaceSection(
                      title: 'Overview · all time',
                      child: _Overview(orgId: orgId, events: acts.length + events.length, push: push),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StartStep extends StatelessWidget {
  final int n;
  final String title;
  final String line;
  final bool done;
  final VoidCallback onTap;
  const _StartStep(this.n, this.title, this.line, {this.done = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 32,
            child: done
                ? Icon(Icons.check, color: p.success)
                : Text('$n', style: CanopyWorkspace.metricValue.copyWith(fontSize: 20, color: p.ink)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
              Text(line, style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: p.inkFaint),
        ]),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final String orgId;
  final int events;
  final void Function(Widget) push;
  const _Overview({required this.orgId, required this.events, required this.push});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final shell = OrgShellScope.of(context);
    Future<int> count(Query<Map<String, dynamic>> q) =>
        q.count().get().then((a) => a.count ?? 0).catchError((_) => 0);
    return FutureBuilder<List<int>>(
      future: Future.wait([
        count(db.collection('programmes').where('orgId', isEqualTo: orgId)),
        count(db.collection('OrgMembers').where('orgId', isEqualTo: orgId)),
        count(db.collection('articles').where('orgId', isEqualTo: orgId)),
      ]),
      builder: (context, snap) {
        final v = snap.data;
        String n(int i) => v == null ? '—' : '${v[i]}';
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: CanopySpace.s12,
          crossAxisSpacing: CanopySpace.s16,
          childAspectRatio: 2.4,
          children: [
            MetricTile(value: '$events', label: 'Events', onTap: () => shell?.goTo(OrgTab.operations, sub: 'events')),
            MetricTile(value: n(0), label: 'Programmes', onTap: () => shell?.goTo(OrgTab.programmes)),
            MetricTile(value: n(1), label: 'Volunteers', onTap: () => shell?.goTo(OrgTab.people)),
            MetricTile(value: n(2), label: 'Articles', onTap: () => push(OrgArticlesScreen(orgId: orgId))),
          ],
        );
      },
    );
  }
}
