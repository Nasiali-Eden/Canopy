// lib/Shared/Activities/activity_detail_screen.dart
//
// Activity detail (DESIGN_HANDOFF.md §3) — the ONE detail screen. Merges the
// old activity_detail.dart (image gallery, participant progress, legacy join)
// and activity_detail_screen.dart (registration flow) into a single screen on
// the registrations model:
//
//   gallery (16:9, swipe, designed fallback) → labels (status · type · points)
//   → title → organiser row (opens the org page) → facts group (when ·
//   duration · where · capacity) → about → tags → sticky action:
//     signed out  → Sign in to register
//     registered  → "You're going" + Scan QR to check in (+ quiet cancel)
//     ended/cancelled/full → status line, no primary
//     otherwise   → Register
//
// [activity] is optional: the screen streams activities/{id} and uses the
// passed map only until the first snapshot (e.g. straight after creating).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Community/Events/log_work_event_screen.dart' show QrScanScreen;
import '../../Models/user.dart';
import '../../Organization/Explorer/org_view_screen.dart';
import '../../Services/Community/community_service.dart';
import '../../theme/canopy_components.dart';
import 'activity_card.dart';
import 'activity_registration_sheet.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic>? activity;

  const ActivityDetailScreen({super.key, required this.activityId, this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() => _stream = FirebaseFirestore.instance
      .collection('activities')
      .doc(widget.activityId)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data?.data() ?? widget.activity;
        if (data == null) {
          if (snap.hasError) {
            return CanopyScaffold(
              appBar: canopyAppBar(context),
              body: CanopyErrorState(
                  title: "Couldn't load this activity",
                  onRetry: () => setState(_subscribe)),
            );
          }
          if (snap.hasData && !snap.data!.exists) {
            return CanopyScaffold(
              appBar: canopyAppBar(context),
              body: const CanopyEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'This activity was removed',
                line: 'Its organiser took it down.',
              ),
            );
          }
          return CanopyScaffold(
            appBar: canopyAppBar(context),
            body: ListView(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              children: const [
                CanopyCardSkeleton(),
                SizedBox(height: CanopySpace.s16),
                CanopyListSkeleton(rows: 3),
              ],
            ),
          );
        }
        return _Detail(activityId: widget.activityId, a: data);
      },
    );
  }
}

class _Detail extends StatelessWidget {
  final String activityId;
  final Map<String, dynamic> a;
  const _Detail({required this.activityId, required this.a});

  List<String> get _images {
    final raw = (a['images'] as List?)?.whereType<String>().where((s) => s.isNotEmpty).toList() ??
        <String>[];
    final cover = a['coverImageUrl'] as String?;
    if (raw.isEmpty && cover != null && cover.isNotEmpty) return [cover];
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final type = a['type'] as String? ?? 'other';
    final title = (a['title'] as String?)?.trim() ?? '';
    final description = (a['description'] as String?)?.trim() ?? '';
    final at = a['scheduledAt'] as Timestamp?;
    final minutes = a['durationMinutes'] as int? ?? 0;
    final place = activityLocationName(a);
    final org = (a['organizerName'] as String?)?.trim() ?? '';
    final orgId = a['orgId'] as String?;
    final points = (a['pointsPerCheckin'] as num?)?.toInt();
    final tags = (a['tags'] as List?)?.whereType<String>().toList() ?? const [];
    final (statusText, statusColor, live) = activityStatus(p, a);

    return CanopyScaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.sizeOf(context).width * 9 / 16,
            backgroundColor: p.canvas,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: CanopySpace.s4),
              child: CanopyIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onImage: true,
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _Gallery(images: _images),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter,
                CanopySpace.s20, CanopySpace.gutter, CanopySpace.s32),
            sliver: SliverList.list(
              children: [
                LabelRow(children: [
                  StatusLabel(statusText, color: statusColor, live: live),
                  StatusLabel(activityTypeLabel(type), color: p.inkMuted),
                  if (points != null && points > 0) PointsLabel(points),
                ]),
                const SizedBox(height: CanopySpace.s8),
                Semantics(
                  header: true,
                  child: Text(title,
                      style: CanopyType.display.copyWith(color: p.ink)),
                ),
                const SizedBox(height: CanopySpace.s16),
                if (org.isNotEmpty) ...[
                  CanopyOrgChip(
                    name: org,
                    logoUrl: a['orgLogoUrl'] as String?,
                    onTap: orgId == null ? null : () => _openOrg(context, orgId),
                  ),
                  const SizedBox(height: CanopySpace.s16),
                ],
                CanopyListGroup(children: [
                  if (at != null)
                    CanopyListRow(
                      icon: Icons.calendar_today_outlined,
                      title: formatActivityFullDate(at),
                      subtitle: minutes > 0
                          ? '${minutes >= 60 ? '${minutes ~/ 60} h ' : ''}${minutes % 60 > 0 ? '${minutes % 60} min' : ''}'.trim()
                          : 'When',
                    ),
                  if (place.isNotEmpty)
                    CanopyListRow(
                      icon: Icons.location_on_outlined,
                      title: place,
                      subtitle: 'Meeting point',
                    ),
                  CanopyListRow(
                    icon: Icons.group_outlined,
                    title: activityGoingLabel(a),
                    below: ActivityCapacityBar(
                      registeredCount: a['registeredCount'] as int? ?? 0,
                      maxParticipants: a['maxParticipants'] as int? ?? 0,
                    ),
                  ),
                ]),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: CanopySpace.section),
                  const CanopySectionHeader(
                      title: 'About', padding: EdgeInsets.zero),
                  Text(description,
                      style: CanopyType.body.copyWith(color: p.ink, height: 22 / 14)),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: CanopySpace.s16),
                  Text(tags.join(' · '),
                      style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
      sticky: _ActionBar(activityId: activityId, a: a),
    );
  }

  Future<void> _openOrg(BuildContext context, String orgId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      if (!context.mounted || !doc.exists) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => OrgViewScreen(orgId: orgId, orgData: doc.data()!)),
      );
    } catch (_) {
      if (context.mounted) {
        showCanopySnack(context, "Couldn't open the organisation.", error: true);
      }
    }
  }
}

