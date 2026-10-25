// lib/Community/Contributions/entry_feed_card.dart
//
// FeedCard (v3) for a logged contribution: the photo fills the card, with
// story-style progress bars and the organisation's logo + name over it; below,
// the title, a three-line summary with "Read more", date · type, copy-link and
// share, and the organisation's social links when they have added any. Tapping
// opens the full post (feed_post_screen.dart) with the map pin. In the owner's
// own list it also shows the review status and Edit / Delete.
// 1px outline, no shadow, lg radius.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Organization/Explorer/org_view_screen.dart';
import '../../Services/Contributions/contribution_service.dart';
import '../../theme/canopy_components.dart';
import '../../Shared/widgets/report_sheet.dart';
import 'feed_post_screen.dart';


/// Feed cards use a tight 6dp corner.
const double _kCardRadius = 6;

/// The organisation behind a post: logo, verified tick and any social links.
class FeedOrg {
  final String name;
  final String? orgId; // null when the poster is a member, not an organisation
  final String? logoUrl;
  final bool verified;
  final Map<String, String> socials;
  const FeedOrg({this.name = '', this.orgId, this.logoUrl, this.verified = false, this.socials = const {}});
}

final Map<String, Future<FeedOrg>> _orgCache = {};

/// One read per organisation per session, shared by every card in the feed.
Future<FeedOrg> feedOrgFor(String? orgId) {
  if (orgId == null || orgId.isEmpty) return Future.value(const FeedOrg());
  return _orgCache.putIfAbsent(orgId, () async {
    try {
      final d = (await FirebaseFirestore.instance.collection('organizations').doc(orgId).get()).data() ?? {};
      final socials = <String, String>{};
      void take(dynamic raw) {
        if (raw is Map) {
          raw.forEach((k, v) {
            if (v != null && v.toString().trim().isNotEmpty) socials[k.toString().toLowerCase()] = v.toString();
          });
        }
      }

      take(d['socialLinks']);
      take(d['socials']);
      for (final k in const ['facebook', 'instagram', 'linkedin', 'tiktok']) {
        final v = d[k];
        if (v is String && v.trim().isNotEmpty) socials[k] = v;
      }
      return FeedOrg(
          name: '${d['org_name'] ?? d['name'] ?? ''}'.trim(),
          orgId: orgId,
          logoUrl: (d['logoUrl'] ?? d['profilePhoto']) as String?,
          verified: d['verified'] == true,
          socials: socials);
    } catch (_) {
      _orgCache.remove(orgId);
      return const FeedOrg();
    }
  });
}

final Map<String, Future<FeedOrg>> _posterCache = {};

/// Who to show on a post: its organisation, else the organisation that ran the
/// activity it was logged against, else the organisation the poster represents,
/// else the member themselves.
Future<FeedOrg> feedPosterFor(FeedEntry e) {
  final key = '${e.orgId}|${e.activityId}|${e.userId}';
  return _posterCache.putIfAbsent(key, () async {
    final db = FirebaseFirestore.instance;
    try {
      var orgId = e.orgId;
      if ((orgId == null || orgId.isEmpty) && (e.activityId ?? '').isNotEmpty) {
        final a = (await db.collection('activities').doc(e.activityId).get()).data();
        orgId = (a?['orgId'] ?? a?['org_id']) as String?;
      }
      if (orgId != null && orgId.isNotEmpty) {
        final o = await feedOrgFor(orgId);
        if (o.name.isNotEmpty) return o;
      }
      if ((e.userId ?? '').isNotEmpty) {
        final u = (await db.collection('Users').doc(e.userId).get()).data() ?? {};
        // An organisation's representative posts as their organisation.
        final repOrg = '${u['orgId'] ?? ''}'.trim();
        if (repOrg.isNotEmpty) {
          final o = await feedOrgFor(repOrg);
          if (o.name.isNotEmpty) return o;
        }
        final first = '${u['FirstName'] ?? ''}'.trim();
        final last = '${u['LastName'] ?? ''}'.trim();
        final name = '${u['name'] ?? ''}'.trim().isNotEmpty ? '${u['name']}'.trim() : '$first $last'.trim();
        if (name.isNotEmpty) {
          return FeedOrg(name: name, logoUrl: (u['profilePhoto'] ?? u['photoUrl'] ?? u['avatarUrl']) as String?);
        }
      }
    } catch (_) {
      _posterCache.remove(key);
    }
    return FeedOrg(name: e.orgName);
  });
}

