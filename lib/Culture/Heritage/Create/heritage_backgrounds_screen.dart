// lib/Culture/Heritage/Create/heritage_backgrounds_screen.dart
//
// Backgrounds (ARCHIVE_HANDOFF §3.4, F). CompletenessCard → Country images
// (Banner 2:1 — country page / Card 1:1 — Heritage tab) → "Preview [country]
// as a member" → Category backgrounds (3-col grid of 12; set or category
// fallback + "Empty · add") → Community backgrounds (set / uploading with
// progress / failed + Retry / empty "Falls back to [country]'s background").
// Writes heritage_hierarchy/{nodeId} — the nodes the public screens read.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Community/Heritage/country_screen.dart';
import '../../../theme/canopy_components.dart';
import '../Services/heritage_content_types.dart';
import '../Services/heritage_data_service.dart';
import 'country_completeness_card.dart';

class HeritageBackgroundsScreen extends StatefulWidget {
  final String orgId;
  const HeritageBackgroundsScreen({super.key, required this.orgId});

  @override
  State<HeritageBackgroundsScreen> createState() => _HeritageBackgroundsScreenState();
}

class _HeritageBackgroundsScreenState extends State<HeritageBackgroundsScreen> {
  final _service = HeritageDataService();
  late final Future<HeritageCountry?> _country = _service.resolveOrgCountry(widget.orgId);

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Backgrounds'),
      body: FutureBuilder<HeritageCountry?>(
        future: _country,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final c = snap.data;
          if (c == null) {
            return const CanopyEmptyState(
              icon: Icons.public_off,
              title: 'Set your country first',
              line: 'Add your country in organisation details, or add an entry — its locality sets the country.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
            children: [
              CountryCompletenessCard(orgId: widget.orgId),
              const CanopySectionHeader(title: 'Country images', padding: EdgeInsets.only(top: CanopySpace.section)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 2,
                  child: _Slot(nodeId: c.id, field: 'bg_image_url', aspect: 2, label: 'Banner — country page', fallbackIcon: Icons.landscape_outlined),
                ),
                const SizedBox(width: CanopySpace.s12),
                Expanded(child: _Slot(nodeId: c.id, field: 'card_image_url', aspect: 1, label: 'Card — Heritage tab', fallbackIcon: Icons.crop_square)),
              ]),
              const SizedBox(height: CanopySpace.s12),
              CanopyButton.secondary(
                label: 'Preview ${c.name} as a member',
                expand: true,
                onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => CountryScreen(country: c))),
              ),
              const CanopySectionHeader(title: 'Category backgrounds', padding: EdgeInsets.only(top: CanopySpace.section)),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: CanopySpace.s12,
                crossAxisSpacing: CanopySpace.s8,
                childAspectRatio: .70,
                children: [
                  for (final t in HeritageContentTypes.ordered)
                    _Slot(
                      nodeId: HeritageDataService.categoryNodeId(c.id, t.key),
                      field: 'bg_image_url',
                      aspect: 1,
                      label: t.label,
                      fallbackIcon: t.icon,
                      fallback: t.category.fallback,
                    ),
                ],
              ),
              const CanopySectionHeader(title: 'Community backgrounds', padding: EdgeInsets.only(top: CanopySpace.section)),
              StreamBuilder<List<CommunitySummary>>(
                stream: _service.streamCommunitiesForCountry(c.id),
                builder: (context, cs) {
                  final list = cs.data ?? const <CommunitySummary>[];
                  if (!cs.hasData) return const CanopyListSkeleton(rows: 2);
                  if (list.isEmpty) {
                    return Text('Communities appear here once they have public entries.', style: CanopyType.body.copyWith(color: p.inkMuted));
                  }
                  return Column(children: [
                    for (final com in list) ...[
                      _CommunityRow(nodeId: HeritageDataService.communityNodeId(com.id), name: com.name, countryName: c.name),
                      const SizedBox(height: CanopySpace.s8),
                    ],
                  ]);
                },
              ),
              const CanopySectionHeader(title: 'Entry covers', padding: EdgeInsets.only(top: CanopySpace.section)),
              Text(
                  'The photo on each entry\'s card and page. Entries without one show their category photo.',
                  style: CanopyType.caption.copyWith(color: p.inkMuted)),
              const SizedBox(height: CanopySpace.s12),
              _EntryCovers(orgId: widget.orgId),
            ],
          );
        },
      ),
    );
  }
}

