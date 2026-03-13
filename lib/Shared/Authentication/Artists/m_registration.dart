import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../MarketPlace/market_home.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../Pages/login.dart';
import '../../theme/app_theme.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  MarketplaceRegisterScreen
//
//  Registration for Canopy Marketplace sellers.
//  Role options: Collector · Processor · Maker/Artisan
//  (Everyone can browse and buy without registering.)
//
//  6-step progressive-unlock flow:
//    Step 1 · Role
//    Step 2 · Account Details
//    Step 3 · Shop Identity   (shop name, individual/business, logo)
//    Step 4 · Marketplace Profile  (role-adaptive specialisations + bio)
//    Step 5 · Location
//    Step 6 · Review & Submit
//
//  On success: writes to [marketplace_sellers] via CommunityAuthService,
//  then navigates to SellerHomeScreen.
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceRegisterScreen extends StatefulWidget {
  const MarketplaceRegisterScreen({super.key});

  @override
  State<MarketplaceRegisterScreen> createState() =>
      _MarketplaceRegisterScreenState();
}

// ── Marketplace role enum ─────────────────────────────────────────────────────

enum MarketplaceRole {
  collector('Collector', Icons.recycling_outlined,
      'Gather and sell recovered materials directly to processors.',
      Color(0xFF2D7A4F)),
  processor('Processor', Icons.factory_outlined,
      'Buy raw materials, refine them, and supply the creative market.',
      Color(0xFF0097A7)),
  maker('Maker / Artisan', Icons.palette_outlined,
      'Create original works from recycled and recovered materials.',
      Color(0xFFC4A961));

  final String label;
  final IconData icon;
  final String description;
  final Color color;

  const MarketplaceRole(this.label, this.icon, this.description, this.color);
}

// ── Specialisation data ───────────────────────────────────────────────────────

const _plasticTypes = [
  ('PET Bottles', '♻️'),
  ('HDPE', '🏺'),
  ('Carrier Bags', '🛍️'),
  ('Soft Plastics', '🧃'),
  ('Hard Plastics', '🪣'),
  ('Foam / EPS', '📦'),
  ('Mixed Plastics', '🔀'),
];

const _materialCategories = [
  ('Plastics', '♻️'),
  ('Metals', '⚙️'),
  ('Glass', '🔮'),
  ('Paper & Cardboard', '📄'),
  ('Rubber & Composites', '🛞'),
  ('Reclaimed Wood', '🪵'),
  ('Textiles', '🧵'),
  ('Electronics & Parts', '🔌'),
];

const _creativeCategories = [
  ('Sculpture & 3D Art', '🗿'),
  ('Furniture & Objects', '🪑'),
  ('Jewellery & Accessories', '💍'),
  ('Fashion & Textiles', '👗'),
  ('Painting & Mixed Media', '🎨'),
  ('Ceramics & Glass Art', '🏺'),
  ('Home & Lifestyle', '🏠'),
  ('Print & Paper Art', '🖨️'),
];

// ─────────────────────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────────────────────

