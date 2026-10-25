// lib/Shared/widgets/immersive_header.dart
//
// ImmersiveHeader (ORG_HANDOFF §2): sharp cover, dark top scrim for the
// status bar, glass back / trailing buttons, and a fade into canvas at the
// bottom. Used by the public org, programme and event pages.

import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';

class ImmersiveHeader extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final IconData fallbackIcon;
  final List<Widget> actions;
  final bool showBack;

  const ImmersiveHeader({
    super.key,
    required this.imageUrl,
    this.height = 280,
    this.fallbackIcon = Icons.image_outlined,
    this.actions = const [],
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        CanopyImage(url: imageUrl, fallbackIcon: fallbackIcon),
        // Top scrim keeps the status bar and glass buttons legible.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0x8C000000), Color(0x00000000)],
            ),
          ),
        ),
        // Fade into canvas.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.canvas.withValues(alpha: 0), p.canvas],
              ),
            ),
          ),
        ),
        Positioned(
          top: top + CanopySpace.s8,
          left: CanopySpace.s12,
          right: CanopySpace.s12,
          child: Row(children: [
            if (showBack && Navigator.of(context).canPop())
              CanopyIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onImage: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            const Spacer(),
            for (final a in actions) ...[const SizedBox(width: CanopySpace.s8), a],
          ]),
        ),
      ]),
    );
  }
}
