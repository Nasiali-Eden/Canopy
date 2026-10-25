// lib/Culture/Heritage/Create/edit_entry_screen.dart
//
// Edit a published entry (ARCHIVE_HANDOFF §3.3, T). Cover, type · locality
// label, title, description, visibility row (tap → selector → confirm, saved
// at once), Preview, and an explicit "Save changes" — a published entry
// never shows half-finished edits. The app bar shows when it was last saved.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Archive/heritage_archive_screen.dart' show changeEntryVisibility;

class HeritageEntryEditScreen extends StatefulWidget {
  final String entryId;
  const HeritageEntryEditScreen({super.key, required this.entryId});

  @override
  State<HeritageEntryEditScreen> createState() => _HeritageEntryEditScreenState();
}

class _HeritageEntryEditScreenState extends State<HeritageEntryEditScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _type = '';
  String? _community, _coverUrl;
  File? _newCover;
  DateTime? _savedAt;
  bool _loading = true, _failed = false, _saving = false, _showErrors = false;

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance.collection('cultural_entries').doc(widget.entryId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final d = (await _ref.get()).data() ?? {};
      _title.text = d['title'] as String? ?? '';
      _desc.text = d['description'] as String? ?? '';
      _type = d['content_type'] as String? ?? '';
      _community = ((d['locality'] as Map?)?['community_name']) as String?;
      _coverUrl = (d['cover_image_url'] ?? d['image_url']) as String?;
      _savedAt = (d['updated_at'] as Timestamp?)?.toDate();
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickCover() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f != null) setState(() => _newCover = File(f.path));
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (_title.text.trim().isEmpty || _desc.text.trim().length < 50) return;
    setState(() => _saving = true);
    try {
      var cover = _coverUrl;
      if (_newCover != null) {
        final ref = FirebaseStorage.instance.ref('cultural_entries/${widget.entryId}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_newCover!);
        cover = await ref.getDownloadURL();
      }
      await _ref.update({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        if (cover != null) 'cover_image_url': cover,
        'updated_at': FieldValue.serverTimestamp(),
        'last_activity_at': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      showCanopySnack(context, 'Changes saved.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Your changes are still here — try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final ago = _savedAt == null ? null : DateTime.now().difference(_savedAt!).inMinutes;
    final bar = canopyAppBar(context, title: 'Edit entry', actions: [
      if (ago != null)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: CanopySpace.gutter),
            child: Text(ago < 1 ? 'Saved just now' : (ago < 60 ? 'Saved $ago min ago' : 'Saved earlier'), style: CanopyType.caption.copyWith(color: p.inkMuted)),
          ),
        ),
    ]);
    if (_loading) return CanopyScaffold(appBar: bar, body: const Center(child: CircularProgressIndicator()));
    if (_failed) return CanopyScaffold(appBar: bar, body: CanopyErrorState(title: "Couldn't load this entry", onRetry: _load));
    return CanopyScaffold(
      appBar: bar,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.md),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Material(
                color: p.surfaceMuted,
                child: InkWell(
                  onTap: _pickCover,
                  child: Stack(fit: StackFit.expand, children: [
                    if (_newCover != null)
                      Image.file(_newCover!, fit: BoxFit.cover)
                    else
                      CategoryThumb(typeKey: _type, url: _coverUrl, size: 400),
                    Positioned(
                      right: CanopySpace.s8,
                      bottom: CanopySpace.s8,
                      child: CanopyIconButton(icon: Icons.edit_outlined, tooltip: 'Change cover', onImage: true, onPressed: _pickCover),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: CanopySpace.s12),
          ContentTypeLabel(_type, suffix: _community),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Name',
            controller: _title,
            error: _showErrors && _title.text.trim().isEmpty ? 'The entry needs a name.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Description',
            controller: _desc,
            minLines: 4,
            maxLines: 12,
            error: _showErrors && _desc.text.trim().length < 50 ? 'At least 50 characters.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.section),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _ref.snapshots(),
            builder: (context, snap) {
              final v = visibilityFrom(snap.data?.data()?['visibility'] as String?);
              return CanopyListGroup(children: [
                CanopyListRow(
                  icon: Icons.shield_outlined,
                  title: 'Visibility',
                  trailing: VisibilityLabel(v),
                  onTap: () => changeEntryVisibility(context, widget.entryId, v),
                ),
                CanopyListRow(
                  icon: Icons.visibility_outlined,
                  title: 'Preview as a member',
                  onTap: () => openEntryPreview(context, widget.entryId, published: true),
                ),
              ]);
            },
          ),
        ],
      ),
      sticky: StickyActionBar(children: [CanopyButton(label: 'Save changes', expand: true, loading: _saving, onPressed: _save)]),
    );
  }
}
