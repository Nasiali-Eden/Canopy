// lib/Shared/Authentication/organization/org_register_wizard.dart
//
// Register an organisation (v2), six steps, one per screen:
//   1 Account  2 What you do  3 Who you serve  4 Where  5 Logo  6 Review
// Next validates only the current step; Back (or system back) returns one
// step. On success → the guidelines gate (the new rep is signed in).

import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Services/Authentication/community_auth.dart';
import '../../../theme/canopy_components.dart';
import '../../Pages/community_guidelines.dart';
import '../components/choice_sheet.dart';
import '../models/org_taxonomy_models.dart';

class OrgRegisterWizard extends StatefulWidget {
  const OrgRegisterWizard({super.key});

  @override
  State<OrgRegisterWizard> createState() => _OrgRegisterWizardState();
}

class _OrgRegisterWizardState extends State<OrgRegisterWizard> {
  static const _labels = ['Account', 'What you do', 'Who you serve', 'Where', 'Logo', 'Review'];
  int _step = 0;
  bool _showErrors = false, _submitting = false, _obscure = true;

  // 1 Account
  final _orgName = TextEditingController();
  final _repName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // 2 What you do
  OrgSector? _sector;
  OrgType? _type;
  final Set<String> _subTypeIds = {};
  LegalDesignation? _designation;
  final _background = TextEditingController();
  final List<TextEditingController> _functions = List.generate(5, (_) => TextEditingController());

  // 3 Who you serve
  final Set<String> _beneficiaryIds = {};

  // 4 Where
  Map<String, List<Map<String, dynamic>>> _cities = {};
  bool _citiesFailed = false;
  String? _city, _area;

