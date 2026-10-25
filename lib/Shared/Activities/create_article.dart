// lib/Shared/Activities/create_article.dart
//
// Article editor (ORG_HANDOFF §3.3, F). Cover (16:9, designed empty slot) →
// category (filter chips; 'special' only for the Super Admin org) →
// headline (artTitle) → collaborators (credited orgs) → block editor
// (P / H1 / H2 / H3 blocks; the focused block has an ink outline; move,
// retype, remove) → Preview (renders in the article view) → sticky
// "Publish" + quiet "Save draft". Edit mode adds a quiet-danger delete.
//
// Body is stored as the same markdown-ish lines ArticleService and the
// reader already use ('# ', '## ', '### ', paragraphs).

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../Community/Articles/article_view_screen.dart';
import '../../Services/Article/article_service.dart';
import '../../theme/canopy_components.dart';
import '../config/platform_config.dart';
import '../utils/rich_body.dart';

const _categories = <(String, String)>[
  ('news', 'News'),
  ('announcement', 'Announcement'),
  ('education', 'Education'),
  ('impact_story', 'Impact story'),
  ('event_recap', 'Event recap'),
];

/// Restricted to the Super Admin org (also enforced by firestore.rules).
const _special = ('special', 'Special');

enum _BlockType { h1, h2, h3, paragraph }

extension on _BlockType {
  String get marker => switch (this) {
        _BlockType.h1 => '# ',
        _BlockType.h2 => '## ',
        _BlockType.h3 => '### ',
        _BlockType.paragraph => '',
      };
  String get short => switch (this) {
        _BlockType.h1 => 'H1',
        _BlockType.h2 => 'H2',
        _BlockType.h3 => 'H3',
        _BlockType.paragraph => 'P',
      };
  String get hint => switch (this) {
        _BlockType.h1 => 'Section title',
        _BlockType.h2 => 'Sub-heading',
        _BlockType.h3 => 'Minor heading',
        _BlockType.paragraph => 'Write a paragraph…',
      };
  TextStyle get style => switch (this) {
        _BlockType.h1 => CanopyType.artH2.copyWith(fontSize: 24, height: 30 / 24),
        _BlockType.h2 => CanopyType.artH2,
        _BlockType.h3 => CanopyType.heading,
        _BlockType.paragraph => CanopyType.artBody,
      };
}

