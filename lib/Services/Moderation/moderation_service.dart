// lib/Services/Moderation/moderation_service.dart
//
// Reporting and blocking. A report is a record the Canopy team reviews in the
// Firebase console (`reports`); nobody but the team can read them. Blocking is
// private to the person who blocked: their feed stops showing that person's
// posts (`Users/{me}/blockedUsers/{theirUid}`).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  ModerationService._();
  static final ModerationService instance = ModerationService._();

  final _db = FirebaseFirestore.instance;
  String? get _me => FirebaseAuth.instance.currentUser?.uid;

  static const reasons = <(String, String)>[
    ('spam', 'Spam or scam'),
    ('inappropriate', 'Inappropriate or offensive'),
    ('harassment', 'Harassment or hate'),
    ('false', 'False or misleading'),
    ('unsafe', 'Unsafe or illegal'),
    ('privacy', 'Shares private information'),
    ('other', 'Something else'),
  ];

  /// [targetType]: contribution · listing · service · heritage_entry · comment · user · organisation
  Future<void> report({
    required String targetType,
    required String targetId,
    String? ownerId,
    required String reason,
    String details = '',
  }) async {
    final me = _me;
    if (me == null) throw StateError('signed out');
    await _db.collection('reports').add({
      'targetType': targetType,
      'targetId': targetId,
      if (ownerId != null && ownerId.isNotEmpty) 'ownerId': ownerId,
      'reason': reason,
      if (details.trim().isNotEmpty) 'details': details.trim(),
      'reporterId': me,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>>? get _blocks {
    final me = _me;
    return me == null ? null : _db.collection('Users').doc(me).collection('blockedUsers');
  }

  Future<void> block(String uid) async {
    if (uid.isEmpty || uid == _me) return;
    await _blocks?.doc(uid).set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unblock(String uid) async => _blocks?.doc(uid).delete();

  /// The ids this person has blocked, live.
  Stream<Set<String>> watchBlocked() {
    final c = _blocks;
    if (c == null) return Stream.value(const <String>{});
    return c.snapshots().map((s) => {for (final d in s.docs) d.id}).handleError((_) {});
  }
}