const List<(String, IconData, String)> _kSocialOrder = [
  ('facebook', Icons.facebook, 'Facebook'),
  ('instagram', Icons.camera_alt_outlined, 'Instagram'),
  ('tiktok', Icons.music_note, 'TikTok'),
  ('linkedin', Icons.business, 'LinkedIn'),
];

/// One slide: an image and an optional Before / After caption.
typedef FeedSlide = ({String url, String? label});

/// A single community feed entry rendered by [EntryFeedCard].
class FeedEntry {
  final String title;
  final String description;
  final String orgName;
  final String? orgId;
  final String type;
  final List<String> imageUrls;

  /// Photos taken after the work. When present, slide 1 is labelled Before
  /// and the first after photo follows as slide 2.
  final List<String> afterImageUrls;
  final Map<String, String> socials;
  final String? contributionId;
  final Timestamp? postedAt;
  final String? userId;
  final String? activityId;

  /// Where the work happened (place text and the exact point, when logged).
  final String location;
  final double? latitude, longitude;

  /// pending / verified / rejected.
  final String status;

  const FeedEntry({
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrls,
    this.afterImageUrls = const [],
    this.orgName = '',
    this.orgId,
    this.socials = const {},
    this.contributionId,
    this.postedAt,
    this.userId,
    this.activityId,
    this.location = '',
    this.latitude,
    this.longitude,
    this.status = 'pending',
  });

  /// Build from a `contributions` document. Images come from `photos`
  /// (falling back to `beforeImages`); after photos from `afterImages`.
  factory FeedEntry.fromContribution(Map<String, dynamic> d, {String orgName = '', String? contributionId}) {
    List<String> images(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList() : const [];
    var photos = images(d['photos']);
    if (photos.isEmpty) photos = images(d['beforeImages']);
    final after = images(d['afterImages']).where((u) => !photos.contains(u)).toList();

    final socials = <String, String>{};
    final raw = d['socialLinks'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) socials[k.toString()] = v.toString();
      });
    }
    final title = (d['title'] as String?)?.trim() ?? '';
    return FeedEntry(
      title: title.isNotEmpty ? title : (d['workType'] as String? ?? 'Contribution'),
      description: d['description'] as String? ?? '',
      type: d['workType'] as String? ?? d['type'] as String? ?? '',
      imageUrls: photos,
      afterImageUrls: after,
      orgName: orgName.isNotEmpty ? orgName : (d['orgName'] as String? ?? ''),
      orgId: d['orgId'] as String?,
      socials: socials,
      contributionId: contributionId ?? d['id'] as String?,
      postedAt: d['createdAt'] as Timestamp?,
      userId: d['userId'] as String?,
      activityId: d['activityId'] as String?,
      location: (d['location'] as String?)?.trim() ?? '',
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      status: d['status'] as String? ?? 'pending',
    );
  }

  List<FeedSlide> get slides {
    if (afterImageUrls.isEmpty) return [for (final u in imageUrls) (url: u, label: null)];
    return [
      if (imageUrls.isNotEmpty) (url: imageUrls.first, label: 'Before'),
      (url: afterImageUrls.first, label: 'After'),
      for (final u in imageUrls.skip(1)) (url: u, label: null),
      for (final u in afterImageUrls.skip(1)) (url: u, label: null),
    ];
  }
}

IconData feedTypeIcon(String type) => switch (type) {
      'Cleanup' => Icons.cleaning_services_outlined,
      'Tree Planting' => Icons.park_outlined,
      'School Upgrading' => Icons.school_outlined,
      'Waste Management' => Icons.recycling,
      'Water & Sanitation' => Icons.water_drop_outlined,
      'Infrastructure' => Icons.construction_outlined,
      _ => Icons.volunteer_activism_outlined,
    };

class EntryFeedCard extends StatefulWidget {
  final FeedEntry entry;

  /// Owner view: shows the review status and Edit / Delete.
  final bool editable;

  const EntryFeedCard({super.key, required this.entry, this.editable = false});

  @override
  State<EntryFeedCard> createState() => _EntryFeedCardState();
}

class _EntryFeedCardState extends State<EntryFeedCard> {
  final _pages = PageController();
  int _current = 0;
  late String _title = widget.entry.title;
  late String _description = widget.entry.description;
  bool _busy = false, _deleted = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _openOrg(String? orgId) async {
    if (orgId == null || orgId.isEmpty) return;
    final nav = Navigator.of(context);
    try {
      final doc = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
      if (!mounted || !doc.exists) return;
      nav.push(MaterialPageRoute(builder: (_) => OrgViewScreen(orgId: orgId, orgData: doc.data()!)));
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't open the organisation.", error: true);
    }
  }

