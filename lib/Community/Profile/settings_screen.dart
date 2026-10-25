// lib/Community/Profile/settings_screen.dart
//
// Settings (v2): appearance (System / Light / Dark), account, about, and the
// version row. The long-press on the version opens a developer route and is
// deliberately undiscoverable. Rows only link to screens that exist.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Config/legal.dart';
import '../../Providers/theme_provider.dart';
import '../../Services/storage/user_persistence.dart';
import '../../Shared/widgets/legal_consent.dart';
import '../../Shared/widgets/report_sheet.dart';
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
            CanopyListRow(icon: Icons.person_off_outlined, title: 'Blocked people', onTap: () => showBlockedSheet(context)),
            CanopyListRow(
              icon: Icons.delete_forever_outlined,
              title: 'Delete account',
              subtitle: 'Remove your account and personal data',
              titleColor: p.danger,
              onTap: () => _deleteAccount(context),
            ),
          ]),
          const CanopySectionHeader(title: 'About Canopy', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            CanopyListRow(icon: Icons.info_outline, title: 'About', onTap: () => Navigator.pushNamed(context, '/about')),
            CanopyListRow(icon: Icons.rule_outlined, title: 'Community guidelines', onTap: () => Navigator.pushNamed(context, '/guidelines')),
            CanopyListRow(icon: Icons.privacy_tip_outlined, title: 'Privacy', onTap: () => Navigator.pushNamed(context, '/privacy')),
            CanopyListRow(icon: Icons.policy_outlined, title: 'Privacy policy (website)', onTap: () => openLegalUrl(context, kPrivacyUrl)),
            CanopyListRow(icon: Icons.gavel_outlined, title: 'Terms of service', onTap: () => openLegalUrl(context, kTermsUrl)),
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


/// Delete the signed-in person's account and personal data. Asks twice (the
/// second time they type DELETE), then runs the server function, signs out and
/// returns to the welcome screen.
Future<void> _deleteAccount(BuildContext context) async {
  final ok = await showCanopyConfirm(
    context,
    title: 'Delete your account?',
    message: 'This removes your profile, contributions, points, notifications and the photos you uploaded. It cannot be undone.',
    confirmLabel: 'Continue',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  final ctrl = TextEditingController();
  final typed = await showCanopySheet<bool>(context, builder: (ctx) {
    return StatefulBuilder(builder: (ctx, setSheet) {
      return CanopySheetBody(
        title: 'Type DELETE to confirm',
        children: [
          CanopyTextField(label: 'Type DELETE', controller: ctrl, textCapitalization: TextCapitalization.characters, onChanged: (_) => setSheet(() {})),
        ],
        actions: [
          CanopyButton(
            label: 'Delete my account',
            variant: CanopyButtonVariant.danger,
            expand: true,
            onPressed: ctrl.text.trim().toUpperCase() == 'DELETE' ? () => Navigator.pop(ctx, true) : null,
          ),
        ],
      );
    });
  });
  ctrl.dispose();
  if (typed != true || !context.mounted) return;

  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    await FirebaseFunctions.instance.httpsCallable('deleteMyAccount').call();
    try {
      await UserPersistence.clearUserData();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    nav.pushNamedAndRemoveUntil('/welcome', (_) => false);
  } on FirebaseFunctionsException catch (e) {
    nav.pop(); // the progress dialog
    if (context.mounted) {
      showCanopySnack(context, e.message ?? "Couldn't delete your account. Try again, or use $kDeleteAccountUrl.", error: true);
    }
  } catch (_) {
    nav.pop();
    if (context.mounted) showCanopySnack(context, "Couldn't delete your account. Try again.", error: true);
  }
}