class _Gallery extends StatefulWidget {
  final List<String> images;
  const _Gallery({required this.images});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (widget.images.length <= 1) {
      return Stack(fit: StackFit.expand, children: [
        CanopyImage(
            url: widget.images.isEmpty ? null : widget.images.first,
            fallbackIcon: Icons.eco_outlined),
        _topScrim(p),
      ]);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => CanopyImage(url: widget.images[i]),
        ),
        _topScrim(p),
        Positioned(
          right: CanopySpace.s12,
          bottom: CanopySpace.s12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s8, vertical: 2),
            decoration: BoxDecoration(
              color: p.scrim,
              borderRadius: BorderRadius.circular(CanopyRadius.pill),
            ),
            child: Text('${_index + 1} / ${widget.images.length}',
                style: CanopyType.micro.copyWith(color: CanopyPalette.onHero)),
          ),
        ),
      ],
    );
  }

  Widget _topScrim(CanopyPalette p) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [p.scrim, p.scrim.withAlpha(0)],
            ),
          ),
        ),
      );
}

class _ActionBar extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> a;
  const _ActionBar({required this.activityId, required this.a});

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  bool _busy = false;

  Future<void> _register(String userId) async {
    setState(() => _busy = true);
    final profile = await CommunityService().getUserProfile(userId: userId);
    if (!mounted) return;
    setState(() => _busy = false);
    await showCanopySheet(
      context,
      builder: (_) => ActivityRegistrationSheet(
        activityId: widget.activityId,
        activity: widget.a,
        userId: userId,
        userEmail: profile?['email'] as String? ?? '',
        userName: (profile?['displayName'] ?? profile?['name']) as String? ?? '',
        userAvatarUrl: profile?['avatarUrl'] as String?,
      ),
    );
  }

  Future<void> _cancel(String registrationId) async {
    final ok = await showCanopyConfirm(
      context,
      title: 'Cancel your registration?',
      message:
          "You'll be removed from ${widget.a['title'] ?? 'this activity'} and your spot opens up for someone else.",
      confirmLabel: 'Cancel registration',
      cancelLabel: 'Keep my spot',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      await db.runTransaction((txn) async {
        txn.update(db.collection('activity_registrations').doc(registrationId),
            {'status': 'cancelled'});
        txn.update(db.collection('activities').doc(widget.activityId), {
          'registeredCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (mounted) showCanopySnack(context, 'Registration cancelled.');
    } catch (_) {
      if (mounted) {
        showCanopySnack(context, "Couldn't cancel. Try again.", error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final user = Provider.of<F_User?>(context);
    if (user == null) {
      return StickyActionBar(children: [
        CanopyButton(
          label: 'Sign in to register',
          expand: true,
          onPressed: () => Navigator.pushNamed(context, '/welcome'),
        ),
      ]);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: CommunityService().getUserRegistrationStream(
          activityId: widget.activityId, userId: user.uid),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final registered = docs.isNotEmpty &&
            (docs.first.data() as Map)['status'] == 'registered';
        final ended = CommunityService.hasEnded(widget.a) ||
            widget.a['status'] == 'completed';
        final cancelled = widget.a['status'] == 'cancelled';
        final full = widget.a['status'] == 'full';

        if (!snap.hasData) {
          return const StickyActionBar(children: [
            CanopySkeleton(height: CanopySpace.minTouch),
          ]);
        }
        if (registered && !ended && !cancelled) {
          return StickyActionBar(children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: CanopyIconSize.s18, color: p.success),
                const SizedBox(width: CanopySpace.s8),
                Expanded(
                  child: Text("You're going",
                      style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                ),
                CanopyButton.quietDanger(
                  label: 'Cancel',
                  size: CanopyButtonSize.compact,
                  loading: _busy,
                  onPressed: () => _cancel(docs.first.id),
                ),
              ],
            ),
            CanopyButton(
              label: 'Scan QR to check in',
              expand: true,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QrScanScreen())),
            ),
          ]);
        }
        final line = cancelled
            ? 'This activity was cancelled by its organiser.'
            : ended
                ? 'This activity has ended.'
                : full
                    ? "This activity is full. Check back — spots open when people cancel."
                    : null;
        if (line != null) {
          return StickyActionBar(children: [
            Text(line,
                textAlign: TextAlign.center,
                style: CanopyType.body.copyWith(color: p.inkMuted)),
          ]);
        }
        return StickyActionBar(children: [
          CanopyButton(
            label: 'Register',
            expand: true,
            loading: _busy,
            onPressed: () => _register(user.uid),
          ),
        ]);
      },
    );
  }
}
