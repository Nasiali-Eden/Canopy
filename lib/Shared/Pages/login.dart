import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../MarketPlace/market_home.dart';
import '../../Shared/theme/app_theme.dart';
import '../../Services/Authentication/auth.dart';
import '../../Community/Home/community_home.dart';
import '../../Organization/Home/org_home.dart';
import '../../Shared/Authentication/join_community.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LoginPage
//
//  Single login screen for all user types.
//  After sign-in, checks Firestore in this order:
//    1. marketplace_sellers  →  SellerHomeScreen
//    2. org_rep              →  OrganizationHome
//    3. members              →  CommunityHomeScreen
//    4. (none)               →  JoinCommunityScreen
// ─────────────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscure = true;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Sign-in ────────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final user = await _authService.signIn(
          _emailCtrl.text.trim(), _passwordCtrl.text);

      if (!mounted) return;

      if (user == null) {
        _showError('Invalid email or password.');
        return;
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _route(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _showError('Invalid email or password.');
          break;
        case 'user-disabled':
          _showError('This account has been disabled.');
          break;
        case 'too-many-requests':
          _showError('Too many attempts. Please try again later.');
          break;
        default:
          _showError('Sign-in failed: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
      if (kDebugMode) print('[Login] error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Routing: check collections in order ───────────────────────────────────

  Future<void> _route(User user) async {
    final db = FirebaseFirestore.instance;

    try {
      // 1 — Marketplace Seller
      final sellerDoc = await db.collection('marketplace_sellers').doc(user.uid).get();
      if (sellerDoc.exists) {
        _navigateTo(const SellerHomeScreen());
        return;
      }

      // 2 — Org Rep
      final orgDoc = await db.collection('org_rep').doc(user.uid).get();
      if (orgDoc.exists) {
        _navigateTo(const OrganizationHome());
        return;
      }

      // 3 — Community Member
      final memberDoc = await db.collection('members').doc(user.uid).get();
      if (memberDoc.exists) {
        _navigateTo(const CommunityHomeScreen());
        return;
      }

      // Not found in any collection
      _navigateTo(const JoinCommunityScreen());
    } catch (e) {
      if (kDebugMode) print('[Login] routing error: $e');
      if (!mounted) return;
      _showError('Error loading your account. Please try again.');
    }
  }

  void _navigateTo(Widget destination) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
          (route) => false,
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { Navigator.pop(context); return false; },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 40),
              Image.asset('pngs/logotext.png', width: 150, height: 90),
              const SizedBox(height: 20),
              Text('Sign In to Canopy',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.black, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Track your community contributions',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  textAlign: TextAlign.center),
              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(children: [
                  // Email
                  _InputField(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email cannot be empty';
                      if (!RegExp(r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-z]+$').hasMatch(v))
                        return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  _InputField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _isObscure,
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          color: const Color(0xFF1a1a1a)),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password cannot be empty';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 28),

                  // Sign in button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _signIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // Divider
              Row(children: [
                Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or', style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 13)),
                ),
                Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
              ]),
              const SizedBox(height: 24),

              // Social sign-in buttons (placeholder)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _SocialButton(
                  assetPath: 'images/google.png',
                  onTap: () { /* TODO: Google sign-in */ },
                ),
                const SizedBox(width: 16),
                _SocialButton(
                  assetPath: 'images/apple.png',
                  onTap: () { /* TODO: Apple sign-in */ },
                ),
              ]),

              const SizedBox(height: 32),

              // Sign up prompt
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign Up',
                        style: TextStyle(
                            color: AppTheme.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small local widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        cursorColor: AppTheme.primary,
        cursorWidth: 0.5,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF1a1a1a)),
          prefixIcon: Icon(icon, color: const Color(0xFF1a1a1a)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primary, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
        ),
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onTap;

  const _SocialButton({required this.assetPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}