import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Article/article_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ARTICLE TOPIC
// ─────────────────────────────────────────────────────────────────────────────

enum ArticleTopic {
  community,
  health,
  environment,
  tech,
  education,
  policy;

  String get label {
    switch (this) {
      case ArticleTopic.community:
        return 'Community';
      case ArticleTopic.health:
        return 'Health';
      case ArticleTopic.environment:
        return 'Environment';
      case ArticleTopic.tech:
        return 'Tech';
      case ArticleTopic.education:
        return 'Education';
      case ArticleTopic.policy:
        return 'Policy';
    }
  }

  IconData get icon {
    switch (this) {
      case ArticleTopic.community:
        return Icons.people_outline;
      case ArticleTopic.health:
        return Icons.favorite_border;
      case ArticleTopic.environment:
        return Icons.park_outlined;
      case ArticleTopic.tech:
        return Icons.memory_outlined;
      case ArticleTopic.education:
        return Icons.school_outlined;
      case ArticleTopic.policy:
        return Icons.account_balance_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ArticleTopic.community:
        return AppTheme.primary;
      case ArticleTopic.health:
        return const Color(0xFFD45F5F);
      case ArticleTopic.environment:
        return AppTheme.accent;
      case ArticleTopic.tech:
        return const Color(0xFF5B7FD4);
      case ArticleTopic.education:
        return AppTheme.tertiary;
      case ArticleTopic.policy:
        return AppTheme.darkGreen;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOCK MODEL
// ─────────────────────────────────────────────────────────────────────────────

enum BlockType { h1, h2, h3, paragraph }

class ArticleBlock {
  final String id;
  BlockType type;
  final TextEditingController controller;
  final FocusNode focusNode;

  ArticleBlock({
    required this.id,
    required this.type,
    String initialText = '',
  })  : controller = TextEditingController(text: initialText),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CreateArticleScreen extends StatefulWidget {
  const CreateArticleScreen({super.key});

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen>
    with SingleTickerProviderStateMixin {
  // ── Meta ─────────────────────────────────────────────────────────────────
  XFile? _coverPhoto;
  ArticleTopic _topic = ArticleTopic.community;
  final _headingController = TextEditingController();
  final _headingFocus = FocusNode();

  // ── Body blocks ──────────────────────────────────────────────────────────
  final List<ArticleBlock> _blocks = [];

  // ── State ────────────────────────────────────────────────────────────────
  bool _saving = false;
  bool _showToolbar = false;
  int? _focusedBlockIndex;

  late AnimationController _coverAnimController;
  late Animation<double> _coverAnim;
  final _picker = ImagePicker();
  final _scrollController = ScrollController();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _coverAnimController =
        AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _coverAnim =
        CurvedAnimation(parent: _coverAnimController, curve: Curves.easeOut);

    // Start with one empty paragraph block
    _addBlock(BlockType.paragraph, focusAfter: false);

    _headingFocus.addListener(() {
      if (_headingFocus.hasFocus) {
        setState(() {
          _showToolbar = false;
          _focusedBlockIndex = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _coverAnimController.dispose();
    _headingController.dispose();
    _headingFocus.dispose();
    for (final b in _blocks) {
      b.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  // ── Cover photo ───────────────────────────────────────────────────────────
  Future<void> _pickCover() async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null || !mounted) return;
    setState(() => _coverPhoto = file);
    _coverAnimController.forward(from: 0);
  }

  void _removeCover() {
    setState(() => _coverPhoto = null);
    _coverAnimController.reverse();
  }

  // ── Block management ──────────────────────────────────────────────────────
  String _uid() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_blocks.length}';

  ArticleBlock _addBlock(BlockType type,
      {int? afterIndex, bool focusAfter = true}) {
    final block = ArticleBlock(id: _uid(), type: type);

    block.focusNode.addListener(() {
      if (block.focusNode.hasFocus) {
        final idx = _blocks.indexOf(block);
        setState(() {
          _showToolbar = true;
          _focusedBlockIndex = idx;
        });
      }
    });

    setState(() {
      if (afterIndex != null && afterIndex + 1 <= _blocks.length) {
        _blocks.insert(afterIndex + 1, block);
      } else {
        _blocks.add(block);
      }
    });

    if (focusAfter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        block.focusNode.requestFocus();
        _scrollToBottom();
      });
    }
    return block;
  }

  void _removeBlock(int index) {
    if (_blocks.length <= 1) return; // always keep at least one block
    final block = _blocks[index];
    setState(() => _blocks.removeAt(index));
    block.dispose();

    // Focus the block above
    if (_blocks.isNotEmpty) {
      final newIdx = (index - 1).clamp(0, _blocks.length - 1);
      _blocks[newIdx].focusNode.requestFocus();
      setState(() => _focusedBlockIndex = newIdx);
    }
  }

  void _changeBlockType(int index, BlockType newType) {
    setState(() => _blocks[index].type = newType);
    _blocks[index].focusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Publish ───────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    final heading = _headingController.text.trim();
    if (heading.isEmpty) {
      _showSnack('Please add a heading');
      _headingFocus.requestFocus();
      return;
    }
    if (_coverPhoto == null) {
      _showSnack('Please add a cover photo');
      return;
    }
    final hasContent = _blocks.any((b) => b.controller.text.trim().isNotEmpty);
    if (!hasContent) {
      _showSnack('Please add some content');
      return;
    }

    setState(() => _saving = true);
    try {
      final user = Provider.of<F_User?>(context, listen: false);
      final body = _blocks
          .map((b) => {
                'type': b.type.name,
                'text': b.controller.text.trim(),
              })
          .toList();

      final orgId = await (user?.orgId);
      await ArticleService().createArticle(
        heading: heading,
        topic: _topic.label,
        body: body,
        coverPhoto: _coverPhoto!,
        orgId: orgId,
        createdBy: user?.uid,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Cover photo ──────────────────────────────────────
                  _CoverPhotoSection(
                    file: _coverPhoto,
                    onPick: _pickCover,
                    onRemove: _removeCover,
                    fadeAnim: _coverAnim,
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Topic chips ────────────────────────────────
                        _TopicSelector(
                          selected: _topic,
                          onChanged: (t) => setState(() => _topic = t),
                        ),

                        const SizedBox(height: 20),

                        // ── Article heading ────────────────────────────
                        TextField(
                          controller: _headingController,
                          focusNode: _headingFocus,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen,
                            height: 1.3,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Article heading…',
                            hintStyle: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGreen.withOpacity(0.25),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Heading underline
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppTheme.primary,
                              AppTheme.tertiary.withOpacity(0.4),
                              Colors.transparent,
                            ]),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Body blocks ────────────────────────────────
                        ..._blocks.asMap().entries.map((entry) {
                          final i = entry.key;
                          final block = entry.value;
                          return _BlockEditor(
                            key: ValueKey(block.id),
                            block: block,
                            index: i,
                            isFocused: _focusedBlockIndex == i,
                            onDelete: () => _removeBlock(i),
                            onTypeChange: (t) => _changeBlockType(i, t),
                            onSubmitted: () =>
                                _addBlock(BlockType.paragraph, afterIndex: i),
                          );
                        }),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Floating block toolbar ─────────────────────────────────
          AnimatedSlide(
            offset: _showToolbar ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _showToolbar ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _BlockToolbar(
                focusedIndex: _focusedBlockIndex,
                blocks: _blocks,
                onAddParagraph: () => _addBlock(
                  BlockType.paragraph,
                  afterIndex: _focusedBlockIndex,
                ),
                onAddH1: () => _addBlock(
                  BlockType.h1,
                  afterIndex: _focusedBlockIndex,
                ),
                onAddH2: () => _addBlock(
                  BlockType.h2,
                  afterIndex: _focusedBlockIndex,
                ),
                onAddH3: () => _addBlock(
                  BlockType.h3,
                  afterIndex: _focusedBlockIndex,
                ),
                onChangeType: _focusedBlockIndex != null
                    ? (t) => _changeBlockType(_focusedBlockIndex!, t)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.close, size: 18, color: AppTheme.darkGreen),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.article_outlined,
                size: 15, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          const Text(
            'Write Article',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 17),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary))
              : GestureDetector(
                  onTap: _publish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.darkGreen, AppTheme.primary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: const Text(
                      'Publish',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child:
            Container(height: 1, color: AppTheme.lightGreen.withOpacity(0.18)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COVER PHOTO SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _CoverPhotoSection extends StatelessWidget {
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final Animation<double> fadeAnim;

  const _CoverPhotoSection({
    required this.file,
    required this.onPick,
    required this.onRemove,
    required this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 200,
          margin: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.07),
            border: Border(
              bottom: BorderSide(
                  color: AppTheme.lightGreen.withOpacity(0.2), width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    size: 32, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add cover photo',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to choose from gallery',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.45)),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: fadeAnim,
      child: Stack(
        children: [
          // Cover image
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Image.file(
              File(file!.path),
              fit: BoxFit.cover,
            ),
          ),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ),

          // Cover label
          Positioned(
            bottom: 10,
            left: 14,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Cover Photo',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),

          // Change / remove buttons
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                _OverlayButton(
                  icon: Icons.edit_outlined,
                  label: 'Change',
                  onTap: onPick,
                ),
                const SizedBox(width: 8),
                _OverlayButton(
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  onTap: onRemove,
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.82)
              : Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOPIC SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _TopicSelector extends StatelessWidget {
  final ArticleTopic selected;
  final ValueChanged<ArticleTopic> onChanged;

  const _TopicSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ArticleTopic.values.map((t) {
          final isSelected = t == selected;
          return GestureDetector(
            onTap: () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected ? t.color : t.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected ? t.color : t.color.withOpacity(0.25),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon,
                      size: 13,
                      color: isSelected ? Colors.white : t.color),
                  const SizedBox(width: 5),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : t.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOCK EDITOR — single content block (H1/H2/H3/paragraph)
// ─────────────────────────────────────────────────────────────────────────────

class _BlockEditor extends StatelessWidget {
  final ArticleBlock block;
  final int index;
  final bool isFocused;
  final VoidCallback onDelete;
  final ValueChanged<BlockType> onTypeChange;
  final VoidCallback onSubmitted;

  const _BlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.isFocused,
    required this.onDelete,
    required this.onTypeChange,
    required this.onSubmitted,
  });

  _BlockStyle get _style => _BlockStyle.forType(block.type);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _style.bottomSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block type indicator strip
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 3,
            height: _style.minHeight,
            margin: const EdgeInsets.only(right: 10, top: 4),
            decoration: BoxDecoration(
              color: isFocused
                  ? _style.accentColor
                  : _style.accentColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: block.controller,
              focusNode: block.focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: block.type == BlockType.paragraph
                  ? TextCapitalization.sentences
                  : TextCapitalization.words,
              style: _style.textStyle,
              decoration: InputDecoration(
                hintText: _style.hint,
                hintStyle: _style.textStyle.copyWith(
                    color: AppTheme.darkGreen.withOpacity(0.22)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),

          // Delete button (only when focused and more than one block exists)
          if (isFocused)
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 16,
                  color: Colors.black26,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlockStyle {
  final TextStyle textStyle;
  final String hint;
  final Color accentColor;
  final double minHeight;
  final double bottomSpacing;

  const _BlockStyle({
    required this.textStyle,
    required this.hint,
    required this.accentColor,
    required this.minHeight,
    required this.bottomSpacing,
  });

  static _BlockStyle forType(BlockType type) {
    switch (type) {
      case BlockType.h1:
        return _BlockStyle(
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGreen,
            height: 1.3,
          ),
          hint: 'Section heading…',
          accentColor: AppTheme.primary,
          minHeight: 32,
          bottomSpacing: 12,
        );
      case BlockType.h2:
        return _BlockStyle(
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkGreen,
            height: 1.35,
          ),
          hint: 'Sub-heading…',
          accentColor: AppTheme.secondary,
          minHeight: 26,
          bottomSpacing: 10,
        );
      case BlockType.h3:
        return _BlockStyle(
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.accent,
            height: 1.4,
          ),
          hint: 'Minor heading…',
          accentColor: AppTheme.accent,
          minHeight: 22,
          bottomSpacing: 8,
        );
      case BlockType.paragraph:
        return _BlockStyle(
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF2C3E35),
            height: 1.65,
          ),
          hint: 'Write something…',
          accentColor: AppTheme.lightGreen,
          minHeight: 24,
          bottomSpacing: 4,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOCK TOOLBAR  — slides up above the keyboard
// ─────────────────────────────────────────────────────────────────────────────

class _BlockToolbar extends StatelessWidget {
  final int? focusedIndex;
  final List<ArticleBlock> blocks;
  final VoidCallback onAddParagraph;
  final VoidCallback onAddH1;
  final VoidCallback onAddH2;
  final VoidCallback onAddH3;
  final ValueChanged<BlockType>? onChangeType;

  const _BlockToolbar({
    required this.focusedIndex,
    required this.blocks,
    required this.onAddParagraph,
    required this.onAddH1,
    required this.onAddH2,
    required this.onAddH3,
    this.onChangeType,
  });

  BlockType? get _currentType =>
      focusedIndex != null ? blocks[focusedIndex!].type : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.lightGreen.withOpacity(0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Insert label ─────────────────────────────────────────
          Text('Insert',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38)),
          const SizedBox(width: 10),

          // ── Block type buttons ────────────────────────────────────
          _ToolbarBtn(
            label: 'H1',
            onTap: onAddH1,
            isActive: _currentType == BlockType.h1,
            color: AppTheme.primary,
            isBold: true,
          ),
          _ToolbarBtn(
            label: 'H2',
            onTap: onAddH2,
            isActive: _currentType == BlockType.h2,
            color: AppTheme.secondary,
            isBold: true,
          ),
          _ToolbarBtn(
            label: 'H3',
            onTap: onAddH3,
            isActive: _currentType == BlockType.h3,
            color: AppTheme.accent,
            isBold: true,
          ),
          _ToolbarBtn(
            label: '¶',
            onTap: onAddParagraph,
            isActive: _currentType == BlockType.paragraph,
            color: AppTheme.darkGreen,
          ),

          const Spacer(),

          // ── Convert current block type ─────────────────────────
          if (focusedIndex != null && onChangeType != null) ...[
            Text('Convert',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38)),
            const SizedBox(width: 8),
            _ConvertMenu(
              currentType: _currentType!,
              onSelect: onChangeType!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color color;
  final bool isBold;

  const _ToolbarBtn({
    required this.label,
    required this.onTap,
    required this.isActive,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isActive ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _ConvertMenu extends StatelessWidget {
  final BlockType currentType;
  final ValueChanged<BlockType> onSelect;

  const _ConvertMenu(
      {required this.currentType, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.lightGreen.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(currentType),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.swap_vert,
                size: 14, color: AppTheme.darkGreen),
          ],
        ),
      ),
    );
  }

  String _label(BlockType t) {
    switch (t) {
      case BlockType.h1:
        return 'H1';
      case BlockType.h2:
        return 'H2';
      case BlockType.h3:
        return 'H3';
      case BlockType.paragraph:
        return '¶ Para';
    }
  }

  void _showMenu(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);

    showMenu<BlockType>(
      context: context,
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 180,
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: [
        _menuItem(BlockType.h1, 'H1 — Section Heading',
            FontWeight.w800, 16, AppTheme.primary),
        _menuItem(BlockType.h2, 'H2 — Sub-Heading',
            FontWeight.w700, 14, AppTheme.secondary),
        _menuItem(BlockType.h3, 'H3 — Minor Heading',
            FontWeight.w700, 13, AppTheme.accent),
        _menuItem(BlockType.paragraph, '¶  Paragraph',
            FontWeight.w400, 14, AppTheme.darkGreen),
      ],
    ).then((val) {
      if (val != null) onSelect(val);
    });
  }

  PopupMenuItem<BlockType> _menuItem(
      BlockType type, String label, FontWeight fw, double size, Color color) {
    final isSelected = type == currentType;
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: fw,
                    fontSize: size,
                    color: isSelected ? color : AppTheme.darkGreen)),
          ),
          if (isSelected)
            Icon(Icons.check, size: 16, color: color),
        ],
      ),
    );
  }
}