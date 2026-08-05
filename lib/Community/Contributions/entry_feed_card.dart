import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Organization/Explorer/org_view_screen.dart';
import '../../Services/Contributions/contribution_service.dart';
import '../../Shared/theme/app_theme.dart';

/// Number of characters of [FeedEntry.description] shown before "Show more".
const int _kDescriptionPreviewChars = 50;

/// How long each carousel image stays before auto-advancing (and how long the
/// indicator takes to fill).
const Duration _kDwell = Duration(seconds: 6);

/// Corner radius applied to the whole card (all sides).
const double _kRadius = 8;

/// Silvery grey for the social link icons.
const Color _kSocialGrey = Color(0xFF9AA0A6);

/// Social platforms rendered (in order) when the entry provides a link.
const List<(String, IconData)> _kSocialOrder = [
  ('facebook', Icons.facebook),
  ('instagram', Icons.camera_alt_outlined),
  ('tiktok', Icons.music_note),
  ('linkedin', Icons.business),
];

/// A single community feed entry rendered by [EntryFeedCard].
///
/// Kept deliberately simple (plain Dart) so it can be built from either
/// hard-coded placeholders or a Firestore document map.
class FeedEntry {
  final String title;
  final String description;

  /// Name of the posting organisation — shown top-left over the image.
  final String orgName;

  /// Organisation id — when set, tapping the org name opens its profile.
  final String? orgId;

  /// Work type — drives the accent colour of the type line.
  final String type;

  /// 1:1 images shown in the auto-advancing carousel.
  final List<String> imageUrls;

  /// Optional social links keyed by platform (facebook/instagram/tiktok/
  /// linkedin). Only the platforms present here render an icon.
  final Map<String, String> socials;

  /// Firestore document id of the backing contribution, when this entry was
  /// built from one. Needed to persist edits.
  final String? contributionId;

  const FeedEntry({
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrls,
    this.orgName = '',
    this.orgId,
    this.socials = const {},
    this.contributionId,
  });

  /// Build a feed entry from a `contributions` Firestore document map.
  ///
  /// Tolerant of the field aliases the writer uses: images come from `photos`
  /// (falling back to the legacy `beforeImages`), the type line from
  /// `workType` (falling back to `type`), and socials from `socialLinks`.
  factory FeedEntry.fromContribution(Map<String, dynamic> d,
      {String orgName = '', String? contributionId}) {
    List<String> images(dynamic v) => (v is List)
        ? v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const [];

    var photos = images(d['photos']);
    if (photos.isEmpty) photos = images(d['beforeImages']);

    final socialsRaw = d['socialLinks'];
    final socials = <String, String>{};
    if (socialsRaw is Map) {
      socialsRaw.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) {
          socials[k.toString()] = v.toString();
        }
      });
    }

    return FeedEntry(
      title: (d['title'] as String?)?.trim().isNotEmpty == true
          ? d['title'] as String
          : (d['workType'] as String? ?? 'Contribution'),
      description: d['description'] as String? ?? '',
      type: d['workType'] as String? ?? d['type'] as String? ?? '',
      imageUrls: photos,
      orgName: orgName,
      socials: socials,
      contributionId: contributionId ?? d['id'] as String?,
    );
  }
}

/// Accent colour for a work type — the small line above the title.
Color feedTypeColor(String type) {
  switch (type) {
    case 'Cleanup':
      return AppTheme.primary;
    case 'Tree Planting':
      return const Color(0xFF4CAF50);
    case 'School Upgrading':
      return AppTheme.tertiary;
    case 'Waste Management':
      return const Color(0xFF9C27B0);
    case 'Water & Sanitation':
      return const Color(0xFF2196F3);
    case 'Infrastructure':
      return const Color(0xFFFF9800);
    default:
      return AppTheme.primary;
  }
}

/// Community feed card:
///   • full-width 1:1 image carousel spanning the card width, with the posting
///     org name (tappable → org profile) overlaid top-left and a story-style
///     page indicator overlaid bottom;
///   • below the image: a colour-coded type line, the title, an expandable
///     description, and grey social icons for any links the entry provided.
class EntryFeedCard extends StatefulWidget {
  final FeedEntry entry;