/// Every entry this organisation recorded, with its cover: tap to add or
/// change it. Writes cultural_entries/{id}.cover_image_url.
class _EntryCovers extends StatelessWidget {
  final String orgId;
  const _EntryCovers({required this.orgId});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('cultural_entries').where('org_id', isEqualTo: orgId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text("Couldn't load your entries.", style: CanopyType.body.copyWith(color: p.danger));
        }
        if (!snap.hasData) return const CanopyListSkeleton(rows: 3);
        final docs = [...snap.data!.docs]
          ..sort((a, b) => '${a.data()['title'] ?? ''}'.toLowerCase().compareTo('${b.data()['title'] ?? ''}'.toLowerCase()));
        if (docs.isEmpty) {
          return Text('Entries you record appear here.', style: CanopyType.body.copyWith(color: p.inkMuted));
        }
        return Column(children: [
          for (final d in docs) ...[
            _EntryCoverRow(orgId: orgId, doc: d),
            const SizedBox(height: CanopySpace.s8),
          ],
        ]);
      },
    );
  }
}

class _EntryCoverRow extends StatefulWidget {
  final String orgId;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _EntryCoverRow({required this.orgId, required this.doc});

  @override
  State<_EntryCoverRow> createState() => _EntryCoverRowState();
}

class _EntryCoverRowState extends State<_EntryCoverRow> {
  double? progress;
  bool failed = false;
  File? lastFile;

  Future<void> _upload({File? retry}) async {
    var file = retry;
    if (file == null) {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
      if (x == null) return;
      file = File(x.path);
    }
    lastFile = file;
    setState(() {
      failed = false;
      progress = 0;
    });
    try {
      final path = 'cultural_media/${widget.orgId}/covers/${widget.doc.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final task = FirebaseStorage.instance.ref(path).putFile(file);
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0 && mounted) setState(() => progress = s.bytesTransferred / s.totalBytes);
      });
      final snap = await task;
      await sub.cancel();
      final url = await snap.ref.getDownloadURL();
      await widget.doc.reference.update({'cover_image_url': url, 'updated_at': FieldValue.serverTimestamp()});
      if (mounted) setState(() => progress = null);
    } catch (_) {
      if (mounted) {
        setState(() {
          progress = null;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final m = widget.doc.data();
    final url = (m['cover_image_url'] ?? m['image_url']) as String?;
    final set = (url ?? '').isNotEmpty;
    final type = HeritageContentTypes.byKey('${m['content_type'] ?? ''}');
    final title = '${m['title'] ?? ''}'.trim();
    final status = progress != null
        ? 'Uploading ${(progress! * 100).round()}%'
        : failed
            ? "Couldn't upload"
            : set
                ? 'Cover set'
                : 'No cover — shows the ${type?.label ?? 'category'} photo';
    return CanopyCard(
      padding: const EdgeInsets.all(CanopySpace.s12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(CanopyRadius.xs),
          child: SizedBox(
            width: 64,
            height: 48,
            child: set
                ? CanopyImage(url: url)
                : DecoratedBox(
                    decoration: BoxDecoration(gradient: type?.category.fallback),
                    child: Icon(type?.icon ?? Icons.image_outlined, color: const Color(0x99FFFFFF), size: 20),
                  ),
          ),
        ),
        const SizedBox(width: CanopySpace.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.isEmpty ? 'Untitled' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
            Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: failed ? p.danger : p.inkMuted)),
            if (progress != null) ...[const SizedBox(height: CanopySpace.s4), CanopyProgressBar(value: progress!, ink: true)],
          ]),
        ),
        if (progress == null)
          CanopyButton.quiet(
            label: failed ? 'Retry' : (set ? 'Change' : 'Add'),
            size: CanopyButtonSize.compact,
            onPressed: () => _upload(retry: failed ? lastFile : null),
          ),
      ]),
    );
  }
}

/// Upload an image to heritage_hierarchy/{nodeId}.{field} with progress and
/// a retry on failure. Returns the watched URL via [streamNodeImages].
mixin _Uploader<T extends StatefulWidget> on State<T> {
  double? progress; // null idle
  bool failed = false;
  File? lastFile;

  Future<void> upload(String nodeId, String field, {File? retry}) async {
    File? file = retry;
    if (file == null) {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      file = File(x.path);
    }
    lastFile = file;
    setState(() {
      failed = false;
      progress = 0;
    });
    try {
      final task = FirebaseStorage.instance.ref('heritage_backgrounds/$nodeId/${DateTime.now().millisecondsSinceEpoch}.jpg').putFile(file);
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0 && mounted) setState(() => progress = s.bytesTransferred / s.totalBytes);
      });
      final snap = await task;
      await sub.cancel();
      final url = await snap.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection(HeritageDataService.hierarchyCollection).doc(nodeId).set({field: url}, SetOptions(merge: true));
      if (mounted) setState(() => progress = null);
    } catch (_) {
      if (mounted) {
        setState(() {
          progress = null;
          failed = true;
        });
      }
    }
  }
}

