// lib/Culture/Heritage/Media/heritage_media_screen.dart
//
// Manage media for one entry (ARCHIVE_HANDOFF §3.3, T). Grid of the entry's
// photos: cover = 2.5 ink ring; uploading shows a scrim + %; failed shows a
// danger scrim + Retry; every photo needs a credit ("N images have no
// credit"). Tap a photo to set credit / caption, make it the cover, or
// remove it. Audio is honest: not built yet.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Models/cultural_media.dart';

class HeritageMediaScreen extends StatefulWidget {
  final String orgId;
  final String entryId;
  final String entryTitle;

  const HeritageMediaScreen({required this.orgId, required this.entryId, this.entryTitle = '', super.key});

  @override
  State<HeritageMediaScreen> createState() => _HeritageMediaScreenState();
}

class _Pending {
  final String id;
  final File file;
  double progress = 0;
  bool failed = false;
  _Pending(this.id, this.file);
}

class _HeritageMediaScreenState extends State<HeritageMediaScreen> {
  final _db = FirebaseFirestore.instance;
  final List<_Pending> _pending = [];

  Stream<List<CulturalMedia>> get _media =>
      _db.collection('cultural_media').where('entry_id', isEqualTo: widget.entryId).snapshots().map(
            (s) => s.docs.map(CulturalMedia.fromFirestore).where((m) => m.mediaType == 'image').toList()
              ..sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt)),
          );

  Future<void> _add() async {
    final xs = await ImagePicker().pickMultiImage(imageQuality: 90);
    for (final x in xs) {
      final p = _Pending(const Uuid().v4(), File(x.path));
      setState(() => _pending.add(p));
      _upload(p);
    }
  }

  Future<void> _upload(_Pending p) async {
    setState(() {
      p.failed = false;
      p.progress = 0;
    });
    try {
      final path = 'cultural_media/${widget.orgId}/${widget.entryId}/${p.id}.jpg';
      final task = FirebaseStorage.instance.ref(path).putFile(p.file);
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0 && mounted) setState(() => p.progress = s.bytesTransferred / s.totalBytes);
      });
      final snap = await task;
      await sub.cancel();
      final url = await snap.ref.getDownloadURL();
      final now = Timestamp.now();
      await _db.collection('cultural_media').add({
        'entry_id': widget.entryId,
        'org_id': widget.orgId,
        'uploaded_by_uid': FirebaseAuth.instance.currentUser?.uid,
        'media_type': 'image',
        'mime_type': 'image/jpeg',
        'media_role': 'documentation_image',
        'storage_url': url,
        'storage_path': path,
        'filename': p.file.path.split(RegExp(r'[\\/]')).last,
        'is_primary': false,
        'visibility': 'inherits_from_entry',
        'created_at': now,
      });
      await _db.collection('cultural_entries').doc(widget.entryId).update({'media_count': FieldValue.increment(1), 'updated_at': now});
      if (mounted) setState(() => _pending.remove(p));
    } catch (_) {
      if (mounted) setState(() => p.failed = true);
    }
  }

  Future<void> _edit(CulturalMedia m, List<CulturalMedia> all) async {
    final credit = TextEditingController(text: m.credit ?? '');
    final caption = TextEditingController(text: m.caption ?? '');
    final action = await showCanopySheet<String>(context, builder: (ctx) {
      return CanopySheetBody(
        title: m.isPrimary ? 'Cover photo' : 'Photo',
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(CanopyRadius.sm), child: AspectRatio(aspectRatio: 4 / 3, child: CanopyImage(url: m.fileUrl))),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(label: 'Credit', hint: 'Who took it', controller: credit),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(label: 'Caption (optional)', controller: caption),
        ],
        actions: [
          CanopyButton(label: 'Save', expand: true, onPressed: () => Navigator.pop(ctx, 'save')),
          if (!m.isPrimary) CanopyButton.secondary(label: 'Make cover', expand: true, onPressed: () => Navigator.pop(ctx, 'cover')),
          CanopyButton.quietDanger(label: 'Remove photo', expand: true, onPressed: () => Navigator.pop(ctx, 'remove')),
        ],
      );
    });
    final ref = _db.collection('cultural_media').doc(m.id);
    try {
      switch (action) {
        case 'save':
          await ref.update({'credit': credit.text.trim().isEmpty ? null : credit.text.trim(), 'caption': caption.text.trim().isEmpty ? null : caption.text.trim()});
        case 'cover':
          final batch = _db.batch();
          for (final o in all.where((o) => o.isPrimary)) {
            batch.update(_db.collection('cultural_media').doc(o.id), {'is_primary': false});
          }
          batch.update(ref, {'is_primary': true, 'credit': credit.text.trim().isEmpty ? m.credit : credit.text.trim()});
          batch.update(_db.collection('cultural_entries').doc(widget.entryId), {'cover_image_url': m.fileUrl, 'cover_image_media_id': m.id, 'updated_at': FieldValue.serverTimestamp()});
          await batch.commit();
        case 'remove':
          if (!mounted) return;
          final ok = await showCanopyConfirm(context, title: 'Remove this photo?', message: 'It is taken off the entry.', confirmLabel: 'Remove', danger: true);
          if (!ok) return;
          final batch = _db.batch();
          batch.delete(ref);
          batch.update(_db.collection('cultural_entries').doc(widget.entryId), {
            'media_count': FieldValue.increment(-1),
            if (m.isPrimary) 'cover_image_url': null,
            if (m.isPrimary) 'cover_image_media_id': null,
          });
          await batch.commit();
      }
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    } finally {
      credit.dispose();
      caption.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Media'),
      body: StreamBuilder<List<CulturalMedia>>(
        stream: _media,
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(title: "Couldn't load media");
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final media = snap.data!;
          final uncredited = media.where((m) => (m.credit ?? '').trim().isEmpty).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
            children: [
              if (widget.entryTitle.isNotEmpty) Text(widget.entryTitle, style: CanopyType.title.copyWith(color: p.ink)),
              if (uncredited > 0) ...[
                const SizedBox(height: CanopySpace.s12),
                CanopyCallout(kind: CalloutKind.warning, text: '$uncredited image${uncredited == 1 ? ' has' : 's have'} no credit. Tap to add who took it.'),
              ],
              const SizedBox(height: CanopySpace.s16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: CanopySpace.s8,
                crossAxisSpacing: CanopySpace.s8,
                children: [
                  for (final m in media)
                    GestureDetector(
                      onTap: () => _edit(m, media),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(CanopyRadius.sm),
                          border: m.isPrimary ? Border.all(color: p.ink, width: CanopyArchive.coverRing) : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(CanopyRadius.sm - (m.isPrimary ? 2 : 0)),
                          child: Stack(fit: StackFit.expand, children: [
                            CanopyImage(url: m.fileUrl),
                            if ((m.credit ?? '').trim().isEmpty)
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: p.warning, borderRadius: BorderRadius.circular(4)),
                                  child: Text('No credit', style: CanopyType.caption.copyWith(color: const Color(0xFF000000), fontSize: 10)),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  for (final pd in _pending)
                    GestureDetector(
                      onTap: pd.failed ? () => _upload(pd) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(CanopyRadius.sm),
                        child: Stack(fit: StackFit.expand, children: [
                          Image.file(pd.file, fit: BoxFit.cover),
                          Container(
                            color: pd.failed ? p.danger.withValues(alpha: .78) : const Color(0x99000000),
                            child: Center(
                              child: Text(pd.failed ? 'Failed · Retry' : '${(pd.progress * 100).round()}%',
                                  style: CanopyType.label.copyWith(color: const Color(0xFFFFFFFF))),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  Material(
                    color: p.surfaceMuted,
                    borderRadius: BorderRadius.circular(CanopyRadius.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(CanopyRadius.sm),
                      onTap: _add,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, color: p.inkMuted),
                        Text('Add photos', style: CanopyType.caption.copyWith(color: p.inkMuted)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CanopySpace.section),
              const CanopyComingSoon(
                boxed: true,
                icon: Icons.graphic_eq,
                label: 'Not built yet',
                title: 'Audio recordings',
                line: 'Adding songs and spoken stories is coming.',
              ),
            ],
          );
        },
      ),
    );
  }
}
