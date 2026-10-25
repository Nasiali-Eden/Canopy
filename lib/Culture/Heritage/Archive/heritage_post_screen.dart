// lib/Culture/Heritage/Archive/heritage_post_screen.dart
//
// One screen per post: everything about a single entry in one place, grouped
// by post rather than by category. Cover and headline → overview (title,
// description, community, visibility) → every content field, each editable →
// media → discussion → preview as a member. Reads cultural_entries/{id} live,
// so an edit shows immediately. Writes only fields an org member may update.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:image_picker/image_picker.dart';

import '../../../Shared/Inputs/pin_picker_screen.dart';
import '../../../theme/canopy_components.dart';
import '../../archive_ui.dart';
import '../Create/locality_selector_sheet.dart';
import '../Feedback/heritage_feedback_screen.dart';
import '../Media/heritage_media_screen.dart';
import '../Services/heritage_bundled_images.dart';
import '../Services/heritage_content_types.dart';
import 'heritage_archive_screen.dart' show changeEntryVisibility;

class HeritagePostScreen extends StatefulWidget {
  final String entryId;
  final String orgId;
  const HeritagePostScreen({super.key, required this.entryId, required this.orgId});

  @override
  State<HeritagePostScreen> createState() => _HeritagePostScreenState();
}

class _HeritagePostScreenState extends State<HeritagePostScreen> {
  late final DocumentReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('cultural_entries').doc(widget.entryId);
  double? _coverProgress;
  bool _coverFailed = false;

  // Long-form fields first, in the reading order the public page uses.
  static const _order = <String>[
    'body', 'body_english', 'body_swahili', 'lyrics', 'lyrics_english', 'lyrics_swahili',
    'bio', 'cultural_significance', 'moral_or_meaning', 'preparation_notes',
    'technique_steps', 'construction_notes', 'rhythm_notes', 'harvesting_knowledge',
    'pattern_meaning', 'what_is_being_lost', 'what_has_changed',
  ];

  Future<void> _save(Map<String, dynamic> data, {String ok = 'Saved.'}) async {
    try {
      await _ref.update({...data, 'updated_at': FieldValue.serverTimestamp(), 'last_activity_at': FieldValue.serverTimestamp()});
      if (mounted) showCanopySnack(context, ok);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    }
  }

