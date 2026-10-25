import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileData {
  final String name;
  final String location;
  final String? photoUrl;
  final String? phone;

  const ProfileData({
    required this.name,
    required this.location,
    required this.photoUrl,
    this.phone,
  });
}

class ProfileService {
  final FirebaseFirestore _db;

  ProfileService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Stream<ProfileData> watchProfile({required String userId}) {
    return _db.collection('Users').doc(userId).snapshots().map((doc) {
      final data = doc.data() ?? {};
      return ProfileData(
        name: (data['name'] ?? '') as String,
        location: (data['location'] ?? '') as String,
        photoUrl: data['photoUrl'] as String?,
        phone: data['phone'] as String?,
      );
    });
  }

  Future<ProfileData?> getProfile({required String userId}) async {
    final doc = await _db.collection('Users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    return ProfileData(
      name: (data['name'] ?? '') as String,
      location: (data['location'] ?? '') as String,
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
    );
  }

  /// Phase 2.4 (Minimal Release Roadmap) — settings should let every role
  /// edit name, phone, location, and password at minimum. Password is a
  /// Firebase Auth operation (see `EditProfileScreen._sendPasswordReset`),
  /// not a Firestore field, so it isn't part of this write.
  Future<void> updateProfile({
    required String userId,
    required String name,
    required String location,
    String? phone,
    String? photoUrl,
  }) {
    return _db.collection('Users').doc(userId).set({
      'name': name,
      'location': location,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