class _Block {
  _BlockType type;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  _Block(this.type, {String text = ''}) : controller = TextEditingController(text: text);
  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class CreateArticleScreen extends StatefulWidget {
  /// When null, resolved from the signed-in user's `orgId`.
  final String? orgId;

  /// Non-null → edit mode. Expects an article map (incl. `id`).
  final Map<String, dynamic>? existing;

  const CreateArticleScreen({super.key, this.orgId, this.existing});

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> {
  final _service = ArticleService();
  final _scroll = ScrollController();
  final _heading = TextEditingController();

  String? _orgId;
  String? _category;
  final List<_Block> _blocks = [];
  bool _superAdmin = false;
  XFile? _coverFile;
  String? _coverUrl;
  final List<Map<String, String?>> _collaborators = [];
  bool _saving = false;
  bool _publishing = false;
  bool _showErrors = false;

  bool get _isEdit => widget.existing != null;
  String? get _articleId => widget.existing?['id'] as String?;
  List<(String, String)> get _available => _superAdmin ? [..._categories, _special] : _categories;

  @override
  void initState() {
    super.initState();
    _orgId = widget.orgId;
    _orgId == null ? _resolveOrg() : _checkSuperAdmin(_orgId);
    final e = widget.existing;
    if (e != null) {
      _heading.text = (e['heading'] ?? e['title'] ?? '') as String;
      _category = (e['category'] ?? e['topic']) as String?;
      _coverUrl = (e['coverPhotoUrl'] ?? e['coverImageUrl']) as String?;
      _collaborators.addAll((e['collaboratorOrgs'] as List?)
              ?.whereType<Map>()
              .map((m) => <String, String?>{
                    'name': (m['name'] as String?)?.trim(),
                    'logoUrl': m['logoUrl'] as String?,
                  })
              .where((m) => (m['name'] ?? '').isNotEmpty) ??
          const <Map<String, String?>>[]);
      for (final raw in richBodyToMarkdown(e['body']).split('\n')) {
        final line = raw.trimRight();
        if (line.trim().isEmpty) continue;
        if (line.startsWith('### ')) {
          _blocks.add(_Block(_BlockType.h3, text: line.substring(4)));
        } else if (line.startsWith('## ')) {
          _blocks.add(_Block(_BlockType.h2, text: line.substring(3)));
        } else if (line.startsWith('# ')) {
          _blocks.add(_Block(_BlockType.h1, text: line.substring(2)));
        } else {
          _blocks.add(_Block(_BlockType.paragraph, text: line));
        }
      }
    }
    if (_blocks.isEmpty) _blocks.add(_Block(_BlockType.paragraph));
    for (final b in _blocks) {
      b.focus.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _heading.dispose();
    for (final b in _blocks) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _resolveOrg() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        if (mounted) setState(() => _orgId = doc.data()?['orgId'] as String?);
      }
    } catch (_) {}
    await _checkSuperAdmin(_orgId);
  }

  Future<void> _checkSuperAdmin(String? orgId) async {
    if (orgId == null) return;
    if (orgId == kSuperAdminOrgId) {
      if (mounted) setState(() => _superAdmin = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
      if (mounted) setState(() => _superAdmin = doc.data()?['isSuperAdmin'] == true);
    } catch (_) {}
  }

  String _body() => [
        for (final b in _blocks)
          if (b.controller.text.trim().isNotEmpty) '${b.type.marker}${b.controller.text.trim()}',
      ].join('\n\n');

  void _addBlock(_BlockType t) {
    final b = _Block(t);
    b.focus.addListener(() => setState(() {}));
    setState(() => _blocks.add(b));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      b.focus.requestFocus();
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: CanopyMotion.pagePush, curve: CanopyMotion.standard);
      }
    });
  }

  String? get _headingError => _heading.text.trim().isEmpty ? 'Give your article a headline.' : null;
  String? get _categoryError => _category == null ? 'Pick a category so readers can find it.' : null;
  String? get _bodyError => _body().trim().isEmpty ? 'Add some content.' : null;

  Future<void> _save({required bool publish}) async {
    setState(() => _showErrors = true);
    if (_orgId == null) {
      showCanopySnack(context, 'No organisation is linked to this account.', error: true);
      return;
    }
    if (_headingError != null || _categoryError != null || (publish && _bodyError != null)) {
      showCanopySnack(context, 'Fill in the highlighted parts first.', error: true);
      return;
    }
    setState(() => publish ? _publishing = true : _saving = true);
    try {
      if (_isEdit) {
        await _service.updateArticle(
          articleId: _articleId!,
          heading: _heading.text.trim(),
          category: _category!,
          body: _body(),
          coverPhoto: _coverFile,
          coverPhotoUrl: _coverFile == null ? _coverUrl : null,
          orgId: _orgId,
          publish: publish,
          collaboratorOrgs: _collaborators,
        );
      } else {
        await _service.createArticle(
          heading: _heading.text.trim(),
          category: _category!,
          body: _body(),
          coverPhoto: _coverFile,
          orgId: _orgId,
          createdBy: FirebaseAuth.instance.currentUser?.uid,
          publish: publish,
          collaboratorOrgs: _collaborators,
        );
      }
      if (!mounted) return;
      showCanopySnack(context, publish ? 'Published — members see it on Home.' : 'Draft saved.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Try again.", error: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _publishing = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showCanopyConfirm(context,
        title: 'Delete this article?',
        message: "It's removed for everyone. This can't be undone.",
        confirmLabel: 'Delete article',
        danger: true);
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await _service.deleteArticle(_articleId!);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showCanopySnack(context, "Couldn't delete. Try again.", error: true);
      }
    }
  }

  void _preview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleViewScreen(
          articleId: 'local-preview', // never exists → view renders articleData
          articleData: {
            'title': _heading.text.trim().isEmpty ? 'Untitled' : _heading.text.trim(),
            'body': _body(),
            'category': _category,
            'coverImageUrl': _coverUrl,
            'collaboratorOrgs': _collaborators,
            'readTimeMinutes': (_body().split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 60),
          },
        ),
      ),
    );
  }

  Future<void> _pickCollaborator() async {
    final picked = await showCanopySheet<Map<String, String?>>(
      context,
      tall: true,
      builder: (_) => _CollaboratorSheet(
          excludeOrgId: _orgId, taken: _collaborators.map((c) => c['name'] ?? '').toSet()),
    );
    if (picked != null && mounted) setState(() => _collaborators.add(picked));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: _isEdit ? 'Edit article' : 'New article', actions: [
        CanopyButton.quiet(label: 'Preview', size: CanopyButtonSize.compact, onPressed: _preview),
      ]),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
        children: [
          // Cover
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _coverFile == null && (_coverUrl ?? '').isEmpty
                ? DashedBorder(
                    color: p.outlineStrong,
                    radius: CanopyRadius.md,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: _pickCover,
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_photo_alternate_outlined, color: p.ink),
                            const SizedBox(height: CanopySpace.s4),
                            Text('Add a cover photo', style: CanopyType.label.copyWith(color: p.ink)),
                          ]),
                        ),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(CanopyRadius.md),
                    child: Stack(fit: StackFit.expand, children: [
                      _coverFile != null
                          ? Image.file(File(_coverFile!.path), fit: BoxFit.cover)
                          : CanopyImage(url: _coverUrl),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(children: [
                          CanopyIconButton(
                              icon: Icons.edit_outlined, tooltip: 'Change cover', onImage: true, onPressed: _pickCover),
                          CanopyIconButton(
                              icon: Icons.close,
                              tooltip: 'Remove cover',
                              onImage: true,
                              onPressed: () => setState(() {
                                    _coverFile = null;
                                    _coverUrl = null;
                                  })),
                        ]),
                      ),
                    ]),
                  ),
          ),
          const SizedBox(height: CanopySpace.s16),
          Text('Category', style: CanopyType.label.copyWith(color: p.ink)),
          Wrap(spacing: CanopySpace.s8, children: [
            for (final c in _available)
              CanopyFilterChip(
                  label: c.$2, selected: _category == c.$1, onTap: () => setState(() => _category = c.$1)),
          ]),
          if (_showErrors && _categoryError != null)
            Text(_categoryError!, style: CanopyType.caption.copyWith(color: p.danger)),
          const SizedBox(height: CanopySpace.s12),
          TextField(
            controller: _heading,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: CanopyType.artTitle.copyWith(color: p.ink),
            cursorColor: p.primary,
            decoration: InputDecoration(
              hintText: 'Headline',
              hintStyle: CanopyType.artTitle.copyWith(color: p.inkFaint),
              border: InputBorder.none,
              errorText: _showErrors ? _headingError : null,
            ),
          ),
          const SizedBox(height: CanopySpace.s8),
          Wrap(
            spacing: CanopySpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in _collaborators)
                CanopyRemovableChip(
                    label: 'With ${c['name']}', onRemove: () => setState(() => _collaborators.remove(c))),
              CanopyButton.quiet(
                  label: 'Credit a partner organisation',
                  size: CanopyButtonSize.compact,
                  onPressed: _pickCollaborator),
            ],
          ),
          Divider(height: CanopySpace.s32, color: p.outline),
          for (var i = 0; i < _blocks.length; i++) _blockEditor(i, p),
          if (_showErrors && _bodyError != null)
            Text(_bodyError!, style: CanopyType.caption.copyWith(color: p.danger)),
          const SizedBox(height: CanopySpace.s8),
          Row(children: [
            Text('Add', style: CanopyType.label.copyWith(color: p.inkMuted)),
            const SizedBox(width: CanopySpace.s8),
            for (final t in _BlockType.values) ...[
              CanopyFilterChip(label: t.short, selected: false, onTap: () => _addBlock(t)),
              const SizedBox(width: CanopySpace.s4 + 2),
            ],
          ]),
          if (_isEdit) ...[
            const SizedBox(height: CanopySpace.section),
            CanopyButton.quietDanger(label: 'Delete article', onPressed: _saving ? null : _delete),
          ],
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
            label: _isEdit ? 'Save and publish' : 'Publish',
            expand: true,
            loading: _publishing,
            onPressed: _saving ? null : () => _save(publish: true)),
        CanopyButton.quiet(
            label: 'Save draft',
            expand: true,
            loading: _saving,
            onPressed: _publishing ? null : () => _save(publish: false)),
      ]),
    );
  }

  Future<void> _pickCover() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (f != null && mounted) setState(() => _coverFile = f);
  }

  Widget _blockEditor(int i, CanopyPalette p) {
    final b = _blocks[i];
    final focused = b.focus.hasFocus;
    return Container(
      key: ObjectKey(b),
      margin: const EdgeInsets.only(bottom: CanopySpace.s8),
      padding: const EdgeInsets.fromLTRB(CanopySpace.s12, CanopySpace.s4, CanopySpace.s4, CanopySpace.s4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        border: Border.all(color: focused ? p.ink : Colors.transparent, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (focused)
          Row(children: [
            InkWell(
              onTap: () => setState(() =>
                  b.type = _BlockType.values[(b.type.index + 1) % _BlockType.values.length]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CanopySpace.s8),
                child: Text('${b.type.short} · change', style: CanopyType.label.copyWith(color: p.inkMuted)),
              ),
            ),
            const Spacer(),
            CanopyIconButton(
                icon: Icons.arrow_upward,
                tooltip: 'Move up',
                onPressed: i == 0
                    ? null
                    : () => setState(() => _blocks.insert(i - 1, _blocks.removeAt(i)))),
            CanopyIconButton(
                icon: Icons.arrow_downward,
                tooltip: 'Move down',
                onPressed: i == _blocks.length - 1
                    ? null
                    : () => setState(() => _blocks.insert(i + 1, _blocks.removeAt(i)))),
            CanopyIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Remove block',
                color: p.danger,
                onPressed: () => setState(() {
                      _blocks.removeAt(i).dispose();
                      if (_blocks.isEmpty) _addBlock(_BlockType.paragraph);
                    })),
          ]),
        TextField(
          controller: b.controller,
          focusNode: b.focus,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: b.type.style.copyWith(color: p.ink),
          cursorColor: p.primary,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: b.type.hint,
            hintStyle: b.type.style.copyWith(color: p.inkFaint),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ]),
    );
  }
}

