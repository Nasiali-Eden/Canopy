import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'Services/storage/user_persistence.dart';
import 'Community/Map/org_logo_cache.dart';

import 'Community/Communication/announcements_list.dart';
import 'Community/Contributions/log_contribution.dart';
import 'Community/Home/community_home.dart';
import 'Community/Impact/impact_dashboard.dart';
import 'Community/Profile/community_info.dart';
import 'Community/Profile/edit_profile.dart';
import 'Community/Profile/roadmap_screen.dart';
import 'Community/Profile/settings_screen.dart';
import 'Community/Recognition/badges_screen.dart';
import 'Models/user.dart';
import 'Providers/location_provider.dart';
import 'Services/Geo/geo_registry.dart';
import 'Providers/theme_provider.dart';
import 'Services/Authentication/auth.dart';
import 'Shared/Pages/splash_screen.dart';
import 'Shared/Pages/welcome_screen.dart';

import 'Shared/theme/app_theme.dart';
import 'firebase_options.dart';

/// Initialize Firebase safely with retry logic
Future<void> initializeFirebase() async {
  const int maxRetries = 3;
  const Duration retryDelay = Duration(seconds: 2);

  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        debugPrint(
            '[Firebase] Already initialized (${Firebase.apps.length} apps found)');
        await _configureFirestoreSafely();
        return;
      }

      debugPrint('[Firebase] Initialization attempt $attempt/$maxRetries...');

      // Initialize Firebase with timeout
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Firebase initialization timed out after 20 seconds');
        },
      );

      debugPrint('[Firebase] ✅ Initialized successfully on attempt $attempt');
      await _configureFirestoreSafely();
      return;
    } on FirebaseException catch (e) {
      debugPrint(
          '[Firebase] Exception on attempt $attempt: ${e.code} - ${e.message}');

      // If it's already initialized error, check for apps
      if (e.code == 'duplicate-app' || Firebase.apps.isNotEmpty) {
        debugPrint('[Firebase] Already initialized, proceeding...');
        await _configureFirestoreSafely();
        return;
      }

      // For other Firebase errors, retry unless it's the last attempt
      if (attempt == maxRetries) {
        debugPrint('[Firebase] ❌ Failed after $maxRetries attempts');
        rethrow;
      }
    } on TimeoutException catch (e) {
      debugPrint('[Firebase] Timeout on attempt $attempt: $e');
      if (attempt == maxRetries) {
        debugPrint('[Firebase] ❌ Timed out after $maxRetries attempts');
        rethrow;
      }
    } catch (e) {
      debugPrint('[Firebase] Unexpected error on attempt $attempt: $e');

      // Check if Firebase became available despite the error
      if (Firebase.apps.isNotEmpty) {
        debugPrint('[Firebase] Available despite error, proceeding...');
        await _configureFirestoreSafely();
        return;
      }

      if (attempt == maxRetries) {
        debugPrint('[Firebase] ❌ Failed after $maxRetries attempts');
        rethrow;
      }
    }

    // Wait before retry (except on last attempt)
    if (attempt < maxRetries) {
      debugPrint('[Firebase] Waiting ${retryDelay.inSeconds}s before retry...');
      await Future.delayed(retryDelay);
    }
  }
}

/// Configure Firestore settings safely
Future<void> _configureFirestoreSafely() async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Small delay for stability
    await Future.delayed(const Duration(milliseconds: 100));

    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    debugPrint(
        '[Firestore] ✅ Settings configured (persistence enabled, unlimited cache)');

    // Enable network
    await firestore.enableNetwork();
    debugPrint('[Firestore] ✅ Network enabled');
  } catch (e) {
    debugPrint('[Firestore] ⚠️ Configuration error: $e');
    // Continue anyway - Firestore might already be configured or will use defaults
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 35, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize the app',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please restart the application.',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
                onPressed: () {
                  // Force app exit to restart
                  exit(1);
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Close App',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('[App] Starting initialization...');

    // Initialize user persistence first
    await UserPersistence.init();
    debugPrint('[App] ✅ User persistence initialized');

    // Then initialize Firebase
    await initializeFirebase();
    debugPrint('[App] ✅ Firebase initialized');

    // Warm up org logo images in the background so map markers render
    // instantly when the map opens (fire-and-forget — never block startup).
    OrgLogoCache.instance.warmUp();

    // Load the geography registry before the first frame. It backs the
    // location switch, every geo-scoped query, and the legacy-location
    // resolver, so having it cold on first paint causes a visible flicker.
    await GeoRegistry.instance.ensureLoaded();

    debugPrint('[App] ✅ App initialization completed successfully');
    runApp(const MyApp());
  } catch (e) {
    debugPrint('[App] ❌ Initialization failed: $e');
    // Still run the app but show error
    runApp(const ErrorApp());
  }
}

