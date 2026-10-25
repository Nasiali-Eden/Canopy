// lib/Community/Heritage/heritage_ui.dart
//
// Heritage components (handoff/HERITAGE_HANDOFF.md §1–§2) on the Heritage
// sub-theme: dusk in dark mode, afternoon (parchment) in light.
//
//   HeritageTheme · HeritageCard (poster / tile / banner / row) ·
//   HeritageFallback · CategoryLabel · FieldBadge · GlassIconButton ·
//   HeritageSectionHeader · HeritageBackdropPage (ImmersiveHeader + sheet) ·
//   CountryCard (live / soon) · CommunityBanner · RestrictionNote ·
//   LanguageSwitch · ShortFieldRow · HeritageSkeletonRail · CheckBackLater ·
//   HeritageRail.
//
// v3 glass (HERITAGE_HANDOFF §1): every page sits on a full-screen photo;
// cards, chips, buttons, search and nav float on it in glass, long text in the
// denser reading glass. The photo is sharp except behind search/lists. Category
// colour only from HeritageCategory.text(); every image slot falls back
// silently to the category gradient.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary, ScrollDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_bundled_images.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../theme/canopy_components.dart';
import '../../theme/heritage_tone.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────

extension HeritageContext on BuildContext {
  HeritagePalette get heritage => HeritagePalette.of(Theme.of(this).brightness);
}

/// Frosted-glass panel: blur → tint → 1px border. [reading] is the denser
/// tint for long text.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool reading;
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = HeritageGlass.radiusCard,
    this.padding = const EdgeInsets.all(8),
    this.reading = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = HeritageGlass.of(Theme.of(context).brightness);
    final sigma = (reading ? HeritageGlass.blurReading : HeritageGlass.blurCard) / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: reading ? g.readingGlass : g.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: g.glassBorder),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Reading glass: bodies, bios, item fields. Radius 28, padding 20.
class ReadingGlass extends StatelessWidget {
  final Widget child;
  const ReadingGlass({super.key, required this.child});

  @override
  Widget build(BuildContext context) => GlassSurface(
        reading: true,
        radius: HeritageGlass.radiusReading,
        padding: const EdgeInsets.all(20),
        child: child,
      );
}

/// Re-grounds the shared components (buttons, chips, sheets) on heritage
/// surfaces by swapping canvas/surface/ink in the CanopyPalette extension.
class HeritageTheme extends StatelessWidget {
  final Widget child;
  const HeritageTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeritagePalette.of(theme.brightness);
    final b = theme.brightness == Brightness.dark ? CanopyPalette.dark : CanopyPalette.light;
    final p = CanopyPalette(
      canvas: h.base,
      surface: h.raised,
      surfaceMuted: h.raisedHi,
      surfaceBrand: b.surfaceBrand,
      frost: h.glass,
      scrim: b.scrim,
      ink: h.ink,
      inkMuted: h.inkMuted,
      inkFaint: h.inkFaint,
      outline: h.outline,
      outlineStrong: h.outlineStrong,
      focus: b.focus,
      primary: b.primary,
      primaryDeep: b.primaryDeep,
      primaryDim: b.primaryDim,
      primarySoft: b.primarySoft,
      primaryInk: b.primaryInk,
      onPrimary: b.onPrimary,
      accent: b.accent,
      gold: b.gold,
      goldInk: b.goldInk,
      goldSoft: b.goldSoft,
      medalSilver: b.medalSilver,
      medalBronze: b.medalBronze,
      success: b.success,
      successSoft: b.successSoft,
      warning: b.warning,
      warningSoft: b.warningSoft,
      danger: b.danger,
      dangerSoft: b.dangerSoft,
      info: b.info,
      infoSoft: b.infoSoft,
      viz: b.viz,
      seq: b.seq,
      map: b.map,
      gradientCanopy: b.gradientCanopy,
      gradientScrim: b.gradientScrim,
    );
    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: h.base, extensions: [p]),
      child: child,
    );
  }
}

HeritageCategory heritageCategoryFor(String contentType) =>
    HeritageContentTypes.byKey(contentType)?.category ?? HeritageCategory.communities;

IconData heritageIconFor(String contentType) =>
    HeritageContentTypes.byKey(contentType)?.icon ?? Icons.label_outline;

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA
// ─────────────────────────────────────────────────────────────────────────────

