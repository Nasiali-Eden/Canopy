import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../theme/app_theme.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../Pages/community_guidelines.dart';
import '../models/org_taxonomy_models.dart';
import '../components/inputs.dart';
import '../components/org_tiles.dart';
import '../components/selection_chip.dart';

class OrgRegisterWizard extends StatefulWidget {
  const OrgRegisterWizard({super.key});

  @override
  State<OrgRegisterWizard> createState() => _OrgRegisterWizardState();
}

enum OrgStep { basics, classification, beneficiaries, facilities, location, logo, summary }

class _OrgRegisterWizardState extends State<OrgRegisterWizard> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  OrgStep _step = OrgStep.basics;

  // Org basics
  final _orgNameController = TextEditingController();
  final _orgRepNameController = TextEditingController();
  final _orgEmailController = TextEditingController();
  final _orgPasswordController = TextEditingController();
  final _orgConfirmPasswordController = TextEditingController();
  bool _orgObscure = true;
  bool _orgObscureConfirm = true;

  // Org classification
  OrgSector? _selectedSector;
  OrgType? _selectedOrgType;
  List<String> _selectedSubTypeIds = [];
  LegalDesignation? _selectedDesignation;
  final _backgroundController = TextEditingController();
  final List<TextEditingController> _functionControllers = List.generate(5, (_) => TextEditingController());

  // Org beneficiaries
  Set<String> _selectedBeneficiaryIds = {};

  // Org facilities
  Set<String> _selectedFacilityIds = {};

  // Org location
  final _countryController = TextEditingController(text: 'Kenya');
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  String? _selectedCity;
  String? _selectedArea;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  // Org logo (transparent PNG)
  XFile? _orgLogo;

  late AnimationController _pageAnimController;

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this)..forward();
    _loadKenyaCities();
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _orgRepNameController.dispose();
    _orgEmailController.dispose();
    _orgPasswordController.dispose();
    _orgConfirmPasswordController.dispose();
    _backgroundController.dispose();
    for (var c in _functionControllers) c.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _pageAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadKenyaCities() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/Cities/African/KenyaCities.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final map = data['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      final parsed = <String, List<Map<String, dynamic>>>{};
      for (final entry in map.entries) {
        final list = (entry.value as List).cast<Map<String, dynamic>>();
        parsed[entry.key] = list;
      }
      setState(() {
        _kenyaCities = parsed;
        _selectedCity ??= _kenyaCities.keys.contains('Nairobi') ? 'Nairobi' : (_kenyaCities.keys.isNotEmpty ? _kenyaCities.keys.first : null);
        _selectedArea = null;
      });
    } catch (e) {
      debugPrint('Failed to load KenyaCities.json: $e');
    }
  }

  Future<void> _pickOrgLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _orgLogo = file);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating));
  }

  Future<void> _submitOrg() async {
    setState(() => _submitting = true);
    try {
      final communityAuth = CommunityAuthService();
      final functions = _functionControllers.map((c) => c.text.trim()).where((f) => f.isNotEmpty).toList();

      final user = await communityAuth.registerAsOrganization(
        email: _orgEmailController.text.trim(),
        password: _orgPasswordController.text,
        orgName: _orgNameController.text.trim(),
        orgRepName: _orgRepNameController.text.trim(),
        background: _backgroundController.text.trim(),
        mainFunctions: functions,
        orgDesignation: _selectedDesignation?.acronym ?? '',
        profilePhoto: _orgLogo,
      );
      if (!mounted) return;
      if (user == null) {
        _showError('Could not create organization. Please try again.');
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CommunityGuidelinesScreen()));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int get _orgStepIndex {
    switch (_step) {
      case OrgStep.basics:
        return 0;
      case OrgStep.classification:
        return 1;
      case OrgStep.beneficiaries:
        return 2;
      case OrgStep.facilities:
        return 3;
      case OrgStep.location:
        return 4;
      case OrgStep.logo:
        return 5;
      case OrgStep.summary:
        return 6;
    }
  }

  static const int _orgTotalSteps = 7;

  void _go(OrgStep s) {
    _pageAnimController.reverse().then((_) {
      setState(() => _step = s);
      _pageAnimController.forward();
    });
  }

  void _back() {
    switch (_step) {
      case OrgStep.basics:
        Navigator.pop(context);
        break;
      case OrgStep.classification:
        _go(OrgStep.basics);
        break;
      case OrgStep.beneficiaries:
        _go(OrgStep.classification);
        break;
      case OrgStep.facilities:
        _go(OrgStep.beneficiaries);
        break;
      case OrgStep.location:
        _go(OrgStep.facilities);
        break;
      case OrgStep.logo:
        _go(OrgStep.location);
        break;
      case OrgStep.summary:
        _go(OrgStep.logo);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), color: AppTheme.darkGreen, onPressed: _back),
        title: Text(
          _titleForStep(_step),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.darkGreen, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_orgStepIndex + 1) / _orgTotalSteps,
            backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(opacity: _pageAnimController, child: _buildStep()),
      ),
    );
  }

  String _titleForStep(OrgStep s) {
    switch (s) {
      case OrgStep.basics:
        return 'Step 1 of 7 — Basics';
      case OrgStep.classification:
        return 'Step 2 of 7 — Classification';
      case OrgStep.beneficiaries:
        return 'Step 3 of 7 — Who You Serve';
      case OrgStep.facilities:
        return 'Step 4 of 7 — Facilities';
      case OrgStep.location:
        return 'Step 5 of 7 — Location';
      case OrgStep.logo:
        return 'Step 6 of 7 — Logo';
      case OrgStep.summary:
        return 'Step 7 of 7 — Review';
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case OrgStep.basics:
        return _buildBasics();
      case OrgStep.classification:
        return _buildClassification();
      case OrgStep.beneficiaries:
        return _buildBeneficiaries();
      case OrgStep.facilities:
        return _buildFacilities();
      case OrgStep.location:
        return _buildLocation();
      case OrgStep.logo:
        return _buildLogo();
      case OrgStep.summary:
        return _buildSummary();
    }
  }

  Widget _buildBasics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InputHelpers.sectionHeader(Icons.business_outlined, 'Organization Details', context),
        const SizedBox(height: 16),
        TextFormField(
          controller: _orgNameController,
          decoration: InputHelpers.inputDec(label: 'Organization Name', icon: Icons.corporate_fare),
          validator: (v) => v!.trim().isEmpty ? 'Organization name is required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _orgRepNameController,
          decoration: InputHelpers.inputDec(label: 'Your Full Name (Representative)', icon: Icons.person_outline),
          validator: (v) => v!.trim().isEmpty ? 'Your name is required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _orgEmailController,
          decoration: InputHelpers.inputDec(label: 'Organization Email', icon: Icons.email_outlined),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v!.isEmpty) return 'Email is required';
            if (!RegExp(r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-z]+$').hasMatch(v)) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _orgPasswordController,
          obscureText: _orgObscure,
          decoration: InputHelpers.inputDec(label: 'Password', icon: Icons.lock_outline).copyWith(
            suffixIcon: IconButton(icon: Icon(_orgObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _orgObscure = !_orgObscure)),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _orgConfirmPasswordController,
          obscureText: _orgObscureConfirm,
          decoration: InputHelpers.inputDec(label: 'Confirm Password', icon: Icons.lock_outline).copyWith(
            suffixIcon: IconButton(icon: Icon(_orgObscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _orgObscureConfirm = !_orgObscureConfirm)),
          ),
          validator: (v) => v != _orgPasswordController.text ? 'Passwords do not match' : null,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            if (_orgNameController.text.trim().isEmpty ||
                _orgRepNameController.text.trim().isEmpty ||
                _orgEmailController.text.trim().isEmpty ||
                _orgPasswordController.text.isEmpty ||
                _orgPasswordController.text != _orgConfirmPasswordController.text) {
              _showError('Please fill all fields correctly.');
              return;
            }
            _go(OrgStep.classification);
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ]),
        ),
      ]),
    );
  }

  Widget _buildClassification() {
    final orgTypes = _selectedSector?.orgTypes ?? [];
    final subTypes = _selectedOrgType?.subTypes ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InputHelpers.sectionHeader(Icons.category_outlined, 'Primary Sector', context),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kSectors
              .map((sector) => SelectionChip(
                    label: sector.label,
                    selected: _selectedSector?.id == sector.id,
                    color: InputHelpers.hexColor(sector.color),
                    onTap: () => setState(() {
                      _selectedSector = sector;
                      _selectedOrgType = null;
                      _selectedSubTypeIds = [];
                    }),
                  ))
              .toList(),
        ),
        if (_selectedSector != null) ...[
          const SizedBox(height: 24),
          InputHelpers.sectionHeader(Icons.business_center_outlined, 'Organization Type', context),
          const SizedBox(height: 12),
          ...orgTypes.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrgTypeCard(
                  type: type,
                  selected: _selectedOrgType?.id == type.id,
                  onTap: () => setState(() {
                    _selectedOrgType = type;
                    _selectedSubTypeIds = [];
                  }),
                ),
              )),
        ],
        if (_selectedOrgType != null && subTypes.isNotEmpty) ...[
          const SizedBox(height: 24),
          InputHelpers.sectionHeader(Icons.tune, 'Sub-Type(s) — select all that apply', context),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subTypes
                .map((st) => SelectionChip(
                      label: st.label,
                      selected: _selectedSubTypeIds.contains(st.id),
                      color: InputHelpers.hexColor(_selectedOrgType!.color),
                      onTap: () => setState(() {
                        _selectedSubTypeIds.contains(st.id)
                            ? _selectedSubTypeIds.remove(st.id)
                            : _selectedSubTypeIds.add(st.id);
                      }),
                    ))
                .toList(),
          ),
        ],
        if (_selectedOrgType != null) ...[
          const SizedBox(height: 24),
          InputHelpers.sectionHeader(Icons.account_balance_outlined, 'Legal Designation', context),
          const SizedBox(height: 12),
          ...kLegalDesignations.map((des) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DesignationTile(
                  designation: des,
                  selected: _selectedDesignation?.id == des.id,
                  onTap: () => setState(() => _selectedDesignation = des),
                ),
              )),
          const SizedBox(height: 24),
          InputHelpers.sectionHeader(Icons.description_outlined, 'Background (max 150 words)', context),
          const SizedBox(height: 12),
          TextFormField(
            controller: _backgroundController,
            maxLines: 5,
            decoration: InputHelpers.inputDec(hint: 'Briefly describe your organization\'s history, mission, and impact...', icon: Icons.notes).copyWith(alignLabelWithHint: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please provide a background description';
              final wc = v.trim().split(RegExp(r'\s+')).length;
              if (wc > 150) return 'Maximum 150 words (currently $wc words)';
              return null;
            },
          ),
          const SizedBox(height: 24),
          InputHelpers.sectionHeader(Icons.checklist, 'Main Functions (up to 5)', context),
          const SizedBox(height: 12),
          ..._functionControllers.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: e.value,
                  decoration: InputHelpers.inputDec(label: 'Function ${e.key + 1}', icon: Icons.check_circle_outline, hint: e.key == 0 ? 'e.g., Community recycling drives' : null),
                ),
              )),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            if (_selectedSector == null ||
                _selectedOrgType == null ||
                _selectedSubTypeIds.isEmpty ||
                _selectedDesignation == null ||
                _backgroundController.text.trim().isEmpty) {
              _showError('Please complete all classification fields.');
              return;
            }
            _go(OrgStep.beneficiaries);
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBeneficiaries() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InputHelpers.sectionHeader(Icons.diversity_3, 'Who does your organization serve?', context),
        const SizedBox(height: 6),
        Text('Select all groups that are primary beneficiaries of your work.', style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.65))),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kBeneficiaryGroups
              .map((bg) => BeneficiaryChip(
                    group: bg,
                    selected: _selectedBeneficiaryIds.contains(bg.id),
                    onTap: () => setState(() {
                      _selectedBeneficiaryIds.contains(bg.id)
                          ? _selectedBeneficiaryIds.remove(bg.id)
                          : _selectedBeneficiaryIds.add(bg.id);
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            if (_selectedBeneficiaryIds.isEmpty) {
              _showError('Please select at least one beneficiary group.');
              return;
            }
            _go(OrgStep.facilities);
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ]),
        ),
      ]),
    );
  }

  List<Map<String, String>> _allFacilityOptions() => [
        {'id': 'facility_clinic', 'label': 'Clinic / Health Facility', 'icon': 'local_hospital', 'color': '#E53935'},
        {'id': 'facility_school', 'label': 'School / Learning Center', 'icon': 'school', 'color': '#1976D2'},
        {'id': 'facility_training_center', 'label': 'Training / Vocational Center', 'icon': 'build', 'color': '#0277BD'},
        {'id': 'facility_collection_point', 'label': 'Waste Collection Point', 'icon': 'recycling', 'color': '#388E3C'},
        {'id': 'facility_drop_off', 'label': 'Drop-Off Point', 'icon': 'archive', 'color': '#43A047'},
        {'id': 'facility_workshop', 'label': 'Workshop / Studio', 'icon': 'palette', 'color': '#00897B'},
        {'id': 'facility_shelter', 'label': 'Shelter / Safe House', 'icon': 'home', 'color': '#AD1457'},
        {'id': 'facility_community_center', 'label': 'Community / Social Center', 'icon': 'groups', 'color': '#00897B'},
        {'id': 'facility_water_point', 'label': 'Water Point / WASH', 'icon': 'water_drop', 'color': '#1E88E5'},
        {'id': 'facility_youth_center', 'label': 'Youth Center', 'icon': 'group', 'color': '#7E57C2'},
        {'id': 'facility_office', 'label': 'Administrative Office', 'icon': 'business', 'color': '#546E7A'},
        {'id': 'facility_food_bank', 'label': 'Food Bank / Feeding Program', 'icon': 'restaurant', 'color': '#EF6C00'},
        {'id': 'facility_rehabilitation_center', 'label': 'Rehabilitation Center', 'icon': 'accessibility_new', 'color': '#0288D1'},
        {'id': 'facility_legal_aid_office', 'label': 'Legal Aid Office', 'icon': 'gavel', 'color': '#6A1B9A'},
        {'id': 'facility_gallery', 'label': 'Gallery / Exhibition Space', 'icon': 'photo_library', 'color': '#F57C00'},
        {'id': 'facility_nursery', 'label': 'Plant Nursery / Nature Center', 'icon': 'park', 'color': '#2E7D32'},
      ];

  Widget _buildFacilities() {
    final allFacilities = _allFacilityOptions();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InputHelpers.sectionHeader(Icons.apartment_outlined, 'What facilities do you have?', context),
        const SizedBox(height: 6),
        Text('Select all facilities available at your organization. This helps users find specific services on the map.', style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.65))),
        const SizedBox(height: 20),
        ...allFacilities.map((f) {
          final selected = _selectedFacilityIds.contains(f['id']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FacilityTile(
              id: f['id']!,
              label: f['label']!,
              icon: f['icon']!,
              color: InputHelpers.hexColor(f['color']!),
              selected: selected,
              onTap: () => setState(() {
                selected ? _selectedFacilityIds.remove(f['id']) : _selectedFacilityIds.add(f['id']!);
              }),
            ),
          );
        }),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => _go(OrgStep.location),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ]),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => _go(OrgStep.location),
          child: Text('Skip for now', style: TextStyle(color: AppTheme.darkGreen.withOpacity(0.5))),
        ),
      ]),
    );
  }

  Widget _buildLocation() {
    final cities = _kenyaCities.keys.toList()..sort();
    final areas = (_selectedCity != null && _kenyaCities[_selectedCity!] != null)
        ? _kenyaCities[_selectedCity!]!.map((e) => (e['area'] ?? e['name']).toString()).toList()
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InputHelpers.sectionHeader(Icons.location_on_outlined, 'Where are you based?', context),
        const SizedBox(height: 6),
        Text('Your location will be used to place your organization on the map.', style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.65))),
        const SizedBox(height: 20),
        InputDecorator(
          decoration: InputHelpers.inputDec(label: 'Country', icon: Icons.public),
          child: const Text('Kenya', style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          items: cities.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
          onChanged: (val) => setState(() {
            _selectedCity = val;
            _selectedArea = null;
          }),
          decoration: InputHelpers.inputDec(label: 'City / County', icon: Icons.location_city),
          validator: (v) => (v == null || v.isEmpty) ? 'City is required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedArea,
          items: areas.map((a) => DropdownMenuItem<String>(value: a, child: Text(a))).toList(),
          onChanged: (val) => setState(() => _selectedArea = val),
          decoration: InputHelpers.inputDec(label: 'Area / Neighbourhood', icon: Icons.pin_drop_outlined),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            final hasCity = _selectedCity != null && _selectedCity!.trim().isNotEmpty;
            if (!hasCity) {
              _showError('City is required.');
              return;
            }
            _countryController.text = 'Kenya';
            _cityController.text = _selectedCity ?? '';
            _areaController.text = _selectedArea ?? '';
            _go(OrgStep.logo);
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLogo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InputHelpers.sectionHeader(Icons.image_outlined, 'Upload Your Logo', context),
        const SizedBox(height: 6),
        Text('Upload a transparent PNG of your organization logo. It will be used as your map marker so users can instantly recognize you.', style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.65))),
        const SizedBox(height: 32),
        Center(
          child: GestureDetector(
            onTap: _pickOrgLogo,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _orgLogo != null ? AppTheme.primary : AppTheme.lightGreen.withOpacity(0.4), width: _orgLogo != null ? 2.5 : 1.5),
              ),
              child: _orgLogo != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.file(File(_orgLogo!.path), fit: BoxFit.contain))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppTheme.primary.withOpacity(0.6)),
                      const SizedBox(height: 10),
                      Text('Tap to upload PNG', style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.55))),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_orgLogo != null)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _orgLogo = null),
              icon: Icon(Icons.close, size: 16, color: Colors.red.shade400),
              label: Text('Remove', style: TextStyle(color: Colors.red.shade400)),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Use a transparent PNG with your logo centered. Recommended size: 256×256px or larger. The logo will appear as a custom map pin visible to all users.', style: TextStyle(fontSize: 12, color: Colors.amber.shade900))),
          ]),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => _go(OrgStep.summary),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ]),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: () => _go(OrgStep.summary), child: Text('Skip — add logo later', style: TextStyle(color: AppTheme.darkGreen.withOpacity(0.5)))),
      ]),
    );
  }

  Widget _buildSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primary.withOpacity(0.08), AppTheme.secondary.withOpacity(0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (_orgLogo != null)
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_orgLogo!.path), width: 56, height: 56, fit: BoxFit.contain))
              else
                Container(width: 56, height: 56, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business, color: Colors.white, size: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_orgNameController.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(_orgRepNameController.text, style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            _summaryRow('Sector', _selectedSector?.label ?? '—'),
            _summaryRow('Type', _selectedOrgType?.label ?? '—'),
            _summaryRow('Designation', _selectedDesignation?.acronym ?? '—'),
            _summaryRow(
              'Beneficiaries',
              _selectedBeneficiaryIds.isEmpty
                  ? '—'
                  : _selectedBeneficiaryIds
                      .map((id) => kBeneficiaryGroups.firstWhere((b) => b.id == id, orElse: () => const BeneficiaryGroup(id: '', label: '', icon: '', color: '')).label)
                      .join(', '),
            ),
            _summaryRow('Location', '${_areaController.text.isNotEmpty ? "${_areaController.text}, " : ""}${_cityController.text}, ${_countryController.text}'),
          ]),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _submitting ? null : _submitOrg,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: _submitting
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Register Organization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _back,
          style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.primary.withOpacity(0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), minimumSize: const Size.fromHeight(52)),
          child: Text('Edit Details', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.55), fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
