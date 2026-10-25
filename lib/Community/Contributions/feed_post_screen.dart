// lib/Community/Contributions/feed_post_screen.dart
//
// "Read more" for a feed post: the full gallery, the organisation (logo,
// verified, link to their profile), the whole description, what and when and
// where, the map pin of the exact spot (when one was logged), the
// organisation's social links, and copy / share.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Organization/Explorer/org_view_screen.dart';
import '../../theme/canopy_components.dart';
import '../../Shared/widgets/report_sheet.dart';
import 'entry_feed_card.dart';

class FeedPostScreen extends StatefulWidget {
  final FeedEntry entry;
  const FeedPostScreen({super.key, required this.entry});

  @override
  State<FeedPostScreen> createState() => _FeedPostScreenState();
}

class _FeedPostScreenState extends State<FeedPostScreen> {
  final _pages = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String get _shareText {
    final e = widget.entry;
    final d = e.description.trim();
    return [
      e.title,
      if (d.isNotEmpty) d.length > 280 ? '${d.substring(0, 280).trimRight()}…' : d,
      if (e.orgName.trim().isNotEmpty) 'Posted by ${e.orgName.trim()} on Canopy',
    ].join('\n\n');
  }

  Future<void> _open(String raw) async {
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

  Future<void> _openOrg(String? id) async {
    if (id == null || id.isEmpty) return;
    final nav = Navigator.of(context);
    try {
      final doc = await FirebaseFirestore.instance.collection('organizations').doc(id).get();
      if (!mounted || !doc.exists) return;
      nav.push(MaterialPageRoute(builder: (_) => OrgViewScreen(orgId: id, orgData: doc.data()!)));
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't open the organisation.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final e = widget.entry;
    final slides = e.slides;
    final date = e.postedAt == null ? null : DateFormat('EEEE d MMMM yyyy').format(e.postedAt!.toDate());
    final hasPin = e.latitude != null && e.longitude != null;
    final pin = hasPin ? LatLng(e.latitude!, e.longitude!) : null;

    return CanopyScaffold(
      appBar: canopyAppBar(
        context,
        actions: [
          CanopyIconButton(
              icon: Icons.flag_outlined,
              tooltip: 'Report',
              onPressed: () => showReportSheet(context,
                  targetType: 'contribution', targetId: e.contributionId ?? '', ownerId: e.userId, subject: 'this post')),
          CanopyIconButton(
              icon: Icons.ios_share,
              tooltip: 'Share',
              onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText, subject: e.title))),
        ],
      ),
      body: FutureBuilder<FeedOrg>(
        future: feedPosterFor(e),
        builder: (context, org) {
          final o = org.data ?? const FeedOrg();
          final posterName = o.name.trim().isNotEmpty ? o.name.trim() : e.orgName.trim();
          final posterOrgId = o.orgId ?? e.orgId;
          final merged = {...o.socials, ...e.socials};
          return ListView(
            padding: const EdgeInsets.only(bottom: CanopySpace.s32),
            children: [
              if (slides.isNotEmpty)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(fit: StackFit.expand, children: [
                    PageView.builder(
                      controller: _pages,
                      itemCount: slides.length,
                      onPageChanged: (i) => setState(() => _current = i),
                      itemBuilder: (_, i) => CanopyImage(url: slides[i].url, fallbackIcon: feedTypeIcon(e.type)),
                    ),
                    if (slides.length > 1)
                      Positioned(
                        bottom: CanopySpace.s12,
                        left: 0,
                        right: 0,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (var i = 0; i < slides.length; i++)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _current ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(i == _current ? 255 : 150),
                                borderRadius: BorderRadius.circular(CanopyRadius.pill),
                              ),
                            ),
                        ]),
                      ),
                    if (slides[_current].label != null)
                      Positioned(
                        left: CanopySpace.s12,
                        top: CanopySpace.s12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s8, vertical: CanopySpace.s4),
                          decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(CanopyRadius.xs)),
                          child: Text(slides[_current].label!.toUpperCase(), style: CanopyType.statusLabel.copyWith(color: Colors.white)),
                        ),
                      ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (posterName.isNotEmpty)
                    InkWell(
                      onTap: (posterOrgId ?? '').isEmpty ? null : () => _openOrg(posterOrgId),
                      child: Row(children: [
                        CanopyAvatar(url: o.logoUrl, name: posterName, size: 40, org: posterOrgId != null),
                        const SizedBox(width: CanopySpace.s12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(
                                child: Text(posterName,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                              ),
                              if (o.verified) ...[
                                const SizedBox(width: CanopySpace.s4),
                                Icon(Icons.verified_outlined, size: 16, color: p.primaryInk),
                              ],
                            ]),
                            if ((posterOrgId ?? '').isNotEmpty) Text('View organisation', style: CanopyType.caption.copyWith(color: p.primaryInk)),
                          ]),
                        ),
                      ]),
                    ),
                  const SizedBox(height: CanopySpace.s16),
                  if (e.type.isNotEmpty) Text(e.type.toUpperCase(), style: CanopyType.statusLabel.copyWith(color: p.inkMuted)),
                  const SizedBox(height: CanopySpace.s4),
                  Text(e.title, style: CanopyType.display.copyWith(color: p.ink)),
                  if (e.description.trim().isNotEmpty) ...[
                    const SizedBox(height: CanopySpace.s12),
                    Text(e.description.trim(), style: CanopyType.body.copyWith(color: p.ink, height: 24 / 15)),
                  ],
                  const SizedBox(height: CanopySpace.section),
                  CanopyListGroup(children: [
                    if (date != null) CanopyListRow(icon: Icons.event_outlined, title: date, subtitle: 'Posted', chevron: false),
                    if (e.type.isNotEmpty) CanopyListRow(icon: feedTypeIcon(e.type), title: e.type, subtitle: 'Type of work', chevron: false),
                    if (e.location.isNotEmpty) CanopyListRow(icon: Icons.place_outlined, title: e.location, subtitle: 'Where', chevron: false),
                  ]),
                  if (hasPin) ...[
                    const CanopySectionHeader(title: 'Where it happened', padding: EdgeInsets.only(top: CanopySpace.section)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 200,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(target: pin!, zoom: 16),
                          markers: {Marker(markerId: const MarkerId('post'), position: pin)},
                          liteModeEnabled: true,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: CanopySpace.s8),
                    CanopyButton.secondary(
                      label: 'Directions',
                      expand: true,
                      onPressed: () => launchUrl(
                          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${pin.latitude},${pin.longitude}'),
                          mode: LaunchMode.externalApplication),
                    ),
                  ],
                  if (merged.isNotEmpty) ...[
                    const CanopySectionHeader(title: 'Follow them', padding: EdgeInsets.only(top: CanopySpace.section)),
                    Wrap(spacing: CanopySpace.s8, children: [
                      for (final entry in const [
                        ('facebook', Icons.facebook, 'Facebook'),
                        ('instagram', Icons.camera_alt_outlined, 'Instagram'),
                        ('linkedin', Icons.business, 'LinkedIn'),
                        ('tiktok', Icons.music_note, 'TikTok'),
                      ])
                        if ((merged[entry.$1] ?? '').trim().isNotEmpty)
                          CanopyButton.secondary(
                            label: entry.$3,
                            size: CanopyButtonSize.compact,
                            onPressed: () => _open(merged[entry.$1]!),
                          ),
                    ]),
                  ],
                  const SizedBox(height: CanopySpace.section),
                  Row(children: [
                    Expanded(
                      child: CanopyButton.secondary(
                        label: 'Copy',
                        expand: true,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _shareText));
                          if (context.mounted) showCanopySnack(context, 'Copied to your clipboard.');
                        },
                      ),
                    ),
                    const SizedBox(width: CanopySpace.s8),
                    Expanded(
                      child: CanopyButton(
                        label: 'Share',
                        expand: true,
                        onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText, subject: e.title)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
