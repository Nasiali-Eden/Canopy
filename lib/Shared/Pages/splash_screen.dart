import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Community/Home/community_home.dart';
import '../../MarketPlace/market_home.dart';
import '../../Organization/Home/org_home.dart';
import '../../Shared/Pages/welcome_screen.dart';
import '../../Services/Demo/demo_seeder.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);

    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // Minimum brand display time
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _navigated) return;

    // Wait for Firebase Auth to restore session (max 5s)
    final authUser = await _waitForAuth();

    if (authUser == null) {
      _go(const WelcomeScreen());
      return;
    }

    // Seed demo data (non-critical)
    try {
      final seeder = DemoSeeder();
      await Future.wait([
        seeder.seedIfNeeded(userId: authUser.uid),
        seeder.seedCommsIfNeeded(userId: authUser.uid),
      ]);
    } catch (_) {}

    if (!mounted || _navigated) return;
    await _routeByCollection(authUser.uid);
  }

  Future<User?> _waitForAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser;

    final completer = Completer<User?>();
    StreamSubscription? sub;
    sub = auth.authStateChanges().listen((user) {
      if (!completer.isCompleted) { completer.complete(user); sub?.cancel(); }
    });
    await Future.delayed(const Duration(seconds: 5));
    if (!completer.isCompleted) { sub.cancel(); completer.complete(auth.currentUser); }
    return completer.future;
  }

  /// Check collections in priority order and route accordingly.
  Future<void> _routeByCollection(String uid) async {
    final db = FirebaseFirestore.instance;
    try {
      // 1 — Marketplace Seller
      final sellerDoc = await db.collection('marketplace_sellers').doc(uid).get();
      if (sellerDoc.exists) { _go(const SellerHomeScreen()); return; }

      // 2 — Org Rep
      final orgDoc = await db.collection('org_rep').doc(uid).get();
      if (orgDoc.exists) { _go(const OrganizationHome()); return; }

      // 3 — Community Member
      final memberDoc = await db.collection('members').doc(uid).get();
      if (memberDoc.exists) { _go(const CommunityHomeScreen()); return; }

      // Not found in any collection
      _go(const WelcomeScreen());
    } catch (e) {
      debugPrint('[Splash] routing error: $e');
      _go(const WelcomeScreen());
    }
  }

  void _go(Widget destination) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
            (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(children: [
              const Spacer(),
              Center(
                child: Column(children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Image.asset('pngs/logotext.png', width: 200, height: 120),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Track real-world contributions.\nBuild community impact.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor),
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Opacity(
                  opacity: 0.5,
                  child: Text('v1.0.0',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.black54)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}