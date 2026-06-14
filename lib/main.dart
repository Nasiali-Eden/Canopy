import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'Services/storage/user_persistence.dart';
import 'Community/Map/org_logo_cache.dart';

import 'Models/user.dart';
import 'Providers/theme_provider.dart';
import 'Services/Authentication/auth.dart';
import 'Shared/Pages/splash_screen.dart';

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

    debugPrint('[App] ✅ App initialization completed successfully');
    runApp(const MyApp());
  } catch (e) {
    debugPrint('[App] ❌ Initialization failed: $e');
    // Still run the app but show error
    runApp(const ErrorApp());
  }
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Impact Ledger',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.mode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