  /// When true, shows an edit affordance that lets the owner change the title
  /// and description only. Requires [FeedEntry.contributionId] to be set.
  final bool editable;

  const EntryFeedCard({super.key, required this.entry, this.editable = false});

  @override
  State<EntryFeedCard> createState() => _EntryFeedCardState();
}

class _EntryFeedCardState extends State<EntryFeedCard>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _progress;
  int _current = 0;
  bool _active = false;

  // Local copies so an edit reflects immediately, before the Firestore stream
  // round-trips. Only title and description are editable.
  late String _title = widget.entry.title;
  late String _description = widget.entry.description;
  bool _savingEdit = false;
  bool _deleted = false;

  ScrollPosition? _position;

  List<String> get _images => widget.entry.imageUrls;
  bool get _multi => _images.length > 1;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _kDwell)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPos = Scrollable.maybeOf(context)?.position;
    if (newPos != _position) {
      _position?.removeListener(_onScroll);
      _position = newPos;
      _position?.addListener(_onScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeActive());
  }

  void _onScroll() => _recomputeActive();

  void _recomputeActive() {
    if (!mounted) return;
    bool visible = true;
    final box = context.findRenderObject() as RenderBox?;
    final viewport =
        _position?.context.storageContext.findRenderObject() as RenderBox?;
    if (box != null && box.attached && viewport != null && viewport.attached) {
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final h = box.size.height;
      final vh = viewport.size.height;
      final shown = (top + h).clamp(0.0, vh) - top.clamp(0.0, vh);
      visible = h > 0 && shown / h >= 0.4;
    }
    _setActive(visible);
  }

  void _setActive(bool value) {
    if (value == _active) return;
    _active = value;
    if (!_multi) return;
    if (value) {
      _progress.forward();
    } else {
      _progress.stop();
    }
  }

  void _advance() {
    if (!mounted || !_pageController.hasClients || !_multi) return;
    final next = (_current + 1) % _images.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int i) {
    setState(() => _current = i);
    if (_multi && _active) {
      _progress.forward(from: 0);
    } else {
      _progress.value = 0;
    }
  }

  Future<void> _openOrg() async {
    final orgId = widget.entry.orgId;
    if (orgId == null || orgId.isEmpty) return;
    final navigator = Navigator.of(context);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      if (!mounted || !doc.exists) return;
      navigator.push(MaterialPageRoute(
        builder: (_) => OrgViewScreen(orgId: orgId, orgData: doc.data()!),
      ));
    } catch (_) {/* ignore — org profile just won't open */}
  }

  Future<void> _openEditSheet() async {
    final id = widget.entry.contributionId;
    if (id == null) return;

    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditContributionSheet(
        initialTitle: _title,
        initialDescription: _description,
      ),
    );
    if (result == null || !mounted) return;

    final (newTitle, newDescription) = result;
    setState(() => _savingEdit = true);
    try {
      await FirebaseFirestore.instance
          .collection('contributions')
          .doc(id)
          .update({
        'title': newTitle,
        'description': newDescription,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _title = newTitle;
        _description = newDescription;
        _savingEdit = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingEdit = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save changes: $e')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final id = widget.entry.contributionId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete contribution?'),
        content: const Text(
            'This permanently removes the contribution and its points. This '
            'cannot be undone.'),
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
    if (confirmed != true || !mounted) return;

    setState(() => _savingEdit = true);
    try {
      await ContributionService()
          .deleteContribution(contributionId: id, userId: uid);
      if (!mounted) return;
      setState(() {
        _deleted = true;
        _savingEdit = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingEdit = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _openUrl(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    _progress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final accent = feedTypeColor(widget.entry.type);
    final orgName = widget.entry.orgName.trim();
    final socials = <(String, IconData, String)>[
      for (final (key, icon) in _kSocialOrder)
        if ((widget.entry.socials[key] ?? '').trim().isNotEmpty)
          (key, icon, widget.entry.socials[key]!.trim()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGreen.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image (full card width, square) ───────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(_kRadius)),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (_, i) => _CarouselImage(url: _images[i]),
                  ),
                  // Top scrim for the org chip.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 64,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.30),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (orgName.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _OrgChip(name: orgName, onTap: _openOrg),
                    ),
                  if (_multi)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (_, __) => _StoryIndicator(
                          count: _images.length,
                          current: _current,
                          fill: _progress.value,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TitleWithAccent(title: _title, accent: accent),
                    ),
                    if (widget.editable &&
                        widget.entry.contributionId != null) ...[
                      const SizedBox(width: 8),
                      if (_savingEdit)
                        const Padding(
                          padding: EdgeInsets.all(4),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else ...[
                        InkWell(
                          onTap: _openEditSheet,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.edit_outlined,
                                size: 18,
                                color: AppTheme.darkGreen.withOpacity(0.55)),
                          ),
                        ),
                        InkWell(
                          onTap: _confirmDelete,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red.shade300),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                if (_description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ExpandableText(text: _description.trim()),
                ],
                if (socials.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (_, icon, url) in socials)
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: InkWell(
                            onTap: () => _openUrl(url),
                            customBorder: const CircleBorder(),
                            child: Icon(icon, size: 22, color: _kSocialGrey),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _OrgChip({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.8), size: 14),
          ],
        ),
      ),
    );
  }
}

class _CarouselImage extends StatelessWidget {
  final String url;
  const _CarouselImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppTheme.lightGreen.withOpacity(0.15),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.lightGreen.withOpacity(0.2),
        child: Icon(Icons.broken_image_outlined,
            color: AppTheme.lightGreen, size: 36),
      ),
    );
  }
}

