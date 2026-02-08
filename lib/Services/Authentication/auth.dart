import 'package:firebase_auth/firebase_auth.dart';
import '../../Models/user.dart';
import '../database/database.dart'; // Import the database service
import '../storage/user_persistence.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  // Add a method to check if the token is valid and refresh if needed
  Future<String?> _getValidToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Force a token refresh
        final tokenResult = await user.getIdTokenResult(true);
        return tokenResult.token;
      }
      return null;
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      // Sign in
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Ensure we have a valid token before proceeding
        await _getValidToken();

        // Add a small delay to ensure token propagation
        await Future.delayed(Duration(milliseconds: 500));

        // Determine user role and save persistent login state
        final role = await _databaseService.getUserRole(user.uid);
        if (role != null) {
          await UserPersistence.saveLoginState(user.uid, role);
          // Cache user profile data
          await UserPersistence.refreshUserProfile(user.uid);
        }
      }

      return user;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  Future<User?> signUp(String email, String password, String role,
      Map<String, dynamic> additionalData) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      // Ensure we have a valid token before proceeding
      await _getValidToken();

      // Add a small delay to ensure token propagation
      await Future.delayed(Duration(milliseconds: 500));

      if (user != null) {
        await _databaseService.postDetailsToFirestore(
            user.uid, email, role, additionalData);
      }
      return user;
    } catch (e) {
      print('Sign up error: $e');
      return null;
    }
  }

  // Add a method to verify authentication state
  Future<bool> isAuthenticated() async {
    final token = await _getValidToken();
    return token != null;
  }

  F_User? _userFromFirebaseUser(User? user) {
    if (user == null) return null;
    return F_User(uid: user.uid); // Ensure uid is never null
  }

  Stream<F_User?> get user {
    return _auth.authStateChanges().map(_userFromFirebaseUser);
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }
}