  /// Bottom sheet with a text box; returns the new text or null.
  Future<String?> _editText(String label, String current, {bool multiline = true, String? helper}) {
    final ctrl = TextEditingController(text: current);
    return showCanopySheet<String>(context, tall: true, builder: (ctx) {
      return CanopySheetBody(title: label, children: [
        CanopyTextField(
          label: label,
          controller: ctrl,
          autofocus: true,
          minLines: multiline ? 6 : 1,
          maxLines: multiline ? 16 : 2,
          helper: helper,
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyButton(label: 'Save', expand: true, onPressed: () => Navigator.pop(ctx, ctrl.text.trim())),
      ]);
    }).whenComplete(ctrl.dispose);
  }

  Future<void> _changeCover() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      _coverFailed = false;
      _coverProgress = 0;
    });
    try {
      final path = 'cultural_media/${widget.orgId}/covers/${widget.entryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final task = FirebaseStorage.instance.ref(path).putFile(File(x.path));
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0 && mounted) setState(() => _coverProgress = s.bytesTransferred / s.totalBytes);
      });
      final snap = await task;
      await sub.cancel();
      final url = await snap.ref.getDownloadURL();
      await _ref.update({'cover_image_url': url, 'updated_at': FieldValue.serverTimestamp()});
      if (mounted) setState(() => _coverProgress = null);
    } catch (_) {
      if (mounted) {
        setState(() {
          _coverProgress = null;
          _coverFailed = true;
        });
      }
    }
  }

  /// Pin this entry on the culture map: move the map under the pin, or use
  /// where you are standing.
  Future<void> _pinHere({GeoPoint? current}) async {
    final at = await pickPin(context,
        initial: current == null ? null : LatLng(current.latitude, current.longitude), title: 'Where is this?');
    if (at == null) return;
    await _save({'map_point': GeoPoint(at.latitude, at.longitude)}, ok: 'Pinned on the culture map.');
  }

  Future<void> _editLocality() async {
    final r = await showCanopySheet<CommunitySelection>(context, tall: true, builder: (_) => const LocalitySelectorSheet());
    if (r == null) return;
    await _save({
      'locality.community_id': r.isUnknown ? null : r.id,
      'locality.community_name': r.isUnknown ? null : r.name,
      'locality.community_unknown': r.isUnknown,
    }, ok: 'Community updated.');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyScaffold(
              appBar: canopyAppBar(context, title: 'Post'),
              body: const CanopyErrorState(title: "Couldn't load this post"));
        }
        if (!snap.hasData) {
          return CanopyScaffold(
              appBar: canopyAppBar(context, title: 'Post'),
              body: const Center(child: CircularProgressIndicator()));
        }
        final d = snap.data!.data();
        if (d == null) {
          return CanopyScaffold(
              appBar: canopyAppBar(context, title: 'Post'),
              body: const CanopyEmptyState(icon: Icons.inventory_2_outlined, title: 'This post no longer exists'));
        }
        return _body(context, p, d);
      },
    );
  }

  Widget _body(BuildContext context, CanopyPalette p, Map<String, dynamic> d) {
    final type = HeritageContentTypes.byKey('${d['content_type'] ?? ''}');
    final title = '${d['title'] ?? ''}'.trim();
    final desc = '${d['description'] ?? ''}'.trim();
    final visibility = '${d['visibility'] ?? 'draft'}';
    final isDraft = visibility == 'draft';
    final cover = '${d['cover_image_url'] ?? d['image_url'] ?? ''}';
    final loc = (d['locality'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final community = '${loc['community_name'] ?? ''}'.trim();
    final td = (d['type_data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    // Content fields: long-form in reading order, then the rest alphabetically.
    final keys = <String>[
      ..._order.where(td.containsKey),
      ...(td.keys.where((k) => !_order.contains(k)).toList()..sort()),
    ];

    Widget row({required String label, required String value, VoidCallback? onTap, bool empty = false}) => CanopyListRow(
          title: label,
          subtitle: value,
          onTap: onTap,
        );

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: title.isEmpty ? 'Post' : title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          // ── Cover + headline ───────────────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.md),
              child: Stack(fit: StackFit.expand, children: [
                if (cover.isNotEmpty)
                  CanopyImage(url: cover)
                else if (HeritageBundledImages.forContentType('${d['content_type'] ?? ''}') != null)
                  Image.asset(HeritageBundledImages.assetPath(HeritageBundledImages.forContentType('${d['content_type'] ?? ''}')!), fit: BoxFit.cover)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: type?.category.fallback),
                    child: Icon(type?.icon ?? Icons.image_outlined, color: const Color(0x99FFFFFF), size: 36),
                  ),
                if (_coverProgress != null)
                  Container(color: const Color(0x99000000), child: Center(child: Text('${(_coverProgress! * 100).round()}%', style: CanopyType.label.copyWith(color: const Color(0xFFFFFFFF))))),
                Positioned(
                  right: CanopySpace.s8,
                  bottom: CanopySpace.s8,
                  child: CanopyButton.secondary(
                    label: cover.isEmpty ? 'Add cover' : 'Change cover',
                    size: CanopyButtonSize.compact,
                    onPressed: _coverProgress != null ? null : _changeCover,
                  ),
                ),
              ]),
            ),
          ),
          if (cover.isEmpty && _coverProgress == null && !_coverFailed)
            Padding(
              padding: const EdgeInsets.only(top: CanopySpace.s4),
              child: Text('No cover yet. This is the ${type?.label ?? 'category'} photo.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ),
          if (_coverFailed)
            Padding(
              padding: const EdgeInsets.only(top: CanopySpace.s4),
              child: Text("Couldn't upload the cover. Try again.", style: CanopyType.caption.copyWith(color: p.danger)),
            ),
          const SizedBox(height: CanopySpace.s12),
          Row(children: [
            ContentTypeLabel('${d['content_type'] ?? ''}'),
            const SizedBox(width: CanopySpace.s8),
            VisibilityLabel(visibilityFrom(visibility)),
          ]),

          if (d['map_point'] is! GeoPoint && !isDraft) ...[
            const SizedBox(height: CanopySpace.s12),
            CanopyCallout(
              kind: CalloutKind.warning,
              title: 'Add a location to this entry',
              text: 'Every entry sits on the culture map. Pin where this is so people can find it.',
              action: CanopyButton.secondary(label: 'Add a location', size: CanopyButtonSize.compact, onPressed: () => _pinHere()),
            ),
          ],
          // ── Overview ───────────────────────────────────────────────────
          const CanopySectionHeader(title: 'Overview', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            row(
              label: 'Title',
              value: title.isEmpty ? 'Add a title' : title,
              onTap: () async {
                final v = await _editText('Title', title, multiline: false);
                if (v != null && v.isNotEmpty) await _save({'title': v});
              },
            ),
            row(
              label: 'Description',
              value: desc.isEmpty ? 'Add a short description' : desc,
              onTap: () async {
                final v = await _editText('Description', desc, helper: 'One or two sentences shown on cards and under the title.');
                if (v != null) await _save({'description': v});
              },
            ),
            row(
              label: 'Community',
              value: community.isEmpty ? 'Not set' : community,
              onTap: _editLocality,
            ),
            row(
              label: 'Location on the culture map',
              value: d['map_point'] is GeoPoint ? 'Pinned · tap to move' : 'Not pinned yet. Tap to add a location.',
              onTap: () => _pinHere(current: d['map_point'] as GeoPoint?),
            ),
            if (!isDraft)
              row(
                label: 'Who can see it',
                value: visibilityLabelText(visibility),
                onTap: () => changeEntryVisibility(context, widget.entryId, visibilityFrom(visibility)),
              ),
          ]),

          // ── Content: every field, each editable ────────────────────────
          const CanopySectionHeader(title: 'Content', padding: EdgeInsets.only(top: CanopySpace.section)),
          if (keys.isEmpty)
            Text('No content fields yet.', style: CanopyType.body.copyWith(color: p.inkMuted))
          else
            CanopyListGroup(children: [
              for (final k in keys) _fieldRow(context, p, k, td[k]),
            ]),

          // ── Media ──────────────────────────────────────────────────────
          const CanopySectionHeader(title: 'Photos and recordings', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.photo_library_outlined,
              title: 'Manage media',
              subtitle: 'Photos, audio and video attached to this post',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HeritageMediaScreen(orgId: widget.orgId, entryId: widget.entryId, entryTitle: title))),
            ),
          ]),

          // ── Discussion ─────────────────────────────────────────────────
          const CanopySectionHeader(title: 'Discussion', padding: EdgeInsets.only(top: CanopySpace.section)),
          _Discussion(entryId: widget.entryId, orgId: widget.orgId),

          // ── Preview ────────────────────────────────────────────────────
          const SizedBox(height: CanopySpace.section),
          CanopyButton.secondary(
            label: 'Preview as a member',
            expand: true,
            onPressed: () => openEntryPreview(context, widget.entryId, published: !isDraft),
          ),
        ],
      ),
    );
  }

  String visibilityLabelText(String v) => switch (v) {
        'public' => 'Public',
        'community' => 'Community only',
        'restricted' => 'Restricted',
        'sealed' => 'Sealed',
        _ => v,
      };

  Widget _fieldRow(BuildContext context, CanopyPalette p, String key, dynamic value) {
    final label = heritageHumanizeKey(key);
    if (value is bool) {
      return CanopyListRow(
        title: label,
        trailing: Switch(value: value, onChanged: (v) => _save({'type_data.$key': v})),
      );
    }
    if (value is List) {
      final items = value.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      return CanopyListRow(
        title: label,
        subtitle: items.isEmpty ? 'Empty' : items.join(', '),
        onTap: () async {
          final v = await _editText(label, items.join(', '), multiline: false, helper: 'Separate items with commas.');
          if (v != null) {
            await _save({'type_data.$key': v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()});
          }
        },
      );
    }
    final text = '${value ?? ''}'.trim();
    return CanopyListRow(
      title: label,
      subtitle: text.isEmpty ? 'Empty' : text,
      onTap: () async {
        final v = await _editText(label, text, multiline: text.length > 60 || _order.contains(key));
        if (v != null) await _save({'type_data.$key': v});
      },
    );
  }
}