  Future<void> _edit() async {
    final id = widget.entry.contributionId;
    if (id == null) return;
    final result = await showCanopySheet<(String, String)>(
      context,
      builder: (_) => _EditSheet(title: _title, description: _description),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('contributions').doc(id).update({
        'title': result.$1,
        'description': result.$2,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _title = result.$1;
        _description = result.$2;
      });
      showCanopySnack(context, 'Saved.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.entry.contributionId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) return;
    final ok = await showCanopyConfirm(
      context,
      title: 'Delete this contribution?',
      message: 'It is removed from your record along with any points it earned. This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ContributionService().deleteContribution(contributionId: id, userId: uid);
      if (mounted) setState(() => _deleted = true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showCanopySnack(context, "Couldn't delete. Try again.", error: true);
      }
    }
  }

  Future<void> _openUrl(String raw) async {
    var url = raw.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't open that link.", error: true);
    }
  }

  (String, Color) _status(CanopyPalette p) => switch (widget.entry.status) {
        'verified' => ('Verified', p.success),
        'rejected' => ('Not accepted', p.danger),
        _ => ('In review', p.warning),
      };

  String get _shareText {
    final e = widget.entry;
    final desc = _description.trim();
    final short = desc.length > 160 ? '${desc.substring(0, 160).trimRight()}…' : desc;
    return [
      _title,
      if (short.isNotEmpty) short,
      if (e.orgName.trim().isNotEmpty) 'Posted by ${e.orgName.trim()} on Canopy',
    ].join('\n\n');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (mounted) showCanopySnack(context, 'Copied to your clipboard.');
  }

  Future<void> _share() => SharePlus.instance.share(ShareParams(text: _shareText, subject: _title));

  void _report() => showReportSheet(context,
      targetType: 'contribution', targetId: widget.entry.contributionId ?? '', ownerId: widget.entry.userId, subject: 'this post');

  void _openPost() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedPostScreen(entry: widget.entry)));

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final p = context.canopy;
    final e = widget.entry;
    final slides = e.slides;
    final desc = _description.trim();
    final date = e.postedAt == null ? null : DateFormat('EEE d MMM').format(e.postedAt!.toDate());
    final meta = [if (date != null) date, if (e.type.isNotEmpty) e.type].join(' · ');
    const shade = Color(0xB3000000);

    return FutureBuilder<FeedOrg>(
      future: feedPosterFor(e),
      builder: (context, org) {
        final o = org.data ?? const FeedOrg();
        final orgName = o.name.trim().isNotEmpty ? o.name.trim() : e.orgName.trim();
        // Social links: the ones on this post, then the organisation's own.
        final merged = {...o.socials, ...e.socials};
        final socials = [
          for (final (key, icon, name) in _kSocialOrder)
            if ((merged[key] ?? '').trim().isNotEmpty) (icon, name, merged[key]!.trim()),
        ];
        return CanopyCard(
          padding: EdgeInsets.zero,
          radius: _kCardRadius,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Photo with progress bars and the organisation over it.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(_kCardRadius - 1)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: Stack(fit: StackFit.expand, children: [
                  GestureDetector(
                    onTap: _openPost,
                    child: slides.isEmpty
                        ? CanopyImage(url: null, fallbackIcon: feedTypeIcon(e.type))
                        : PageView.builder(
                            controller: _pages,
                            itemCount: slides.length,
                            onPageChanged: (i) => setState(() => _current = i),
                            itemBuilder: (_, i) => Semantics(
                              image: true,
                              label: slides[i].label == null ? 'Photo ${i + 1} of ${slides.length}' : '${slides[i].label} photo',
                              child: CanopyImage(url: slides[i].url, fallbackIcon: feedTypeIcon(e.type)),
                            ),
                          ),
                  ),
                  // Top scrim so the bars and chip read on any photo.
                  const IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: 96,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x73000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: CanopySpace.s8,
                    left: CanopySpace.s12,
                    right: CanopySpace.s12,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (slides.length > 1)
                        Row(children: [
                          for (var i = 0; i < slides.length; i++)
                            Expanded(
                              child: Container(
                                height: 3,
                                margin: EdgeInsets.only(right: i == slides.length - 1 ? 0 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(i <= _current ? 235 : 90),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ]),
                      if (orgName.isNotEmpty) ...[
                        SizedBox(height: slides.length > 1 ? CanopySpace.s12 : 0),
                        GestureDetector(
                          onTap: (o.orgId ?? e.orgId ?? '').isEmpty ? null : () => _openOrg(o.orgId ?? e.orgId),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                            decoration: BoxDecoration(color: shade, borderRadius: BorderRadius.circular(CanopyRadius.pill)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              CanopyAvatar(url: o.logoUrl, name: orgName, size: 28, org: o.orgId != null),
                              const SizedBox(width: CanopySpace.s8),
                              Flexible(
                                child: Text(orgName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: CanopyType.label.copyWith(color: Colors.white)),
                              ),
                              if (o.verified) ...[
                                const SizedBox(width: CanopySpace.s4),
                                const Icon(Icons.verified_outlined, size: 15, color: Colors.white),
                              ],
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  if (slides.isNotEmpty && slides[_current].label != null)
                    Positioned(
                      left: CanopySpace.s12,
                      bottom: CanopySpace.s12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s8, vertical: CanopySpace.s4),
                        decoration: BoxDecoration(color: shade, borderRadius: BorderRadius.circular(CanopyRadius.xs)),
                        child: Text(slides[_current].label!.toUpperCase(), style: CanopyType.statusLabel.copyWith(color: Colors.white)),
                      ),
                    ),
                ]),
              ),
            ),
            // Body
            InkWell(
              onTap: _openPost,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.cardPadding, CanopySpace.s12, CanopySpace.cardPadding, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (widget.editable) ...[
                    StatusLabel(_status(p).$1, color: _status(p).$2),
                    const SizedBox(height: CanopySpace.s4),
                  ],
                  Text(_title, style: CanopyType.subhead.copyWith(color: p.ink)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: CanopySpace.s4),
                    Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: CanopyType.body.copyWith(color: p.inkMuted)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
                      child: Text('Read more', style: CanopyType.label.copyWith(color: p.primaryInk)),
                    ),
                  ] else
                    const SizedBox(height: CanopySpace.s8),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(CanopySpace.cardPadding, 0, CanopySpace.s8, CanopySpace.s8),
              child: Row(children: [
                Expanded(child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: p.inkMuted))),
                for (final (icon, name, url) in socials)
                  CanopyIconButton(icon: icon, tooltip: name, color: p.inkMuted, onPressed: () => _openUrl(url)),
                CanopyIconButton(icon: Icons.link, tooltip: 'Copy link', color: p.inkMuted, onPressed: _copy),
                CanopyIconButton(icon: Icons.ios_share, tooltip: 'Share', color: p.inkMuted, onPressed: _share),
                if (!widget.editable)
                  CanopyIconButton(icon: Icons.flag_outlined, tooltip: 'Report', color: p.inkMuted, onPressed: _report),
              ]),
            ),
            if (widget.editable && e.contributionId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.cardPadding, 0, CanopySpace.cardPadding, CanopySpace.cardPadding),
                child: _busy
                    ? const LinearProgressIndicator()
                    : Row(children: [
                        CanopyButton(label: 'Edit', variant: CanopyButtonVariant.quiet, size: CanopyButtonSize.compact, onPressed: _edit),
                        const SizedBox(width: CanopySpace.s8),
                        CanopyButton(label: 'Delete', variant: CanopyButtonVariant.quietDanger, size: CanopyButtonSize.compact, onPressed: _delete),
                      ]),
              ),
          ]),
        );
      },
    );
  }
}

class _EditSheet extends StatefulWidget {
  final String title, description;
  const _EditSheet({required this.title, required this.description});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _title = TextEditingController(text: widget.title);
  late final _desc = TextEditingController(text: widget.description);
  bool _showErrors = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CanopySheetBody(
      title: 'Edit contribution',
      caption: 'Only the title and description can change. Photos and details stay as logged.',
      children: [
        CanopyTextField(
          label: 'Title',
          controller: _title,
          error: _showErrors && _title.text.trim().isEmpty ? 'Add a title.' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Description', controller: _desc, maxLines: 5),
      ],
      actions: [
        CanopyButton(
          label: 'Save',
          expand: true,
          onPressed: () {
            if (_title.text.trim().isEmpty) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.pop(context, (_title.text.trim(), _desc.text.trim()));
          },
        ),
      ],
    );
  }
}