class _CollaboratorSheet extends StatefulWidget {
  final String? excludeOrgId;
  final Set<String> taken;
  const _CollaboratorSheet({required this.excludeOrgId, required this.taken});

  @override
  State<_CollaboratorSheet> createState() => _CollaboratorSheetState();
}

class _CollaboratorSheetState extends State<_CollaboratorSheet> {
  late final Future<List<({String id, String name, String? logo})>> _orgs = () async {
    final snap = await FirebaseFirestore.instance.collection('organizations').get();
    final list = snap.docs
        .map((d) => (
              id: d.id,
              name: ((d.data()['org_name'] ?? d.data()['name']) as String?)?.trim() ?? '',
              logo: (d.data()['logoUrl'] ?? d.data()['profilePhoto']) as String?,
            ))
        .where((o) => o.name.isNotEmpty && o.id != widget.excludeOrgId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopySheetBody(
      title: 'Credit an organisation',
      caption: 'Partners you worked with on this story.',
      children: [
        CanopyTextField.search(
            hint: 'Search organisations', onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
        const SizedBox(height: CanopySpace.s12),
        FutureBuilder<List<({String id, String name, String? logo})>>(
          future: _orgs,
          builder: (context, snap) {
            if (snap.hasError) return const CanopyErrorState(inline: true, title: "Couldn't load organisations.");
            if (!snap.hasData) return const CanopyListSkeleton(rows: 4);
            final m = snap.data!.where((o) => _q.isEmpty || o.name.toLowerCase().contains(_q)).toList();
            if (m.isEmpty) {
              return CanopyEmptyState(
                  boxed: true,
                  icon: Icons.search_off_outlined,
                  title: snap.data!.isEmpty ? 'No other organisations yet' : 'No organisation matches');
            }
            return CanopyListGroup(children: [
              for (final o in m.take(50))
                CanopyListRow(
                  leading: CanopyAvatar(url: o.logo, name: o.name, size: 32, org: true),
                  title: o.name,
                  chevron: false,
                  trailing: widget.taken.contains(o.name) ? Icon(Icons.check, color: p.success) : null,
                  onTap: widget.taken.contains(o.name)
                      ? null
                      : () => Navigator.pop(context, <String, String?>{'name': o.name, 'logoUrl': o.logo}),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