class _MarketplaceRegisterScreenState
    extends State<MarketplaceRegisterScreen>
    with SingleTickerProviderStateMixin {
  // Entry animation
  late AnimationController _entryCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // Section unlock flags
  bool _s1Done = false; // Role
  bool _s2Done = false; // Account Details
  bool _s3Done = false; // Shop Identity
  bool _s4Done = false; // Marketplace Profile
  bool _s5Done = false; // Location
  bool _submitting = false;

  // Step 1
  MarketplaceRole? _role;

  // Step 2
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Step 3 — Shop Identity
  final _shopNameCtrl = TextEditingController();
  bool _isBusiness = false;
  final _businessRegCtrl = TextEditingController();
  bool _logoSelected = false; // TODO: replace with XFile? _shopLogo

  // Step 4 — Marketplace profile
  Set<String> _selectedPlastics = {};
  Set<String> _selectedMaterials = {};
  Set<String> _selectedCreative = {};
  final _bioCtrl = TextEditingController();

  // Step 5 — Location
  String? _selectedCity;
  String? _selectedArea;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  final _scrollCtrl = ScrollController();
  final List<GlobalKey> _sectionKeys = List.generate(6, (_) => GlobalKey());
  final _formKey = GlobalKey<FormState>();

  final _authService = CommunityAuthService();

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this)
      ..forward();
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _loadCities();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _shopNameCtrl.dispose();
    _businessRegCtrl.dispose();
    _bioCtrl.dispose();
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
    } catch (_) {}
  }

  void _scrollTo(int i) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0);
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Validations ───────────────────────────────────────────────────────────

  bool _validateS1() {
    if (_role == null) { _showError('Please select your marketplace role.'); return false; }
    return true;
  }

  bool _validateS2() {
    if (_nameCtrl.text.trim().isEmpty) { _showError('Name is required.'); return false; }
    if (!_emailCtrl.text.contains('@')) { _showError('Enter a valid email address.'); return false; }
    if (_passCtrl.text.length < 6) { _showError('Password must be at least 6 characters.'); return false; }
    if (_passCtrl.text != _confirmCtrl.text) { _showError('Passwords do not match.'); return false; }
    return true;
  }

  bool _validateS3() {
    if (_shopNameCtrl.text.trim().isEmpty) { _showError('Shop name is required.'); return false; }
    if (_role != MarketplaceRole.collector && !_logoSelected) {
      _showError('Please upload a shop logo.');
      return false;
    }
    return true;
  }

  bool _validateS4() {
    if (_role == MarketplaceRole.collector && _selectedPlastics.isEmpty) {
      _showError('Please select at least one plastic type.'); return false;
    }
    if (_role == MarketplaceRole.processor && _selectedMaterials.isEmpty) {
      _showError('Please select at least one material category.'); return false;
    }
    if (_role == MarketplaceRole.maker && _selectedMaterials.isEmpty) {
      _showError('Please select at least one material you work with.'); return false;
    }
    return true;
  }

  bool _validateS5() {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showError('Please select a city.'); return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SUBMIT — wired to CommunityAuthService
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_role == null) return;
    setState(() => _submitting = true);

    try {
      final specialisations = _role == MarketplaceRole.collector
          ? _selectedPlastics.toList()
          : _selectedMaterials.toList();

      await _authService.registerAsMarketplaceSeller(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        shopName: _shopNameCtrl.text.trim(),
        marketplaceRole: _role!.label,
        isBusiness: _isBusiness,
        businessRegNo: _businessRegCtrl.text.trim(),
        // shopLogo: _shopLogo, // TODO: pass XFile when image_picker is integrated
        specialisations: specialisations,
        creativeCategories: _selectedCreative.toList(),
        bio: _bioCtrl.text.trim(),
        city: _selectedCity ?? '',
        area: _selectedArea ?? '',
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SellerHomeScreen()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _submitting = false);
      switch (e.code) {
        case 'email-already-in-use':
          _showError('An account with this email already exists.');
          break;
        case 'weak-password':
          _showError('Password is too weak. Use at least 6 characters.');
          break;
        case 'invalid-email':
          _showError('Invalid email address.');
          break;
        default:
          _showError('Registration failed: ${e.message}');
      }
    } catch (e) {
      setState(() => _submitting = false);
      _showError('Something went wrong. Please try again.');
      debugPrint('[MarketplaceRegister] error: $e');
    }
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
              color: AppTheme.tertiary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 15, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Marketplace',
              style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
          Text('Join the circular economy',
              style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.5), fontSize: 11)),
        ]),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MarketplaceBanner(),
                  const SizedBox(height: 20),
                  _ProgressBar(
                    completedSections: [_s1Done, _s2Done, _s3Done, _s4Done, _s5Done],
                    label: 'Marketplace Registration',
                    color: AppTheme.tertiary,
                  ),
                  const SizedBox(height: 24),

                  // Step 1 — Role
                  _MpSectionWrapper(
                    key: _sectionKeys[0],
                    index: 1,
                    title: 'Your Marketplace Role',
                    icon: Icons.storefront_outlined,
                    subtitle: 'How will you participate?',
                    isLocked: false,
                    isDone: _s1Done,
                    child: _buildRoleSection(),
                    onComplete: _s1Done ? null : () {
                      if (_validateS1()) { setState(() => _s1Done = true); _scrollTo(1); }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Step 2 — Account Details
                  _MpSectionWrapper(
                    key: _sectionKeys[1],
                    index: 2,
                    title: 'Account Details',
                    icon: Icons.person_outline,
                    subtitle: 'Name, email & M-Pesa number',
                    isLocked: !_s1Done,
                    isDone: _s2Done,
                    child: _buildAccountSection(),
                    onComplete: _s2Done ? null : () {
                      if (_validateS2()) { setState(() => _s2Done = true); _scrollTo(2); }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Step 3 — Shop Identity
                  _MpSectionWrapper(
                    key: _sectionKeys[2],
                    index: 3,
                    title: 'Shop Identity',
                    icon: Icons.storefront_outlined,
                    subtitle: 'Your public shop name, logo & type',
                    isLocked: !_s2Done,
                    isDone: _s3Done,
                    child: _buildShopIdentitySection(),
                    onComplete: _s3Done ? null : () {
                      if (_validateS3()) { setState(() => _s3Done = true); _scrollTo(3); }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Step 4 — Marketplace Profile
                  _MpSectionWrapper(
                    key: _sectionKeys[3],
                    index: 4,
                    title: _role == null ? 'Marketplace Profile' : '${_role!.label} Profile',
                    icon: Icons.badge_outlined,
                    subtitle: 'Specialisations, materials & bio',
                    isLocked: !_s3Done,
                    isDone: _s4Done,
                    child: _buildProfileSection(),
                    onComplete: _s4Done ? null : () {
                      if (_validateS4()) { setState(() => _s4Done = true); _scrollTo(4); }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Step 5 — Location
                  _MpSectionWrapper(
                    key: _sectionKeys[4],
                    index: 5,
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    subtitle: 'Where are you based?',
                    isLocked: !_s4Done,
                    isDone: _s5Done,
                    child: _buildLocationSection(),
                    onComplete: _s5Done ? null : () {
                      if (_validateS5()) { setState(() => _s5Done = true); _scrollTo(5); }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Step 6 — Review & Submit
                  _MpSectionWrapper(
                    key: _sectionKeys[5],
                    index: 6,
                    title: 'Review & Submit',
                    icon: Icons.rocket_launch_outlined,
                    subtitle: 'Confirm your details and launch your shop',
                    isLocked: !_s5Done,
                    isDone: false,
                    showCompleteButton: false,
                    child: _buildSubmitSection(),
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
  //  SECTION BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRoleSection() {
    return Column(children: [
      ...MarketplaceRole.values.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RoleCard(
          role: r,
          selected: _role == r,
          onTap: () => setState(() => _role = r),
        ),
      )),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          Icon(Icons.shopping_bag_outlined,
              color: AppTheme.primary.withOpacity(0.7), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Buying is open to everyone — no registration needed. Only register if you want to list, sell, or supply.',
              style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.65)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildAccountSection() {
    const accent = AppTheme.primary;
    return Column(children: [
      _Field(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline, accent: accent,
          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
      const SizedBox(height: 14),
      _Field(controller: _emailCtrl, label: 'Email Address', icon: Icons.email_outlined, accent: accent,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v!.contains('@') ? null : 'Enter a valid email'),
      const SizedBox(height: 14),
      _Field(controller: _phoneCtrl, label: 'Phone Number (M-Pesa)', icon: Icons.phone_outlined, accent: accent,
          keyboardType: TextInputType.phone, hint: '+254 700 000 000'),
      const SizedBox(height: 14),
      _PasswordField(controller: _passCtrl, label: 'Password', obscure: _obscurePass, accent: accent,
          onToggle: () => setState(() => _obscurePass = !_obscurePass)),
      const SizedBox(height: 14),
      _PasswordField(controller: _confirmCtrl, label: 'Confirm Password', obscure: _obscureConfirm, accent: accent,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null),
    ]);
  }

  Widget _buildShopIdentitySection() {
    const accent = AppTheme.tertiary;
    final isLogoRequired = _role != MarketplaceRole.collector;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Field(controller: _shopNameCtrl, label: 'Shop Name', icon: Icons.storefront_outlined, accent: accent,
          validator: (v) => v!.trim().isEmpty ? 'Shop name is required' : null),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          'Displayed on all your listings, your profile, and the map.',
          style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5)),
        ),
      ),
      const SizedBox(height: 18),

      _sectionLabel('Account Type', accent),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _ToggleOption(label: 'Individual', icon: Icons.person_outline,
            selected: !_isBusiness, color: accent, onTap: () => setState(() => _isBusiness = false))),
        const SizedBox(width: 10),
        Expanded(child: _ToggleOption(label: 'Business', icon: Icons.business_outlined,
            selected: _isBusiness, color: accent, onTap: () => setState(() => _isBusiness = true))),
      ]),

      if (_isBusiness) ...[
        const SizedBox(height: 14),
        _Field(controller: _businessRegCtrl, label: 'Business Registration No. (optional)',
            icon: Icons.numbers_outlined, accent: accent),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Used for trust signalling — not validated by the platform.',
              style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
        ),
      ],

      const SizedBox(height: 20),
      _sectionLabel(isLogoRequired ? 'Shop Logo *' : 'Shop Logo (optional)', accent),
      const SizedBox(height: 10),
      _LogoUploadTile(
        selected: _logoSelected,
        isRequired: isLogoRequired,
        accent: accent,
        onTap: () => setState(() => _logoSelected = true), // TODO: image_picker
        onRemove: () => setState(() => _logoSelected = false),
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text('Square PNG or JPG · minimum 200×200 px · shown on listings, profile, and map pin.',
            style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
      ),
    ]);
  }

  Widget _buildProfileSection() {
    if (_role == null) return const SizedBox.shrink();
    final roleColor = _role!.color;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_role == MarketplaceRole.collector) ...[
        _sectionLabel('Plastic Types You Collect', roleColor),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
            children: _plasticTypes.map((p) => _Chip(
              label: p.$1, emoji: p.$2,
              selected: _selectedPlastics.contains(p.$1), color: roleColor,
              onTap: () => setState(() => _selectedPlastics.contains(p.$1)
                  ? _selectedPlastics.remove(p.$1) : _selectedPlastics.add(p.$1)),
            )).toList()),
      ],
      if (_role == MarketplaceRole.processor) ...[
        _sectionLabel('Material Categories', roleColor),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
            children: _materialCategories.map((m) => _Chip(
              label: m.$1, emoji: m.$2,
              selected: _selectedMaterials.contains(m.$1), color: roleColor,
              onTap: () => setState(() => _selectedMaterials.contains(m.$1)
                  ? _selectedMaterials.remove(m.$1) : _selectedMaterials.add(m.$1)),
            )).toList()),
      ],
      if (_role == MarketplaceRole.maker) ...[
        _sectionLabel('Materials You Work With', roleColor),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
            children: _materialCategories.map((m) => _Chip(
              label: m.$1, emoji: m.$2,
              selected: _selectedMaterials.contains(m.$1), color: roleColor,
              onTap: () => setState(() => _selectedMaterials.contains(m.$1)
                  ? _selectedMaterials.remove(m.$1) : _selectedMaterials.add(m.$1)),
            )).toList()),
        const SizedBox(height: 18),
        _sectionLabel('Creative Categories', roleColor),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
            children: _creativeCategories.map((c) => _Chip(
              label: c.$1, emoji: c.$2,
              selected: _selectedCreative.contains(c.$1), color: roleColor,
              onTap: () => setState(() => _selectedCreative.contains(c.$1)
                  ? _selectedCreative.remove(c.$1) : _selectedCreative.add(c.$1)),
            )).toList()),
      ],

      const SizedBox(height: 18),
      _sectionLabel('Short Bio (optional)', roleColor),
      const SizedBox(height: 6),
      Text(
        _role == MarketplaceRole.maker
            ? 'This becomes the foundation of your story-driven listings. Write richly.'
            : 'Shown on your seller profile and listing pages.',
        style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5)),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _bioCtrl,
        maxLines: 3,
        maxLength: 500,
        style: const TextStyle(
            color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: _inputDec(
          label: _role == MarketplaceRole.maker
              ? 'Tell the story of your craft and materials...'
              : 'Tell buyers / collectors a bit about yourself...',
          icon: Icons.notes_outlined,
          accent: roleColor,
        ),
      ),
    ]);
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
          const Text('Kenya',
              style: TextStyle(color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: const Text('Fixed',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _selectedCity,
        dropdownColor: Colors.white,
        menuMaxHeight: 280,
        style: const TextStyle(color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent.withOpacity(0.6), size: 20),
        decoration: _inputDec(label: 'City / County', icon: Icons.location_city, accent: accent),
        items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() { _selectedCity = v; _selectedArea = null; }),
        validator: (v) => (v == null || v.isEmpty) ? 'City is required' : null,
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _selectedArea,
        dropdownColor: Colors.white,
        menuMaxHeight: 280,
        style: const TextStyle(color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent.withOpacity(0.6), size: 20),
        decoration: _inputDec(
            label: 'Area / Neighbourhood (optional)', icon: Icons.pin_drop_outlined, accent: accent),
        items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
        onChanged: (v) => setState(() => _selectedArea = v),
      ),
    ]);
  }

  Widget _buildSubmitSection() {
    if (!_s5Done) return const SizedBox.shrink();
    final roleColor = _role?.color ?? AppTheme.primary;

    return Column(children: [
      // Summary card
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [roleColor.withOpacity(0.08), roleColor.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: roleColor.withOpacity(0.2)),
        ),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Logo preview
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _logoSelected ? roleColor.withOpacity(0.15) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _logoSelected ? roleColor.withOpacity(0.4) : Colors.grey.shade300),
              ),
              child: Icon(
                _logoSelected ? Icons.store : Icons.image_outlined,
                color: _logoSelected ? roleColor : Colors.grey.shade400,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _shopNameCtrl.text.isNotEmpty ? _shopNameCtrl.text : 'Your Shop',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  if (_role != null) _RoleBadge(role: _role!),
                  if (_isBusiness)
                    _ReviewTag(label: 'Business', icon: Icons.business_outlined, color: AppTheme.accent),
                ]),
              ]),
            ),
          ]),
          const Divider(height: 22),
          _reviewRow(Icons.person_outline, 'Name', _nameCtrl.text),
          _reviewRow(Icons.email_outlined, 'Email', _emailCtrl.text),
          if (_phoneCtrl.text.isNotEmpty)
            _reviewRow(Icons.phone_outlined, 'Phone', _phoneCtrl.text),
          if (_isBusiness && _businessRegCtrl.text.isNotEmpty)
            _reviewRow(Icons.numbers_outlined, 'Reg No.', _businessRegCtrl.text),
          _reviewRow(Icons.location_on_outlined, 'Location',
              [_selectedArea, _selectedCity, 'Kenya']
                  .where((s) => s != null && s!.isNotEmpty)
                  .join(', ')),
        ]),
      ),
      const SizedBox(height: 16),

      // Info note
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your marketplace profile is public. Your Canopy transaction history builds over time — verified proof of work that becomes pricing leverage.',
              style: TextStyle(fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.7)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // Submit
      _GradientButton(
        label: 'Launch My Shop',
        icon: Icons.storefront_outlined,
        isLoading: _submitting,
        gradientColors: [AppTheme.darkGreen, roleColor, AppTheme.tertiary],
        onPressed: _submitting ? null : _submit,
      ),
      const SizedBox(height: 16),

      // Sign in link
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Already have an account? ',
            style: TextStyle(color: AppTheme.darkGreen.withOpacity(0.6), fontSize: 13)),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const LoginPage())),
          child: const Text('Sign In',
              style: TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    ]);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, Color color) => Text(text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color));

  Widget _reviewRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 15, color: AppTheme.primary.withOpacity(0.7)),
      const SizedBox(width: 8),
      SizedBox(
        width: 72,
        child: Text(label,
            style: TextStyle(
                fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.5), fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
    ]),
  );

  InputDecoration _inputDec({required String label, required IconData icon, required Color accent, String? hint}) {
    return InputDecoration(
      labelText: hint == null ? label : null,
      hintText: hint,
      labelStyle: TextStyle(color: accent.withOpacity(0.75), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Padding(padding: const EdgeInsets.all(10), child: _IconPill(icon: icon, color: accent)),
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
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
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MarketplaceBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primary, AppTheme.tertiary.withOpacity(0.85)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Canopy Marketplace',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 3),
            Text('Connect directly. No middlemen. Build your verified history.',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final List<bool> completedSections;
  final String label;
  final Color color;

  const _ProgressBar({required this.completedSections, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final done = completedSections.where((b) => b).length;
    final total = completedSections.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$done of $total steps complete',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
        const Spacer(),
        Text('${((done / total) * 100).round()}%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: done / total,
          backgroundColor: color.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

class _RoleCard extends StatelessWidget {
  final MarketplaceRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? role.color.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? role.color : Colors.grey.withOpacity(0.22), width: selected ? 2 : 1),
          boxShadow: selected
              ? [BoxShadow(color: role.color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: selected ? role.color : role.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(role.icon, color: selected ? Colors.white : role.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role.label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: selected ? role.color : AppTheme.darkGreen)),
              const SizedBox(height: 2),
              Text(role.description,
                  style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.55))),
            ]),
          ),
          if (selected) Icon(Icons.check_circle_rounded, color: role.color, size: 20),
        ]),
      ),
    );
  }
}