class _Slot extends StatefulWidget {
  final String nodeId;
  final String field;
  final double aspect;
  final String label;
  final IconData fallbackIcon;
  final Gradient? fallback;
  const _Slot({required this.nodeId, required this.field, required this.aspect, required this.label, required this.fallbackIcon, this.fallback});

  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> with _Uploader {
  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<({String? bg, String? card})>(
      stream: HeritageDataService().streamNodeImages(widget.nodeId, bundled: false),
      builder: (context, snap) {
        final url = widget.field == 'card_image_url' ? snap.data?.card : snap.data?.bg;
        final set = (url ?? '').isNotEmpty;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            button: true,
            label: '${widget.label}. ${set ? 'Set — tap to change' : 'Empty — tap to add'}',
            child: GestureDetector(
              onTap: progress != null ? null : () => failed && lastFile != null ? upload(widget.nodeId, widget.field, retry: lastFile) : upload(widget.nodeId, widget.field),
              child: AspectRatio(
                aspectRatio: widget.aspect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CanopyRadius.sm),
                  child: Stack(fit: StackFit.expand, children: [
                    if (set)
                      CanopyImage(url: url)
                    else if (widget.fallback != null)
                      DecoratedBox(
                        decoration: BoxDecoration(gradient: widget.fallback),
                        child: Icon(widget.fallbackIcon, color: const Color(0x99FFFFFF)),
                      )
                    else
                      DashedBorder(
                        color: p.outlineStrong,
                        radius: CanopyRadius.sm,
                        child: Center(child: Icon(Icons.add_photo_alternate_outlined, color: p.inkMuted)),
                      ),
                    if (progress != null)
                      Container(
                        color: const Color(0x99000000),
                        child: Center(child: Text('${(progress! * 100).round()}%', style: CanopyType.label.copyWith(color: const Color(0xFFFFFFFF)))),
                      ),
                    if (failed)
                      Container(
                        color: p.danger.withValues(alpha: .78),
                        child: Center(child: Text('Failed · Retry', style: CanopyType.label.copyWith(color: const Color(0xFFFFFFFF)))),
                      ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: CanopySpace.s4),
          Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: p.ink)),
          if (!set && progress == null && !failed) Text('Empty · add', style: CanopyType.caption.copyWith(color: p.inkMuted, fontSize: 11)),
        ]);
      },
    );
  }
}

class _CommunityRow extends StatefulWidget {
  final String nodeId;
  final String name;
  final String countryName;
  const _CommunityRow({required this.nodeId, required this.name, required this.countryName});

  @override
  State<_CommunityRow> createState() => _CommunityRowState();
}

class _CommunityRowState extends State<_CommunityRow> with _Uploader {
  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<({String? bg, String? card})>(
      stream: HeritageDataService().streamNodeImages(widget.nodeId, bundled: false),
      builder: (context, snap) {
        final url = snap.data?.bg;
        final set = (url ?? '').isNotEmpty;
        final status = progress != null
            ? 'Uploading ${(progress! * 100).round()}%'
            : failed
                ? "Couldn't upload"
                : set
                    ? 'Set'
                    : "Falls back to ${widget.countryName}'s background";
        return CanopyCard(
          padding: const EdgeInsets.all(CanopySpace.s12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.xs),
              child: SizedBox(
                width: 56,
                height: 40,
                child: set ? CanopyImage(url: url) : Container(color: p.surfaceMuted, child: Icon(Icons.groups_outlined, color: p.inkMuted, size: 20)),
              ),
            ),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.name, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                Text(status, style: CanopyType.caption.copyWith(color: failed ? p.danger : p.inkMuted)),
                if (progress != null) ...[const SizedBox(height: CanopySpace.s4), CanopyProgressBar(value: progress!, ink: true)],
              ]),
            ),
            if (progress == null)
              CanopyButton.quiet(
                label: failed ? 'Retry' : (set ? 'Change' : 'Add'),
                size: CanopyButtonSize.compact,
                onPressed: () => failed && lastFile != null ? upload(widget.nodeId, 'bg_image_url', retry: lastFile) : upload(widget.nodeId, 'bg_image_url'),
              ),
          ]),
        );
      },
    );
  }
}
