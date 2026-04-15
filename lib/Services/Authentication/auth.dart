import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../Models/user.dart';
import '../database/database.dart';
import '../storage/user_persistence.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  Future<String?> _getValidToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final tokenResult = await user.getIdTokenResult(true);
        return tokenResult.token;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] Error getting token: $e');
      return null;
    }
  }

  /// Sign in with retry logic for network failures
  /// Throws FirebaseAuthException or other exceptions on failure
  /// Returns User on success
  Future<User?> signIn(String email, String password) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('[AuthService] Sign in attempt $attempt/$_maxRetries for $email');

        UserCredential result = await _auth
            .signInWithEmailAndPassword(
              email: email,
              password: password,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw FirebaseAuthException(
                code: 'network-timeout',
                message: 'Sign in request timed out after 30 seconds',
              ),
            );

        User? user = result.user;
        if (user != null) {
          await _getValidToken();
          await Future.delayed(const Duration(milliseconds: 500));

          final role = await _databaseService.getUserRole(user.uid);
          if (role != null) {
            await UserPersistence.saveLoginState(user.uid, role);
            await UserPersistence.refreshUserProfile(user.uid);
          }
          debugPrint('[AuthService] ✅ Sign in successful on attempt $attempt');
          return user;
        }
        return null;
      } on FirebaseAuthException catch (e) {
        lastException = e;
        debugPrint(
            '[AuthService] Sign in Firebase error on attempt $attempt: ${e.code} - ${e.message}');

        // Don't retry on non-network errors
        if (!_isNetworkError(e.code)) {
          debugPrint('[AuthService] Not a network error (${e.code}), giving up');
          rethrow;
        }

        // If this is the last attempt, rethrow
        if (attempt == _maxRetries) {
          debugPrint('[AuthService] Max retries reached for sign in');
          rethrow;
        }

        debugPrint('[AuthService] Retrying sign in after ${_retryDelay.inSeconds}s...');
        await Future.delayed(_retryDelay);
      } catch (e) {
        lastException = e as Exception;
        debugPrint('[AuthService] Sign in error on attempt $attempt: $e');

        // If this is the last attempt, rethrow
        if (attempt == _maxRetries) {
          debugPrint('[AuthService] Max retries reached for sign in (non-Firebase error)');
          rethrow;
        }

        debugPrint('[AuthService] Retrying sign in after ${_retryDelay.inSeconds}s...');
        await Future.delayed(_retryDelay);
      }
    }

    // Should not reach here, but if we do, throw the last exception
    if (lastException != null) {
      throw lastException;
    }
    throw Exception('Sign in failed after $_maxRetries attempts');
  }

  /// Sign up with retry logic for network failures
  /// Throws FirebaseAuthException or other exceptions on failure
  /// Returns User on success
  Future<User?> signUp(String email, String password, String role,
      Map<String, dynamic> additionalData) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('[AuthService] Sign up attempt $attempt/$_maxRetries for $email');

        UserCredential result = await _auth
            .createUserWithEmailAndPassword(
              email: email,
              password: password,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw FirebaseAuthException(
                code: 'network-timeout',
                message: 'Sign up request timed out after 30 seconds',
              ),
            );

        User? user = result.user;

        if (user != null) {
          await _getValidToken();
          await Future.delayed(const Duration(milliseconds: 500));

          await _databaseService.postDetailsToFirestore(
              user.uid, email, role, additionalData);
          debugPrint('[AuthService] ✅ Sign up successful on attempt $attempt');
          return user;
        }
        return null;
      } on FirebaseAuthException catch (e) {
        lastException = e;
        debugPrint(
            '[AuthService] Sign up Firebase error on attempt $attempt: ${e.code} - ${e.message}');

        // Don't retry on non-network errors
        if (!_isNetworkError(e.code)) {
          debugPrint('[AuthService] Not a network error (${e.code}), giving up');
          rethrow;
        }

        // If this is the last attempt, rethrow
        if (attempt == _maxRetries) {
          debugPrint('[AuthService] Max retries reached for sign up');
          rethrow;
        }

        debugPrint('[AuthService] Retrying sign up after ${_retryDelay.inSeconds}s...');
        await Future.delayed(_retryDelay);
      } catch (e) {
        lastException = e as Exception;
        debugPrint('[AuthService] Sign up error on attempt $attempt: $e');

        // If this is the last attempt, rethrow
        if (attempt == _maxRetries) {
          debugPrint('[AuthService] Max retries reached for sign up (non-Firebase error)');
          rethrow;
        }

        debugPrint('[AuthService] Retrying sign up after ${_retryDelay.inSeconds}s...');
        await Future.delayed(_retryDelay);
      }
    }

    // Should not reach here, but if we do, throw the last exception
    if (lastException != null) {
      throw lastException;
    }
    throw Exception('Sign up failed after $_maxRetries attempts');
  }

  /// Check if error is network-related
  static bool _isNetworkError(String code) {
    return code == 'network-request-failed' ||
        code == 'network-timeout' ||
        code == 'too-many-requests' ||
        code == 'service-disabled';
  }

  Future<bool> isAuthenticated() async {
    final token = await _getValidToken();
    return token != null;
  }

  F_User? _userFromFirebaseUser(User? user) {
    if (user == null) return null;
    return F_User(uid: user.uid);
  }

  Stream<F_User?> get user {
    return _auth.authStateChanges().map(_userFromFirebaseUser);
  }

  Future<void> signOut() async {
    try {
      await UserPersistence.clearUserData();
      await _auth.signOut();
      debugPrint('[AuthService] ✅ Sign out successful');
    } catch (e) {
      debugPrint('[AuthService] Sign out error: $e');
      rethrow;
    }
  }
}
