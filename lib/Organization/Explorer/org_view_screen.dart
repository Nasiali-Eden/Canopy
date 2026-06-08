// lib/Organization/Explorer/org_view_screen.dart
//
// Immersive, fully-visual public profile for an organisation.
// Cover image becomes the ambient background; everything about the org —
// background, main functions, programmes, events, articles — is arranged on
// frosted-glass cards. Sections render a placeholder card when empty.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Models/programme.dart';
import '../Home/Programmes/programme_logic.dart';
import '../../Services/Article/article_service.dart';
import '../../Community/Articles/article_view_screen.dart';
import 'view_commons.dart';
import 'programme_view_screen.dart';
import 'event_view_screen.dart';

class OrgViewScreen extends StatelessWidget {
  final String orgId;
  final Map<String, dynamic> orgData;

  const OrgViewScreen({
    super.key,
    required this.orgId,
    required this.orgData,
  });

  // ── field resolution (matches actual Firestore field names) ──────────────────

  String get _name =>
      (orgData['org_name'] ?? orgData['name'] ?? 'Organisation') as String;
  String? get _logo =>
      (orgData['logoUrl'] ?? orgData['profilePhoto']) as String?;
  String? get _cover =>
      (orgData['coverImageUrl'] ?? orgData['profilePhoto']) as String?;
  String get _sectorId => orgData['sectorId'] as String? ?? '';
  String get _background =>
      (orgData['background'] ?? orgData['description'] ?? orgData['bio'] ?? '')
          as String;
  String get _designation =>
      (orgData['orgDesignation'] ?? orgData['designation'] ?? '') as String;
  bool get _verified => orgData['verified'] as bool? ?? false;
  String get _city => orgData['city'] as String? ?? '';
  String get _area => orgData['area'] as String? ?? '';
  String? get _phone => orgData['phone'] as String?;
  String? get _website => orgData['website'] as String?;
  List<String> get _functions =>
      List<String>.from(orgData['mainFunctions'] ?? const []);

