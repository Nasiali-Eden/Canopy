// lib/Community/Home/home_feed.dart
//
// The community Home tab (DESIGN_HANDOFF.md §3 "Home feed"): greeting, the
// impact hero (my points → Impact, rank → Leaderboard, next registered event),
// an equal four-way quick-action strip (Log work · Report · Services · Market),
// then Announcements (list group), Community updates (content cards) and
// Recent activity (feed cards). "Join Event" is gone from quick actions — the
// hero's empty "Next up" links to Activities instead.
//
// Built on lib/theme/canopy_components.dart (v2). Routing shell:
// community_home.dart.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../HomeServices/services_home_screen.dart';
import '../../MarketPlace/The Market/eco_shop.dart';
import '../../Organization/Access/org_invite_banner.dart';
import '../../Services/Rank/leaderboard_service.dart';
import '../../Shared/Activities/activity_detail_screen.dart';
import '../../theme/canopy_components.dart';
import '../Articles/article_card.dart';
import '../Contributions/entry_feed_card.dart';

// ── Firestore collection paths ─────────────────────────────────────────────────
const _kArticles = 'articles';
const _kAnnouncements = 'announcements';
const _kUsers = 'Users';
const _kContributions = 'contributions';
const _kActivities = 'activities';
const _kRegistrations = 'activity_registrations';