class _MpSectionWrapper extends StatefulWidget {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLocked;
  final bool isDone;
  final Widget child;
  final VoidCallback? onComplete;
  final String? completeLabel;
  final bool showCompleteButton;

  const _MpSectionWrapper({
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
    this.showCompleteButton = true,
  });

  @override
  State<_MpSectionWrapper> createState() => _MpSectionWrapperState();
}

class _MpSectionWrapperState extends State<_MpSectionWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<double> _scale;
  bool _wasLocked = true;

  @override
  void initState() {
    super.initState();
    _wasLocked = widget.isLocked;
    _anim = AnimationController(duration: const Duration(milliseconds: 450), vsync: this);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.97, end: 1.0)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
    if (!widget.isLocked) _anim.value = 1.0;
  }

  @override
  void didUpdateWidget(_MpSectionWrapper old) {
    super.didUpdateWidget(old);
    if (_wasLocked && !widget.isLocked) { _wasLocked = false; _anim.forward(from: 0); }
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.isLocked;
    final isDone = widget.isDone;
    const gold = AppTheme.tertiary;
    final borderColor = isDone
        ? gold.withOpacity(0.5)
        : isLocked ? Colors.grey.withOpacity(0.15) : gold.withOpacity(0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isDone ? 1.5 : 1),
        boxShadow: [BoxShadow(
          color: isDone ? gold.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          blurRadius: isDone ? 16 : 8, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isDone ? gold : isLocked ? Colors.grey.withOpacity(0.12) : gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDone ? Icons.check_rounded : isLocked ? Icons.lock_outline_rounded : widget.icon,
                color: isDone ? Colors.white : isLocked ? Colors.grey.withOpacity(0.45) : gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Step ${widget.index}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: isLocked ? Colors.grey.withOpacity(0.4) : gold.withOpacity(0.7),
                          letterSpacing: 0.5)),
                  if (isDone) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: gold.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Done', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.tertiary)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(widget.title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: isLocked ? Colors.grey.withOpacity(0.35) : AppTheme.darkGreen)),
                Text(widget.subtitle,
                    style: TextStyle(fontSize: 11,
                        color: isLocked ? Colors.grey.withOpacity(0.3) : AppTheme.darkGreen.withOpacity(0.55))),
              ]),
            ),
          ]),
        ),

        // Body
        if (isLocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(children: [
                Icon(Icons.lock_outline_rounded, size: 24, color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 6),
                Text('Complete the previous step first',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.5))),
              ]),
            ),
          )
        else
          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Divider(height: 1, thickness: 1),
                Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 0), child: widget.child),
                if (widget.showCompleteButton && !isDone) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: FilledButton(
                      onPressed: widget.onComplete,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.tertiary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(widget.completeLabel ?? 'Continue',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ]),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}

