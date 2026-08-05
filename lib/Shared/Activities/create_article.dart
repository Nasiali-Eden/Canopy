import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../Services/Article/article_service.dart';
import '../theme/app_theme.dart';
import '../utils/rich_body.dart';

const _kBg = Color(0xFFF7F5F0);

/// Neutral grey for editor borders/dividers/tints — replaces the loud green.
const Color _kFieldAccent = Color(0xFF9AA0A6);

// ─────────────────────────────────────────────────────────────────────────────
// Article categories — must match the reader filters in
// articles_list_screen.dart / community_home.dart.
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  final String value;
  final String label;
  final IconData icon;
  const _Category(this.value, this.label, this.icon);
}

const _categories = <_Category>[
  _Category('news', 'News', Icons.newspaper_outlined),
  _Category('announcement', 'Announcement', Icons.campaign_outlined),
  _Category('education', 'Education', Icons.school_outlined),
  _Category('impact_story', 'Impact Story', Icons.favorite_outline),
  _Category('event_recap', 'Event Recap', Icons.event_available_outlined),
];

// ─────────────────────────────────────────────────────────────────────────────
// Content blocks — the building units of an article body.
// ─────────────────────────────────────────────────────────────────────────────

enum _BlockType { h1, h2, h3, paragraph }

extension _BlockTypeMeta on _BlockType {
  String get marker {
    switch (this) {
      case _BlockType.h1:
        return '# ';
      case _BlockType.h2:
        return '## ';
      case _BlockType.h3:
        return '### ';
      case _BlockType.paragraph:
        return '';
    }
  }

  String get shortLabel {
    switch (this) {
      case _BlockType.h1:
        return 'H1';
      case _BlockType.h2:
        return 'H2';
      case _BlockType.h3:
        return 'H3';
      case _BlockType.paragraph:
        return 'P';
    }
  }

  String get longLabel {
    switch (this) {
      case _BlockType.h1:
        return 'Heading 1';
      case _BlockType.h2:
        return 'Heading 2';
      case _BlockType.h3:
        return 'Heading 3';
      case _BlockType.paragraph:
        return 'Paragraph';
    }
  }

  String get hint {
    switch (this) {
      case _BlockType.h1:
        return 'Section title';
      case _BlockType.h2:
        return 'Sub-heading';
      case _BlockType.h3:
        return 'Minor heading';
      case _BlockType.paragraph:
        return 'Write a paragraph…';
    }
  }

  double get fontSize {
    switch (this) {
      case _BlockType.h1:
        return 22;
      case _BlockType.h2:
        return 19;
      case _BlockType.h3:
        return 16;
      case _BlockType.paragraph:
        return 15;
    }
  }

  FontWeight get fontWeight =>
      this == _BlockType.paragraph ? FontWeight.w400 : FontWeight.w800;
}

class _Block {
  _BlockType type;
  final TextEditingController controller;
  final FocusNode focus;

  _Block(this.type, {String text = ''})
      : controller = TextEditingController(text: text),
        focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CreateArticleScreen — friendly, sectioned article composer (create / edit)
// ─────────────────────────────────────────────────────────────────────────────

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
  final _picker = ImagePicker();
  final _scrollCtrl = ScrollController();

  final _headingCtrl = TextEditingController();

  String? _orgId;
  String? _category;
  final List<_Block> _blocks = [];

  XFile? _coverFile;
  String? _coverUrl;

  bool _saving = false;
  bool _resolvingOrg = false;

  bool get _isEdit => widget.existing != null;
  String? get _articleId => widget.existing?['id'] as String?;

  @override
  void initState() {
    super.initState();
    _orgId = widget.orgId;
    if (_orgId == null) _resolveOrgId();

    final e = widget.existing;
    if (e != null) {
      _headingCtrl.text = (e['heading'] ?? e['title'] ?? '') as String;
      _category = (e['category'] ?? e['topic']) as String?;
      _coverUrl = (e['coverPhotoUrl'] ?? e['coverImageUrl']) as String?;
      _hydrateBlocks(richBodyToMarkdown(e['body']));
    }
    if (_blocks.isEmpty) {
      _blocks.add(_Block(_BlockType.paragraph));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _headingCtrl.dispose();
    for (final b in _blocks) b.dispose();
    super.dispose();
  }

  Future<void> _resolveOrgId() async {
    setState(() => _resolvingOrg = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(uid)
            .get();
        _orgId = (doc.data() ?? {})['orgId'] as String?;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _resolvingOrg = false);
    }
  }