// ── Time helper — exported (via community_home.dart) for sibling screens ──────
String timeAgo(Timestamp timestamp) {
  final diff = DateTime.now().difference(timestamp.toDate());
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return DateFormat('d MMM yyyy').format(timestamp.toDate());
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME FEED
// ─────────────────────────────────────────────────────────────────────────────

class HomeFeed extends StatefulWidget {
  final String? userId;
  final VoidCallback onBrowseActivities;
  final VoidCallback onLogWork;
  final VoidCallback onViewAnnouncements;
  final VoidCallback onViewAllArticles;
  final VoidCallback onViewAllContributions;

  const HomeFeed({
    super.key,
    this.userId,
    required this.onBrowseActivities,
    required this.onLogWork,
    required this.onViewAnnouncements,
    required this.onViewAllArticles,
    required this.onViewAllContributions,
  });

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  final _db = FirebaseFirestore.instance;

  // Held in state so a rebuild doesn't resubscribe, and each section's
  // "Try again" can swap in a fresh stream.
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _user;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _announcements;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _articles;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _contributions;
  int _refreshTick = 0; // bumping it rebuilds the points card with fresh data

  @override
  void initState() {
    super.initState();
    _subscribeUser();
    _subscribeAnnouncements();
    _subscribeArticles();
    _subscribeContributions();
  }

  @override
  void didUpdateWidget(covariant HomeFeed old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _subscribeUser();
  }

  // Firestore: Users/{userId} — same doc Leaderboard, Badges and Profile read.
  void _subscribeUser() {
    final uid = widget.userId;
    _user = uid == null ? null : _db.collection(_kUsers).doc(uid).snapshots();
  }

  // Firestore: announcements — newest first; expiry filtered client-side.
  void _subscribeAnnouncements() => _announcements = _db
      .collection(_kAnnouncements)
      .orderBy('createdAt', descending: true)
      .limit(6)
      .snapshots();

  // Firestore: articles — ordering by publishedAt alone is index-free and
  // returns only live articles (drafts have a null publishedAt).
  void _subscribeArticles() => _articles = _db
      .collection(_kArticles)
      .orderBy('publishedAt', descending: true)
      .limit(3)
      .snapshots();

  // Firestore: contributions — newest first; the full feed is one tap away.
  void _subscribeContributions() => _contributions = _db
      .collection(_kContributions)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots();

  /// Pull to refresh: re-read the member's points from the server (so newly
  /// verified work is counted), then rebuild the rank, next event and feeds.
  Future<void> _refresh() async {
    final uid = widget.userId;
    try {
      if (uid != null) {
        await _db.collection(_kUsers).doc(uid).get(const GetOptions(source: Source.server));
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _refreshTick++;
      _subscribeUser();
      _subscribeAnnouncements();
      _subscribeArticles();
      _subscribeContributions();
    });
    // Let the new streams deliver before the spinner goes away.
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  static const _sectionGap =
      SizedBox(height: CanopySpace.section + CanopySpace.s8);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.canopy.canvas,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.only(top: CanopySpace.s12, bottom: CanopySpace.s32),
          children: [
            _Greeting(user: _user),
            const SizedBox(height: CanopySpace.s16),
            const OrgInviteBanner(),
            _gutter(
              widget.userId == null
                  ? const _SignedOutHero()
                  : _ImpactHero(
                      key: ValueKey('impact_$_refreshTick'),
                      userId: widget.userId!,
                      user: _user!,
                      onBrowseActivities: widget.onBrowseActivities,
                    ),
            ),
            const SizedBox(height: CanopySpace.s16),
            _gutter(_QuickActions(onLogWork: widget.onLogWork)),
            _sectionGap,
            CanopySectionHeader(
                title: 'Announcements', onAction: widget.onViewAnnouncements),
            _gutter(_announcementsSection()),
            _sectionGap,
            CanopySectionHeader(
                title: 'Community updates', onAction: widget.onViewAllArticles),
            _gutter(_articlesSection()),
            _sectionGap,
            CanopySectionHeader(
                title: 'Recent activity', onAction: widget.onViewAllContributions),
            _gutter(_contributionsSection()),
          ],
        ),
        ),
      ),
    );
  }

  Widget _gutter(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
        child: child,
      );

  Widget _announcementsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _announcements,
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyErrorState(
            inline: true,
            title: "Couldn't load announcements.",
            onRetry: () => setState(_subscribeAnnouncements),
          );
        }
        if (!snap.hasData) return const CanopyListSkeleton(rows: 2);

        final now = DateTime.now();
        final docs = snap.data!.docs.where((d) {
          final exp = d.data()['expiresAt'] as Timestamp?;
          return exp == null || exp.toDate().isAfter(now);
        }).toList()
          // Urgent announcements pin to the top (org broadcast "Urgent" switch).
          ..sort((a, b) {
            final ua = a.data()['isUrgent'] == true ? 0 : 1;
            final ub = b.data()['isUrgent'] == true ? 0 : 1;
            return ua.compareTo(ub);
          });

        if (docs.isEmpty) {
          return const CanopyEmptyState(
            boxed: true,
            icon: Icons.campaign_outlined,
            title: 'No announcements yet',
            line: 'Organisations near you will post updates here.',
          );
        }
        return CanopyListGroup(
          children: [
            for (final d in docs.take(3))
              _AnnouncementRow(id: d.id, data: d.data()),
          ],
        );
      },
    );
  }

  Widget _articlesSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _articles,
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyErrorState(
            inline: true,
            title: "Couldn't load community updates.",
            onRetry: () => setState(_subscribeArticles),
          );
        }
        if (!snap.hasData) return const CanopyCardSkeleton();

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const CanopyEmptyState(
            boxed: true,
            icon: Icons.article_outlined,
            title: 'No community updates yet',
            line: 'News from organisations in your area will show up here.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0) const SizedBox(height: CanopySpace.s12),
              ArticleCard(id: docs[i].id, data: docs[i].data()),
            ],
          ],
        );
      },
    );
  }

  Widget _contributionsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _contributions,
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyErrorState(
            inline: true,
            title: "Couldn't load recent activity.",
            onRetry: () => setState(_subscribeContributions),
          );
        }
        if (!snap.hasData) return const CanopyCardSkeleton(aspectRatio: 1);

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return CanopyEmptyState(
            boxed: true,
            icon: Icons.volunteer_activism_outlined,
            title: 'No contributions yet',
            line: 'Log a clean-up, planting or recycling run to start the feed.',
            actionLabel: 'Log a contribution',
            onAction: () => Navigator.pushNamed(context, '/contributions/log'),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0) const SizedBox(height: CanopySpace.s24),
              EntryFeedCard(entry: FeedEntry.fromContribution(docs[i].data())),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GREETING