/// Missing-image fallback: radial fill → deep, fine 3px grain, category glyph
/// (white 72%). Optionally a giant initial at 5% (community backdrops).
class HeritageFallback extends StatelessWidget {
  final HeritageCategory category;
  final IconData? icon;
  final double iconSize;
  final String? initial;
  const HeritageFallback(
      {super.key, required this.category, this.icon, this.iconSize = 32, this.initial});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: category.fallback),
      child: CustomPaint(
        painter: const _GrainPainter(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (initial != null)
              Positioned.fill(
                child: FittedBox(
                  child: Text(initial!,
                      style: CanopyType.heritageDisplay
                          .copyWith(color: CanopyPalette.onHero.withAlpha(0x0D))),
                ),
              ),
            if (icon != null)
              Icon(icon, size: iconSize, color: CanopyPalette.onHero.withAlpha(0xB8)),
          ],
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = CanopyPalette.onHero.withAlpha(0x0D);
    for (double y = 0; y < size.height; y += 3) {
      for (double x = (y ~/ 3).isEven ? 0 : 1.5; x < size.width; x += 3) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Photo with 240ms fade-in; failure falls back to the category gradient
/// silently. Never blurred.
class HeritageMedia extends StatelessWidget {
  final String? url;
  final HeritageCategory category;
  final IconData? icon;
  final Alignment alignment;
  const HeritageMedia(
      {super.key, this.url, required this.category, this.icon, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    final fallback = HeritageFallback(category: category, icon: icon);
    if (url == null || url!.isEmpty) return fallback;
    if (HeritageBundledImages.isAsset(url)) {
      return Image.asset(
        HeritageBundledImages.assetPath(url!),
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => fallback,
      frameBuilder: (_, child, frame, sync) => sync
          ? child
          : AnimatedSwitcher(
              duration: context.reduceMotion ? CanopyMotion.reduced : HeritageMotion.imageFade,
              child: frame == null
                  ? DecoratedBox(
                      key: const ValueKey('loading'),
                      decoration: BoxDecoration(color: category.tint))
                  : child,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LABELS
// ─────────────────────────────────────────────────────────────────────────────

/// Uppercase 11.5/700, +8% tracking, HeritageCategory.text().
class CategoryLabel extends StatelessWidget {
  final String text;
  final HeritageCategory category;
  const CategoryLabel(this.text, {super.key, required this.category});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: CanopyType.statusLabel.copyWith(
          color: category.text(context.heritage), letterSpacing: 0.92));
}

/// Several category/community/country labels divided by hairlines.
class HeritageLabelRow extends StatelessWidget {
  final List<(String, HeritageCategory?)> labels;
  const HeritageLabelRow({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    return LabelRow(children: [
      for (final l in labels)
        l.$2 != null
            ? CategoryLabel(l.$1, category: l.$2!)
            : Text(l.$1.toUpperCase(),
                style: CanopyType.statusLabel.copyWith(color: h.inkMuted, letterSpacing: 0.92)),
    ]);
  }
}

/// Glyph + text, no box (Still practised, Restricted…).
class FieldBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  const FieldBadge(this.text, {super.key, this.icon = Icons.check_circle_outline});

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: CanopyIconSize.s16, color: h.ink),
      const SizedBox(width: CanopySpace.s4 + 2),
      Text(text, style: CanopyType.label.copyWith(color: h.ink)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHROME
// ─────────────────────────────────────────────────────────────────────────────

/// 48dp glass circle — only for chrome floating over a photo.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const GlassIconButton(
      {super.key, required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: canopyGlassBlur,
          child: Material(
            color: h.glass,
            shape: CircleBorder(side: BorderSide(color: h.glassLine)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: CanopySpace.minTouch,
                height: CanopySpace.minTouch,
                child: Icon(icon, size: CanopyIconSize.appBar, color: h.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 8px accent dot + heritageSection title + "Show all N" (only when > 4).
class HeritageSectionHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final int count;
  final VoidCallback? onShowAll;
  const HeritageSectionHeader(
      {super.key, required this.title, required this.accent, this.count = 0, this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          CanopySpace.gutter, CanopySpace.s24, CanopySpace.s8, CanopySpace.s8),
      child: Row(
        children: [
          Container(
              width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: CanopySpace.s8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: CanopyType.heritageSection.copyWith(color: h.ink)),
            ),
          ),
          if (onShowAll != null && count > HeritageCardSize.railPreviewMax)
            InkWell(
              onTap: onShowAll,
              borderRadius: BorderRadius.circular(CanopyRadius.xs),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s12),
                  child: Center(
                    widthFactor: 1,
                    child: Text('Show all $count',
                        style: CanopyType.label.copyWith(color: h.inkMuted)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen photograph, fixed behind the page, under the v3 page scrim; the
/// title block sits on the photo in the top third (title shadow) and everything
/// below floats on it in glass. Back/actions are glass buttons. Shared with the
/// org public page.
class HeritageBackdropPage extends StatefulWidget {
  final Widget backdrop;
  final double backdropHeight;
  final Widget? titleBlock;
  final List<Widget> sheetChildren;
  final List<Widget> actions;
  final bool showBack;
  final ScrollController? controller;
  final ValueChanged<ScrollDirection>? onScrollDirection;
  final double bottomPadding;

  const HeritageBackdropPage({
    super.key,
    required this.backdrop,
    this.backdropHeight = 470,
    this.titleBlock,
    required this.sheetChildren,
    this.actions = const [],
    this.showBack = true,
    this.controller,
    this.onScrollDirection,
    this.bottomPadding = CanopySpace.s32,
  });

  @override
  State<HeritageBackdropPage> createState() => _HeritageBackdropPageState();
}

class _HeritageBackdropPageState extends State<HeritageBackdropPage> {
  late final ScrollController _ctrl = widget.controller ?? ScrollController();
  double _offset = 0;

  // Text colour follows the photo: the page samples how bright the photo is
  // and renders the whole page light-on-dark or dark-on-light to match.
  final _photoKey = GlobalKey();
  bool _photoDark = true;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() => _offset = _ctrl.offset);
    });
    // The photo may still be loading; look again as it settles.
    for (final ms in const [350, 1000, 2200, 4500]) {
      Future.delayed(Duration(milliseconds: ms), _samplePhoto);
    }
  }

  @override
  void didUpdateWidget(covariant HeritageBackdropPage old) {
    super.didUpdateWidget(old);
    for (final ms in const [350, 1200, 3000]) {
      Future.delayed(Duration(milliseconds: ms), _samplePhoto);
    }
  }

  /// Tell the floating nav how bright the photo is (only while this page is
  /// the one on screen).
  void _publishTone() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent ?? true) HeritageTone.photoDark.value = _photoDark;
  }

  Future<void> _samplePhoto() async {
    if (!mounted) return;
    try {
      final b = _photoKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (b == null) return;
      final img = await b.toImage(pixelRatio: 0.05);
      final data = await img.toByteData();
      if (data == null || img.width == 0) return;
      // Where the title and the first cards sit: the top 60% of the photo.
      final rows = (img.height * 0.6).ceil().clamp(1, img.height);
      double sum = 0;
      var n = 0;
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < img.width; x++) {
          final i = (y * img.width + x) * 4;
          sum += 0.2126 * data.getUint8(i) + 0.7152 * data.getUint8(i + 1) + 0.0722 * data.getUint8(i + 2);
          n++;
        }
      }
      if (n == 0 || !mounted) return;
      final dark = sum / n / 255 < 0.5;
      if (dark != _photoDark) setState(() => _photoDark = dark);
      _publishTone();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Title area: the title lives in the top third of the screen.
    final headerHeight = widget.backdropHeight * 0.72 * 0.8; // content sits 20% higher
    // The whole page takes the photo's brightness (not the app's), so text on
    // the photo and the glass above it always contrast with what is behind.
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishTone());
    final forced = Theme.of(context).copyWith(
        brightness: _photoDark ? Brightness.dark : Brightness.light);
    final shadows = _photoDark
        ? const [...HeritageGlass.titleShadow, Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1))]
        : const <Shadow>[];
    return Theme(
      data: forced,
      child: HeritageTheme(
      child: Builder(builder: (context) => Scaffold(
        backgroundColor: context.heritage.base,
        body: Stack(
          children: [
            // Fixed photo, fully visible. Only a soft shade at the very top so
            // the status bar and buttons stay legible.
            Positioned.fill(child: RepaintBoundary(key: _photoKey, child: widget.backdrop)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top + 110,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x59000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                widget.onScrollDirection?.call(n.direction);
                return false;
              },
              child: CustomScrollView(
                controller: _ctrl,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: headerHeight,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s16),
                          // Fades out as the page scrolls so it never runs under
                          // the status bar; unbounded height so a Column title
                          // hugs its content at the bottom of the header.
                          child: Opacity(
                            opacity: (1 - _offset / (headerHeight * 0.6)).clamp(0.0, 1.0),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(shadows: shadows),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                if (widget.titleBlock != null) widget.titleBlock!,
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: widget.bottomPadding + bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.sheetChildren,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: top + CanopySpace.s8,
              left: CanopySpace.s12,
              right: CanopySpace.s12,
              child: Row(
                children: [
                  if (widget.showBack && Navigator.of(context).canPop())
                    GlassIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context)),
                  const Spacer(),
                  ...widget.actions,
                ],
              ),
            ),
          ],
        ),
      )),
      ),
    );
  }
}

/// Heritage scaffold for search and lists: the page photo, blurred to 6 behind
/// the content, under the page scrim.
class HeritagePlainPage extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget> actions;
  const HeritagePlainPage({super.key, this.title, required this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return HeritageTheme(
      child: Builder(
        builder: (context) {
          final g = HeritageGlass.of(Theme.of(context).brightness);
          return Stack(children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                    sigmaX: HeritageGlass.searchListBackdropBlur, sigmaY: HeritageGlass.searchListBackdropBlur),
                child: Image.asset('images/BG.png', fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: g.pageScrim))),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: canopyAppBar(context, title: title, actions: actions),
              body: body,
            ),
          ]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARDS
// ─────────────────────────────────────────────────────────────────────────────

Size heritageCardSize(HeritageCardShape s) => switch (s) {
      HeritageCardShape.poster => HeritageCardSize.poster,
      HeritageCardShape.tile => HeritageCardSize.tile,
      HeritageCardShape.banner => HeritageCardSize.banner,
      HeritageCardShape.row => const Size(280, HeritageCardSize.rowThumb),
    };

/// Solid card: media on top (or 52 thumb for rows), title + caption below on
/// `raised`. Press = 0.98 + raisedHi.
class HeritageCard extends StatefulWidget {
  final HeritageItem item;
  final HeritageCardShape? shape;
  final VoidCallback onTap;
  final bool showCategory;
  final double? width;
  const HeritageCard({
    super.key,
    required this.item,
    required this.onTap,
    this.shape,
    this.showCategory = false,
    this.width,
  });

  @override
  State<HeritageCard> createState() => _HeritageCardState();
}

class _HeritageCardState extends State<HeritageCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    final item = widget.item;
    final cat = heritageCategoryFor(item.contentType);
    final shape = widget.shape ?? cat.shape;
    final size = heritageCardSize(shape);
    final w = widget.width ?? size.width;
    final caption = (item.communityName ?? '').isNotEmpty ? item.communityName! : item.contentTypeLabel;

    final cover = (item.coverImageUrl ?? '').isNotEmpty
        ? item.coverImageUrl
        : HeritageBundledImages.forContentType(item.contentType);
    final media = HeritageMedia(url: cover, category: cat, icon: heritageIconFor(item.contentType));

    final Widget content = shape == HeritageCardShape.row
        ? SizedBox(
            height: 72,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(HeritageGlass.radiusMedia - 4),
                  child: SizedBox(width: 96, height: 72, child: media),
                ),
                const SizedBox(width: CanopySpace.s12),
                Expanded(child: _text(h, cat, caption)),
                Icon(Icons.chevron_right, color: h.inkMuted),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(HeritageGlass.radiusMedia),
                child: SizedBox(height: (w - 16) * size.height / size.width, child: media),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    CanopySpace.s4, CanopySpace.s8, CanopySpace.s4, CanopySpace.s4),
                child: _text(h, cat, caption),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: '${item.contentTypeLabel}: ${item.title}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: HeritageMotion.cardPress,
          child: SizedBox(
            width: w,
            child: GlassSurface(child: content),
          ),
        ),
      ),
    );
  }

  Widget _text(HeritagePalette h, HeritageCategory cat, String caption) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.showCategory) ...[
            CategoryLabel(widget.item.contentTypeLabel, category: cat),
            const SizedBox(height: CanopySpace.s2),
          ],
          Text(widget.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CanopyType.heritageCardTitle.copyWith(color: h.ink)),
          if (caption.isNotEmpty)
            Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CanopyType.caption.copyWith(color: h.inkMuted)),
        ],
      );
}