  Color get _accent => sectorColorOf(_sectorId);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final location =
        [_area, _city].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0D),
      body: Stack(
        children: [
          ImmersiveBackground(imageUrl: _cover, tint: _accent),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // ── Identity header ────────────────────────────────────
                SliverToBoxAdapter(child: _identity(location)),

                // ── About ──────────────────────────────────────────────
                SliverToBoxAdapter(child: _aboutSection()),

                // ── Programmes ─────────────────────────────────────────
                SliverToBoxAdapter(child: _programmesSection(context)),

                // ── Events ─────────────────────────────────────────────
                SliverToBoxAdapter(child: _eventsSection(context)),

                // ── Articles ───────────────────────────────────────────
                SliverToBoxAdapter(child: _articlesSection(context)),

                // ── Contact ────────────────────────────────────────────
                SliverToBoxAdapter(child: _contactSection()),

                SliverToBoxAdapter(child: SizedBox(height: bottomPad + 110)),
              ],
            ),
          ),

          // Back button
          Positioned(
            top: topPad + 8,
            left: 16,
            child: CircleGlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: topPad + 8,
            right: 16,
            child: CircleGlassButton(
              icon: Icons.share_outlined,
              onTap: () {},
            ),
          ),

          // Bottom action bar (pill, echoes org_home nav)
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomPad + 18,
            child: _actionBar(context),
          ),
        ],
      ),
    );
  }

  // ── IDENTITY ────────────────────────────────────────────────────────────────

  Widget _identity(String location) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _logo != null && _logo!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _logo!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _logoFallback(),
                      )
                    : _logoFallback(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_designation.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _designation,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (_verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              color: Colors.white, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sector + location chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.category_outlined, sectorLabelOf(_sectorId)),
              if (location.isNotEmpty) _chip(Icons.place_outlined, location),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logoFallback() {
    final initials = _name.isNotEmpty ? _name.trim()[0].toUpperCase() : 'O';
    return Container(
      color: _accent,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── ABOUT ───────────────────────────────────────────────────────────────────

  Widget _aboutSection() {
    if (_background.isEmpty && _functions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_background.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _background,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 13.5,
                  height: 1.6,
                ),
              ),
            ],
            if (_functions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'What we do',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _functions
                    .map((f) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _accent.withOpacity(0.4)),
                          ),
                          child: Text(
                            f,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── PROGRAMMES ────────────────────────────────────────────────────────────────

  Widget _programmesSection(BuildContext context) {
    return StreamBuilder<List<Programme>>(
      stream: ProgrammeLogic.streamProgrammes(orgId),
      builder: (context, snap) {
        final all = snap.data ?? const <Programme>[];
        final items = all
            .where((p) =>
                p.status != ProgrammeStatus.archived &&
                p.status != ProgrammeStatus.draft)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              icon: Icons.school_outlined,
              title: 'Programmes',
              count: items.isEmpty ? null : '${items.length}',
              accent: _accent,
            ),
            if (items.isEmpty)
              const EmptyCategoryCard(
                icon: Icons.school_outlined,
                message: 'No programmes published yet. Check back soon.',
              )
            else
              SizedBox(
                height: 232,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return MediaPosterCard(
                      imageUrl: p.coverImageUrl,
                      title: p.title,
                      subtitle: '${p.type.label} · ${p.displayPrice}',
                      badge: p.isFree ? 'FREE' : (p.isVolunteer ? 'VOLUNTEER' : null),
                      accent: _accent,
                      fallbackIcon: Icons.school_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProgrammeViewScreen(
                            programme: p,
                            orgName: _name,
                            accent: _accent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // ── EVENTS ──────────────────────────────────────────────────────────────────

  Widget _eventsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('orgId', isEqualTo: orgId)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot>[];
        final items = docs
            .where((d) =>
                ((d.data() as Map<String, dynamic>)['status'] ?? '') != 'draft')
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              icon: Icons.event_outlined,
              title: 'Events',
              count: items.isEmpty ? null : '${items.length}',
              accent: _accent,
            ),
            if (items.isEmpty)
              const EmptyCategoryCard(
                icon: Icons.event_outlined,
                message: 'No upcoming events right now.',
              )
            else
              SizedBox(
                height: 232,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final doc = items[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return MediaPosterCard(
                      imageUrl: _firstImage(data),
                      title: (data['name'] ?? data['title'] ?? 'Event') as String,
                      subtitle: _eventSubtitle(data),
                      badge: (data['status'] as String?)?.toUpperCase(),
                      accent: _accent,
                      fallbackIcon: Icons.event_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventViewScreen(
                            eventId: doc.id,
                            data: data,
                            orgName: _name,
                            accent: _accent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  static String? _firstImage(Map<String, dynamic> data) {
    final imgs = data['images'];
    if (imgs is List) {
      for (final x in imgs) {
        if (x is String && x.isNotEmpty) return x;
      }
    }
    return data['coverImageUrl'] as String? ?? data['imageUrl'] as String?;
  }

  static String _eventSubtitle(Map<String, dynamic> data) {
    final loc = data['location'];
    String place = '';
    if (loc is String) place = loc;
    if (loc is Map) {
      place = [loc['venue'], loc['area'], loc['city']]
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    final raw = data['date'] ?? data['dateTime'];
    if (raw is Timestamp) {
      final dt = raw.toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final d = '${dt.day} ${months[dt.month - 1]}';
      return place.isEmpty ? d : '$d · $place';
    }
    return place.isEmpty ? 'Upcoming' : place;
  }

  // ── ARTICLES ──────────────────────────────────────────────────────────────────

  Widget _articlesSection(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ArticleService().watchOrgArticles(orgId),
      builder: (context, snap) {
        final all = snap.data ?? const <Map<String, dynamic>>[];
        final items =
            all.where((a) => (a['status'] ?? '') == 'published').toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              icon: Icons.article_outlined,
              title: 'Articles',
              count: items.isEmpty ? null : '${items.length}',
              accent: _accent,
            ),
            if (items.isEmpty)
              const EmptyCategoryCard(
                icon: Icons.article_outlined,
                message: 'This organisation hasn\'t published any articles yet.',
              )
            else
              ...items.map((a) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _ArticleRow(
                      data: a,
                      accent: _accent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArticleViewScreen(
                            articleId: a['id'] as String? ?? '',
                            articleData: a,
                          ),
                        ),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }

  // ── CONTACT ───────────────────────────────────────────────────────────────────

  Widget _contactSection() {
    final hasContact = (_phone != null && _phone!.isNotEmpty) ||
        (_website != null && _website!.isNotEmpty);
    if (!hasContact) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_phone != null && _phone!.isNotEmpty)
              _contactRow(Icons.phone_outlined, _phone!),
            if (_website != null && _website!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _contactRow(Icons.language_outlined, _website!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── ACTION BAR ────────────────────────────────────────────────────────────────

  Widget _actionBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact flow coming soon')),
            ),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Get in touch',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        CircleGlassButton(
            icon: Icons.directions_outlined, onTap: () {}, size: 54),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARTICLE ROW — horizontal glass card with thumbnail
// ─────────────────────────────────────────────────────────────────────────────

class _ArticleRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;
  final VoidCallback onTap;

  const _ArticleRow({
    required this.data,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final heading =
        (data['heading'] ?? data['title'] ?? 'Article') as String;
    final topic = data['topic'] as String? ?? '';
    final cover =
        (data['coverPhotoUrl'] ?? data['coverImageUrl']) as String?;

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 96,
              height: 96,
              child: cover != null && cover.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (topic.isNotEmpty)
                      Text(
                        topic.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      heading,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: accent.withOpacity(0.3),
      alignment: Alignment.center,
      child: Icon(Icons.article_outlined,
          color: Colors.white.withOpacity(0.6), size: 26),
    );
  }
}
