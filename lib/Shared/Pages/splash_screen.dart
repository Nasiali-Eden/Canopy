import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../Community/Home/community_home.dart';
import '../../MarketPlace/market_home.dart';
import '../../Organization/Home/org_home.dart';
import '../../Services/storage/user_persistence.dart';
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

    debugPrint('[Splash] Starting auth check...');

    // Wait for Firebase Auth to restore session (max 10s)
    final authUser = await _waitForAuth();

    if (authUser == null) {
      debugPrint('[Splash] No authenticated user, going to WelcomeScreen');
      _go(const WelcomeScreen());
      return;
    }

    debugPrint('[Splash] User authenticated: ${authUser.uid}');

    // Seed demo data (non-critical)
    try {
      final seeder = DemoSeeder();
      await Future.wait([
        seeder.seedIfNeeded(userId: authUser.uid),
        seeder.seedCommsIfNeeded(userId: authUser.uid),
      ]);
    } catch (e) {
      debugPrint('[Splash] Demo seeding error (non-critical): $e');
    }

    if (!mounted || _navigated) return;
    await _routeByCollection(authUser.uid);
  }

  /// Wait for Firebase Auth to restore session
  /// Returns current user if available, or waits up to 10 seconds for auth state change
  Future<User?> _waitForAuth() async {
    final auth = FirebaseAuth.instance;
    
    // If user is already signed in, return immediately
    if (auth.currentUser != null) {
      debugPrint('[Splash] User already signed in: ${auth.currentUser!.uid}');
      return auth.currentUser;
    }

    debugPrint('[Splash] Waiting for auth state changes (max 10s)...');
    
    final completer = Completer<User?>();
    StreamSubscription? sub;
    
    sub = auth.authStateChanges().listen((user) {
      if (!completer.isCompleted) {
        if (user != null) {
          debugPrint('[Splash] Auth state changed: user signed in');
        } else {
          debugPrint('[Splash] Auth state changed: user signed out');
        }
        completer.complete(user);
        sub?.cancel();
      }
    });

    // Wait max 10 seconds for auth state change
    await Future.delayed(const Duration(seconds: 10));
    
    if (!completer.isCompleted) {
      debugPrint('[Splash] Auth state timeout, using current user');
      sub?.cancel();
      completer.complete(auth.currentUser);
    }
    
    return completer.future;
  }

  /// Ensure Firestore is ready with retry logic
  Future<bool> _ensureFirestoreReady() async {
    const maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
      try {
        debugPrint('[Splash] Firestore readiness check attempt ${i + 1}/$maxRetries');
        final db = FirebaseFirestore.instance;
        
        // Enable network to ensure connectivity
        await db.enableNetwork();
        
        // Small delay for stability
        await Future.delayed(const Duration(milliseconds: 500));
        
        debugPrint('[Splash] ✅ Firestore is ready');
        return true;
      } catch (e) {
        debugPrint('[Splash] Firestore ready check failed: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    debugPrint('[Splash] ⚠️ Firestore readiness check failed after $maxRetries attempts');
    return false;
  }

  /// Check collections in priority order and route accordingly
  /// Implements offline-first fallback using cached user profile
  Future<void> _routeByCollection(String uid) async {
    final db = FirebaseFirestore.instance;
    
    try {
      debugPrint('[Splash] Routing user $uid...');
      
      // Ensure Firestore is ready before making queries
      final firestoreReady = await _ensureFirestoreReady();
      
      if (firestoreReady) {
        // Try Firestore routing with retry logic
        final routed = await _routeWithFirestore(db, uid);
        if (routed) return;
      }

      // If Firestore fails or is not ready, try offline-first routing
      debugPrint('[Splash] Firestore routing failed, trying offline-first routing...');
      final offlineRouted = await _routeOfflineFirst(uid);
      if (offlineRouted) return;

      // If all else fails, go to welcome screen
      debugPrint('[Splash] No user profile found, routing to WelcomeScreen');
      _go(const WelcomeScreen());
    } catch (e) {
      debugPrint('[Splash] Routing error: $e');
      _go(const WelcomeScreen());
    }
  }

  /// Try to route using Firestore with retry logic
  Future<bool> _routeWithFirestore(FirebaseFirestore db, String uid) async {
    const maxRetries = 3;
    const timeout = Duration(seconds: 10);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[Splash] Firestore routing attempt $attempt/$maxRetries');

        // 1 — Marketplace Seller
        try {
          final sellerDoc = await db
              .collection('marketplace_sellers')
              .doc(uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(timeout);
          if (sellerDoc.exists) {
            debugPrint('[Splash] ✅ Found marketplace seller');
            await UserPersistence.saveUserProfile(sellerDoc.data() ?? {});
            _go(const SellerHomeScreen());
            return true;
          }
        } catch (e) {
          debugPrint('[Splash] Marketplace check error: $e');
        }

        // 2 — Org Rep
        try {
          final orgDoc = await db
              .collection('org_rep')
              .doc(uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(timeout);
          if (orgDoc.exists) {
            debugPrint('[Splash] ✅ Found org rep');
            await UserPersistence.saveUserProfile(orgDoc.data() ?? {});
            _go(const OrganizationHome());
            return true;
          }
        } catch (e) {
          debugPrint('[Splash] Org rep check error: $e');
        }

        // 3 — Community Member
        try {
          final memberDoc = await db
              .collection('members')
              .doc(uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(timeout);
          if (memberDoc.exists) {
            debugPrint('[Splash] ✅ Found community member');
            await UserPersistence.saveUserProfile(memberDoc.data() ?? {});
            _go(const CommunityHomeScreen());
            return true;
          }
        } catch (e) {
          debugPrint('[Splash] Member check error: $e');
        }

        // All checks passed but no user found
        return false;
      } catch (e) {
        debugPrint('[Splash] Firestore routing attempt $attempt failed: $e');
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
        debugPrint('[Splash] No cached profile found');
        return false;
      }

      debugPrint('[Splash] Using cached profile for routing');
      
      final role = cachedProfile['role'] as String?;
      
      if (role == 'Org Rep') {
        debugPrint('[Splash] ✅ Cached profile is Org Rep');
        _go(const OrganizationHome());
        return true;
      } else if (role == 'Marketplace Seller') {
        debugPrint('[Splash] ✅ Cached profile is Marketplace Seller');
        _go(const SellerHomeScreen());
        return true;
      } else {
        debugPrint('[Splash] ✅ Cached profile is Community Member');
        _go(const CommunityHomeScreen());
        return true;
      }
    } catch (e) {
      debugPrint('[Splash] Offline-first routing error: $e');
      return false;
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
                    child: Image.asset('pngs/logotext.png',
                        width: 200, height: 120),
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