/// Rail of ≤4 cards in the category's shape; a single entry is one
/// full-width card.
class HeritageRail extends StatelessWidget {
  final List<HeritageItem> items;
  final HeritageCardShape shape;
  final void Function(HeritageItem) onOpen;
  final bool showCategory;
  const HeritageRail(
      {super.key,
      required this.items,
      required this.shape,
      required this.onOpen,
      this.showCategory = false});

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
        child: LayoutBuilder(
          builder: (_, c) => HeritageCard(
            item: items.first,
            shape: shape == HeritageCardShape.poster ? HeritageCardShape.banner : shape,
            width: c.maxWidth,
            showCategory: showCategory,
            onTap: () => onOpen(items.first),
          ),
        ),
      );
    }
    if (shape == HeritageCardShape.row) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
        child: Column(children: [
          for (final it in items.take(HeritageCardSize.railPreviewMax)) ...[
            LayoutBuilder(
              builder: (_, c) => HeritageCard(
                  item: it, shape: shape, width: c.maxWidth, onTap: () => onOpen(it)),
            ),
            const SizedBox(height: CanopySpace.s8),
          ],
        ]),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final it in items.take(HeritageCardSize.railPreviewMax)) ...[
            HeritageCard(
                item: it, shape: shape, showCategory: showCategory, onTap: () => onOpen(it)),
            const SizedBox(width: CanopySpace.s12),
          ],
        ],
      ),
    );
  }
}