/// Story-style page indicator — thin segments spanning the width; segments
/// before the current one are filled, the current one fills left-to-right by
/// [fill] (0..1), the rest are dim. Sits on top of the image.
class _StoryIndicator extends StatelessWidget {
  final int count;
  final int current;
  final double fill;

  const _StoryIndicator({
    required this.count,
    required this.current,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final double f = i < current
            ? 1.0
            : i == current
                ? fill.clamp(0.0, 1.0)
                : 0.0;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == count - 1 ? 0 : 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: f,
                  child: Container(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Colour-coded accent line at ≈1/3 of the title's measured width, directly
/// above the title.
class _TitleWithAccent extends StatelessWidget {
  final String title;
  final Color accent;

  const _TitleWithAccent({required this.title, required this.accent});

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppTheme.darkGreen,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final painter = TextPainter(
          text: TextSpan(text: title, style: _titleStyle),
          maxLines: 2,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: maxWidth);

        final lineWidth = (painter.width / 3).clamp(18.0, maxWidth);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: lineWidth,
              height: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: _titleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

/// Description that collapses after [_kDescriptionPreviewChars] characters with
/// an inline "Show more" / "Show less" toggle.
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isLong = text.length > _kDescriptionPreviewChars;
    final style = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: AppTheme.darkGreen.withOpacity(0.7),
    );

    if (!isLong) {
      return Text(text, style: style);
    }

    final shown = _expanded
        ? text
        : '${text.substring(0, _kDescriptionPreviewChars).trimRight()}… ';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Text.rich(
        TextSpan(
          text: shown,
          style: style,
          children: [
            TextSpan(
              text: _expanded ? '  Show less' : 'Show more',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT SHEET — title + description only
// ─────────────────────────────────────────────────────────────────────────────

class _EditContributionSheet extends StatefulWidget {
  final String initialTitle;
  final String initialDescription;

  const _EditContributionSheet({
    required this.initialTitle,
    required this.initialDescription,
  });

  @override
  State<_EditContributionSheet> createState() => _EditContributionSheetState();
}

class _EditContributionSheetState extends State<_EditContributionSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _description =
      TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }
    Navigator.of(context).pop((title, _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Edit contribution',
                style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('You can update the title and description.',
                style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.55),
                    fontSize: 13)),
            const SizedBox(height: 18),
            const Text('Title',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'Contribution title',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Description',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the work…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save changes',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
