import 'dart:io';
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
      print('[CommunityAuth] registerAsOrganization start');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        print(
            '[CommunityAuth] createUserWithEmailAndPassword returned null user');
        return null;
      }
      print('[CommunityAuth] organization registered uid=${user.uid}');

      // Generate UUID for organization ID
      const uuid = Uuid();
      final orgId = uuid.v4();

      String? profilePhotoUrl;
      if (profilePhoto != null) {
        try {
          final ref = _storage.ref().child(
              'organizations/$orgId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
          print(
              '[CommunityAuth] uploading org profile photo to ${ref.fullPath}');
          await ref.putFile(File(profilePhoto.path));
          profilePhotoUrl = await ref.getDownloadURL();
          print('[CommunityAuth] org profile photo uploaded');
        } catch (e, st) {
          print('[CommunityAuth] photo upload error: $e');
          print(st);
          // Continue without photo
        }
      }

      // Save to org_rep collection (indexed by uid)
      final orgRepData = {
        'uid': user.uid,
        'email': email,
        'name': orgRepName,
        'org_name': orgName,
        'createdAt': FieldValue.serverTimestamp(),
      };

      print(
          '[CommunityAuth] writing org rep doc to org_rep/${user.uid} => $orgRepData');
      await _db.collection('org_rep').doc(user.uid).set(orgRepData);

      // Save to organizations collection (full organization data)
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

      print(
          '[CommunityAuth] writing organization doc to organizations/$orgId => $organizationsData');
      await _db.collection('organizations').doc(orgId).set(organizationsData);

      // Also update the Users collection for backwards compatibility
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

      print(
          '[CommunityAuth] organization registration completed for uid=${user.uid}');
      return F_User(uid: user.uid);
    } on FirebaseException catch (e, st) {
      print('[CommunityAuth] FirebaseException: ${e.code} ${e.message}');
      print(st);
      rethrow;
    } catch (e, st) {
      print('[CommunityAuth] error: $e');
      print(st);
      rethrow;
    }
  }

  Future<F_User?> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      print('[CommunityAuth] registerWithEmail start');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        print(
            '[CommunityAuth] createUserWithEmailAndPassword returned null user');
        return null;
      }
      print('[CommunityAuth] registered uid=${user.uid}');

      // Save to members collection ordered by UID
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

      print('[CommunityAuth] writing user doc to members/${user.uid} => $data');
      await _db.collection('members').doc(user.uid).set(data);

      // Also update the Users collection for backwards compatibility
      await _db.collection('Users').doc(user.uid).set(
        {
          ...data,
          'isPrototypeMode': true,
        },
        SetOptions(merge: true),
      );

      print('[CommunityAuth] registration completed for uid=${user.uid}');
      return F_User(uid: user.uid);
    } on FirebaseException catch (e, st) {
      print('[CommunityAuth] FirebaseException: ${e.code} ${e.message}');
      print(st);
      rethrow;
    } catch (e, st) {
      print('[CommunityAuth] error: $e');
      print(st);
      rethrow;
    }
  }

  Future<F_User?> joinCommunity({
    required String name,
    required String location,
    required String role,
    XFile? profilePhoto,
  }) async {
    try {
      print('[CommunityAuth] join start');
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        print('[CommunityAuth] signInAnonymously returned null user');
        return null;
      }
      print('[CommunityAuth] signed in uid=${user.uid}');

      String? photoUrl;
      if (profilePhoto != null) {
        try {
          final ref = _storage.ref().child(
              'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
          print('[CommunityAuth] uploading profile photo to ${ref.fullPath}');
          await ref.putFile(File(profilePhoto.path));
          photoUrl = await ref.getDownloadURL();
          print('[CommunityAuth] profile photo uploaded');
        } catch (e, st) {
          print('[CommunityAuth] photo upload error: $e');
          print(st);
          // Continue without photo, but surface error to caller
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
      print('[CommunityAuth] writing user doc to Users/${user.uid} => $data');
      await _db.collection('Users').doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );

      print('[CommunityAuth] join completed for uid=${user.uid}');
      return F_User(uid: user.uid);
    } on FirebaseException catch (e, st) {
      print('[CommunityAuth] FirebaseException: ${e.code} ${e.message}');
      print(st);
      rethrow;
    } catch (e, st) {
      print('[CommunityAuth] error: $e');
      print(st);
      rethrow;
    }
  }

  Future<void> setGuidelinesAccepted({required String uid}) async {
    final timestamp = FieldValue.serverTimestamp();
    
    // Update Users collection (backwards compatibility)
    await _db.collection('Users').doc(uid).set({
      'guidelinesAcceptedAt': timestamp,
    }, SetOptions(merge: true));

    // Check which collection the user is in and update accordingly
    final memberDoc = await _db.collection('members').doc(uid).get();
    if (memberDoc.exists) {
      // Update members collection
      await _db.collection('members').doc(uid).set({
        'guidelinesAcceptedAt': timestamp,
      }, SetOptions(merge: true));
    } else {
      // Check org_rep collection  
      final orgDoc = await _db.collection('org_rep').doc(uid).get();
      if (orgDoc.exists) {
        // Update org_rep collection
        await _db.collection('org_rep').doc(uid).set({
          'guidelinesAcceptedAt': timestamp,
        }, SetOptions(merge: true));
        
        // Also update the organizations collection
        final orgRepData = orgDoc.data() as Map<String, dynamic>?;
        final orgName = orgRepData?['org_name'];
        if (orgName != null) {
          final orgQuery = await _db.collection('organizations')
              .where('org_name', isEqualTo: orgName)
              .where('org_rep_uid', isEqualTo: uid)
              .limit(1)
              .get();
          
          if (orgQuery.docs.isNotEmpty) {
            await _db.collection('organizations').doc(orgQuery.docs.first.id).set({
              'guidelinesAcceptedAt': timestamp,
            }, SetOptions(merge: true));
          }
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guidelinesKey(uid), true);
  }

  Future<bool> hasAcceptedGuidelines({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getBool(_guidelinesKey(uid));
    if (local == true) return true;

    // Check members collection first
    final memberDoc = await _db.collection('members').doc(uid).get();
    if (memberDoc.exists) {
      final acceptedAt = memberDoc.data()?['guidelinesAcceptedAt'];
      final hasAccepted = acceptedAt != null;
      if (hasAccepted) {
        await prefs.setBool(_guidelinesKey(uid), true);
      }
      return hasAccepted;
    }

    // Check org_rep collection
    final orgDoc = await _db.collection('org_rep').doc(uid).get();
    if (orgDoc.exists) {
      final acceptedAt = orgDoc.data()?['guidelinesAcceptedAt'];
      final hasAccepted = acceptedAt != null;
      if (hasAccepted) {
        await prefs.setBool(_guidelinesKey(uid), true);
      }
      return hasAccepted;
    }

    // Fallback to Users collection for backwards compatibility
    final doc = await _db.collection('Users').doc(uid).get();
    if (!doc.exists) return false;
    final acceptedAt = doc.data()?['guidelinesAcceptedAt'];
    final hasAccepted = acceptedAt != null;
    if (hasAccepted) {
      await prefs.setBool(_guidelinesKey(uid), true);
    }
    return hasAccepted;
  }

  String _guidelinesKey(String uid) => 'guidelines_accepted_$uid';
}