/// Skeletons in the section's own card shape (category tint).
class HeritageSkeletonRail extends StatelessWidget {
  final HeritageCardShape shape;
  final HeritageCategory category;
  const HeritageSkeletonRail({super.key, required this.shape, required this.category});

  @override
  Widget build(BuildContext context) {
    final size = heritageCardSize(shape);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
      child: Row(children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: size.width,
            height: shape == HeritageCardShape.row ? 72 : size.height + 56,
            decoration: BoxDecoration(
              color: category.tint,
              borderRadius: BorderRadius.circular(HeritageCardSize.radius),
            ),
          ),
          const SizedBox(width: CanopySpace.s12),
        ],
      ]),
    );
  }
}

/// Community banner 220×110: photo or communities fallback, name bottom-left
/// on a dark fade.
class CommunityBanner extends StatelessWidget {
  final String name;
  final int count;
  final String? imageUrl;
  final VoidCallback onTap;
  final double? width;
  const CommunityBanner(
      {super.key,
      required this.name,
      required this.count,
      required this.onTap,
      this.imageUrl,
      this.width});

  @override
  Widget build(BuildContext context) {
    final size = HeritageCardSize.communityBanner;
    return Semantics(
      button: true,
      label: '$name, $count entries',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HeritageCardSize.radius),
          child: SizedBox(
            width: width ?? size.width,
            height: size.height,
            child: Stack(fit: StackFit.expand, children: [
              imageUrl != null && imageUrl!.isNotEmpty
                  ? HeritageMedia(url: imageUrl, category: HeritageCategory.communities)
                  : HeritageFallback(
                      category: HeritageCategory.communities,
                      initial: name.isEmpty ? null : name.characters.first.toUpperCase()),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [HeritagePalette.dusk.base.withAlpha(0), HeritagePalette.dusk.base.withAlpha(0xC7)],
                  ),
                ),
              ),
              Positioned(
                left: CanopySpace.s12,
                right: CanopySpace.s12,
                bottom: CanopySpace.s12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CanopyType.heritageCardTitle
                            .copyWith(color: HeritagePalette.dusk.ink)),
                    Text('$count ${count == 1 ? 'entry' : 'entries'}',
                        style: CanopyType.caption.copyWith(color: HeritagePalette.dusk.inkMuted)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Country card. Live: photo banner 168, LIVE label, heritageTitle name,
/// "N entries · N communities". Soon: dashed 1.5 outlineStrong, serif name,
/// "Opening soon".
class CountryCard extends StatelessWidget {
  final HeritageCountry country;
  final ({int entries, int communities})? stats;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool compact;
  const CountryCard({
    super.key,
    required this.country,
    required this.stats,
    this.imageUrl,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    final live = (stats?.entries ?? 0) > 0;
    if (!live) {
      return GlassSurface(
        padding: const EdgeInsets.all(CanopySpace.s12),
        child: SizedBox(
          height: compact ? 64 : 86,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(country.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CanopyType.heritageCardTitle.copyWith(color: h.ink)),
                Text('OPENING SOON',
                    style: CanopyType.statusLabel.copyWith(color: h.inkMuted, letterSpacing: 0.92)),
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '${country.name}, ${stats!.entries} entries',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // The photo fills the card; the name and counts sit on it, over a
        // bottom shade, in light ink that always reads on the photo.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HeritageGlass.radiusCard),
          child: SizedBox(
            height: 280,
            child: Stack(fit: StackFit.expand, children: [
              HeritageMedia(url: imageUrl, category: HeritageCategory.places),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB8000000)],
                  ),
                ),
              ),
              Positioned(
                left: CanopySpace.cardPadding,
                right: CanopySpace.cardPadding,
                bottom: CanopySpace.cardPadding,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(shadows: HeritageGlass.titleShadow),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusLabel('Live', color: CanopyPalette.dark.success, live: true),
                      Text(country.name,
                          style: CanopyType.heritageTitle.copyWith(color: HeritagePalette.dusk.ink)),
                      Text(
                          '${stats!.entries} ${stats!.entries == 1 ? 'entry' : 'entries'} · ${stats!.communities} ${stats!.communities == 1 ? 'community' : 'communities'}',
                          style: CanopyType.caption.copyWith(color: HeritagePalette.dusk.inkMuted)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM PIECES
// ─────────────────────────────────────────────────────────────────────────────

/// Restriction note: directly under the title, before the body. The
/// organisation's words verbatim.
class RestrictionNote extends StatelessWidget {
  final String text;
  const RestrictionNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final dusk = context.heritage.isDusk;
    final fill = dusk ? HeritageRestriction.duskFill : HeritageRestriction.afternoonFill;
    final line = dusk ? HeritageRestriction.duskLine : HeritageRestriction.afternoonLine;
    final label = dusk ? HeritageRestriction.duskLabel : HeritageRestriction.afternoonLabel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CanopySpace.cardPadding),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(HeritageRestriction.radius),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.shield_outlined, size: CanopyIconSize.s18, color: label),
            const SizedBox(width: CanopySpace.s8),
            Text('SHARED WITH LIMITS',
                style: CanopyType.heritageFieldLabel.copyWith(color: label)),
          ]),
          const SizedBox(height: CanopySpace.s8),
          Text(text, style: CanopyType.body.copyWith(color: context.heritage.ink, height: 21 / 14)),
        ],
      ),
    );
  }
}

/// Segmented language switch — only languages the entry holds; the choice is
/// remembered across entries.
class LanguageSwitch extends StatefulWidget {
  final List<String> languages; // subset of English / Kiswahili / Original
  final ValueChanged<String> onChanged;
  final String? value;
  const LanguageSwitch(
      {super.key, required this.languages, required this.onChanged, this.value});

