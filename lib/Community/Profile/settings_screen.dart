// lib/Community/Profile/settings_screen.dart
//
// Settings (v2): appearance (System / Light / Dark), account, about, and the
// version row. The long-press on the version opens a developer route and is
// deliberately undiscoverable. Rows only link to screens that exist.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/theme_provider.dart';
import '../../theme/canopy_components.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final theme = context.watch<ThemeProvider>();
    final user = FirebaseAuth.instance.currentUser;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          const CanopySectionHeader(title: 'Appearance', padding: EdgeInsets.zero),
          CanopySegmented<ThemeMode>(
            options: const [(ThemeMode.system, 'System'), (ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark')],
            value: theme.mode,
            onChanged: theme.setMode,
          ),
          const SizedBox(height: CanopySpace.s4),
          Text('Applies everywhere in Canopy.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
          const CanopySectionHeader(title: 'Your account', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.person_outline,
              title: 'Edit profile',
              subtitle: 'Name, photo and location',
              onTap: () => Navigator.pushNamed(context, '/profile/edit'),
            ),
            CanopyListRow(icon: Icons.lock_outline, title: 'Password & security', onTap: () => Navigator.pushNamed(context, '/security')),
            CanopyListRow(icon: Icons.notifications_none, title: 'Notifications', onTap: () => Navigator.pushNamed(context, '/notifications')),
          ]),
          const CanopySectionHeader(title: 'About Canopy', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            CanopyListRow(icon: Icons.info_outline, title: 'About', onTap: () => Navigator.pushNamed(context, '/about')),
            CanopyListRow(icon: Icons.rule_outlined, title: 'Community guidelines', onTap: () => Navigator.pushNamed(context, '/guidelines')),
            CanopyListRow(icon: Icons.privacy_tip_outlined, title: 'Privacy', onTap: () => Navigator.pushNamed(context, '/privacy')),
            CanopyListRow(
              icon: Icons.route_outlined,
              title: 'Roadmap',
              subtitle: "What's built and what's next",
              onTap: () => Navigator.pushNamed(context, '/roadmap'),
            ),
          ]),
          const SizedBox(height: CanopySpace.section),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => Navigator.pushNamed(context, '/dev/blockchain'),
            child: Column(children: [
              Text('Canopy 1.0.0', style: CanopyType.label.copyWith(color: p.inkMuted)),
              if (user != null) Text(user.uid, style: CanopyType.micro.copyWith(color: p.inkFaint)),
            ]),
          ),
        ],
      ),
    );
  }
}
