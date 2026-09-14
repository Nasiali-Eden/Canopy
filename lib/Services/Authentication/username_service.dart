// lib/Services/Authentication/username_service.dart
//
// Phase 3.2 (Minimal Release Roadmap) — "Add a username field to
// registration (across all roles) with real-time availability checking
// before submission."
//
// Uniqueness is enforced by reserving `usernames/{normalized}` as its own
// document — Firestore has no unique-index constraint, so "create a doc
// only if it doesn't already exist" is the standard way to get atomic
// uniqueness: two people racing for the same name can't both succeed,
// because only one `create` can win against a security rule that requires
// the document not already exist.

import 'package:cloud_firestore/cloud_firestore.dart';

class UsernameService {
  final FirebaseFirestore _db;

  UsernameService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Lowercase, trimmed — the canonical form usernames are compared and
  /// stored in, so "Jane" and "jane" collide as they should.
  static String normalize(String raw) => raw.trim().toLowerCase();

  /// `letters, digits, underscore, 3-20 chars` — permissive enough for names
  /// in any script isn't attempted here (Firestore doc IDs need to stay
  /// URL-safe query keys); flagged as a follow-up if the pilot needs wider
  /// script support.
  static final RegExp validPattern = RegExp(r'^[a-z0-9_]{3,20}$');

  static String? validationError(String raw) {
    final n = normalize(raw);
    if (n.isEmpty) return 'Username is required';
    if (!validPattern.hasMatch(n)) {
      return '3-20 characters: letters, numbers, underscore only';
    }
    return null;
  }

  Future<bool> isAvailable(String username) async {
    final n = normalize(username);
    if (validationError(n) != null) return false;
    final doc = await _db.collection('usernames').doc(n).get();
    return !doc.exists;
  }

  /// Call right after the auth account is created (needs `request.auth` for
  /// the security rule below to accept the write) — never before, since the
  /// live-typing availability check in [isAvailable] runs pre-auth and must
  /// stay a read-only check.
  Future<void> reserve({required String username, required String uid}) {
    final n = normalize(username);
    return _db.collection('usernames').doc(n).set({
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
