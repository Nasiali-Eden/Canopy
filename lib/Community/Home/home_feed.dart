// lib/Community/Home/home_feed.dart
//
// The community Home tab UI (hero, quick actions, announcements, community
// updates, recent activity feed). Extracted out of community_home.dart so that
// file is a routing-only shell — see [CommunityHomeScreen].

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../HomeServices/services_home_screen.dart';
import '../../MarketPlace/The Market/eco_shop.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Shared/utils/rich_body.dart';
import '../Articles/article_view_screen.dart';
import '../Contributions/entry_feed_card.dart';

// ── Firestore collection paths ─────────────────────────────────────────────────
const _kArticles = 'articles';
const _kAnnouncements = 'announcements';
const _kUsers = 'users';

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

class HomeFeed extends StatelessWidget {
  final String? userId;
  final VoidCallback onJoinActivity;
  final VoidCallback onLogWork;
  final VoidCallback onViewAnnouncements;
  final VoidCallback onViewAllArticles;
  final VoidCallback onViewAllContributions;

  const HomeFeed({
    super.key,
    this.userId,
    required this.onJoinActivity,
    required this.onLogWork,
    required this.onViewAnnouncements,
    required this.onViewAllArticles,
    required this.onViewAllContributions,
  });

  @override
  Widget build(BuildContext context) {
    // No app bar for this tab (Phase 1.1 — removed entirely so content fills
    // the reclaimed space); a plain white background enforces the theme's
    // own `scaffoldBackgroundColor: Colors.white` instead of the old green
    // wash. SafeArea keeps the hero card clear of the status bar now that
    // there's no app bar reserving that space.
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero ──────────────────────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.lightGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Building a Better',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 26,
                                          height: 1.2,
                                        )),
                                Text('Community Together',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 20,
                                          height: 1.2,
                                        )),
                                const SizedBox(height: 12),
                                Text('Every action counts. Track your impact.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 14,
                                        )),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.eco,
                                size: 40, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (userId != null)
                        StreamBuilder<DocumentSnapshot>(
                          // Firestore: users/{userId}
                          stream: FirebaseFirestore.instance
                              .collection(_kUsers)
                              .doc(userId)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.hasError) return const SizedBox.shrink();
                            final data =
                                snap.data?.data() as Map<String, dynamic>?;
                            final points = data?['totalPoints'] ?? 0;
                            final contributions = data?['contributions'] ?? 0;
                            final rank = data?['rank'] ?? '0';
                            return Row(
                              children: [
                                Expanded(
                                    child: _StatCard(
                                        label: 'Points',
                                        value: points.toString(),
                                        icon: Icons.bolt)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _StatCard(
                                        label: 'Contributions',
                                        value: contributions.toString(),
                                        icon: Icons.volunteer_activism)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _StatCard(
                                        label: 'Rank',
                                        value: rank.toString(),
                                        icon: Icons.emoji_events)),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // ── Quick Actions ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Actions',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkGreen,
                                    fontSize: 18,
                                  )),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Log Work — QR event check-in (was a locked
                          // "coming soon" tile; see LogWorkEventScreen).
                          Expanded(
                            child: _QuickActionCard(
                              title: 'Log Work',
                              icon: Icons.qr_code_scanner_rounded,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: onLogWork,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Join Event — same coral family as Log
                          // Work now that both are event-tied actions.
                          Expanded(
                            child: _QuickActionCard(
                              title: 'Join Event',
                              icon: Icons.event,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: onJoinActivity,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Marketplace + Services, side by side (Phase 1.1: "Add
                      // a Services button beside Marketplace... opening to a
                      // 'coming soon' state").
                      Row(
                        children: [
                          Expanded(
                            child: _HomeEntryCard(
                              title: 'Marketplace',
                              subtitle: 'Shop recycled goods & eco products',
                              icon: Icons.storefront_outlined,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const EcoShopScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HomeEntryCard(
                              title: 'Services',
                              subtitle: 'Book trusted local help',
                              icon: Icons.home_repair_service_outlined,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ServicesHomeScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Announcements ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign_outlined,
                              color: AppTheme.darkGreen, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Announcements',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGreen,
                                      fontSize: 18,
                                    )),
                          ),
                          TextButton(
                            onPressed: onViewAnnouncements,
                            child: const Text('See All',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        // Firestore: announcements — 3 most recent, client-side
                        // expiry filter.
                        stream: FirebaseFirestore.instance
                            .collection(_kAnnouncements)
                            .orderBy('createdAt', descending: true)
                            .limit(6)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const _ErrorCard(onRetry: null);
                          }
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return Column(
                              children: List.generate(
                                  2, (_) => const _AnnouncementPlaceholder()),
                            );
                          }
                          final now = DateTime.now();
                          final docs = (snap.data?.docs ?? []).where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final exp = data['expiresAt'] as Timestamp?;
                            return exp == null || exp.toDate().isAfter(now);
                          }).take(3).toList();

                          if (docs.isEmpty) {
                            return _quietEmptyCard(
                              icon: Icons.notifications_none,
                              label: 'No announcements yet',
                            );
                          }
                          return Column(
                            children: docs.map((d) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AnnouncementCard(
                                    data: d.data() as Map<String, dynamic>),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Community Updates ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.article_outlined,
                              color: AppTheme.darkGreen, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Community Updates',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGreen,
                                      fontSize: 18,
                                    )),
                          ),
                          TextButton(
                            onPressed: onViewAllArticles,
                            child: const Text('See All',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      StreamBuilder<QuerySnapshot>(
                        // Firestore: articles — newest published first, limit 3.
                        // Index-free: ordering by publishedAt alone returns only
                        // live articles (drafts have a null publishedAt).
                        stream: FirebaseFirestore.instance
                            .collection(_kArticles)
                            .orderBy('publishedAt', descending: true)
                            .limit(3)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const _ErrorCard(onRetry: null);
                          }
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return Column(
                              children: const [
                                _ArticlePlaceholderCard(),
                                SizedBox(height: 12),
                                _ArticlePlaceholderCard(),
                              ],
                            );
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppTheme.lightGreen.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.article_outlined,
                                      size: 48, color: AppTheme.lightGreen),
                                  const SizedBox(height: 12),
                                  Text('No community updates yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(color: AppTheme.darkGreen)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Check back soon for news from organisations in your area.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              AppTheme.darkGreen.withOpacity(0.6),
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: docs.asMap().entries.map((e) {
                              final data =
                                  e.value.data() as Map<String, dynamic>;
                              return Padding(
                                padding: EdgeInsets.only(
                                    bottom: e.key < docs.length - 1 ? 12 : 0),
                                child: _CommunityNewsCard(
                                    id: e.value.id, data: data),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Recent Activity ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Recent Activity',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGreen,
                                      fontSize: 18,
                                    )),
                          ),
                          TextButton(
                            onPressed: onViewAllContributions,
                            child: const Text('View All',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Feed entries — real contributions rendered with the new
                      // card design (full-width 1:1 carousel, colour-coded type
                      // line, expandable description). Index-free: a single
                      // orderBy on createdAt, newest first.
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('contributions')
                            .orderBy('createdAt', descending: true)
                            .limit(20)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const _ErrorCard(onRetry: null);
                          }
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const _ArticlePlaceholderCard();
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              alignment: Alignment.center,
                              child: Text(
                                'No contributions yet. Be the first to log one!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.darkGreen.withOpacity(0.55),
                                    fontSize: 13),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (int i = 0; i < docs.length; i++) ...[
                                EntryFeedCard(
                                  entry: FeedEntry.fromContribution(
                                    docs[i].data()
                                        as Map<String, dynamic>,
                                  ),
                                ),
                                if (i < docs.length - 1)
                                  const SizedBox(height: 24),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                  // Clearance so the last card sits above the floating bottom
                  // nav (the body extends behind it via extendBody).
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

Widget _quietEmptyCard({required IconData icon, required String label}) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.lightGreen.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 36, color: AppTheme.lightGreen),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.6),
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback? onRetry;
  const _ErrorCard({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Something went wrong',
                  style: TextStyle(color: Colors.red.shade700))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Shimmer box ───────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.15),
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}

// ── Article placeholder card ──────────────────────────────────────────────────

class _ArticlePlaceholderCard extends StatelessWidget {
  const _ArticlePlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(height: 14, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          _ShimmerBox(
              width: 220, height: 11, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          _ShimmerBox(
              width: 60, height: 10, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }
}

// ── Announcement placeholder ──────────────────────────────────────────────────

class _AnnouncementPlaceholder extends StatelessWidget {
  const _AnnouncementPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                      height: 13, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  _ShimmerBox(
                      width: 160,
                      height: 11,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Announcement card ─────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnnouncementCard({required this.data});

  Color _accentFor(String type) {
    switch (type) {
      case 'alert':
        return Colors.red.shade600;
      case 'event':
        return AppTheme.tertiary;
      case 'update':
        return AppTheme.primary;
      case 'opportunity':
        return AppTheme.accent;
      default:
        return AppTheme.lightGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'general';
    final isUrgent = data['isUrgent'] as bool? ?? false;
    final orgLogoUrl = data['orgLogoUrl'] as String?;
    final orgName = data['orgName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final body = richBodyToMarkdown(data['body']);
    final createdAt = data['createdAt'] as Timestamp?;
    final accent = _accentFor(type);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (orgLogoUrl != null)
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(orgLogoUrl),
                          onBackgroundImageError: (_, __) {},
                        )
                      else
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: accent.withOpacity(0.15),
                          child: Icon(Icons.business, size: 14, color: accent),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(orgName,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.darkGreen.withOpacity(0.65),
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('URGENT',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            fontSize: 13,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(body,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.6),
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(timeAgo(createdAt),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 95,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Marketplace full-width action ─────────────────────────────────────────────

/// Shared style for the home screen's primary entry points (Marketplace,
/// Services) — a dark-green gradient pill with an icon chip, title, and
/// subtitle. Sized to sit half-width, side by side (Phase 1.1).
class _HomeEntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: Colors.white.withOpacity(0.9), size: 18),
              ],
            ),
            const Spacer(),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 19,
                  )),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
        ],
      ),
    );
  }
}

// ── Community News Card ───────────────────────────────────────────────────────
// Cover image on the left; tapping opens the full article view.

class _CommunityNewsCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _CommunityNewsCard({required this.id, required this.data});

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'news':
        return 'News';
      case 'announcement':
        return 'Announcement';
      case 'education':
        return 'Education';
      case 'impact_story':
        return 'Impact Story';
      case 'event_recap':
        return 'Event Recap';
      default:
        return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final body = richBodyToPlainText(data['body']);
    // Articles may store the cover under either key — read both.
    final imageUrl =
        (data['coverImageUrl'] ?? data['coverPhotoUrl']) as String?;
    final publishedAt = data['publishedAt'] as Timestamp?;
    final category = data['category'] as String? ?? '';
    final dateStr = publishedAt != null ? timeAgo(publishedAt) : '';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleViewScreen(articleId: id, articleData: data),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(
                      imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgFallback(),
                      loadingBuilder: (_, child, prog) =>
                          prog == null ? child : _imgFallback(),
                    )
                  : _imgFallback(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_categoryLabel(category),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                      ),
                    Text(title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen,
                              fontSize: 14,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.darkGreen.withOpacity(0.6),
                              fontSize: 12,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 12, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Branded fallback (matches the article list / full view) when an article has
  // no cover or the image fails to load.
  Widget _imgFallback() => Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.lightGreen.withOpacity(0.4),
              AppTheme.primary.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
            child: Icon(Icons.article, size: 26, color: AppTheme.primary)),
      );
}
