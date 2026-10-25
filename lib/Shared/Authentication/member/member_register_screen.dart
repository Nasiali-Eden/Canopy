// lib/Shared/Authentication/member/member_register_screen.dart
//
// Member sign-up (v2): you (name, username, email) → password → where you
// live (county + area; this sets what the app shows by default). On
// success, straight to the guidelines gate — the account is already signed in.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../Services/Authentication/community_auth.dart';
import '../../../theme/canopy_components.dart';
import '../../widgets/legal_consent.dart';
import '../../Pages/community_guidelines.dart';
import '../../Pages/login.dart';
import '../components/choice_sheet.dart';
import '../components/username_field.dart';

class MemberRegisterScreen extends StatefulWidget {
  const MemberRegisterScreen({super.key});

  @override
  State<MemberRegisterScreen> createState() => _MemberRegisterScreenState();
}

class _MemberRegisterScreenState extends State<MemberRegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _username = TextEditingController();

  bool _obscure = true, _loading = false, _usernameOk = false, _showErrors = false;
  bool _agreed = false;
  String? _city, _area;
  Map<String, List<String>> _cities = {};
  bool _citiesFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _username]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final data = json.decode(await rootBundle.loadString('assets/Cities/African/KenyaCities.json')) as Map<String, dynamic>;
      final map = data['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _cities = {
          for (final e in map.entries)
            e.key: [for (final a in (e.value as List).cast<Map<String, dynamic>>()) (a['area'] ?? a['name']).toString()],
        };
        _city = _cities.containsKey('Nairobi') ? 'Nairobi' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _citiesFailed = true);
    }
  }

  static bool _emailOk(String v) => RegExp(r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$').hasMatch(v);

  String? get _nameError => _name.text.trim().isEmpty ? 'Add your name.' : null;
  String? get _emailError {
    final v = _email.text.trim();
    if (v.isEmpty) return 'Add your email.';
    return _emailOk(v) ? null : "That doesn't look like an email.";
  }

  String? get _passwordError => _password.text.length < 6 ? 'At least 6 characters.' : null;
  String? get _confirmError => _confirm.text != _password.text ? "Passwords don't match." : null;
  String? get _cityError => _city == null ? 'Choose your county or city.' : null;

  Future<void> _pickCity() async {
    final keys = _cities.keys.toList()..sort();
    final v = await showChoiceSheet(context, title: 'County or city', options: keys, selected: _city);
    if (v != null && v != _city) {
      setState(() {
        _city = v;
        _area = null;
      });
    }
  }

  Future<void> _pickArea() async {
    final areas = [...?_cities[_city]]..sort();
    final v = await showChoiceSheet(context, title: 'Area in $_city', options: areas, selected: _area);
    if (v != null) setState(() => _area = v);
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    final blocker = (!_agreed ? 'Confirm your age and agree to the Terms and Privacy policy.' : null) ??
        _nameError ??
        (!_usernameOk ? 'Choose an available username.' : null) ??
        _emailError ??
        _passwordError ??
        _confirmError ??
        _cityError;
    if (blocker != null) {
      showCanopySnack(context, blocker, error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await CommunityAuthService().registerWithEmail(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        role: 'Member',
        city: _city,
        area: _area,
        username: _username.text.trim(),
      );
      if (!mounted) return;
      if (user == null) {
        setState(() => _loading = false);
        showCanopySnack(context, "Couldn't create your account. Try again.", error: true);
        return;
      }
      await recordLegalConsent(user.uid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const CommunityGuidelinesScreen()), (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showCanopySnack(
        context,
        switch (e.code) {
          'email-already-in-use' => 'That email already has an account. Sign in instead.',
          'weak-password' => 'Choose a stronger password.',
          'network-request-failed' => 'No connection. Check your internet and try again.',
          _ => "Couldn't create your account. Try again.",
        },
        error: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showCanopySnack(context, "Couldn't create your account. Try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    String? err(String? e) => _showErrors ? e : null;
    void touch(_) => setState(() {});
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Join as a member'),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
          children: [
            const CanopySectionHeader(title: 'About you', padding: EdgeInsets.zero),
            CanopyTextField(label: 'Full name', controller: _name, error: err(_nameError), onChanged: touch, textCapitalization: TextCapitalization.words),
            const SizedBox(height: CanopySpace.s16),
            UsernameField(controller: _username, onAvailabilityChanged: (ok) => setState(() => _usernameOk = ok)),
            const SizedBox(height: CanopySpace.s16),
            CanopyTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              error: err(_emailError),
              onChanged: touch,
            ),
            const CanopySectionHeader(title: 'Password', padding: EdgeInsets.only(top: CanopySpace.section)),
            CanopyTextField(
              label: 'Password',
              controller: _password,
              obscure: _obscure,
              helper: 'At least 6 characters.',
              error: err(_passwordError),
              onChanged: touch,
              suffix: CanopyIconButton(
                icon: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: CanopySpace.s16),
            CanopyTextField(label: 'Confirm password', controller: _confirm, obscure: _obscure, error: err(_confirmError), onChanged: touch),
            const CanopySectionHeader(title: 'Where you live', padding: EdgeInsets.only(top: CanopySpace.section)),
            Text('Canopy shows activities, makers and news from here first. You can look elsewhere anytime.',
                style: CanopyType.caption.copyWith(color: p.inkMuted)),
            const SizedBox(height: CanopySpace.s12),
            if (_citiesFailed)
              CanopyCallout(
                kind: CalloutKind.warning,
                text: "Couldn't load the list of places.",
                action: TextButton(
                  onPressed: () {
                    setState(() => _citiesFailed = false);
                    _loadCities();
                  },
                  child: const Text('Try again'),
                ),
              )
            else ...[
              CanopyPickerField(label: 'Country', value: 'Kenya', icon: Icons.lock_outline, onTap: () {}),
              const SizedBox(height: CanopySpace.s16),
              CanopyPickerField(
                label: 'County or city',
                value: _city,
                placeholder: _cities.isEmpty ? 'Loading…' : 'Choose',
                error: err(_cityError),
                onTap: _cities.isEmpty ? () {} : _pickCity,
              ),
              const SizedBox(height: CanopySpace.s16),
              CanopyPickerField(
                label: 'Area (optional)',
                value: _area,
                placeholder: _city == null ? 'Choose a county first' : 'Choose',
                onTap: _city == null || (_cities[_city]?.isEmpty ?? true) ? () {} : _pickArea,
              ),
            ],
          ],
        ),
      ),
      sticky: StickyActionBar(children: [
        LegalConsentRow(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v),
          error: _showErrors && !_agreed ? 'Required to create an account.' : null,
        ),
        CanopyButton(label: 'Create account', expand: true, loading: _loading, onPressed: _loading ? null : _submit),
        const SizedBox(height: CanopySpace.s8),
        CanopyButton(
          label: 'I already have an account',
          variant: CanopyButtonVariant.quiet,
          expand: true,
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
        ),
      ]),
    );
  }
}