String heritageHumanizeKey(String key) {
  final s = key.replaceAll('_', ' ').trim();
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Comments on this post (questions, additions, disputes) with status, and a
/// way into the feedback inbox to reply.
class _Discussion extends StatelessWidget {
  final String entryId;
  final String orgId;
  const _Discussion({required this.entryId, required this.orgId});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('cultural_comments').where('entry_id', isEqualTo: entryId).snapshots(),
      builder: (context, snap) {
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final x = (a.data()['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
            final y = (b.data()['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
            return y.compareTo(x);
          });
        if (docs.isEmpty) {
          return Text('No comments on this post yet.', style: CanopyType.body.copyWith(color: p.inkMuted));
        }
        return Column(children: [
          CanopyListGroup(children: [
            for (final c in docs.take(4))
              CanopyListRow(
                title: '${c.data()['commenter_name'] ?? 'A member'}${c.data()['comment_action'] == 'dispute' ? ' · Dispute' : ''}',
                subtitle: '${c.data()['comment_body'] ?? ''}',
                chevron: false,
              ),
          ]),
          const SizedBox(height: CanopySpace.s8),
          CanopyButton.quiet(
            label: 'Reply in feedback (${docs.length})',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeritageFeedbackScreen(orgId: orgId))),
          ),
        ]);
      },
    );
  }
}