class _LogoUploadTile extends StatelessWidget {
  final bool selected;
  final bool isRequired;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final Color accent;

  const _LogoUploadTile({
    required this.selected, required this.isRequired,
    required this.onTap, required this.onRemove, required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent.withOpacity(0.4) : Colors.grey.shade200, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: selected ? accent.withOpacity(0.12) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? accent.withOpacity(0.3) : Colors.grey.shade200),
            ),
            child: Icon(selected ? Icons.store_rounded : Icons.add_photo_alternate_outlined,
                color: selected ? accent : Colors.grey.shade400, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(selected ? 'Logo uploaded' : 'Upload shop logo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: selected ? accent : AppTheme.darkGreen)),
              const SizedBox(height: 3),
              Text(selected ? 'Tap × to remove' : 'PNG or JPG · min 200×200 px · square',
                  style: TextStyle(fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
            ]),
          ),
          if (selected)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade200)),
                child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('Choose', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
            ),
        ]),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleOption({required this.label, required this.icon, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey.withOpacity(0.22), width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: selected ? color : AppTheme.darkGreen.withOpacity(0.4)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: selected ? color : AppTheme.darkGreen.withOpacity(0.55))),
          if (selected) ...[const SizedBox(height: 4), Icon(Icons.check_circle_rounded, size: 14, color: color)],
        ]),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final MarketplaceRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: role.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(role.icon, size: 11, color: role.color),
        const SizedBox(width: 4),
        Text(role.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: role.color)),
      ]),
    );
  }
}

