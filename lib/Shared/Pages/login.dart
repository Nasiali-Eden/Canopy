import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../MarketPlace/market_home.dart';
import '../../theme/canopy_components.dart';
import '../../Services/Authentication/auth.dart';
import '../../Services/Profile/profile_privacy.dart';
import '../../Services/storage/user_persistence.dart';
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
//
//  Implements offline-first routing using cached user profile.
// ─────────────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscure = true;
  bool _loading = false, _showErrors = false;
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
    setState(() => _loading = true);

    try {
      debugPrint('[Login] Starting sign in for ${_emailCtrl.text.trim()}');

      final user =
          await _authService.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);

      if (!mounted) return;

      if (user == null) {
        _showError('Invalid email or password.');
        return;
      }

      debugPrint('[Login] Sign in successful, routing user...');
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _route(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('[Login] FirebaseAuthException: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _showError('Invalid email or password. If you joined with Google, tap Continue with Google.');
          break;
        case 'user-disabled':
          _showError('This account has been disabled.');
          break;
        case 'too-many-requests':
          _showError('Too many attempts. Please try again later.');
          break;
        case 'network-timeout':
        case 'network-request-failed':
          _showError(
              'Network error. Please check your connection and try again.');
          break;
        default:
          _showError('Sign-in failed: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Login] Unexpected error: $e');
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google sign-in ─────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
      final user = cred.user;
      if (user == null || !mounted) return;
      debugPrint('[Login] Google sign in successful: ${user.uid}');
      await _route(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('[Login] Google FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'canceled' || e.code == 'web-context-canceled') return;
      if (e.code == 'account-exists-with-different-credential' && e.credential != null && e.email != null) {
        await _linkGoogleToPasswordAccount(e.email!, e.credential!);
        return;
      }
      _showError('Google sign-in failed: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Login] Google sign-in error: $e');
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The email already has a password account: confirm the password once, then
  /// attach Google so either sign-in works from now on.
  Future<void> _linkGoogleToPasswordAccount(String email, AuthCredential google) async {
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link your accounts'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$email already has a Canopy password. Enter it once to link Google, and either sign-in will work.'),
          const SizedBox(height: 12),
          TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'Password')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Link')),
        ],
      ),
    );
    ctrl.dispose();
    if (password == null || password.isEmpty || !mounted) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      await cred.user!.linkWithCredential(google);
      if (!mounted) return;
      showCanopySnack(context, 'Google linked to your account.');
      await _route(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? 'That password is not right.'
          : 'Could not link Google: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Routing: check collections with retry + offline fallback ──────────────

  Future<void> _route(User user) async {
    final db = FirebaseFirestore.instance;
    ProfilePrivacy.sync();

    try {
      debugPrint('[Login] Routing user ${user.uid}...');

      // Try to route using Firestore with retry logic
      final routed = await _routeWithFirestore(db, user.uid);
      if (routed) return;

      // If Firestore fails, try offline-first routing using cached profile
      debugPrint(
          '[Login] Firestore routing failed, trying offline-first routing...');
      final offlineRouted = await _routeOfflineFirst(user.uid);
      if (offlineRouted) return;

      // If all else fails, go to join community
      debugPrint(
          '[Login] No user profile found, routing to JoinCommunityScreen');
      _navigateTo(const JoinCommunityScreen());
    } catch (e) {
      debugPrint('[Login] Routing error: $e');
      if (!mounted) return;
      _showError('Error loading your account. Please try again.');
    }
  }

  /// Try to route using Firestore with retry logic
  Future<bool> _routeWithFirestore(FirebaseFirestore db, String uid) async {
    const maxRetries = 3;
    const timeout = Duration(seconds: 10);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[Login] Firestore routing attempt $attempt/$maxRetries');

        // 1 — Org rep first: a rep with a shop still belongs in their org
        try {
          final orgDoc = await db
              .collection('org_rep')
              .doc(uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(timeout);
          if (orgDoc.exists) {
            debugPrint(
                '[Login] ✅ Found org rep, fetching orgId from Users collection');
            // Cache the profile
            await UserPersistence.saveUserProfile(orgDoc.data() ?? {});

            // Get orgId from Users collection
            try {
              final userDoc = await db
                  .collection('Users')
                  .doc(uid)
                  .get(const GetOptions(source: Source.serverAndCache))
                  .timeout(timeout);

              if (userDoc.exists) {
                final userData = userDoc.data();
                final orgId = userData?['orgId'] as String?;

                if (orgId != null && orgId.isNotEmpty) {
                  debugPrint(
                      '[Login] ✅ Found orgId, routing to OrganizationHome');
                  _navigateTo(const OrganizationHome());
                  return true;
                } else {
                  debugPrint(
                      '[Login] ⚠️ orgId is missing for Org Rep, falling back to CommunityHome');
                  _navigateTo(const CommunityHomeScreen());
                  return true;
                }
              } else {
                debugPrint(
                    '[Login] ⚠️ Users doc not found for Org Rep, falling back to CommunityHome');
                _navigateTo(const CommunityHomeScreen());
                return true;
              }
            } catch (e) {
              debugPrint('[Login] Error fetching orgId: $e');
              _navigateTo(const CommunityHomeScreen());
              return true;
            }
          }
        } catch (e) {
          debugPrint('[Login] Org rep check error: $e');
        }

        // 2 — Marketplace seller (standalone shop accounts)
        try {
          final sellerDoc = await db
              .collection('marketplace_sellers')
              .doc(uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(timeout);
          if (sellerDoc.exists) {
            debugPrint(
                '[Login] ✅ Found marketplace seller, routing to SellerHomeScreen');
            // Cache the profile
            await UserPersistence.saveUserProfile(sellerDoc.data() ?? {});
            _navigateTo(const SellerHomeScreen());
            return true;
          }
        } catch (e) {
          debugPrint('[Login] Marketplace check error: $e');
        }

        // 3 — Community Member
        try {
          final memberDoc = await db
              .collection('members')
              .doc(uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(timeout);
          if (memberDoc.exists) {
            debugPrint(
                '[Login] ✅ Found community member, routing to CommunityHomeScreen');
            // Cache the profile
            await UserPersistence.saveUserProfile(memberDoc.data() ?? {});
            _navigateTo(const CommunityHomeScreen());
            return true;
          }
        } catch (e) {
          debugPrint('[Login] Member check error: $e');
        }

        // All checks passed but no user found
        return false;
      } catch (e) {
        debugPrint('[Login] Firestore routing attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    return false;
  }

  /// Offline-first routing using cached user profile
  Future<bool> _routeOfflineFirst(String uid) async {
    try {
      final cachedProfile = await UserPersistence.getUserProfile();
      if (cachedProfile == null) {
        debugPrint('[Login] No cached profile found');
        return false;
      }

      debugPrint('[Login] Using cached profile for routing');

      // Determine role from cached profile
      final role = cachedProfile['role'] as String?;

      if (role == 'Org Rep') {
        debugPrint(
            '[Login] ✅ Cached profile is Org Rep, routing to OrganizationHome');
        _navigateTo(const OrganizationHome());
        return true;
      } else if (role == 'Marketplace Seller') {
        debugPrint(
            '[Login] ✅ Cached profile is Marketplace Seller, routing to SellerHomeScreen');
        _navigateTo(const SellerHomeScreen());
        return true;
      } else {
        debugPrint(
            '[Login] ✅ Cached profile is Community Member, routing to CommunityHomeScreen');
        _navigateTo(const CommunityHomeScreen());
        return true;
      }
    } catch (e) {
      debugPrint('[Login] Offline-first routing error: $e');
      return false;
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
    showCanopySnack(context, msg, error: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (!_emailOk(email)) {
      setState(() => _showErrors = true);
      showCanopySnack(context, 'Enter your email above first, then tap Forgot password.', error: true);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showCanopySnack(context, 'If $email has an account, a reset link is on its way.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't send the reset email. Try again.", error: true);
    }
  }

  static bool _emailOk(String v) => RegExp(r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$').hasMatch(v);

  String? get _emailError {
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return 'Enter your email.';
    return _emailOk(v) ? null : "That doesn't look like an email.";
  }

  String? get _passwordError => _passwordCtrl.text.isEmpty ? 'Enter your password.' : null;

  void _submit() {
    setState(() => _showErrors = true);
    if (_emailError != null || _passwordError != null) return;
    _signIn();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, showBack: Navigator.canPop(context)),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
          children: [
            Center(child: Image.asset('pngs/logotext.png', height: 48, fit: BoxFit.contain)),
            const SizedBox(height: CanopySpace.s24),
            Text('Welcome back', style: CanopyType.display.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s4),
            Text('Sign in to your Canopy account.', style: CanopyType.body.copyWith(color: p.inkMuted)),
            const SizedBox(height: CanopySpace.section),
            CanopyTextField(
              label: 'Email',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              error: _showErrors ? _emailError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: CanopySpace.s16),
            CanopyTextField(
              label: 'Password',
              controller: _passwordCtrl,
              obscure: _isObscure,
              textInputAction: TextInputAction.done,
              error: _showErrors ? _passwordError : null,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              suffix: CanopyIconButton(
                icon: _isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                tooltip: _isObscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _isObscure = !_isObscure),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _loading ? null : _resetPassword, child: const Text('Forgot password?')),
            ),
          ],
        ),
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(label: 'Sign in', expand: true, loading: _loading, onPressed: _loading ? null : _submit),
        const SizedBox(height: CanopySpace.s8),
        CanopyButton(
          label: 'Continue with Google',
          variant: CanopyButtonVariant.secondary,
          expand: true,
          onPressed: _loading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: CanopySpace.s8),
        CanopyButton(
          label: "I'm new here — create an account",
          variant: CanopyButtonVariant.quiet,
          expand: true,
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const JoinCommunityScreen())),
        ),
      ]),
    );
  }
}
