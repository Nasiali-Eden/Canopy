// lib/Services/Profile/profile_privacy.dart
//
// A person's email and phone are private: they live in `UserPrivate/{uid}`
// (readable only by that person), not in `Users/{uid}`, which every signed-in
// member can read for names and points. Runs after sign-in and quietly moves
// anything left on the old shared profile, so existing accounts are cleaned up
// the next time they open the app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePrivacy {
  ProfilePrivacy._();

  static bool _done = false;

  static Future<void> sync() async {
    if (_done) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('Users').doc(user.uid);
      final d = (await ref.get()).data() ?? const <String, dynamic>{};
      final phone = (d['phone'] ?? d['Contact']) as String?;

      await db.collection('UserPrivate').doc(user.uid).set({
        if ((user.email ?? '').isNotEmpty) 'email': user.email,
        if ((phone ?? '').isNotEmpty) 'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final stale = {
        for (final k in const ['email', 'phone', 'Contact', 'gender'])
          if (d.containsKey(k)) k: FieldValue.delete(),
      };
      if (stale.isNotEmpty) await ref.update(stale);
      _done = true;
    } catch (_) {
      // Try again next launch; never block the app.
    }
  }

  /// The signed-in person's own phone, from the private record.
  static Future<String?> myPhone() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      return ((await FirebaseFirestore.instance.collection('UserPrivate').doc(uid).get()).data()?['phone']) as String?;
    } catch (_) {
      return null;
    }
  }
}
