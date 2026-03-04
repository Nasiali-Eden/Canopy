import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import '../../theme/app_theme.dart';
import '../../../Services/Authentication/community_auth.dart';
import '../../Pages/login.dart';

class MemberRegisterScreen extends StatefulWidget {
  const MemberRegisterScreen({super.key});

  @override
  State<MemberRegisterScreen> createState() => _MemberRegisterScreenState();
}

class _MemberRegisterScreenState extends State<MemberRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isObscure = true;
  bool _isObscureConfirm = true;
  bool _isLoading = false;

  String? _selectedCity;
  String? _selectedArea;
  bool _locationsLoaded = false;
  Map<String, List<Map<String, dynamic>>> _kenyaCities = {};

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(duration: const Duration(milliseconds: 500), vsync: this)
          ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _loadKenyaCities();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadKenyaCities() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/Cities/African/KenyaCities.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final map = data['kenyaCitiesAndLocations'] as Map<String, dynamic>;
      final parsed = <String, List<Map<String, dynamic>>>{};
      for (final entry in map.entries) {
        parsed[entry.key] = (entry.value as List).cast<Map<String, dynamic>>();
      }
      setState(() {
        _kenyaCities = parsed;
        _selectedCity = parsed.keys.contains('Nairobi')
            ? 'Nairobi'
            : (parsed.keys.isNotEmpty ? parsed.keys.first : null);
      });
    } catch (e) {
      debugPrint('Failed to load KenyaCities.json: $e');
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      _showError('Please select your city.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = CommunityAuthService();
      final user = await auth.registerWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: 'Member',
      );
      if (!mounted) return;
      if (user == null) {
        _showError('Could not create your account. Please try again.');
        setState(() => _isLoading = false);
        return;
      }
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final cities = _kenyaCities.keys.toList()..sort();
    final areas =
        (_selectedCity != null && _kenyaCities[_selectedCity!] != null)
            ? _kenyaCities[_selectedCity!]!
                .map((e) => (e['area'] ?? e['name']).toString())
                .toList()
            : <String>[];

    if (!_locationsLoaded && _kenyaCities.isNotEmpty) {
      _selectedCity = _kenyaCities.keys.contains('Nairobi')
          ? 'Nairobi'
          : cities.first;
      _locationsLoaded = true;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: Navigator.canPop(context)
            ? IconButton(
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
              )
            : null,
        centerTitle: true,
        title: const Text(
          'Create Account',
          style: TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
        
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Welcome Banner ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppTheme.lightGreen.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.07),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.eco_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Welcome to Canopy',
                                style: TextStyle(
                                    color: AppTheme.darkGreen,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('Fill in your details to get started',
                                style: TextStyle(
                                    color: Colors.black38,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.tertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.tertiary.withOpacity(0.3)),
                        ),
                        child: const Text('Member',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.tertiary)),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 26),

                  // ── SECTION: Personal Info ─────────────────────────────
                  _SectionHeader(
                      icon: Icons.person_outline_rounded,
                      label: 'Personal Info',
                      color: AppTheme.primary),
                  const SizedBox(height: 10),

                  _Field(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Your display name',
                    icon: Icons.badge_outlined,
                    accentColor: AppTheme.primary,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'you@example.com',
                    icon: Icons.alternate_email_rounded,
                    accentColor: AppTheme.accent,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Email is required';
                      if (!RegExp(
                              r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-z]+$')
                          .hasMatch(v)) return 'Enter a valid email';
                      return null;
                    },
                  ),

                  const SizedBox(height: 26),

                  // ── SECTION: Security ──────────────────────────────────
                  _SectionHeader(
                      icon: Icons.shield_outlined,
                      label: 'Security',
                      color: AppTheme.secondary),
                  const SizedBox(height: 10),

                  _PasswordField(
                    controller: _passwordController,
                    label: 'Password',
                    obscure: _isObscure,
                    accentColor: AppTheme.secondary,
                    onToggle: () =>
                        setState(() => _isObscure = !_isObscure),
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    obscure: _isObscureConfirm,
                    accentColor: AppTheme.secondary,
                    onToggle: () => setState(
                        () => _isObscureConfirm = !_isObscureConfirm),
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 7),
                  Row(children: [
                    const SizedBox(width: 2),
                    Icon(Icons.info_outline,
                        size: 12,
                        color: AppTheme.secondary.withOpacity(0.5)),
                    const SizedBox(width: 5),
                    Text('Minimum 6 characters',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondary.withOpacity(0.55))),
                  ]),

                  const SizedBox(height: 26),

                  // ── SECTION: Location ──────────────────────────────────
                  _SectionHeader(
                      icon: Icons.map_outlined,
                      label: 'Your Location',
                      color: AppTheme.accent),
                  const SizedBox(height: 10),

                  // Country read-only tile
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.accent.withOpacity(0.22)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(children: [
                      _IconPill(
                          icon: Icons.public_rounded,
                          color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Country',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          AppTheme.accent.withOpacity(0.65),
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              const Text('Kenya',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGreen)),
                            ]),
                      ),
                      const Text('🇰🇪', style: TextStyle(fontSize: 20)),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  _Dropdown(
                    value: _selectedCity,
                    items: cities,
                    label: 'City / County',
                    icon: Icons.location_city_outlined,
                    accentColor: AppTheme.accent,
                    onChanged: (val) => setState(() {
                      _selectedCity = val;
                      _selectedArea = null;
                    }),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'City is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _Dropdown(
                    value: _selectedArea,
                    items: areas,
                    label: 'Area / Neighbourhood',
                    icon: Icons.pin_drop_outlined,
                    accentColor: AppTheme.lightGreen,
                    onChanged: (val) =>
                        setState(() => _selectedArea = val),
                  ),

                  const SizedBox(height: 30),

                  // ── Step progress ──────────────────────────────────────
                  Row(children: [
                    _StepDot(color: AppTheme.primary, filled: true),
                    _StepLine(color: AppTheme.secondary),
                    _StepDot(color: AppTheme.secondary, filled: true),
                    _StepLine(color: AppTheme.accent),
                    _StepDot(color: AppTheme.accent, filled: true),
                    _StepLine(color: AppTheme.lightGreen),
                    _StepDot(color: AppTheme.tertiary, filled: false),
                  ]),
                  const SizedBox(height: 6),
                  Text('Step 1 of 2 — Account Details',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                          fontWeight: FontWeight.w500)),

                  const SizedBox(height: 26),

                  // ── Submit Button ──────────────────────────────────────
                  _SubmitButton(
                      isLoading: _isLoading, onPressed: _submit),

                  const SizedBox(height: 18),

                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Already have an account?  ',
                        style:
                            TextStyle(color: Colors.black45, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginPage())),
                      child: const Text('Sign In',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 9),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3)),
      const SizedBox(width: 10),
      Expanded(
          child:
              Container(height: 1, color: color.withOpacity(0.12))),
    ]);
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconPill({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

OutlineInputBorder _inputBorder(Color c, {double width = 1.2}) =>
    OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: width));

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
          color: AppTheme.darkGreen,
          fontSize: 14,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            TextStyle(color: accentColor.withOpacity(0.75), fontSize: 13),
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: _IconPill(icon: icon, color: accentColor),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
        border: _inputBorder(accentColor.withOpacity(0.2)),
        enabledBorder: _inputBorder(accentColor.withOpacity(0.22)),
        focusedBorder: _inputBorder(accentColor, width: 2),
        errorBorder: _inputBorder(Colors.red.shade300),
        focusedErrorBorder: _inputBorder(Colors.red.shade400, width: 2),
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
  final Color accentColor;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.accentColor,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
          color: AppTheme.darkGreen,
          fontSize: 14,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: accentColor.withOpacity(0.75), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: _IconPill(
              icon: Icons.lock_outline_rounded, color: accentColor),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: accentColor.withOpacity(0.55),
            size: 18,
          ),
          onPressed: onToggle,
        ),
        border: _inputBorder(accentColor.withOpacity(0.2)),
        enabledBorder: _inputBorder(accentColor.withOpacity(0.22)),
        focusedBorder: _inputBorder(accentColor, width: 2),
        errorBorder: _inputBorder(Colors.red.shade300),
        focusedErrorBorder: _inputBorder(Colors.red.shade400, width: 2),
      ),
      validator:
          validator ?? (v) => v!.length < 6 ? 'At least 6 characters' : null,
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String label;
  final IconData icon;
  final Color accentColor;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white,
      menuMaxHeight: 300,
      style: const TextStyle(
          color: AppTheme.darkGreen,
          fontSize: 14,
          fontWeight: FontWeight.w500),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: accentColor.withOpacity(0.6), size: 20),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: accentColor.withOpacity(0.75), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: _IconPill(icon: icon, color: accentColor),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
        border: _inputBorder(accentColor.withOpacity(0.2)),
        enabledBorder: _inputBorder(accentColor.withOpacity(0.22)),
        focusedBorder: _inputBorder(accentColor, width: 2),
        errorBorder: _inputBorder(Colors.red.shade300),
        focusedErrorBorder: _inputBorder(Colors.red.shade400, width: 2),
      ),
      items: items
          .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class _StepDot extends StatelessWidget {
  final Color color;
  final bool filled;
  const _StepDot({required this.color, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final Color color;
  const _StepLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child:
            Container(height: 1.5, color: color.withOpacity(0.3)));
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _SubmitButton({required this.isLoading, required this.onPressed});

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
          onTap: isLoading ? null : onPressed,
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
                      const Icon(Icons.eco_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      const Text('Join the Community',
                          style: TextStyle(
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