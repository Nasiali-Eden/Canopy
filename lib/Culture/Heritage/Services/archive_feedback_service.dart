// lib/Culture/Heritage/Services/archive_feedback_service.dart
//
// Feedback and connections for one organisation's archive, index-free:
// every query is a single equality or a whereIn of ≤10 ids, merged and
// sorted on the client. (The old providers used whereIn over every entry id
// plus orderBy, which fails past 10 entries and needs a composite index.)

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Models/cultural_comment.dart';
import '../Models/cultural_relation.dart';

class ArchiveFeedbackService {
  ArchiveFeedbackService._();
  static final instance = ArchiveFeedbackService._();

  final _db = FirebaseFirestore.instance;

  /// Latest value from several query streams, merged by document id.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _merge(List<Query<Map<String, dynamic>>> queries) {
    late StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>> c;
    final latest = <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final subs = <StreamSubscription>[];
    void emit() {
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final l in latest.values) {
        for (final d in l) {
          byId[d.id] = d;
        }
      }
      c.add(byId.values.toList());
    }

    c = StreamController(
      onListen: () {
        if (queries.isEmpty) {
          c.add(const []);
          return;
        }
        for (var i = 0; i < queries.length; i++) {
          subs.add(queries[i].snapshots().listen((s) {
            latest[i] = s.docs;
            if (latest.length == queries.length) emit();
          }, onError: c.addError));
        }
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return c.stream;
  }

  List<List<String>> _chunks(List<String> ids) => [
        for (var i = 0; i < ids.length; i += 10) ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10),
      ];

  Stream<List<CulturalComment>> comments(String orgId, List<String> entryIds) {
    final col = _db.collection('cultural_comments');
    return _merge([
      col.where('org_id', isEqualTo: orgId),
      for (final c in _chunks(entryIds)) col.where('entry_id', whereIn: c),
    ]).map((docs) => docs.map(CulturalComment.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Stream<List<CulturalRelation>> relations(List<String> entryIds) {
    final col = _db.collection('cultural_relations');
    return _merge([
      for (final c in _chunks(entryIds)) col.where('from_entry_id', whereIn: c),
      for (final c in _chunks(entryIds)) col.where('to_entry_id', whereIn: c),
    ]).map((docs) => docs.map(CulturalRelation.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<String> _me() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'Archive team';
    final d = (await _db.collection('Users').doc(u.uid).get()).data() ?? {};
    return (d['name'] ?? d['displayName'] ?? u.displayName ?? 'Archive team') as String;
  }

  Future<void> assignToMe(String commentId) async {
    await _db.collection('cultural_comments').doc(commentId).update({
      'owner_uid': FirebaseAuth.instance.currentUser?.uid,
      'owner_name': await _me(),
    });
  }

  /// Reply to the member; [resolved] closes it, otherwise it stays under review.
  Future<void> reply(String commentId, String text, {required bool resolved}) async {
    await _db.collection('cultural_comments').doc(commentId).update({
      'reply_text': text.trim(),
      'has_reply': true,
      'replied_at': FieldValue.serverTimestamp(),
      'status': resolved ? 'resolved' : 'under_review',
      'is_resolved': resolved,
      'owner_uid': FirebaseAuth.instance.currentUser?.uid,
      'owner_name': await _me(),
    });
  }

  /// Close a dispute with a note that stays on record.
  Future<void> resolveDispute(String commentId, String note) async {
    await _db.collection('cultural_comments').doc(commentId).update({
      'resolution_note': note.trim(),
      'status': 'resolved',
      'is_resolved': true,
      'resolved_at': FieldValue.serverTimestamp(),
      'owner_uid': FirebaseAuth.instance.currentUser?.uid,
      'owner_name': await _me(),
    });
  }

  Future<void> setRelationStatus(String relationId, {required bool confirm, String? orgId}) async {
    await _db.collection('cultural_relations').doc(relationId).update({
      'status': confirm ? 'confirmed' : 'rejected',
      'org_endorsed': confirm,
      'endorsing_org_id': orgId,
      'confirmed_by_name': confirm ? await _me() : null,
      'confirmed_at': confirm ? FieldValue.serverTimestamp() : null,
    });
  }
}
