import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../Pages/community_guidelines.dart';
import '../models/org_taxonomy_models.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  OrgRegisterWizard  –  single-scroll, progressive-unlock sections
// ─────────────────────────────────────────────────────────────────────────────

class OrgRegisterWizard extends StatefulWidget {
  const OrgRegisterWizard({super.key});

  @override
  State<OrgRegisterWizard> createState() => _OrgRegisterWizardState();
}

class _OrgRegisterWizardState extends State<OrgRegisterWizard>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Section completion flags – each unlocks the next section
  bool _s1Done = false; // Basics
  bool _s2Done = false; // Classification
  bool _s3Done = false; // Beneficiaries
  bool _s4Done = false; // Location
  bool _s5Done = false; // Logo
  bool _submitting = false;

  // ── Section 1: Basics ──────────────────────────────────────────────────────
  final _orgNameCtrl = TextEditingController();
  final _repNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // ── Section 2: Classification ──────────────────────────────────────────────
  OrgSector? _sector;
  OrgType? _orgType;
  List<String> _subTypeIds = [];
  LegalDesignation? _designation;
  final _backgroundCtrl = TextEditingController();
  final List<TextEditingController> _funcCtrl =
  List.generate(5, (_) => TextEditingController());

  // ── Section 3: Beneficiaries ───────────────────────────────────────────────
  Set<String> _beneficiaryIds = {};

  // ── Section 4: Location ────────────────────────────────────────────────────
  String? _selectedCity;
  String? _selectedArea;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  // ── Section 5: Logo ────────────────────────────────────────────────────────
  XFile? _logo;

  // Section keys for scrolling
  final List<GlobalKey> _sectionKeys = List.generate(6, (_) => GlobalKey());

  late AnimationController _entryAnim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entryAnim =
    AnimationController(duration: const Duration(milliseconds: 500), vsync: this)
      ..forward();
    _fade = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut));
    _loadCities();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entryAnim.dispose();
    _orgNameCtrl.dispose();
    _repNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _backgroundCtrl.dispose();
    for (final c in _funcCtrl) c.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final js = await rootBundle
          .loadString('assets/Cities/African/KenyaCities.json');
      final data = json.decode(js) as Map<String, dynamic>;
      final map = data['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      final parsed = <String, List<Map<String, dynamic>>>{};
      for (final e in map.entries) {
        parsed[e.key] = (e.value as List).cast<Map<String, dynamic>>();
      }
      setState(() {
        _kenyaCities = parsed;
        _selectedCity = parsed.containsKey('Nairobi')
            ? 'Nairobi'
            : (parsed.keys.isNotEmpty ? parsed.keys.first : null);
      });
    } catch (e) {
      debugPrint('City load error: $e');
    }
  }

  void _scrollToSection(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0);
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final auth = CommunityAuthService();
      final funcs = _funcCtrl
          .map((c) => c.text.trim())
          .where((f) => f.isNotEmpty)
          .toList();
      final user = await auth.registerAsOrganization(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        orgName: _orgNameCtrl.text.trim(),
        orgRepName: _repNameCtrl.text.trim(),
        background: _backgroundCtrl.text.trim(),
        mainFunctions: funcs,
        orgDesignation: _designation?.acronym ?? '',
        profilePhoto: _logo,
      );
      if (!mounted) return;
      if (user == null) {
        _showError('Could not create organisation. Please try again.');
        return;
      }
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const CommunityGuidelinesScreen()));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── completion checks ─────────────────────────────────────────────────────

  bool _validateS1() {
    if (_orgNameCtrl.text.trim().isEmpty) {
      _showError('Organisation name is required.');
      return false;
    }
    if (_repNameCtrl.text.trim().isEmpty) {
      _showError('Representative name is required.');
      return false;
    }
    if (!_emailCtrl.text.contains('@')) {
      _showError('Enter a valid email address.');
      return false;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Password must be at least 6 characters.');
      return false;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _showError('Passwords do not match.');
      return false;
    }
    return true;
  }

  bool _validateS2() {
    if (_sector == null) {
      _showError('Please select a sector.');
      return false;
    }
    if (_orgType == null) {
      _showError('Please select an organisation type.');
      return false;
    }
    if (_backgroundCtrl.text.trim().isEmpty) {
      _showError('Please provide a background description.');
      return false;
    }
    return true;
  }

  bool _validateS3() {
    if (_beneficiaryIds.isEmpty) {
      _showError('Please select at least one beneficiary group.');
      return false;
    }
    return true;
  }

  bool _validateS4() {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showError('Please select a city.');
      return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 15, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Register Organisation',
          style: TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress bar
                  _ProgressBar(
                    completedSections: [
                      _s1Done,
                      _s2Done,
                      _s3Done,
                      _s4Done,
                      _s5Done
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Section 1: Basics ─────────────────────────────────
                  _SectionWrapper(
                    key: _sectionKeys[0],
                    index: 1,
                    title: 'Organisation Basics',
                    icon: Icons.business_outlined,
                    subtitle: 'Account credentials and representative info',
                    isLocked: false,
                    isDone: _s1Done,
                    child: _buildBasicsSection(),
                    onComplete: _s1Done
                        ? null
                        : () {
                      if (_validateS1()) {
                        setState(() => _s1Done = true);
                        _scrollToSection(1);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Section 2: Classification ──────────────────────────
                  _SectionWrapper(
                    key: _sectionKeys[1],
                    index: 2,
                    title: 'Classification',
                    icon: Icons.category_outlined,
                    subtitle: 'Sector, type, legal designation & background',
                    isLocked: !_s1Done,
                    isDone: _s2Done,
                    child: _buildClassificationSection(),
                    onComplete: _s2Done
                        ? null
                        : () {
                      if (_validateS2()) {
                        setState(() => _s2Done = true);
                        _scrollToSection(2);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Section 3: Beneficiaries ───────────────────────────
                  _SectionWrapper(
                    key: _sectionKeys[2],
                    index: 3,
                    title: 'Beneficiaries',
                    icon: Icons.people_alt_outlined,
                    subtitle: 'Who does your organisation serve?',
                    isLocked: !_s2Done,
                    isDone: _s3Done,
                    child: _buildBeneficiariesSection(),
                    onComplete: _s3Done
                        ? null
                        : () {
                      if (_validateS3()) {
                        setState(() => _s3Done = true);
                        _scrollToSection(3);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Section 4: Location ────────────────────────────────
                  _SectionWrapper(
                    key: _sectionKeys[3],
                    index: 4,
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    subtitle: 'Where is your organisation based?',
                    isLocked: !_s3Done,
                    isDone: _s4Done,
                    child: _buildLocationSection(),
                    onComplete: _s4Done
                        ? null
                        : () {
                      if (_validateS4()) {
                        setState(() => _s4Done = true);
                        _scrollToSection(4);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Section 5: Logo ────────────────────────────────────
                  _SectionWrapper(
                    key: _sectionKeys[4],
                    index: 5,
                    title: 'Logo',
                    icon: Icons.image_outlined,
                    subtitle: 'Your organisation\'s visual identity on the map',
                    isLocked: !_s4Done,
                    isDone: _s5Done,
                    child: _buildLogoSection(),
                    onComplete: _s5Done
                        ? null
                        : () {
                      setState(() => _s5Done = true);
                      _scrollToSection(5);
                    },
                    completeLabel:
                    _logo != null ? 'Logo Added — Continue' : 'Skip — Add Later',
                    completeIcon: _logo != null
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                  ),
                  const SizedBox(height: 16),

                  // ── Section 6: Review & Submit ─────────────────────────
                  _SectionWrapper(
                    key: _sectionKeys[5],
                    index: 6,
                    title: 'Review & Submit',
                    icon: Icons.fact_check_outlined,
                    subtitle: 'Confirm your details before registering',
                    isLocked: !_s5Done,
                    isDone: false,
                    showCompleteButton: false,
                    child: _buildReviewSection(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SECTION CONTENT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBasicsSection() {
    const accent = AppTheme.primary;
    return Column(children: [
      _field(
        controller: _orgNameCtrl,
        label: 'Organisation Name',
        icon: Icons.business_outlined,
        accent: accent,
        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      _field(
        controller: _repNameCtrl,
        label: 'Representative Name',
        icon: Icons.person_outline,
        accent: accent,
        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      _field(
        controller: _emailCtrl,
        label: 'Email Address',
        icon: Icons.email_outlined,
        accent: accent,
        keyboardType: TextInputType.emailAddress,
        validator: (v) =>
        v!.contains('@') ? null : 'Enter a valid email',
      ),
      const SizedBox(height: 14),
      _passwordField(
        controller: _passwordCtrl,
        label: 'Password',
        obscure: _obscurePass,
        onToggle: () => setState(() => _obscurePass = !_obscurePass),
        accent: accent,
      ),
      const SizedBox(height: 14),
      _passwordField(
        controller: _confirmCtrl,
        label: 'Confirm Password',
        obscure: _obscureConfirm,
        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        accent: accent,
        validator: (v) =>
        v != _passwordCtrl.text ? 'Passwords do not match' : null,
      ),
    ]);
  }

  Widget _buildClassificationSection() {
    const accent = Color(0xFF0097A7);
    return Column(children: [
      // Sector
      DropdownButtonFormField<OrgSector>(
        value: _sector,
        dropdownColor: Colors.white,
        style: const TextStyle(
            color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: accent.withOpacity(0.6), size: 20),
        decoration: _inputDec(label: 'Sector', icon: Icons.category_outlined, accent: accent),
        items: kSectors
            .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
            .toList(),
        onChanged: (v) => setState(() { _sector = v; _orgType = null; }),
        validator: (v) => v == null ? 'Please select a sector' : null,
      ),
      const SizedBox(height: 14),
      // Org Type
      DropdownButtonFormField<OrgType>(
        value: _orgType,
        dropdownColor: Colors.white,
        style: const TextStyle(
            color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: accent.withOpacity(0.6), size: 20),
        decoration: _inputDec(label: 'Organisation Type', icon: Icons.account_tree_outlined, accent: accent),
        items: (_sector?.orgTypes ?? [])
            .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
            .toList(),
        onChanged: (v) => setState(() => _orgType = v),
        validator: (v) => v == null ? 'Please select a type' : null,
      ),
      const SizedBox(height: 14),
      // Legal designation
      DropdownButtonFormField<LegalDesignation>(
        value: _designation,
        dropdownColor: Colors.white,
        style: const TextStyle(
            color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: accent.withOpacity(0.6), size: 20),
        decoration: _inputDec(label: 'Legal Designation', icon: Icons.gavel_outlined, accent: accent),
        items: kLegalDesignations
            .map((d) =>
            DropdownMenuItem(value: d, child: Text('${d.acronym} — ${d.fullForm}')))
            .toList(),
        onChanged: (v) => setState(() => _designation = v),
      ),
      const SizedBox(height: 14),
      // Background
      TextFormField(
        controller: _backgroundCtrl,
        maxLines: 4,
        style: const TextStyle(
            color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: _inputDec(
            label: 'Organisation Background', icon: Icons.notes_outlined, accent: accent),
        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      // Functions
      ...List.generate(
        _funcCtrl.length,
            (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: _funcCtrl[i],
            style: const TextStyle(
                color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
            decoration: _inputDec(
              label: 'Main Function ${i + 1}${i == 0 ? ' *' : ' (optional)'}',
              icon: Icons.bolt_outlined,
              accent: accent,
            ),
            validator: i == 0
                ? (v) => v!.trim().isEmpty ? 'At least one function required' : null
                : null,
          ),
        ),
      ),
    ]);
  }

  Widget _buildBeneficiariesSection() {
    const accent = AppTheme.tertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select all that apply',
            style: TextStyle(
                fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6))),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kBeneficiaryGroups
              .map((b) => _SelectChip(
            label: b.label,
            icon: b.icon,
            selected: _beneficiaryIds.contains(b.id),
            accent: AppTheme.tertiary,
            onTap: () {
              setState(() {
                if (_beneficiaryIds.contains(b.id)) {
                  _beneficiaryIds.remove(b.id);
                } else {
                  _beneficiaryIds.add(b.id);
                }
              });
            },
          ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    final cities = _kenyaCities.keys.toList()..sort();
    final areas = (_selectedCity != null && _kenyaCities[_selectedCity!] != null)
        ? _kenyaCities[_selectedCity!]!
        .map((e) => (e['area'] ?? e['name']).toString())
        .toList()
        : <String>[];
    const accent = AppTheme.accent;

    return Column(children: [
      // Country (fixed)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: accent.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _IconPill(icon: Icons.public, color: accent),
          const SizedBox(width: 12),
          Text('Kenya',
              style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _selectedCity,
        dropdownColor: Colors.white,
        menuMaxHeight: 280,
        style: const TextStyle(
            color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: accent.withOpacity(0.6), size: 20),
        decoration: _inputDec(label: 'City / County', icon: Icons.location_city, accent: accent),
        items: cities
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedCity = v;
          _selectedArea = null;
        }),
        validator: (v) => (v == null || v.isEmpty) ? 'City is required' : null,
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _selectedArea,
        dropdownColor: Colors.white,
        menuMaxHeight: 280,
        style: const TextStyle(
            color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: accent.withOpacity(0.6), size: 20),
        decoration:
        _inputDec(label: 'Area / Neighbourhood (optional)', icon: Icons.pin_drop_outlined, accent: accent),
        items: areas
            .map((a) => DropdownMenuItem(value: a, child: Text(a)))
            .toList(),
        onChanged: (v) => setState(() => _selectedArea = v),
      ),
    ]);
  }

  Widget _buildLogoSection() {
    return Column(children: [
      GestureDetector(
        onTap: () async {
          final picker = ImagePicker();
          final file = await picker.pickImage(source: ImageSource.gallery);
          if (file != null) setState(() => _logo = file);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _logo != null
                  ? AppTheme.primary
                  : AppTheme.lightGreen.withOpacity(0.4),
              width: _logo != null ? 2.5 : 1.5,
            ),
          ),
          child: _logo != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(File(_logo!.path), fit: BoxFit.contain),
          )
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  size: 28, color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            const Text('Tap to upload logo (PNG)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen)),
            const SizedBox(height: 4),
            Text('Transparent PNG · 256×256px recommended',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGreen.withOpacity(0.45))),
          ]),
        ),
      ),
      if (_logo != null) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _logo = null),
            icon: Icon(Icons.close, size: 14, color: Colors.red.shade400),
            label: Text('Remove',
                style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
          ),
        ),
      ],
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Your logo becomes a custom map pin. It will be visible to all platform users.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.amber.shade900))),
        ]),
      ),
    ]);
  }

  Widget _buildReviewSection() {
    if (!_s5Done) {
      return const SizedBox.shrink();
    }
    final funcs = _funcCtrl
        .map((c) => c.text.trim())
        .where((f) => f.isNotEmpty)
        .toList();
    return Column(children: [
      // Summary card
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withOpacity(0.06),
              AppTheme.secondary.withOpacity(0.03)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Column(children: [
          // Logo + name
          Row(children: [
            _logo != null
                ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(_logo!.path),
                    width: 52, height: 52, fit: BoxFit.contain))
                : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business,
                    color: Colors.white, size: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_orgNameCtrl.text,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(_repNameCtrl.text,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGreen.withOpacity(0.6))),
                  ]),
            ),
          ]),
          const Divider(height: 24),
          _reviewRow(Icons.email_outlined, 'Email', _emailCtrl.text),
          _reviewRow(Icons.category_outlined, 'Sector', _sector?.label ?? '—'),
          _reviewRow(
              Icons.account_tree_outlined, 'Type', _orgType?.label ?? '—'),
          _reviewRow(Icons.gavel_outlined, 'Designation',
              _designation?.acronym ?? '—'),
          _reviewRow(Icons.people_alt_outlined, 'Beneficiaries',
              _beneficiaryIds.isEmpty
                  ? '—'
                  : _beneficiaryIds
                  .map((id) => kBeneficiaryGroups
                  .firstWhere((b) => b.id == id,
                  orElse: () => const BeneficiaryGroup(
                      id: '', label: '', icon: '', color: ''))
                  .label)
                  .join(', ')),
          _reviewRow(Icons.location_on_outlined, 'Location',
              [_selectedArea, _selectedCity, 'Kenya']
                  .where((s) => s != null && s!.isNotEmpty)
                  .join(', ')),
          if (funcs.isNotEmpty)
            _reviewRow(Icons.bolt_outlined, 'Functions', funcs.join(' · ')),
        ]),
      ),
      const SizedBox(height: 24),
      // Submit
      _GradientButton(
        label: 'Register Organisation',
        icon: Icons.eco_outlined,
        isLoading: _submitting,
        onPressed: _submitting ? null : _submit,
      ),
    ]);
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: AppTheme.primary.withOpacity(0.7)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.5),
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color accent,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
          color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: _inputDec(label: label, icon: icon, accent: accent),
      validator: validator,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required Color accent,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
          color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: _inputDec(label: label, icon: Icons.lock_outline, accent: accent).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: accent.withOpacity(0.55),
            size: 18,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator ?? (v) => v!.length < 6 ? 'At least 6 characters' : null,
    );
  }

  InputDecoration _inputDec(
      {required String label, required IconData icon, required Color accent}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: accent.withOpacity(0.75), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(10),
        child: _IconPill(icon: icon, color: accent),
      ),
      prefixIconConstraints:
      const BoxConstraints(minWidth: 52, minHeight: 52),
      border: _border(accent.withOpacity(0.2)),
      enabledBorder: _border(accent.withOpacity(0.22)),
      focusedBorder: _border(accent, width: 2),
      errorBorder: _border(Colors.red.shade300),
      focusedErrorBorder: _border(Colors.red.shade400, width: 2),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width));
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SectionWrapper  –  the progressive-lock container
// ─────────────────────────────────────────────────────────────────────────────

