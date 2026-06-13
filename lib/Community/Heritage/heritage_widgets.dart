// lib/Community/Heritage/heritage_widgets.dart
//
// Phase 2/3 shared, data-driven cards for the community-facing Heritage screens.
// A single HeritageItemCard fills whatever box it's given (grid cell or a sized
// box in a horizontal preview rail), so the Country hub, Category browse and
// Community screens all render entries consistently. Missing cover images fall
// back to an accent gradient + the content-type icon (never an emoji).

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../Shared/theme/glass.dart';

/// A glassy entry card. Sizes to its parent — wrap in SizedBox (rails) or let a
/// GridView cell constrain it.
class HeritageItemCard extends StatelessWidget {
  final HeritageItem item;
  final VoidCallback onTap;

  /// When true, lays out as a compact horizontal row (used for the Language
  /// "row" shape and dense lists).
  final bool compact;

  const HeritageItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  HeritageContentType? get _type => HeritageContentTypes.byKey(item.contentType);
  Color get _accent => _type?.accent ?? GlassPalette.accent;
  IconData get _icon => _type?.icon ?? Icons.label_outline;

  @override
  Widget build(BuildContext context) {
    if (compact) return _compact();
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _image()),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if ((item.coverImageUrl ?? '').isNotEmpty)
          CachedNetworkImage(
            imageUrl: item.coverImageUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _gradient(),
            placeholder: (_, __) => _gradient(),
          )
        else
          _gradient(),
        // subtle bottom scrim so the footer blends
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black26],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradient() => DecoratedBox(
        decoration: BoxDecoration(gradient: GlassPalette.tintedGradient(_accent)),
        child: Center(
          child: Icon(_icon, size: 34, color: Colors.white.withOpacity(0.55)),
        ),
      );

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      color: Colors.white.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            (item.communityName ?? '').isNotEmpty
                ? item.communityName!
                : item.contentTypeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compact() {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: (item.coverImageUrl ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _gradient(),
                      )
                    : _gradient(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text(
                        (item.communityName ?? '').isNotEmpty
                            ? item.communityName!
                            : item.contentTypeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A representative "design" placeholder card — glassy, translucent, showing the
/// content-type icon over skeleton bars. Used to convey how a category's cards
/// will look before any real entry exists (abstract skeleton, NOT fake content).
class HeritagePlaceholderCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool compact;

  const HeritagePlaceholderCard({
    super.key,
    required this.icon,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                color: accent.withOpacity(0.14),
                child: Icon(icon, color: Colors.white.withOpacity(0.35), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_bar(70), const SizedBox(height: 7), _bar(44)],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: accent.withOpacity(0.12),
                alignment: Alignment.center,
                child: Icon(icon, size: 32, color: Colors.white.withOpacity(0.3)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_bar(double.infinity), const SizedBox(height: 7), _bar(60)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double width) => Container(
        width: width,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

/// Loading shimmer placeholder (a glass skeleton) — shown while a stream
/// resolves. This is a loading state, not invented content.
class HeritageLoadingRail extends StatelessWidget {
  final double height;
  const HeritageLoadingRail({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: height * 0.78,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
        ),
      ),
    );
  }
}
