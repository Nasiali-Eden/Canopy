// lib/Community/Profile/security_screen.dart
//
// Password & Security (DESIGN_HANDOFF §4 — "keep, small screen"): change
// password with re-authentication, or email a reset link. Accounts that sign
// in with another provider are told where their password lives instead.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _sendingReset = false;
  bool _linkingGoogle = false;
  bool _showErrors = false;
  String? _serverError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _currentError => _current.text.isEmpty ? 'Enter your current password.' : null;
  String? get _nextError =>
      _next.text.length < 8 ? 'Use at least 8 characters.' : null;
  String? get _confirmError =>
      _confirm.text != _next.text ? "Passwords don't match." : null;

  Future<void> _change(User user) async {
    setState(() {
      _showErrors = true;
      _serverError = null;
    });
    if (_currentError != null || _nextError != null || _confirmError != null) return;
    setState(() => _saving = true);
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: _current.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_next.text);
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      setState(() => _showErrors = false);
      showCanopySnack(context, 'Password changed.');
    } on FirebaseAuthException catch (e) {
      setState(() => _serverError = switch (e.code) {
            'wrong-password' || 'invalid-credential' => 'Your current password is wrong.',
            'weak-password' => 'Choose a stronger password.',
            'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
            'network-request-failed' => "You're offline. Connect and try again.",
            _ => "Couldn't change your password. Try again.",
          });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Google-only accounts: attach an email/password so both sign-ins work.
  Future<void> _addPassword(User user) async {
    setState(() {
      _showErrors = true;
      _serverError = null;
    });
    if (_nextError != null || _confirmError != null || user.email == null) return;
    setState(() => _saving = true);
    try {
      await user.linkWithCredential(EmailAuthProvider.credential(email: user.email!, password: _next.text));
      await user.reload();
      if (!mounted) return;
      _next.clear();
      _confirm.clear();
      setState(() => _showErrors = false);
      showCanopySnack(context, 'Password added. You can now sign in with email or Google.');
    } on FirebaseAuthException catch (e) {
      setState(() => _serverError = switch (e.code) {
            'weak-password' => 'Choose a stronger password.',
            'requires-recent-login' => 'For security, sign in again, then add a password.',
            'provider-already-linked' || 'email-already-in-use' || 'credential-already-in-use' =>
              'This email already has a password.',
            'network-request-failed' => "You're offline. Connect and try again.",
            _ => "Couldn't add a password. Try again.",
          });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Password accounts: attach Google so both sign-ins work.
  Future<void> _linkGoogle(User user) async {
    setState(() => _linkingGoogle = true);
    try {
      await user.linkWithProvider(GoogleAuthProvider());
      await user.reload();
      if (mounted) {
        setState(() {});
        showCanopySnack(context, 'Google linked. You can now sign in with email or Google.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted || e.code == 'canceled' || e.code == 'web-context-canceled') return;
      showCanopySnack(
          context,
          switch (e.code) {
            'credential-already-in-use' => 'That Google account is already used by another Canopy account.',
            'provider-already-linked' => 'Google is already linked.',
            _ => "Couldn't link Google. Try again.",
          },
          error: true);
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  Future<void> _reset(String email) async {
    setState(() => _sendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showCanopySnack(context, 'Reset link sent to $email.');
    } catch (_) {
      if (mounted) {
        showCanopySnack(context, "Couldn't send the reset link. Try again.", error: true);
      }
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Password & security'),
          body: const CanopySignedOutState());
    }
    final usesPassword = user.providerData.any((i) => i.providerId == 'password');
    final usesGoogle = user.providerData.any((i) => i.providerId == 'google.com');

    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Password & security'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.mail_outline,
              title: user.email ?? 'No email on this account',
              subtitle: 'Sign-in email',
            ),
          ]),
          const SizedBox(height: CanopySpace.section),
          CanopySectionHeader(title: 'Ways to sign in', padding: EdgeInsets.zero),
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.password_outlined,
              title: 'Email and password',
              subtitle: usesPassword ? 'Linked' : 'Not set. Add a password below',
              chevron: false,
            ),
            CanopyListRow(
              icon: Icons.account_circle_outlined,
              title: 'Google',
              subtitle: usesGoogle ? 'Linked' : 'Not linked',
              chevron: false,
              trailing: usesGoogle
                  ? null
                  : CanopyButton.quiet(label: 'Link', loading: _linkingGoogle, onPressed: () => _linkGoogle(user)),
            ),
          ]),
          const SizedBox(height: CanopySpace.section),
          if (!usesPassword) ...[
            CanopySectionHeader(title: 'Add a password', padding: EdgeInsets.zero),
            Text('So you can also sign in with ${user.email ?? 'your email'} and a password.',
                style: CanopyType.caption.copyWith(color: p.inkMuted)),
            const SizedBox(height: CanopySpace.s12),
            CanopyTextField(
              label: 'New password',
              controller: _next,
              obscure: true,
              helper: 'At least 8 characters.',
              textCapitalization: TextCapitalization.none,
              error: _showErrors ? _nextError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: CanopySpace.s16),
            CanopyTextField(
              label: 'Confirm password',
              controller: _confirm,
              obscure: true,
              textCapitalization: TextCapitalization.none,
              error: _showErrors ? _confirmError : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: CanopySpace.s12),
              CanopyCallout(kind: CalloutKind.danger, text: _serverError!),
            ],
          ] else ...[
            CanopySectionHeader(title: 'Change password', padding: EdgeInsets.zero),
            CanopyTextField(
              label: 'Current password',
              controller: _current,
              obscure: true,
              textCapitalization: TextCapitalization.none,
              error: _showErrors ? _currentError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: CanopySpace.s16),
            CanopyTextField(
              label: 'New password',
              controller: _next,
              obscure: true,
              helper: 'At least 8 characters.',
              textCapitalization: TextCapitalization.none,
              error: _showErrors ? _nextError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: CanopySpace.s16),
            CanopyTextField(
              label: 'Confirm new password',
              controller: _confirm,
              obscure: true,
              textCapitalization: TextCapitalization.none,
              error: _showErrors ? _confirmError : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: CanopySpace.s12),
              CanopyCallout(kind: CalloutKind.danger, text: _serverError!),
            ],
            const SizedBox(height: CanopySpace.section),
            Text('Forgot your current password?',
                style: CanopyType.bodyStrong.copyWith(color: p.ink)),
            Text("We'll email you a link to set a new one.",
                style: CanopyType.caption.copyWith(color: p.inkMuted)),
            Align(
              alignment: Alignment.centerLeft,
              child: CanopyButton.quiet(
                label: 'Email me a reset link',
                loading: _sendingReset,
                onPressed: user.email == null ? null : () => _reset(user.email!),
              ),
            ),
          ],
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
            label: usesPassword ? 'Change password' : 'Add password',
            expand: true,
            loading: _saving,
            onPressed: () => usesPassword ? _change(user) : _addPassword(user)),
      ]),
    );
  }
}