  // Parse a stored body string back into editable blocks.
  void _hydrateBlocks(String body) {
    final lines = body.split('\n');
    for (final raw in lines) {
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

  String _assembleBody() {
    final parts = <String>[];
    for (final b in _blocks) {
      final text = b.controller.text.trim();
      if (text.isEmpty) continue;
      parts.add('${b.type.marker}$text');
    }
    return parts.join('\n\n');
  }

  // ── Image picking ───────────────────────────────────────────────────────────

  Future<void> _pickCover() async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (!mounted || file == null) return;
    setState(() => _coverFile = file);
  }

  void _removeCover() => setState(() {
        _coverFile = null;
        _coverUrl = null;
      });

  // ── Block ops ───────────────────────────────────────────────────────────────

  void _addBlock(_BlockType type) {
    setState(() {
      final block = _Block(type);
      _blocks.add(block);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        block.focus.requestFocus();
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index).dispose();
      if (_blocks.isEmpty) _blocks.add(_Block(_BlockType.paragraph));
    });
  }

  void _moveBlock(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _blocks.length) return;
    setState(() {
      final b = _blocks.removeAt(index);
      _blocks.insert(target, b);
    });
  }

  void _cycleBlockType(int index) {
    setState(() {
      const order = _BlockType.values;
      final cur = _blocks[index].type;
      _blocks[index].type = order[(cur.index + 1) % order.length];
    });
  }

  // ── Validation + save ────────────────────────────────────────────────────────

  bool _validate() {
    if (_orgId == null) {
      _snack('No organisation linked to this account.');
      return false;
    }
    if (_headingCtrl.text.trim().isEmpty) {
      _snack('Give your article a headline.');
      return false;
    }
    if (_category == null) {
      _snack('Pick a category so readers can find it.');
      return false;
    }
    if (_assembleBody().trim().isEmpty) {
      _snack('Add some content before publishing.');
      return false;
    }
    return true;
  }

  Future<void> _confirmDelete() async {
    final id = _articleId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete article?'),
        content: const Text(
            'This permanently removes the article. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _service.deleteArticle(id);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _save({required bool publish}) async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final heading = _headingCtrl.text.trim();
      final body = _assembleBody();

      if (_isEdit) {
        await _service.updateArticle(
          articleId: _articleId!,
          heading: heading,
          category: _category!,
          body: body,
          coverPhoto: _coverFile,
          coverPhotoUrl: _coverFile == null ? _coverUrl : null,
          orgId: _orgId,
          publish: publish,
        );
      } else {
        await _service.createArticle(
          heading: heading,
          category: _category!,
          body: body,
          coverPhoto: _coverFile,
          orgId: _orgId,
          createdBy: uid,
          publish: publish,
        );
      }

      if (!mounted) return;
      _snack(publish
          ? (_isEdit ? 'Article updated.' : 'Article published.')
          : 'Draft saved.');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.darkGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        foregroundColor: AppTheme.darkGreen,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kFieldAccent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 15, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _isEdit ? 'Edit Article' : 'Write Article',
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
              fontSize: 18),
        ),
        actions: [
          if (_isEdit && !_saving)
            IconButton(
              tooltip: 'Delete article',
              onPressed: _confirmDelete,
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400, size: 22),
            ),
          if (!_saving)
            TextButton(
              onPressed: () => _save(publish: false),
              child: Text(
                'Save draft',
                style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _resolvingOrg
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _coverCard(),
                  const SizedBox(height: 16),
                  _sectionCard(
                    icon: Icons.title_rounded,
                    title: 'Headline & category',
                    subtitle: 'The first thing readers see',
                    child: _headlineSection(),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    icon: Icons.notes_rounded,
                    title: 'Story',
                    subtitle: 'Build it block by block',
                    child: _storySection(),
                  ),
                  const SizedBox(height: 24),
                  _publishButton(),
                ],
              ),
            ),
    );
  }

  // ── Cover ────────────────────────────────────────────────────────────────────

  Widget _coverCard() {
    final hasNew = _coverFile != null;
    final hasImage = hasNew || (_coverUrl != null && _coverUrl!.isNotEmpty);

    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasImage
                ? AppTheme.primary.withOpacity(0.35)
                : _kFieldAccent.withOpacity(0.4),
            width: hasImage ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: hasNew
                        ? Image.file(File(_coverFile!.path), fit: BoxFit.cover)
                        : Image.network(
                            _coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverEmpty(),
                          ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        _coverChip(
                            icon: Icons.edit_outlined, onTap: _pickCover),
                        const SizedBox(width: 8),
                        _coverChip(
                            icon: Icons.close_rounded, onTap: _removeCover),
                      ],
                    ),
                  ),
                ],
              )
            : _coverEmpty(),
      ),
    );
  }

  Widget _coverEmpty() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              color: AppTheme.primary, size: 26),
        ),
        const SizedBox(height: 10),
        Text(
          'Add a cover photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Optional, but it makes a great first impression',
          style: TextStyle(
              fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.4)),
        ),
      ],
    );
  }

  Widget _coverChip({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  // ── Headline + category ──────────────────────────────────────────────────────

  Widget _headlineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _headingCtrl,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGreen,
            height: 1.25,
          ),
          decoration: InputDecoration(
            hintText: 'Your headline…',
            hintStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen.withOpacity(0.25),
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: _kFieldAccent.withOpacity(0.25)),
        const SizedBox(height: 14),
        Text(
          'CATEGORY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppTheme.darkGreen.withOpacity(0.45),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final active = _category == c.value;
            return GestureDetector(
              onTap: () => setState(() => _category = c.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      active ? AppTheme.primary.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppTheme.primary : Colors.grey.shade200,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon,
                        size: 14,
                        color: active
                            ? AppTheme.primary
                            : AppTheme.darkGreen.withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? AppTheme.primary : AppTheme.darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Story / blocks ───────────────────────────────────────────────────────────

  Widget _storySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _blocks.length; i++)
          _BlockEditor(
            key: ValueKey(_blocks[i]),
            block: _blocks[i],
            index: i,
            total: _blocks.length,
            onCycleType: () => _cycleBlockType(i),
            onRemove: () => _removeBlock(i),
            onMoveUp: () => _moveBlock(i, -1),
            onMoveDown: () => _moveBlock(i, 1),
          ),
        const SizedBox(height: 6),
        _addBlockBar(),
      ],
    );
  }

  Widget _addBlockBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: _kFieldAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Add',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen.withOpacity(0.55),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                _addChip(_BlockType.h1),
                _addChip(_BlockType.h2),
                _addChip(_BlockType.h3),
                _addChip(_BlockType.paragraph),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addChip(_BlockType type) {
    final isP = type == _BlockType.paragraph;
    return GestureDetector(
      onTap: () => _addBlock(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isP ? Icons.subject_rounded : Icons.title_rounded,
                size: 14, color: AppTheme.primary),
            const SizedBox(width: 5),
            Text(
              isP ? 'Paragraph' : type.shortLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Publish ──────────────────────────────────────────────────────────────────

  Widget _publishButton() {
    return FilledButton(
      onPressed: _saving ? null : () => _save(publish: true),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        minimumSize: const Size.fromHeight(54),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.publish_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  _isEdit ? 'Update & publish' : 'Publish article',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }

  // ── Section card shell ───────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kFieldAccent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGreen)),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.darkGreen.withOpacity(0.55))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlockEditor — a single editable content block with type + reorder controls
// ─────────────────────────────────────────────────────────────────────────────

class _BlockEditor extends StatelessWidget {
  final _Block block;
  final int index;
  final int total;
  final VoidCallback onCycleType;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _BlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.total,
    required this.onCycleType,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final type = block.type;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kFieldAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onCycleType,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: type == _BlockType.paragraph
                          ? AppTheme.darkGreen.withOpacity(0.08)
                          : AppTheme.tertiary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          type.longLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: type == _BlockType.paragraph
                                ? AppTheme.darkGreen.withOpacity(0.6)
                                : AppTheme.darkGreen,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.swap_horiz_rounded,
                            size: 13,
                            color: AppTheme.darkGreen.withOpacity(0.45)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _iconBtn(Icons.keyboard_arrow_up_rounded,
                    enabled: index > 0, onTap: onMoveUp),
                _iconBtn(Icons.keyboard_arrow_down_rounded,
                    enabled: index < total - 1, onTap: onMoveDown),
                _iconBtn(Icons.delete_outline_rounded,
                    enabled: true,
                    onTap: onRemove,
                    color: Colors.red.shade300),
              ],
            ),
          ),
          // Text field
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: TextField(
              controller: block.controller,
              focusNode: block.focus,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: type.fontSize,
                fontWeight: type.fontWeight,
                color: AppTheme.darkGreen,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: type.hint,
                hintStyle: TextStyle(
                  fontSize: type.fontSize,
                  fontWeight: type.fontWeight,
                  color: AppTheme.darkGreen.withOpacity(0.3),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon,
      {required bool enabled, required VoidCallback onTap, Color? color}) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 19,
        color: enabled
            ? (color ?? AppTheme.darkGreen.withOpacity(0.5))
            : AppTheme.darkGreen.withOpacity(0.18),
      ),
    );
  }
}