  // 5 Logo
  XFile? _logo;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    for (final c in [_orgName, _repName, _email, _password, _confirm, _background, ..._functions]) {
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
        _cities = {for (final e in map.entries) e.key: (e.value as List).cast<Map<String, dynamic>>()};
        _city ??= _cities.containsKey('Nairobi') ? 'Nairobi' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _citiesFailed = true);
    }
  }

  List<String> _areasOf(String? city) => [for (final e in _cities[city] ?? const []) (e['area'] ?? e['name']).toString()];

  ({double? lat, double? lng}) _coordinates() {
    final entries = _cities[_city];
    if (entries == null || entries.isEmpty) return (lat: null, lng: null);
    final match = entries.firstWhere((e) => (e['area'] ?? e['name']).toString() == _area, orElse: () => entries.first);
    final c = match['coordinates'] as Map<String, dynamic>?;
    return (lat: (c?['lat'] as num?)?.toDouble(), lng: (c?['lng'] as num?)?.toDouble());
  }

  // ── validation ──────────────────────────────────────────────────────────

  static bool _emailOk(String v) => RegExp(r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$').hasMatch(v);

  String? get _orgNameError => _orgName.text.trim().isEmpty ? "Add your organisation's name." : null;
  String? get _repNameError => _repName.text.trim().isEmpty ? 'Add your name.' : null;
  String? get _emailError => _emailOk(_email.text.trim()) ? null : 'Add a valid email.';
  String? get _passwordError => _password.text.length < 6 ? 'At least 6 characters.' : null;
  String? get _confirmError => _confirm.text != _password.text ? "Passwords don't match." : null;
  String? get _backgroundError => _background.text.trim().isEmpty ? 'Say a little about what you do.' : null;
  String? get _functionError => _functions.first.text.trim().isEmpty ? 'Add at least one main activity.' : null;

  String? _blocker(int step) => switch (step) {
        0 => _orgNameError ?? _repNameError ?? _emailError ?? _passwordError ?? _confirmError,
        1 => (_sector == null ? 'Choose a sector.' : null) ??
            (_type == null ? 'Choose what kind of organisation you are.' : null) ??
            _backgroundError ??
            _functionError,
        2 => _beneficiaryIds.isEmpty ? 'Choose at least one group you serve.' : null,
        3 => _city == null ? 'Choose your county or city.' : null,
        _ => null,
      };

  void _next() {
    final b = _blocker(_step);
    if (b != null) {
      setState(() => _showErrors = true);
      showCanopySnack(context, b, error: true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _showErrors = false;
        _step--;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final coords = _coordinates();
      final user = await CommunityAuthService().registerAsOrganization(
        email: _email.text.trim(),
        password: _password.text,
        orgName: _orgName.text.trim(),
        orgRepName: _repName.text.trim(),
        background: _background.text.trim(),
        mainFunctions: [for (final c in _functions) if (c.text.trim().isNotEmpty) c.text.trim()],
        orgDesignation: _designation?.acronym ?? '',
        sectorId: _sector?.id ?? '',
        orgTypeId: _type?.id ?? '',
        subTypeIds: _subTypeIds.toList(),
        beneficiaryGroupIds: _beneficiaryIds.toList(),
        facilityTypeIds: _type?.facilityIds ?? const [],
        country: 'Kenya',
        city: _city ?? '',
        area: _area ?? '',
        lat: coords.lat,
        lng: coords.lng,
        profilePhoto: _logo,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() => _submitting = false);
        showCanopySnack(context, "Couldn't register the organisation. Try again.", error: true);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const CommunityGuidelinesScreen()), (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showCanopySnack(
        context,
        switch (e.code) {
          'email-already-in-use' => 'That email already has an account. Go back to step 1 and use another.',
          'network-request-failed' => 'No connection. Check your internet and try again.',
          _ => "Couldn't register the organisation. Try again.",
        },
        error: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showCanopySnack(context, "Couldn't register the organisation. Try again.", error: true);
    }
  }

  // ── steps ───────────────────────────────────────────────────────────────

  String? _err(String? e) => _showErrors ? e : null;
  void _touch(_) => setState(() {});

  List<Widget> _account() => [
        CanopyTextField(label: 'Organisation name', controller: _orgName, error: _err(_orgNameError), onChanged: _touch, textCapitalization: TextCapitalization.words),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(
          label: 'Your name',
          helper: "You'll manage the organisation's account.",
          controller: _repName,
          error: _err(_repNameError),
          onChanged: _touch,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, error: _err(_emailError), onChanged: _touch),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(
          label: 'Password',
          controller: _password,
          obscure: _obscure,
          helper: 'At least 6 characters.',
          error: _err(_passwordError),
          onChanged: _touch,
          suffix: CanopyIconButton(
            icon: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Confirm password', controller: _confirm, obscure: _obscure, error: _err(_confirmError), onChanged: _touch),
      ];

  List<Widget> _whatYouDo() {
    final p = context.canopy;
    return [
      const CanopySectionHeader(title: 'Sector', padding: EdgeInsets.zero),
      for (final s in kSectors) ...[
        CanopyOptionCard(
          selected: _sector?.id == s.id,
          title: s.label,
          caption: s.description.isEmpty ? null : s.description,
          onTap: () => setState(() {
            if (_sector?.id != s.id) {
              _sector = s;
              _type = null;
              _subTypeIds.clear();
            }
          }),
        ),
        const SizedBox(height: CanopySpace.s8),
      ],
      if (_showErrors && _sector == null) Text('Choose one.', style: CanopyType.caption.copyWith(color: p.danger)),
      if (_sector != null) ...[
        const CanopySectionHeader(title: 'Kind of organisation', padding: EdgeInsets.only(top: CanopySpace.section)),
        Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
          for (final t in _sector!.orgTypes)
            CanopyFilterChip(
              label: t.label,
              selected: _type?.id == t.id,
              onTap: () => setState(() {
                if (_type?.id != t.id) {
                  _type = t;
                  _subTypeIds.clear();
                }
              }),
            ),
        ]),
        if (_showErrors && _type == null) ...[
          const SizedBox(height: CanopySpace.s4),
          Text('Choose one.', style: CanopyType.caption.copyWith(color: p.danger)),
        ],
      ],
      if (_type != null && _type!.subTypes.isNotEmpty) ...[
        const CanopySectionHeader(title: 'Focus (optional, pick any)', padding: EdgeInsets.only(top: CanopySpace.section)),
        Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
          for (final st in _type!.subTypes)
            CanopyFilterChip(
              label: st.label,
              selected: _subTypeIds.contains(st.id),
              onTap: () => setState(() => _subTypeIds.contains(st.id) ? _subTypeIds.remove(st.id) : _subTypeIds.add(st.id)),
            ),
        ]),
      ],
      const SizedBox(height: CanopySpace.section),
      CanopyPickerField(
        label: 'Legal registration (optional)',
        value: _designation == null ? null : '${_designation!.acronym} · ${_designation!.fullForm}',
        onTap: () async {
          final opts = [for (final d in kLegalDesignations) '${d.acronym} · ${d.fullForm}'];
          final v = await showChoiceSheet(context, title: 'Legal registration', options: opts, selected: null);
          if (v != null) setState(() => _designation = kLegalDesignations[opts.indexOf(v)]);
        },
      ),
      const SizedBox(height: CanopySpace.s16),
      CanopyTextField(
        label: 'About the organisation',
        hint: 'Who you are and what you do, in a few sentences.',
        controller: _background,
        minLines: 3,
        maxLines: 6,
        error: _err(_backgroundError),
        onChanged: _touch,
      ),
      const CanopySectionHeader(title: 'Main activities', padding: EdgeInsets.only(top: CanopySpace.section)),
      for (var i = 0; i < _functions.length; i++) ...[
        CanopyTextField(
          label: i == 0 ? 'Activity 1' : 'Activity ${i + 1} (optional)',
          hint: i == 0 ? 'e.g. Weekly river clean-ups' : null,
          controller: _functions[i],
          error: i == 0 ? _err(_functionError) : null,
          onChanged: _touch,
        ),
        const SizedBox(height: CanopySpace.s12),
      ],
    ];
  }

  List<Widget> _whoYouServe() {
    final p = context.canopy;
    return [
      Text('Choose every group you work with.', style: CanopyType.body.copyWith(color: p.inkMuted)),
      const SizedBox(height: CanopySpace.s16),
      Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
        for (final b in kBeneficiaryGroups)
          CanopyFilterChip(
            label: b.label,
            selected: _beneficiaryIds.contains(b.id),
            onTap: () => setState(() => _beneficiaryIds.contains(b.id) ? _beneficiaryIds.remove(b.id) : _beneficiaryIds.add(b.id)),
          ),
      ]),
      if (_showErrors && _beneficiaryIds.isEmpty) ...[
        const SizedBox(height: CanopySpace.s8),
        Text('Choose at least one.', style: CanopyType.caption.copyWith(color: p.danger)),
      ],
    ];
  }

  List<Widget> _where() {
    final p = context.canopy;
    if (_citiesFailed) {
      return [
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
        ),
      ];
    }
    return [
      Text('Your organisation appears on the map and in searches here.', style: CanopyType.body.copyWith(color: p.inkMuted)),
      const SizedBox(height: CanopySpace.s16),
      CanopyPickerField(label: 'Country', value: 'Kenya', icon: Icons.lock_outline, onTap: () {}),
      const SizedBox(height: CanopySpace.s16),
      CanopyPickerField(
        label: 'County or city',
        value: _city,
        placeholder: _cities.isEmpty ? 'Loading…' : 'Choose',
        error: _showErrors && _city == null ? 'Choose one.' : null,
        onTap: () async {
          if (_cities.isEmpty) return;
          final v = await showChoiceSheet(context, title: 'County or city', options: _cities.keys.toList()..sort(), selected: _city);
          if (v != null && v != _city) {
            setState(() {
              _city = v;
              _area = null;
            });
          }
        },
      ),
      const SizedBox(height: CanopySpace.s16),
      CanopyPickerField(
        label: 'Area (optional)',
        value: _area,
        placeholder: _city == null ? 'Choose a county first' : 'Choose',
        onTap: () async {
          final areas = _areasOf(_city)..sort();
          if (areas.isEmpty) return;
          final v = await showChoiceSheet(context, title: 'Area in $_city', options: areas, selected: _area);
          if (v != null) setState(() => _area = v);
        },
      ),
    ];
  }

  List<Widget> _logoStep() {
    final p = context.canopy;
    Future<void> pick() async {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
      if (f != null) setState(() => _logo = f);
    }

    return [
      Text('Your logo shows on your public page and as your pin on the map. You can add it later.',
          style: CanopyType.body.copyWith(color: p.inkMuted)),
      const SizedBox(height: CanopySpace.s16),
      Center(
        child: Semantics(
          button: true,
          label: _logo == null ? 'Add logo' : 'Change logo',
          child: InkWell(
            onTap: pick,
            borderRadius: BorderRadius.circular(CanopyRadius.lg),
            child: _logo == null
                ? DashedBorder(
                    color: p.outlineStrong,
                    radius: CanopyRadius.lg,
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 32, color: p.inkMuted),
                        const SizedBox(height: CanopySpace.s8),
                        Text('Add logo', style: CanopyType.label.copyWith(color: p.ink)),
                        Text('Square works best', style: CanopyType.caption.copyWith(color: p.inkMuted)),
                      ]),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(CanopyRadius.lg),
                    child: Image.file(File(_logo!.path), width: 160, height: 160, fit: BoxFit.cover),
                  ),
          ),
        ),
      ),
      if (_logo != null) ...[
        const SizedBox(height: CanopySpace.s12),
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CanopyButton(label: 'Change', variant: CanopyButtonVariant.quiet, size: CanopyButtonSize.compact, onPressed: pick),
            CanopyButton(
              label: 'Remove',
              variant: CanopyButtonVariant.quietDanger,
              size: CanopyButtonSize.compact,
              onPressed: () => setState(() => _logo = null),
            ),
          ]),
        ),
      ],
    ];
  }

  List<Widget> _review() {
    final p = context.canopy;
    final functions = [for (final c in _functions) if (c.text.trim().isNotEmpty) c.text.trim()];
    final served = [for (final b in kBeneficiaryGroups) if (_beneficiaryIds.contains(b.id)) b.label];
    Widget edit(int step) => TextButton(onPressed: () => setState(() => _step = step), child: const Text('Edit'));
    return [
      Row(children: [
        _logo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(CanopyRadius.sm),
                child: Image.file(File(_logo!.path), width: 56, height: 56, fit: BoxFit.cover),
              )
            : CanopyAvatar(name: _orgName.text.trim(), size: 56, org: true),
        const SizedBox(width: CanopySpace.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_orgName.text.trim(), style: CanopyType.title.copyWith(color: p.ink)),
            Text('Managed by ${_repName.text.trim()}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
          ]),
        ),
      ]),
      const SizedBox(height: CanopySpace.s16),
      Row(children: [const Expanded(child: CanopySectionHeader(title: 'Account', padding: EdgeInsets.zero)), edit(0)]),
      CanopyListGroup(children: [CanopyFactRow(label: 'Email', value: _email.text.trim())]),
      Row(children: [const Expanded(child: CanopySectionHeader(title: 'What you do', padding: EdgeInsets.zero)), edit(1)]),
      CanopyListGroup(children: [
        CanopyFactRow(label: 'Sector', value: _sector?.label ?? '–'),
        CanopyFactRow(label: 'Kind', value: _type?.label ?? '–'),
        if (_designation != null) CanopyFactRow(label: 'Legal registration', value: _designation!.acronym),
        if (functions.isNotEmpty) CanopyFactRow(label: 'Main activities', value: functions.join(' · ')),
      ]),
      Row(children: [const Expanded(child: CanopySectionHeader(title: 'Who you serve', padding: EdgeInsets.zero)), edit(2)]),
      CanopyListGroup(children: [CanopyFactRow(label: 'Groups', value: served.join(', '))]),
      Row(children: [const Expanded(child: CanopySectionHeader(title: 'Where', padding: EdgeInsets.zero)), edit(3)]),
      CanopyListGroup(children: [
        CanopyFactRow(label: 'Location', value: [_area, _city, 'Kenya'].whereType<String>().where((s) => s.isNotEmpty).join(', ')),
      ]),
      const SizedBox(height: CanopySpace.s16),
      const CanopyCallout(
        kind: CalloutKind.info,
        text: 'Next you will agree to the community guidelines. Then you can add events, invite people and apply for '
            'the Marketplace, Field operations or Cultural archive.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      0 => _account(),
      1 => _whatYouDo(),
      2 => _whoYouServe(),
      3 => _where(),
      4 => _logoStep(),
      _ => _review(),
    };
    final last = _step == _labels.length - 1;
    return PopScope(
      canPop: _step == 0 && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) _back();
      },
      child: CanopyScaffold(
        appBar: canopyAppBar(context, title: 'Register organisation'),
        body: ListView(
          key: ValueKey(_step),
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
          children: [
            CanopyStepper(step: _step + 1, total: _labels.length, label: _labels[_step]),
            const SizedBox(height: CanopySpace.section),
            ...body,
          ],
        ),
        sticky: StickyActionBar(children: [
          Row(children: [
            if (_step > 0) ...[
              Expanded(
                child: CanopyButton(label: 'Back', variant: CanopyButtonVariant.secondary, onPressed: _submitting ? null : _back),
              ),
              const SizedBox(width: CanopySpace.s12),
            ],
            Expanded(
              flex: 2,
              child: last
                  ? CanopyButton(label: 'Register', loading: _submitting, onPressed: _submitting ? null : _submit)
                  : CanopyButton(label: _step == 4 && _logo == null ? 'Skip for now' : 'Next', onPressed: _next),
            ),
          ]),
        ]),
      ),
    );
  }
}
