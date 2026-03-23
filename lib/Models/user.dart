import 'package:cloud_firestore/cloud_firestore.dart';

class F_User {
  final String uid;
  F_User({required this.uid});

  // Reads orgId from Users/{uid} on Firestore. Returns null if absent or on error.
  Future<String?> get orgId async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final value = data['orgId'];
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
    }
  }
}
