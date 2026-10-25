// lib/Shared/Pages/welcome_screen.dart
//
// Welcome (v2): logo, a brand hero, what you can do today, then one ink
// primary (Get started) and a quiet sign-in.

import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';
import '../Authentication/join_community.dart';
import 'login.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _benefits = [
    (Icons.event_available_outlined, 'Join local activities', 'Clean-ups, plantings and events near you, with QR check-in.'),
    (Icons.fact_check_outlined, 'See your impact counted', 'Log what you did; organisations verify it and you earn points.'),
    (Icons.storefront_outlined, 'Find makers and services', 'Buy from local makers and book home services.'),
    (Icons.auto_stories_outlined, 'Explore heritage', 'Stories, food and music from communities across the country.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return PopScope(
      canPop: false,
      child: CanopyScaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
            children: [
              Center(child: Image.asset('pngs/logotext.png', height: 48, fit: BoxFit.contain)),
              const SizedBox(height: CanopySpace.s24),
              CanopyHero(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Look after where you live.', style: CanopyType.display.copyWith(color: p.onPrimary)),
                  const SizedBox(height: CanopySpace.s8),
                  Text('Canopy connects neighbours, organisations and makers around real work in your area.',
                      style: CanopyType.body.copyWith(color: p.onPrimary.withAlpha(220))),
                ]),
              ),
              const SizedBox(height: CanopySpace.section),
              CanopyListGroup(children: [
                for (final (icon, title, line) in _benefits)
                  CanopyListRow(leading: Icon(icon, color: p.primaryInk), title: title, subtitle: line, chevron: false),
              ]),
            ],
          ),
        ),
        sticky: StickyActionBar(children: [
          CanopyButton(
            label: 'Get started',
            expand: true,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinCommunityScreen())),
          ),
          const SizedBox(height: CanopySpace.s8),
          CanopyButton(
            label: 'I already have an account',
            variant: CanopyButtonVariant.quiet,
            expand: true,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage())),
          ),
        ]),
      ),
    );
  }
}