class _ReviewTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _ReviewTag({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accent;
  final TextInputType? keyboardType;
  final String? hint;
  final String? Function(String?)? validator;

  const _Field({required this.controller, required this.label, required this.icon, required this.accent,
    this.keyboardType, this.hint, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: hint == null ? label : null,
        hintText: hint,
        labelStyle: TextStyle(color: accent.withOpacity(0.75), fontSize: 13),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(padding: const EdgeInsets.all(10), child: _IconPill(icon: icon, color: accent)),
        prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.withOpacity(0.22))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade300)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
      ),
      validator: validator,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final Color accent;
  final String? Function(String?)? validator;

  const _PasswordField({required this.controller, required this.label, required this.obscure,
    required this.onToggle, required this.accent, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accent.withOpacity(0.75), fontSize: 13),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(padding: const EdgeInsets.all(10), child: _IconPill(icon: Icons.lock_outline, color: accent)),
        prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: accent.withOpacity(0.55), size: 18),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent.withOpacity(0.22))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade300)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
      ),
      validator: validator ?? (v) => v!.length < 6 ? 'At least 6 characters' : null,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.emoji, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.withOpacity(0.25), width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : AppTheme.darkGreen)),
        ]),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconPill({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;

  const _GradientButton({required this.label, required this.icon, required this.isLoading,
    required this.onPressed, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.centerLeft, end: Alignment.centerRight),
        boxShadow: [BoxShadow(color: gradientColors.last.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 7))],
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
                ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_forward, size: 13, color: Colors.white),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}