  static String? remembered;
  static const _prefsKey = 'heritage_language';

  static Future<String?> load() async {
    if (remembered != null) return remembered;
    try {
      remembered = (await SharedPreferences.getInstance()).getString(_prefsKey);
    } catch (_) {}
    return remembered;
  }

  static Future<void> save(String lang) async {
    remembered = lang;
    try {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, lang);
    } catch (_) {}
  }

  @override
  State<LanguageSwitch> createState() => _LanguageSwitchState();
}

class _LanguageSwitchState extends State<LanguageSwitch> {
  @override
  Widget build(BuildContext context) {
    final v = widget.value ?? widget.languages.first;
    return CanopySegmented<String>(
      options: [for (final l in widget.languages) (l, l)],
      value: v,
      onChanged: (l) {
        LanguageSwitch.save(l);
        widget.onChanged(l);
      },
    );
  }
}

/// heritageFieldLabel (120 column) + value; 1px outline between rows.
class ShortFieldRow extends StatelessWidget {
  final String label;
  final String value;
  const ShortFieldRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: h.outline))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label.toUpperCase(),
                style: CanopyType.heritageFieldLabel.copyWith(color: h.inkMuted)),
          ),
          Expanded(child: Text(value, style: CanopyType.body.copyWith(color: h.ink))),
        ],
      ),
    );
  }
}

/// Glass panel with a glyph and "Check back later" — never styled as an error.
class CheckBackLater extends StatelessWidget {
  final String line;
  final bool glass;
  const CheckBackLater({super.key, required this.line, this.glass = true});

  @override
  Widget build(BuildContext context) {
    final h = context.heritage;
    return GlassSurface(
      padding: const EdgeInsets.all(CanopySpace.s24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_outlined, size: CanopyIconSize.s32, color: h.inkMuted),
            const SizedBox(height: CanopySpace.s12),
            Text('Check back later', style: CanopyType.heritageSection.copyWith(color: h.ink)),
            const SizedBox(height: CanopySpace.s4),
            Text(line, textAlign: TextAlign.center, style: CanopyType.body.copyWith(color: h.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// Human label for a type_data key ("cultural_significance" → "Cultural significance").
String heritageHumanize(String key) {
  final s = key.replaceAll('_', ' ').trim();
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
