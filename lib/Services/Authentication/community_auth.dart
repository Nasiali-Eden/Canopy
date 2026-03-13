import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Models/user.dart';

class CommunityAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CommunityAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // ─────────────────────────────────────────────────────────────────────────
  //  Marketplace Seller Registration
  // ─────────────────────────────────────────────────────────────────────────

  /// Registers a new marketplace seller.
  /// Writes to [marketplace_sellers] (primary) and [Users] (compatibility).
  Future<F_User?> registerAsMarketplaceSeller({
    // Account details
    required String email,
    required String password,
    required String name,
    required String phone,
    // Shop identity
    required String shopName,
    required String marketplaceRole, // 'Collector' | 'Processor' | 'Maker'
    required bool isBusiness,
    String? businessRegNo,
    XFile? shopLogo,
    // Marketplace profile
    required List<String>
        specialisations, // plastics (Collector) or materials (Processor/Maker)
    List<String> creativeCategories = const [], // Maker only
    String bio = '',
    // Location
    required String city,
    String area = '',
  }) async {
    try {
      debugPrint('[CommunityAuth] registerAsMarketplaceSeller start');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        debugPrint(
            '[CommunityAuth] createUserWithEmailAndPassword returned null user');
        return null;
      }
      debugPrint('[CommunityAuth] seller registered uid=${user.uid}');

      // Upload shop logo if provided
      String? shopLogoUrl;
      if (shopLogo != null) {
        try {
          final ref = _storage.ref().child(
              'marketplace_sellers/${user.uid}/shop_logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
          debugPrint('[CommunityAuth] uploading shop logo to ${ref.fullPath}');
          await ref.putFile(File(shopLogo.path));
          shopLogoUrl = await ref.getDownloadURL();
          debugPrint('[CommunityAuth] shop logo uploaded');
        } catch (e) {
          debugPrint('[CommunityAuth] logo upload error: $e');
          // Continue without logo — not critical
        }
      }

      // Primary document in marketplace_sellers collection
      final sellerData = {
        'uid': user.uid,
        'email': email,
        'name': name,
        'phone': phone,
        // Shop identity
        'shop_name': shopName,
        'marketplace_role': marketplaceRole,
        'is_business': isBusiness,
        if (isBusiness && businessRegNo != null && businessRegNo.isNotEmpty)
          'business_reg_no': businessRegNo,
        'shop_logo_url': shopLogoUrl,
        // Marketplace profile
        'specialisations': specialisations,
        if (creativeCategories.isNotEmpty)
          'creative_categories': creativeCategories,
        'bio': bio,
        // Location
        'city': city,
        'area': area,
        'country': 'Kenya',
        // Platform metrics
        'impact_points': 0,
        'kg_diverted': 0.0,
        'active_listings': 0,
        // Meta
        'type': 'Marketplace Seller',
        'createdAt': FieldValue.serverTimestamp(),
        'guidelinesAcceptedAt': null,
        'communityId': 'default',
      };

      debugPrint(
          '[CommunityAuth] writing seller doc to marketplace_sellers/${user.uid}');
      await _db.collection('marketplace_sellers').doc(user.uid).set(sellerData);

      // Mirror to Users collection for backwards compatibility
      await _db.collection('Users').doc(user.uid).set(
        {
          'name': name,
          'email': email,
          'role': 'Marketplace Seller',
          'marketplace_role': marketplaceRole,
          'shop_name': shopName,
          'city': city,
          'impact_points': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'guidelinesAcceptedAt': null,
          'communityId': 'default',
          'isPrototypeMode': true,
        },
        SetOptions(merge: true),
      );

      debugPrint(
          '[CommunityAuth] seller registration completed for uid=${user.uid}');
      return F_User(uid: user.uid);
    } on FirebaseException catch (e, st) {
      debugPrint('[CommunityAuth] FirebaseException: ${e.code} ${e.message}');
      debugPrint('$st');
      rethrow;
    } catch (e, st) {
      debugPrint('[CommunityAuth] error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Organization Registration
  // ─────────────────────────────────────────────────────────────────────────

  Future<F_User?> registerAsOrganization({
    required String email,
    required String password,
    required String orgName,
    required String orgRepName,
    required String background,
    required List<String> mainFunctions,
    required String orgDesignation,
    XFile? profilePhoto,
  }) async {
    try {
      debugPrint('[CommunityAuth] registerAsOrganization start');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        debugPrint(
            '[CommunityAuth] createUserWithEmailAndPassword returned null user');
        return null;
      }
      debugPrint('[CommunityAuth] organization registered uid=${user.uid}');

      const uuid = Uuid();
      final orgId = uuid.v4();

      String? profilePhotoUrl;
      if (profilePhoto != null) {
        try {
          final ref = _storage.ref().child(
              'organizations/$orgId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
          debugPrint(
              '[CommunityAuth] uploading org profile photo to ${ref.fullPath}');
          await ref.putFile(File(profilePhoto.path));
          profilePhotoUrl = await ref.getDownloadURL();
          debugPrint('[CommunityAuth] org profile photo uploaded');
        } catch (e) {
          debugPrint('[CommunityAuth] photo upload error: $e');
        }
      }

      final orgRepData = {
        'uid': user.uid,
        'email': email,
        'name': orgRepName,
        'org_name': orgName,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('org_rep').doc(user.uid).set(orgRepData);

      final organizationsData = {
        'orgId': orgId,
        'org_name': orgName,
        'org_rep_name': orgRepName,
        'org_rep_uid': user.uid,
        'email': email,
        'background': background,
        'mainFunctions': mainFunctions,
        'orgDesignation': orgDesignation,
        'profilePhoto': profilePhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'guidelinesAcceptedAt': null,
        'type': 'Org Rep',
        'impact_points': 0,
        'communityId': 'default',
      };
      await _db.collection('organizations').doc(orgId).set(organizationsData);

      await _db.collection('Users').doc(user.uid).set(
        {
          'name': orgRepName,
          'email': email,
          'role': 'Org Rep',
          'orgId': orgId,
          'orgName': orgName,
          'createdAt': FieldValue.serverTimestamp(),
          'guidelinesAcceptedAt': null,
          'impact_points': 0,
          'communityId': 'default',
          'isPrototypeMode': true,
        },
        SetOptions(merge: true),
      );

      debugPrint(
          '[CommunityAuth] organization registration completed for uid=${user.uid}');
      return F_User(uid: user.uid);
    } on FirebaseException catch (e, st) {
      debugPrint('[CommunityAuth] FirebaseException: ${e.code} ${e.message}');
      debugPrint('$st');
      rethrow;
    } catch (e, st) {
      debugPrint('[CommunityAuth] error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Community Member Registration
  // ─────────────────────────────────────────────────────────────────────────

  Future<F_User?> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      debugPrint('[CommunityAuth] registerWithEmail start');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        debugPrint(
            '[CommunityAuth] createUserWithEmailAndPassword returned null user');
        return null;
      }
      debugPrint('[CommunityAuth] registered uid=${user.uid}');

      final data = {
        'name': name,
        'email': email,
        'role': role,
        if (role == 'Volunteer') 'volunteer': true,
        'createdAt': FieldValue.serverTimestamp(),
        'guidelinesAcceptedAt': null,
        'impact_points': 0,
        'communityId': 'default',
      };

      await _db.collection('members').doc(user.uid).set(data);
      await _db.collection('Users').doc(user.uid).set(
        {...data, 'isPrototypeMode': true},
        SetOptions(merge: true),
      );

      debugPrint('[CommunityAuth] registration completed for uid=${user.uid}');
      return F_User(uid: user.uid);
    } on FirebaseException catch (e, st) {
      debugPrint('[CommunityAuth] FirebaseException: ${e.code} ${e.message}');
      debugPrint('$st');
      rethrow;
    } catch (e, st) {
      debugPrint('[CommunityAuth] error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Anonymous Community Join
  // ─────────────────────────────────────────────────────────────────────────

  Future<F_User?> joinCommunity({
    required String name,
    required String location,
    required String role,
    XFile? profilePhoto,
  }) async {
    try {
      debugPrint('[CommunityAuth] join start');
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        debugPrint('[CommunityAuth] signInAnonymously returned null user');
        return null;
      }
      debugPrint('[CommunityAuth] signed in uid=${user.uid}');

      String? photoUrl;
      if (profilePhoto != null) {
        try {
          final ref = _storage.ref().child(
              'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(File(profilePhoto.path));
          photoUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('[CommunityAuth] photo upload error: $e');
          rethrow;
        }
      }

      final data = {
        'name': name,
        'location': location,
        'role': role,
        'photoUrl': photoUrl,
        'impact_points': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'guidelinesAcceptedAt': null,
        'communityId': 'default',
        'isPrototypeMode': true,
      };
      await _db
          .collection('Users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      debugPrint('[CommunityAuth] join completed for uid=${user.uid}');
      return F_User(uid: user.uid);
    } on FirebaseException catch (e, st) {
      debugPrint('[CommunityAuth] FirebaseException: ${e.code} ${e.message}');
      debugPrint('$st');
      rethrow;
    } catch (e, st) {
      debugPrint('[CommunityAuth] error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Guidelines
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> setGuidelinesAccepted({required String uid}) async {
    final timestamp = FieldValue.serverTimestamp();

    await _db
        .collection('Users')
        .doc(uid)
        .set({'guidelinesAcceptedAt': timestamp}, SetOptions(merge: true));

    final memberDoc = await _db.collection('members').doc(uid).get();
    if (memberDoc.exists) {
      await _db
          .collection('members')
          .doc(uid)
          .set({'guidelinesAcceptedAt': timestamp}, SetOptions(merge: true));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guidelinesKey(uid), true);
      return;
    }

    final orgDoc = await _db.collection('org_rep').doc(uid).get();
    if (orgDoc.exists) {
      await _db
          .collection('org_rep')
          .doc(uid)
          .set({'guidelinesAcceptedAt': timestamp}, SetOptions(merge: true));
      final orgRepData = orgDoc.data() as Map<String, dynamic>?;
      final orgName = orgRepData?['org_name'];
      if (orgName != null) {
        final orgQuery = await _db
            .collection('organizations')
            .where('org_name', isEqualTo: orgName)
            .where('org_rep_uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (orgQuery.docs.isNotEmpty) {
          await _db.collection('organizations').doc(orgQuery.docs.first.id).set(
              {'guidelinesAcceptedAt': timestamp}, SetOptions(merge: true));
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guidelinesKey(uid), true);
      return;
    }

    // Check marketplace_sellers
    final sellerDoc =
        await _db.collection('marketplace_sellers').doc(uid).get();
    if (sellerDoc.exists) {
      await _db
          .collection('marketplace_sellers')
          .doc(uid)
          .set({'guidelinesAcceptedAt': timestamp}, SetOptions(merge: true));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guidelinesKey(uid), true);
  }

  Future<bool> hasAcceptedGuidelines({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_guidelinesKey(uid)) == true) return true;

    for (final collection in [
      'members',
      'org_rep',
      'marketplace_sellers',
      'Users'
    ]) {
      final doc = await _db.collection(collection).doc(uid).get();
      if (doc.exists) {
        final hasAccepted = doc.data()?['guidelinesAcceptedAt'] != null;
        if (hasAccepted) await prefs.setBool(_guidelinesKey(uid), true);
        return hasAccepted;
      }
    }
    return false;
  }

  String _guidelinesKey(String uid) => 'guidelines_accepted_$uid';
}
