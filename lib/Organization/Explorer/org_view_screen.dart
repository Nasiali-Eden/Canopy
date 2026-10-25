// lib/Organization/Explorer/org_view_screen.dart
//
// Public organisation page (ORG_HANDOFF §3.8, F). ImmersiveHeader → logo,
// name, verified → primary "Join organisation" → about → What we do →
// Upcoming events (ActivityCard, landscape cover) → Programmes → Articles
// (real empty state) → Contact. Joining writes a pending OrgMembers record
// that the org approves in People.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Community/Articles/article_card.dart';
import '../../Models/programme.dart';
import '../../Services/Article/article_service.dart';
import '../../Shared/Activities/activity_card.dart';
import '../../Shared/widgets/immersive_header.dart';
import '../../theme/canopy_components.dart';
import '../Home/Programmes/programme_editor.dart' show programmePrice, programmeTypeIcon;
import '../Home/Programmes/programme_logic.dart';
import 'programme_view_screen.dart';

class OrgViewScreen extends StatelessWidget {
  final String orgId;
  final Map<String, dynamic> orgData;

  const OrgViewScreen({super.key, required this.orgId, required this.orgData});

  String get _name => (orgData['org_name'] ?? orgData['name'] ?? 'Organisation') as String;
  String? get _logo => (orgData['logoUrl'] ?? orgData['profilePhoto']) as String?;
  String? get _cover => orgData['coverImageUrl'] as String?;
  String get _about => ((orgData['background'] ?? orgData['about'] ?? orgData['description'] ?? orgData['bio'] ?? '') as String).trim();
  String get _designation => ((orgData['orgDesignation'] ?? orgData['designation'] ?? '') as String).trim();
  bool get _verified => orgData['verified'] == true;
  String get _place => [orgData['area'], orgData['city']].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
  List<String> get _functions => List<String>.from(orgData['mainFunctions'] ?? const []);

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showCanopySnack(context, "Couldn't open that.", error: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final phone = (orgData['phone'] as String?)?.trim() ?? '';
    final website = (orgData['website'] as String?)?.trim() ?? '';

    return CanopyScaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: ImmersiveHeader(imageUrl: _cover, height: 220, fallbackIcon: Icons.apartment_outlined)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
          sliver: SliverList.list(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              CanopyAvatar(url: _logo, name: _name, size: 64, org: true),
              const SizedBox(width: CanopySpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name, style: CanopyType.title.copyWith(color: p.ink)),
                  const SizedBox(height: CanopySpace.s2),
                  Row(children: [
                    if (_verified) ...[
                      Icon(Icons.verified, size: 16, color: p.primary),
                      const SizedBox(width: CanopySpace.s4),
                    ],
                    Flexible(
                      child: Text(
                        [if (_verified) 'Verified${_designation.isEmpty ? '' : ' $_designation'}' else _designation, _place]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: CanopyType.label.copyWith(color: p.inkMuted),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: CanopySpace.s16),
            _JoinButton(orgId: orgId, orgName: _name),
            if (_about.isNotEmpty) ...[
              const CanopySectionHeader(title: 'About', padding: EdgeInsets.only(top: CanopySpace.section)),
              Text(_about, style: CanopyType.body.copyWith(color: p.ink, height: 1.55)),
            ],
            if (_functions.isNotEmpty) ...[
              const CanopySectionHeader(title: 'What we do', padding: EdgeInsets.only(top: CanopySpace.section)),
              CanopyListGroup(children: [
                for (final f in _functions) CanopyListRow(icon: Icons.check, title: f, chevron: false),
              ]),
            ],
            _EventsSection(orgId: orgId),
            _ProgrammesSection(orgId: orgId, orgName: _name),
            _ArticlesSection(orgId: orgId),
            if (phone.isNotEmpty || website.isNotEmpty) ...[
              const CanopySectionHeader(title: 'Contact', padding: EdgeInsets.only(top: CanopySpace.section)),
              CanopyListGroup(children: [
                if (phone.isNotEmpty)
                  CanopyListRow(
                    icon: Icons.phone_outlined,
                    title: phone,
                    subtitle: 'Call',
                    onTap: () => _launch(context, Uri(scheme: 'tel', path: phone)),
                  ),
                if (website.isNotEmpty)
                  CanopyListRow(
                    icon: Icons.language,
                    title: website,
                    subtitle: 'Website',
                    onTap: () {
                      final u = Uri.tryParse(website.startsWith('http') ? website : 'https://$website');
                      if (u != null) _launch(context, u);
                    },
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOIN
// ─────────────────────────────────────────────────────────────────────────────

class _JoinButton extends StatefulWidget {
  final String orgId;
  final String orgName;
  const _JoinButton({required this.orgId, required this.orgName});

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  final _user = FirebaseAuth.instance.currentUser;
  bool _busy = false;
  late final Future<String?> _myOrg = _user == null
      ? Future.value(null)
      : FirebaseFirestore.instance.collection('Users').doc(_user.uid).get().then((d) => d.data()?['orgId'] as String?);

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('OrgMembers').doc('${widget.orgId}_${_user!.uid}');

  Future<void> _join() async {
    final u = _user!;
    setState(() => _busy = true);
    try {
      final prof = (await FirebaseFirestore.instance.collection('Users').doc(u.uid).get()).data() ?? {};
      await _ref.set({
        'orgId': widget.orgId,
        'userId': u.uid,
        'name': (prof['name'] ?? prof['displayName'] ?? u.displayName ?? '') as String,
        'avatarUrl': prof['profilePhoto'] ?? prof['photoUrl'] ?? u.photoURL,
        'contact': u.email ?? u.phoneNumber ?? '',
        'area': prof['area'] ?? prof['city'],
        'role': 'member',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) showCanopySnack(context, 'Request sent to ${widget.orgName}.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't send your request. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(bool member) async {
    final ok = await showCanopyConfirm(context,
        title: member ? 'Leave ${widget.orgName}?' : 'Withdraw your request?',
        message: member ? "You'll stop showing as a member." : 'You can ask again later.',
        confirmLabel: member ? 'Leave' : 'Withdraw',
        danger: member);
    if (!ok) return;
    try {
      await _ref.delete();
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (_user == null) {
      return Text('Sign in to join this organisation.', style: CanopyType.caption.copyWith(color: p.inkMuted));
    }
    return FutureBuilder<String?>(
      future: _myOrg,
      builder: (context, own) {
        if (own.data == widget.orgId) {
          return const CanopyCallout(icon: Icons.visibility_outlined, text: 'This is your organisation as members see it.');
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _ref.snapshots(),
          builder: (context, snap) {
            final status = snap.data?.data()?['status'] as String?;
            if (status == 'pending') {
              return Row(children: [
                StatusLabel('Request sent', color: p.info),
                const Spacer(),
                CanopyButton.quiet(label: 'Withdraw', size: CanopyButtonSize.compact, onPressed: () => _withdraw(false)),
              ]);
            }
            if (status == 'active' || status == 'inactive') {
              return Row(children: [
                StatusLabel("You're a member", color: p.success, icon: Icons.check),
                const Spacer(),
                CanopyButton.quiet(label: 'Leave', size: CanopyButtonSize.compact, onPressed: () => _withdraw(true)),
              ]);
            }
            return CanopyButton(
              label: 'Join organisation',
              expand: true,
              loading: _busy || !snap.hasData && !snap.hasError,
              onPressed: _join,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _EventsSection extends StatelessWidget {
  final String orgId;
  const _EventsSection({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('activities').where('orgId', isEqualTo: orgId).snapshots(),
      builder: (context, snap) {
        final now = DateTime.now();
        DateTime? at(Map<String, dynamic> d) => ((d['dateTime'] ?? d['scheduledAt'] ?? d['date']) as Timestamp?)?.toDate();
        final list = (snap.data?.docs ?? const [])
            .where((d) {
              final s = d.data()['status'] as String? ?? '';
              final t = at(d.data());
              return s != 'draft' && s != 'cancelled' && s != 'completed' && t != null && t.isAfter(now);
            })
            .toList()
          ..sort((a, b) => at(a.data())!.compareTo(at(b.data())!));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CanopySectionHeader(title: 'Upcoming events', padding: EdgeInsets.only(top: CanopySpace.section)),
          if (snap.hasError)
            const CanopyErrorState(inline: true, title: "Couldn't load events.")
          else if (!snap.hasData)
            const CanopyCardSkeleton()
          else if (list.isEmpty)
            const CanopyEmptyState(boxed: true, icon: Icons.event_outlined, title: 'No upcoming events', line: 'Check back soon.')
          else
            for (final d in list.take(5)) ...[
              ActivityCard(activity: d.data(), activityId: d.id),
              const SizedBox(height: CanopySpace.s12),
            ],
        ]);
      },
    );
  }
}

class _ProgrammesSection extends StatelessWidget {
  final String orgId;
  final String orgName;
  const _ProgrammesSection({required this.orgId, required this.orgName});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<List<Programme>>(
      stream: ProgrammeLogic.streamProgrammes(orgId),
      builder: (context, snap) {
        final list = (snap.data ?? const <Programme>[])
            .where((x) => x.status != ProgrammeStatus.draft && x.status != ProgrammeStatus.archived)
            .toList();
        if (snap.hasData && list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CanopySectionHeader(title: 'Programmes', padding: EdgeInsets.only(top: CanopySpace.section)),
          if (!snap.hasData)
            const CanopyCardSkeleton()
          else
            SizedBox(
              height: 212,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: CanopySpace.s12),
                itemBuilder: (_, i) {
                  final g = list[i];
                  return SizedBox(
                    width: 240,
                    child: CanopyCard(
                      padding: EdgeInsets.zero,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ProgrammeViewScreen(programme: g, orgName: orgName))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(CanopyRadius.md - 1)),
                          child: SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: CanopyImage(url: g.coverImageUrl, fallbackIcon: programmeTypeIcon(g.type)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(CanopySpace.s12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                            const SizedBox(height: CanopySpace.s2),
                            Text('${g.type.label} · ${programmePrice(g)}',
                                style: CanopyType.caption.copyWith(color: p.inkMuted)),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ]);
      },
    );
  }
}

class _ArticlesSection extends StatelessWidget {
  final String orgId;
  const _ArticlesSection({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ArticleService().watchOrgArticles(orgId),
      builder: (context, snap) {
        final list = (snap.data ?? const <Map<String, dynamic>>[])
            .where((a) => (a['isPublished'] as bool?) ?? (a['status'] == 'published'))
            .toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CanopySectionHeader(title: 'Articles', padding: EdgeInsets.only(top: CanopySpace.section)),
          if (snap.hasError)
            const CanopyErrorState(inline: true, title: "Couldn't load articles.")
          else if (!snap.hasData)
            const CanopyCardSkeleton()
          else if (list.isEmpty)
            const CanopyEmptyState(boxed: true, icon: Icons.article_outlined, title: 'No articles yet')
          else
            for (final a in list.take(3)) ...[
              ArticleCard(id: a['id'] as String? ?? '', data: a),
              const SizedBox(height: CanopySpace.s12),
            ],
        ]);
      },
    );
  }
}
