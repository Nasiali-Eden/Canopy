// lib/Community/Profile/profile_screen.dart
//
// Profile hub (DESIGN_HANDOFF.md §3). Gradient identity header (avatar, name,
// place, points · contributions · rank) → RoleSwitcher card (only for people
// with more than one context) → Recognition (rank row, badges, check-ins this
// month) → Account (edit profile, settings, password & security) → Stay
// updated → Help (contact support, community guidelines, about, privacy) →
// Sign out (confirm). "Help Center" is gone per the design decisions.
//
// Points/rank/badges read the same server-authoritative Users.impact_points
// field (with the rankingVersion gate) the Leaderboard and Impact screens use.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Culture/culture_home.dart';
import '../../EnvironmentalOps/env_ops_shell.dart';
import '../../MarketPlace/market_home.dart';
import '../../Models/badge.dart' as recognition;
import '../../Models/contribution.dart';
import '../../Models/user.dart';
import '../../Organization/Home/org_home.dart';
import '../../Services/Authentication/auth.dart';
import '../../Services/Events/events_service.dart';
import '../../Services/Impact/impact_service.dart';
import '../../Services/Profile/profile_service.dart';
import '../../Services/Rank/leaderboard_service.dart';
import '../../Services/Recognition/recognition_service.dart';
import '../../Shared/Pages/login.dart';
import '../../Shared/widgets/role_context_switcher.dart';
import '../../theme/canopy_components.dart';
import '../Events/log_work_event_screen.dart';
import 'support_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  String? _uid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDoc;
  Stream<ProfileData>? _profile;
  Future<PersonalRank>? _rank;
  Future<Map<String, dynamic>?>? _org;
  String? _orgFor;

  void _bind(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _userDoc = FirebaseFirestore.instance.collection('Users').doc(uid).snapshots();
    _profile = ProfileService().watchProfile(userId: uid);
    _rank = LeaderboardService().getPersonalRank(uid);
  }

  Future<Map<String, dynamic>?> _orgData(String orgId) {
    if (_orgFor != orgId) {
      _orgFor = orgId;
      _org = FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get()
          .then((d) => d.data())
          .catchError((_) => null);
    }
    return _org!;
  }

  Future<void> _signOut() async {
    // Capture the root navigator before the async gap: signing out tears
    // this subtree down via the global auth listener.
    final navigator = Navigator.of(context, rootNavigator: true);
    final ok = await showCanopyConfirm(
      context,
      title: 'Sign out?',
      message: "You'll need your email and password to sign back in.",
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    await _auth.signOut();
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);
    // Null briefly during sign-out, before the replacement route lands.
    if (user == null) {
      return CanopyScaffold(body: const Center(child: CircularProgressIndicator()));
    }
    _bind(user.uid);

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Profile', showBack: false, actions: [
        CanopyIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ]),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userDoc,
        builder: (context, userSnap) {
          final data = userSnap.data?.data() ?? const <String, dynamic>{};
          final isOrgRep = data['role'] == 'Org Rep';
          final orgId = data['orgId'] as String?;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
            children: [
              StreamBuilder<ProfileData>(
                stream: _profile,
                builder: (context, snap) => _Header(
                  profile: snap.data,
                  userData: data,
                  rank: _rank!,
                  loading: !snap.hasData && !userSnap.hasData,
                ),
              ),
              if (isOrgRep && orgId != null)
                FutureBuilder<Map<String, dynamic>?>(
                  future: _orgData(orgId),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: CanopySpace.s16),
                      child: _switcher(context, snap.data!, orgId),
                    );
                  },
                ),
              const SizedBox(height: CanopySpace.section),
              _Recognition(userId: user.uid, rank: _rank!),
              const SizedBox(height: CanopySpace.section),
              CanopyListGroup(header: 'Account', children: [
                CanopyListRow(
                  icon: Icons.person_outline,
                  title: 'Edit profile',
                  onTap: () => Navigator.pushNamed(context, '/profile/edit'),
                ),
                CanopyListRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                CanopyListRow(
                  icon: Icons.lock_outline,
                  title: 'Password & security',
                  onTap: () => Navigator.pushNamed(context, '/security'),
                ),
              ]),
              const SizedBox(height: CanopySpace.section),
              CanopyListGroup(header: 'Stay updated', children: [
                CanopyListRow(
                  icon: Icons.campaign_outlined,
                  title: 'Announcements',
                  onTap: () => Navigator.pushNamed(context, '/announcements'),
                ),
                CanopyListRow(
                  icon: Icons.notifications_none_outlined,
                  title: 'Notifications',
                  onTap: () => Navigator.pushNamed(context, '/notifications'),
                ),
              ]),
              const SizedBox(height: CanopySpace.section),
              CanopyListGroup(header: 'Help', children: [
                CanopyListRow(
                  icon: Icons.support_agent_outlined,
                  title: 'Contact support',
                  subtitle: 'Send a message to the Canopy team',
                  onTap: () => showSupportSheet(context),
                ),
                CanopyListRow(
                  icon: Icons.menu_book_outlined,
                  title: 'Community guidelines',
                  onTap: () => Navigator.pushNamed(context, '/guidelines'),
                ),
                CanopyListRow(
                  icon: Icons.info_outline,
                  title: 'About Canopy',
                  onTap: () => Navigator.pushNamed(context, '/about'),
                ),
                CanopyListRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                ),
              ]),
              const SizedBox(height: CanopySpace.s16),
              CanopyButton.quietDanger(label: 'Sign out', expand: true, onPressed: _signOut),
            ],
          );
        },
      ),
    );
  }

  Widget _switcher(BuildContext context, Map<String, dynamic> org, String orgId) {
    final hasMarketplace = org['marketplaceStatus'] == 'approved';
    final hasEnvOps = org['envOpsStatus'] == 'approved';
    final hasCultural = org['culturalStatus'] == 'approved';
    void go(Widget screen) => Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => screen), (_) => false);
    return RoleContextSwitcher(
      activeContext: 'member',
      hasMarketplace: hasMarketplace,
      hasEnvOps: hasEnvOps,
      hasCultural: hasCultural,
      onMemberTap: () {},
      onOrgTap: () => go(const OrganizationHome()),
      onMarketplaceTap: () => go(const SellerHomeScreen()),
      onEnvOpsTap: () => go(EnvOpsShell(
        hasMarketplace: hasMarketplace,
        hasCultural: hasCultural,
        orgContextBuilder: (_) => const OrganizationHome(),
        memberContextBuilder: (_) => const ProfileScreen(),
        marketplaceContextBuilder: hasMarketplace ? (_) => const SellerHomeScreen() : null,
        culturalContextBuilder: hasCultural
            ? (_) => CultureHomeScreen(
                orgId: orgId, memberContextBuilder: (_) => const ProfileScreen())
            : null,
      )),
      onCulturalTap: () => go(CultureHomeScreen(
          orgId: orgId, memberContextBuilder: (_) => const ProfileScreen())),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ProfileData? profile;
  final Map<String, dynamic> userData;
  final Future<PersonalRank> rank;
  final bool loading;
  const _Header(
      {required this.profile, required this.userData, required this.rank, required this.loading});

  @override
  Widget build(BuildContext context) {
    final name = (profile?.name ?? '').trim();
    final place = (profile?.location ?? '').trim();
    final points = userData['rankingVersion'] == 1
        ? (userData['impact_points'] as num?)?.toInt() ?? 0
        : 0;
    final contributions = (userData['verifiedContributions'] as num?)?.toInt() ?? 0;
    final role = userData['role'] == 'Org Rep' ? 'Organisation rep' : 'Member';

    Widget stat(String value, String label, VoidCallback onTap, {bool gold = false}) =>
        Expanded(
          child: CanopyHeroTap(
            label: '$label $value',
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: CanopyType.title.copyWith(
                        color: gold ? CanopyPalette.onHeroPoints : CanopyPalette.onHero,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                Text(label,
                    style: CanopyType.caption.copyWith(color: CanopyPalette.onHeroMuted)),
              ],
            ),
          ),
        );

    return CanopyHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CanopyAvatar(
                url: profile?.photoUrl,
                name: name,
                size: 72,
                ring: CanopyPalette.onHero.withAlpha(0x66),
              ),
              const SizedBox(width: CanopySpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loading ? ' ' : (name.isEmpty ? 'Community member' : name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CanopyType.title.copyWith(color: CanopyPalette.onHero)),
                    const SizedBox(height: CanopySpace.s2),
                    Text([role, if (place.isNotEmpty) place].join(' · '),
                        style: CanopyType.caption
                            .copyWith(color: CanopyPalette.onHeroMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CanopySpace.s16),
          Container(height: 1, color: CanopyPalette.onHero.withAlpha(0x29)),
          const SizedBox(height: CanopySpace.s12),
          FutureBuilder<PersonalRank>(
            future: rank,
            builder: (context, snap) => Row(
              children: [
                stat('$points', 'points', () => Navigator.pushNamed(context, '/impact'),
                    gold: true),
                stat('$contributions', 'verified',
                    () => Navigator.pushNamed(context, '/impact')),
                stat(snap.data?.rank == null ? '—' : '#${snap.data!.rank}', 'rank',
                    () => Navigator.pushNamed(context, '/leaderboard')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECOGNITION
// ─────────────────────────────────────────────────────────────────────────────

class _Recognition extends StatelessWidget {
  final String userId;
  final Future<PersonalRank> rank;
  const _Recognition({required this.userId, required this.rank});

  static const _badgeIcons = {
    'welcome': Icons.celebration_outlined,
    'first_contribution': Icons.eco_outlined,
    'contributor_5': Icons.military_tech_outlined,
    'impact_100': Icons.bolt_outlined,
    'impact_500': Icons.bolt_outlined,
    'impact_1000': Icons.workspace_premium_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final impact = ImpactService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CanopySectionHeader(title: 'Recognition', padding: EdgeInsets.zero),
        StreamBuilder<int>(
          stream: impact.watchUserImpactPoints(userId: userId),
          builder: (context, pointsSnap) => StreamBuilder<List<Contribution>>(
            stream: impact.watchUserContributions(userId: userId),
            builder: (context, snap) {
              final points = pointsSnap.data ?? 0;
              final contribs = snap.data ?? const <Contribution>[];
              final verified = contribs.where((c) => c.isVerified).length;
              final badges = RecognitionService()
                  .computeBadges(impactPoints: points, contributionsCount: verified);
              final earned = badges.where((b) => b.earned).length;
              final shown = <recognition.Badge>[
                ...badges.where((b) => b.earned).take(3),
                ...badges.where((b) => !b.earned).take(4),
              ].take(4).toList();
              // Same four milestones AcknowledgementsScreen shows.
              final milestones = [
                true,
                contribs.isNotEmpty,
                contribs.length >= 5,
                contribs.length >= 10
              ].where((m) => m).length;

              return CanopyListGroup(children: [
                FutureBuilder<PersonalRank>(
                  future: rank,
                  builder: (context, r) {
                    final pr = r.data;
                    return CanopyListRow(
                      icon: Icons.leaderboard_outlined,
                      title: pr?.rank == null ? 'Not ranked yet' : 'Rank #${pr!.rank}',
                      subtitle: pr?.rank == null
                          ? 'Your first verified contribution earns a place'
                          : pr!.pointsToNext == null
                              ? 'You share the top score'
                              : '${pr.pointsToNext} pts to move up',
                      onTap: () => Navigator.pushNamed(context, '/leaderboard'),
                    );
                  },
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/recognition/badges'),
                  child: Padding(
                    padding: const EdgeInsets.all(CanopySpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Badges',
                                  style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                            ),
                            Text('$earned of ${badges.length}',
                                style: CanopyType.caption.copyWith(color: p.inkMuted)),
                            Icon(Icons.chevron_right,
                                size: CanopyIconSize.s18, color: p.inkFaint),
                          ],
                        ),
                        const SizedBox(height: CanopySpace.s12),
                        Row(
                          children: [
                            for (final b in shown)
                              Expanded(
                                child: Column(
                                  children: [
                                    CanopyBadge(
                                      icon: _badgeIcons[b.id] ?? Icons.emoji_events_outlined,
                                      earned: b.earned,
                                      progress: b.earned
                                          ? null
                                          : b.requiredPoints != null
                                              ? points / b.requiredPoints!
                                              : b.requiredContributions != null
                                                  ? verified / b.requiredContributions!
                                                  : null,
                                      size: 52,
                                    ),
                                    const SizedBox(height: CanopySpace.s4),
                                    Text(b.title,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: CanopyType.micro.copyWith(
                                            color: b.earned ? p.ink : p.inkMuted)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                CanopyListRow(
                  icon: Icons.favorite_outline,
                  title: 'Acknowledgements',
                  trailing: Text('$milestones of 4',
                      style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  onTap: () =>
                      Navigator.pushNamed(context, '/recognition/acknowledgements'),
                ),
                _CheckinsRow(userId: userId),
              ]);
            },
          ),
        ),
      ],
    );
  }
}

class _CheckinsRow extends StatelessWidget {
  final String userId;
  const _CheckinsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: EventsService().watchMyCheckins(userId),
      builder: (context, snap) {
        final now = DateTime.now();
        final month = (snap.data ?? const []).where((c) {
          final ts = c['checkedInAt'];
          return ts is Timestamp &&
              ts.toDate().year == now.year &&
              ts.toDate().month == now.month;
        }).toList();
        final pts = month.fold<int>(
            0, (t, c) => t + ((c['pointsAwarded'] as num?)?.toInt() ?? 0));
        return CanopyListRow(
          icon: Icons.qr_code_scanner_outlined,
          title: 'Check-ins this month',
          subtitle: '${month.length} check-in${month.length == 1 ? '' : 's'}',
          trailing: pts > 0 ? PointsLabel(pts) : null,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LogWorkEventScreen())),
        );
      },
    );
  }
}
