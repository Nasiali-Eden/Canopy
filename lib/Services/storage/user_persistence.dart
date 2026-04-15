import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserPersistence {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserData = 'user_data';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserUid = 'user_uid';
  static const String _keyLastLogin = 'last_login';
  static const String _keyUserProfile = 'user_profile';

  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get SharedPreferences instance
  static Future<SharedPreferences> get _preferences async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Convert Firestore Timestamp to ISO string for JSON serialization
  static Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        // Convert Timestamp to ISO string
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        // Convert DateTime to ISO string
        sanitized[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        // Recursively sanitize nested maps
        sanitized[key] = _sanitizeForJson(value);
      } else if (value is List) {
        // Sanitize list items
        sanitized[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sanitizeForJson(item);
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          } else if (item is DateTime) {
            return item.toIso8601String();
          }
          return item;
        }).toList();
      } else {
        // Keep other types as-is
        sanitized[key] = value;
      }
    });
    
    return sanitized;
  }

  /// Check if user is logged in (persisted state)
  static Future<bool> isLoggedIn() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Save user login state
  static Future<void> saveLoginState(String uid, String role) async {
    final prefs = await _preferences;
    await Future.wait([
      prefs.setBool(_keyIsLoggedIn, true),
      prefs.setString(_keyUserUid, uid),
      prefs.setString(_keyUserRole, role),
      prefs.setInt(_keyLastLogin, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  /// Get persisted user UID
  static Future<String?> getUserUid() async {
    final prefs = await _preferences;
    return prefs.getString(_keyUserUid);
  }

  /// Get persisted user role
  static Future<String?> getUserRole() async {
    final prefs = await _preferences;
    return prefs.getString(_keyUserRole);
  }

  /// Save user profile data (sanitizes Firestore Timestamps)
  static Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    try {
      final prefs = await _preferences;
      
      // Sanitize data to handle Firestore Timestamps
      final sanitized = _sanitizeForJson(profileData);
      
      final jsonString = jsonEncode(sanitized);
      await prefs.setString(_keyUserProfile, jsonString);
      
      debugPrint('[UserPersistence] ✅ User profile cached successfully');
    } catch (e) {
      debugPrint('[UserPersistence] ⚠️ Error caching user profile: $e');
      // Don't rethrow - caching is not critical
    }
  }

  /// Get cached user profile data
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await _preferences;
    final jsonString = prefs.getString(_keyUserProfile);
    if (jsonString != null) {
      try {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[UserPersistence] ⚠️ Error decoding cached profile: $e');
        return null;
      }
    }
    return null;
  }

  /// Check if login is still valid (within 30 days)
  static Future<bool> isLoginValid() async {
    final prefs = await _preferences;
    final lastLogin = prefs.getInt(_keyLastLogin);
    
    if (lastLogin == null) return false;
    
    final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLogin);
    final now = DateTime.now();
    final difference = now.difference(lastLoginTime).inDays;
    
    // Consider login valid for 30 days
    return difference <= 30;
  }

  /// Refresh user profile from Firestore and cache it
  static Future<Map<String, dynamic>?> refreshUserProfile(String uid) async {
    try {
      final role = await getUserRole();
      if (role == null) return null;

      DocumentSnapshot? userDoc;
      
      // Check in appropriate collection based on role
      if (role == 'Org Rep') {
        userDoc = await FirebaseFirestore.instance
            .collection('org_rep')
            .doc(uid)
            .get();
      } else if (role == 'Marketplace Seller') {
        userDoc = await FirebaseFirestore.instance
            .collection('marketplace_sellers')
            .doc(uid)
            .get();
      } else {
        userDoc = await FirebaseFirestore.instance
            .collection('members')
            .doc(uid)
            .get();
      }

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        await saveUserProfile(userData);
        debugPrint('[UserPersistence] ✅ User profile refreshed and cached');
        return userData;
      }
    } catch (e) {
      debugPrint('[UserPersistence] ⚠️ Error refreshing user profile: $e');
    }
    return null;
  }

  /// Validate current Firebase auth and sync with persistence
  static Future<bool> validateAndSyncAuth() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final isPersistedLogin = await isLoggedIn();
      final isValidLogin = await isLoginValid();
      
      // If Firebase has no user but we have persisted login
      if (currentUser == null && isPersistedLogin && isValidLogin) {
        // Try to restore from cached data - but this means auth token expired
        // Clear the invalid state
        await clearUserData();
        return false;
      }
      
      // If Firebase has user but no persisted login
      if (currentUser != null && !isPersistedLogin) {
        // User might have signed in elsewhere, sync the state
        final userData = await _fetchUserData(currentUser.uid);
        if (userData != null) {
          await saveLoginState(currentUser.uid, userData['role'] ?? 'Member');
          await saveUserProfile(userData);
          return true;
        }
      }
      
      // If both have user and login is valid
      if (currentUser != null && isPersistedLogin && isValidLogin) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('[UserPersistence] ⚠️ Error validating auth: $e');
      return false;
    }
  }

  /// Fetch user data from Firestore
  static Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    try {
      // Check marketplace_sellers first
      final sellerDoc = await FirebaseFirestore.instance
          .collection('marketplace_sellers')
          .doc(uid)
          .get();
      
      if (sellerDoc.exists) {
        final data = sellerDoc.data() as Map<String, dynamic>;
        data['role'] = 'Marketplace Seller';
        return data;
      }

      // Check org_rep collection
      final orgDoc = await FirebaseFirestore.instance
          .collection('org_rep')
          .doc(uid)
          .get();
      
      if (orgDoc.exists) {
        final data = orgDoc.data() as Map<String, dynamic>;
        data['role'] = 'Org Rep';
        return data;
      }
      
      // Check members collection
      final memberDoc = await FirebaseFirestore.instance
          .collection('members')
          .doc(uid)
          .get();
      
      if (memberDoc.exists) {
        final data = memberDoc.data() as Map<String, dynamic>;
        data['role'] = 'Member';
        return data;
      }
    } catch (e) {
      debugPrint('[UserPersistence] ⚠️ Error fetching user data: $e');
    }
    return null;
  }

  /// Clear all user data (on logout)
  static Future<void> clearUserData() async {
    final prefs = await _preferences;
    await Future.wait([
      prefs.remove(_keyIsLoggedIn),
      prefs.remove(_keyUserData),
      prefs.remove(_keyUserRole),
      prefs.remove(_keyUserUid),
      prefs.remove(_keyLastLogin),
      prefs.remove(_keyUserProfile),
    ]);
    debugPrint('[UserPersistence] ✅ User data cleared');
  }

  /// Update last login time (call this periodically when app is active)
  static Future<void> updateLastLogin() async {
    final isLoggedIn = await UserPersistence.isLoggedIn();
    if (isLoggedIn) {
      final prefs = await _preferences;
      await prefs.setInt(_keyLastLogin, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Get time since last login in days
  static Future<int?> getDaysSinceLastLogin() async {
    final prefs = await _preferences;
    final lastLogin = prefs.getInt(_keyLastLogin);
    
    if (lastLogin == null) return null;
    
    final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLogin);
    final now = DateTime.now();
    return now.difference(lastLoginTime).inDays;
  }
}