class _SectionWrapper extends StatefulWidget {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLocked;
  final bool isDone;
  final Widget child;
  final VoidCallback? onComplete;
  final String? completeLabel;
  final IconData? completeIcon;
  final bool showCompleteButton;

  const _SectionWrapper({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLocked,
    required this.isDone,
    required this.child,
    this.onComplete,
    this.completeLabel,
    this.completeIcon,
    this.showCompleteButton = true,
  });

  @override
  State<_SectionWrapper> createState() => _SectionWrapperState();
}

class _SectionWrapperState extends State<_SectionWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _unlockAnim;
  late Animation<double> _unlockFade;
  late Animation<double> _unlockScale;
  bool _wasLocked = true;

  @override
  void initState() {
    super.initState();
    _wasLocked = widget.isLocked;
    _unlockAnim = AnimationController(
        duration: const Duration(milliseconds: 450), vsync: this);
    _unlockFade =
        CurvedAnimation(parent: _unlockAnim, curve: Curves.easeOut);
    _unlockScale = Tween<double>(begin: 0.97, end: 1.0).animate(
        CurvedAnimation(parent: _unlockAnim, curve: Curves.easeOutBack));
    if (!widget.isLocked) _unlockAnim.value = 1.0;
  }

  @override
  void didUpdateWidget(_SectionWrapper old) {
    super.didUpdateWidget(old);
    if (_wasLocked && !widget.isLocked) {
      _wasLocked = false;
      _unlockAnim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _unlockAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.isDone;
    final isLocked = widget.isLocked;

    final headerColor = isDone
        ? AppTheme.primary
        : isLocked
        ? AppTheme.darkGreen.withOpacity(0.35)
        : AppTheme.darkGreen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? AppTheme.primary.withOpacity(0.4)
              : isLocked
              ? Colors.grey.withOpacity(0.15)
              : AppTheme.lightGreen.withOpacity(0.35),
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone
                ? AppTheme.primary.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: isDone ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppTheme.primary
                      : isLocked
                      ? Colors.grey.withOpacity(0.12)
                      : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : isLocked
                      ? Icons.lock_outline_rounded
                      : widget.icon,
                  color: isDone
                      ? Colors.white
                      : isLocked
                      ? Colors.grey.withOpacity(0.45)
                      : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          'Step ${widget.index}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: headerColor.withOpacity(0.55),
                              letterSpacing: 0.5),
                        ),
                        if (isDone) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Complete',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(widget.title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: headerColor)),
                      Text(widget.subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: headerColor.withOpacity(0.6))),
                    ]),
              ),
            ]),
          ),

          // ── Locked overlay vs content ──────────────────────────────
          if (isLocked)
            _LockedPlaceholder()
          else
            FadeTransition(
              opacity: _unlockFade,
              child: ScaleTransition(
                scale: _unlockScale,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: widget.child,
                      ),
                      if (widget.showCompleteButton && !isDone) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          child: FilledButton(
                            onPressed: widget.onComplete,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.completeLabel ?? 'Continue',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                      widget.completeIcon ??
                                          Icons.arrow_forward,
                                      size: 18),
                                ]),
                          ),
                        ),
                      ],
                      if (!widget.showCompleteButton ||
                          (isDone && widget.showCompleteButton)) ...[
                        const SizedBox(height: 18),
                      ],
                    ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _LockedPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(children: [
        Icon(Icons.lock_outline_rounded,
            size: 28, color: Colors.grey.withOpacity(0.3)),
        const SizedBox(height: 8),
        Text('Complete the previous section to continue',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.withOpacity(0.55))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ProgressBar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final List<bool> completedSections;

  const _ProgressBar({required this.completedSections});

  @override
  Widget build(BuildContext context) {
    final done = completedSections.where((b) => b).length;
    final total = completedSections.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$done of $total steps complete',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen)),
        const Spacer(),
        Text('${((done / total) * 100).round()}%',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: done / total,
          backgroundColor: AppTheme.lightGreen.withOpacity(0.18),
          valueColor:
          const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconPill({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.grey.withOpacity(0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : AppTheme.darkGreen)),
        ]),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primary, AppTheme.secondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.08),
          child: Center(
            child: isLoading
                ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward,
                      size: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}