/// Named routes pushed from around the app. Only routes whose screen actually
/// exists are listed; anything else falls through to [MaterialApp.onUnknownRoute].
final Map<String, WidgetBuilder> _appRoutes = {
  '/splash': (_) => const SplashScreen(),
  '/welcome': (_) => const WelcomeScreen(),
  '/home': (_) => const CommunityHomeScreen(),
  '/impact': (_) => const ImpactDashboardScreen(),
  '/contributions/log': (_) => const LogContributionScreen(),
  '/settings': (_) => const SettingsScreen(),
  '/profile/edit': (_) => const EditProfileScreen(),
  '/community/info': (_) => const CommunityInfoScreen(),
  '/announcements': (_) => const AnnouncementsListScreen(),
  '/roadmap': (_) => const RoadmapScreen(),
  '/recognition/badges': (_) => const BadgesScreen(),
};

/// Shown when a screen pushes a route that has no implementation yet. Better a
/// readable dead-end than a red assertion mid-flow.
class _RouteNotFoundScreen extends StatelessWidget {
  final String? name;

  const _RouteNotFoundScreen({this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not available')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined,
                  size: 44, color: AppTheme.primary.withOpacity(0.4)),
              const SizedBox(height: 14),
              Text(
                'This screen is not built yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (name != null) ...[
                const SizedBox(height: 8),
                Text(
                  name!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves the member's home county once auth settles, and again whenever the
/// signed-in user changes. Sits above the app's home so every screen reached
/// from it already has a resolved location scope.
class _LocationBinder extends StatefulWidget {
  final Widget child;
  const _LocationBinder({required this.child});

  @override
  State<_LocationBinder> createState() => _LocationBinderState();
}

class _LocationBinderState extends State<_LocationBinder> {
  String? _boundUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<F_User?>(context);
    final uid = user?.uid;
    if (uid == _boundUid) return;
    _boundUid = uid;

    final provider = context.read<LocationProvider>();
    // Fire and forget — the switch renders "Finding your area…" until this
    // settles, and falls back to Everywhere if the profile has no location.
    user?.orgId.then((orgId) {
      if (mounted) provider.initialise(uid: uid, orgId: orgId);
    }).catchError((Object _) {
      if (mounted) provider.initialise(uid: uid);
    });
    if (uid == null) provider.initialise();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<F_User?>.value(
          value: AuthService().user,
          initialData: null,
          catchError: (context, error) {
            debugPrint('[App] Auth stream error: $error');
            return null;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = ThemeProvider();
            p.load();
            return p;
          },
        ),
        // Location scope for every localized surface — feed, marketplace,
        // activities. Defaults to the member's own county once auth resolves;
        // see _LocationBinder below, which re-initialises on account change.
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Impact Ledger',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.mode,
            home: const _LocationBinder(child: SplashScreen()),
            routes: _appRoutes,
            // Screens across the app push named routes, but no table was ever
            // registered — every one of them threw "Could not find a generator
            // for route". Anything still unmapped lands here instead of
            // crashing the flow it was called from.
            onUnknownRoute: (settings) => MaterialPageRoute(
              builder: (_) => _RouteNotFoundScreen(name: settings.name),
            ),
          );
        },
      ),
    );
  }
}