// ─────────────────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? user;
  const _Greeting({required this.user});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final date = DateFormat('EEEE d MMMM').format(DateTime.now()).toUpperCase();

    Widget title(String? name) => Text(
          name == null ? 'Welcome' : 'Hello, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CanopyType.display.copyWith(color: p.ink),
        );

    return Padding(
      padding:
          const EdgeInsets.only(left: CanopySpace.gutter, right: CanopySpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s4),
                if (user == null)
                  title(null)
                else
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: user,
                    builder: (context, snap) {
                      final full =
                          (snap.data?.data()?['name'] as String?)?.trim();
                      final first = (full == null || full.isEmpty)
                          ? null
                          : full.split(RegExp(r'\s+')).first;
                      return title(first);
                    },
                  ),
              ],
            ),
          ),
          CanopyIconButton(
            icon: Icons.notifications_none_outlined,
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPACT HERO — points (→ Impact) · rank (→ Leaderboard) · next registered event
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactHero extends StatefulWidget {
  final String userId;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> user;
  final VoidCallback onBrowseActivities;

  const _ImpactHero({
    super.key,
    required this.userId,
    required this.user,
    required this.onBrowseActivities,
  });

  @override
  State<_ImpactHero> createState() => _ImpactHeroState();
}

class _ImpactHeroState extends State<_ImpactHero> {
  // Rank is derived from a count aggregate, not a user field — resolve once.
  late Future<PersonalRank> _rank;
  late Future<_NextEvent?> _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ImpactHero old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _load();
  }

  void _load() {
    _rank = LeaderboardService().getPersonalRank(widget.userId);
    _next = _NextEvent.load(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return CanopyHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _points(context)),
              _rankStat(context),
            ],
          ),
          const SizedBox(height: CanopySpace.s16),
          Container(height: 1, color: CanopyPalette.onHero.withAlpha(0x29)),
          FutureBuilder<_NextEvent?>(
            future: _next,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const CanopyHeroRow(eyebrow: 'Next up', title: '…');
              }
              final e = snap.data;
              if (snap.hasError || e == null) {
                return CanopyHeroRow(
                  eyebrow: 'Next up',
                  title: snap.hasError
                      ? "Couldn't load your events"
                      : 'No upcoming events',
                  detail: 'Browse activities',
                  onTap: widget.onBrowseActivities,
                );
              }
              return CanopyHeroRow(
                eyebrow: 'Next up',
                title: e.title,
                detail: [e.when, if (e.place.isNotEmpty) e.place].join(' · '),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ActivityDetailScreen(activityId: e.id, activity: e.data),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _points(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.user,
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        // Same rankingVersion gate ImpactService and LeaderboardService apply.
        final points = data['rankingVersion'] == 1
            ? (data['impact_points'] as num?)?.toInt() ?? 0
            : 0;
        final value =
            snap.hasData ? NumberFormat.decimalPattern().format(points) : '—';
        return CanopyHeroTap(
          label: 'Your points: $value. Opens your impact.',
          onTap: () => Navigator.pushNamed(context, '/impact'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR IMPACT',
                  style: CanopyType.eyebrow
                      .copyWith(color: CanopyPalette.onHeroMuted)),
              const SizedBox(height: CanopySpace.s4),
              Text(value,
                  style:
                      CanopyType.hero.copyWith(color: CanopyPalette.onHeroPoints)),
              Text('points',
                  style: CanopyType.caption
                      .copyWith(color: CanopyPalette.onHeroMuted)),
            ],
          ),
        );
      },
    );
  }

  Widget _rankStat(BuildContext context) {
    return FutureBuilder<PersonalRank>(
      future: _rank,
      builder: (context, snap) {
        final rank = snap.data?.rank;
        final toNext = snap.data?.pointsToNext;
        // '—' until the member has points: unranked genuinely has no rank.
        final value = rank == null ? '—' : '#$rank';
        return CanopyHeroTap(
          label: 'Rank $value. Opens the leaderboard.',
          onTap: () => Navigator.pushNamed(context, '/leaderboard'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: CanopyType.display.copyWith(
                      color: CanopyPalette.onHero,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              Text(
                rank != null && rank > 1 && toNext != null
                    ? '$toNext pts to #${rank - 1}'
                    : 'rank',
                style:
                    CanopyType.caption.copyWith(color: CanopyPalette.onHeroMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The member's soonest upcoming activity they're registered for.
class _NextEvent {
  final String id;
  final Map<String, dynamic> data;
  final DateTime at;

  _NextEvent(this.id, this.data, this.at);

  String get title => (data['title'] as String?)?.trim() ?? 'Activity';
  String get when => DateFormat('EEE d MMM · HH:mm').format(at);
  String get place {
    final name = data['locationName'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    final loc = data['location'];
    if (loc is String) return loc.trim();
    if (loc is Map) {
      final n = loc['name'] ?? loc['address'];
      if (n is String) return n.trim();
    }
    return '';
  }

  /// Index-free: one equality filter on activity_registrations, then the
  /// activities fetched by id in batches of 10 (the whereIn limit).
  static Future<_NextEvent?> load(String userId) async {
    final db = FirebaseFirestore.instance;
    final regs = await db
        .collection(_kRegistrations)
        .where('userId', isEqualTo: userId)
        .get();
    final ids = regs.docs
        .where((d) => (d.data()['status'] ?? 'registered') == 'registered')
        .map((d) => d.data()['activityId'])
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return null;

    final now = DateTime.now();
    _NextEvent? best;
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await db
          .collection(_kActivities)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final at = (doc.data()['scheduledAt'] as Timestamp?)?.toDate();
        if (at == null || at.isBefore(now)) continue;
        if (doc.data()['status'] == 'cancelled') continue;
        if (best == null || at.isBefore(best.at)) {
          best = _NextEvent(doc.id, doc.data(), at);
        }
      }
    }
    return best;
  }
}

class _SignedOutHero extends StatelessWidget {
  const _SignedOutHero();

  @override
  Widget build(BuildContext context) {
    return CanopyHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR IMPACT',
              style:
                  CanopyType.eyebrow.copyWith(color: CanopyPalette.onHeroMuted)),
          const SizedBox(height: CanopySpace.s8),
          Text('Sign in to earn points and keep track of the events you join.',
              style: CanopyType.subhead.copyWith(color: CanopyPalette.onHero)),
          CanopyHeroRow(
            eyebrow: 'Account',
            title: 'Sign in',
            onTap: () => Navigator.pushNamed(context, '/welcome'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS — equal, bare icons, divided strip
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onLogWork;
  const _QuickActions({required this.onLogWork});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final actions = <(String, IconData, VoidCallback)>[
      ('Log work', Icons.qr_code_scanner_outlined, onLogWork),
      (
        'Report',
        Icons.flag_outlined,
        () => Navigator.pushNamed(context, '/report-incident')
      ),
      (
        'Services',
        Icons.handyman_outlined,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ServicesHomeScreen()))
      ),
      (
        'Market',
        Icons.storefront_outlined,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const EcoShopScreen()))
      ),
    ];

    return CanopyCard(
      padding: null,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: p.outline),
              Expanded(
                child: InkWell(
                  onTap: actions[i].$3,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: CanopySpace.s16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(actions[i].$2,
                            size: CanopyIconSize.nav, color: p.ink),
                        const SizedBox(height: CanopySpace.s8),
                        Text(actions[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CanopyType.label.copyWith(color: p.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANNOUNCEMENT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementRow extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _AnnouncementRow({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final title = (data['title'] as String?)?.trim() ?? '';
    final orgName = (data['orgName'] as String?)?.trim() ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final isUrgent = data['isUrgent'] as bool? ?? false;
    final meta = [
      if (orgName.isNotEmpty) orgName,
      if (createdAt != null) timeAgo(createdAt),
    ].join(' · ');

    return CanopyListRow(
      leading: CanopyAvatar(
          url: data['orgLogoUrl'] as String?, name: orgName, size: 40, org: true),
      title: title,
      subtitle: meta,
      below: isUrgent ? StatusLabel('Urgent', color: p.danger) : null,
      onTap: () => Navigator.pushNamed(context, '/announcements/$id'),
    );
  }
}
