import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../../theme/app_theme.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../Pages/login.dart';
import '../components/inputs.dart';
import '../components/role_card.dart';

class MemberRegisterScreen extends StatefulWidget {
  const MemberRegisterScreen({super.key});

  @override
  State<MemberRegisterScreen> createState() => _MemberRegisterScreenState();
}

class _MemberRegisterScreenState extends State<MemberRegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _pageAnimController;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isObscure = true;
  bool _isObscureConfirm = true;

  String? _memberSelectedCity;
  String? _memberSelectedArea;
  bool _memberLocationsLoaded = false;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this)..forward();
    _loadKenyaCities();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        _memberSelectedCity ??= _kenyaCities.keys.contains('Nairobi') ? 'Nairobi' : (_kenyaCities.keys.isNotEmpty ? _kenyaCities.keys.first : null);
        _memberSelectedArea = null;
      });
    } catch (e) {
      debugPrint('Failed to load KenyaCities.json: $e');
    }
  }

  Future<void> _submitMember() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_memberSelectedCity == null || _memberSelectedCity!.trim().isEmpty) {
      _showError('Please select your city.');
      return;
    }

    try {
      final communityAuth = CommunityAuthService();
      final user = await communityAuth.registerWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: 'Member',
      );
      if (!mounted) return;
      if (user == null) {
        _showError('Could not create your account. Please try again.');
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final memberCities = _kenyaCities.keys.toList()..sort();
    final memberAreas = (_memberSelectedCity != null && _kenyaCities[_memberSelectedCity!] != null)
        ? _kenyaCities[_memberSelectedCity!]!.map((e) => (e['area'] ?? e['name']).toString()).toList()
        : <String>[];

    if (!_memberLocationsLoaded && _kenyaCities.isNotEmpty) {
      _memberSelectedCity = _kenyaCities.keys.contains('Nairobi') ? 'Nairobi' : memberCities.first;
      _memberSelectedArea = null;
      _memberLocationsLoaded = true;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), color: AppTheme.darkGreen, onPressed: () => Navigator.pop(context))
            : null,
        title: Text('Your Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _pageAnimController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PrimaryTextField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline, hint: 'Your display name', validator: (v) => v!.trim().isEmpty ? 'Name is required' : null),
                const SizedBox(height: 16),
                PrimaryTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v!.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-z]+$').hasMatch(v)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PasswordField(controller: _passwordController, label: 'Password', obscure: _isObscure, onToggle: () => setState(() => _isObscure = !_isObscure)),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  obscure: _isObscureConfirm,
                  onToggle: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                  validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                InputHelpers.sectionHeader(Icons.location_on_outlined, 'Your Location', context),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputHelpers.inputDec(label: 'Country', icon: Icons.public),
                  child: const Text('Kenya', style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _memberSelectedCity,
                  items: memberCities.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() {
                    _memberSelectedCity = val;
                    _memberSelectedArea = null;
                  }),
                  decoration: InputHelpers.inputDec(label: 'City / County', icon: Icons.location_city),
                  validator: (v) => (v == null || v.isEmpty) ? 'City is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _memberSelectedArea,
                  items: memberAreas.map((a) => DropdownMenuItem<String>(value: a, child: Text(a))).toList(),
                  onChanged: (val) => setState(() => _memberSelectedArea = val),
                  decoration: InputHelpers.inputDec(label: 'Area / Neighbourhood', icon: Icons.pin_drop_outlined),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _submitMember,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
