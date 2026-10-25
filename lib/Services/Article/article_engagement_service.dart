// lib/Services/Article/article_engagement_service.dart
//
// Responses and upvotes on articles (Reddit-style, upvote only).
//
// Firestore layout:
//   articles/{a}.upvotes                         : int (kept in step with votes)
//   articles/{a}/votes/{uid}                     : {createdAt}
//   articles/{a}/responses/{r}                   :
//     authorUid, authorName, authorPhotoUrl, body, parentId (null = top level),
//     createdAt, editedAt?, upvotes, deleted, removedBy?
//   articles/{a}/responses/{r}/votes/{uid}       : {createdAt}
//
// A vote and its counter change are one batch; firestore.rules checks the
// counter moves by exactly one and matches the vote doc appearing or going.
// Removing a response blanks it ("[removed]") so its replies keep context.
// All reads are single-collection, sorted on the client — no indexes.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Profile/profile_service.dart';

class ArticleResponse {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final String body;
  final String? parentId;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final int upvotes;
  final bool deleted;
  final String? removedBy; // 'author' | 'organisation'

  const ArticleResponse({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.body,
    required this.parentId,
    required this.createdAt,
    required this.editedAt,
    required this.upvotes,
    required this.deleted,
    required this.removedBy,
  });

  factory ArticleResponse.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
    return ArticleResponse(
      id: d.id,
      authorUid: m['authorUid'] as String? ?? '',
      authorName: (m['authorName'] as String?)?.trim().isNotEmpty == true ? m['authorName'] as String : 'Member',
      authorPhotoUrl: m['authorPhotoUrl'] as String?,
      body: m['body'] as String? ?? '',
      parentId: m['parentId'] as String?,
      createdAt: ts(m['createdAt']),
      editedAt: ts(m['editedAt']),
      upvotes: (m['upvotes'] as num?)?.toInt() ?? 0,
      deleted: m['deleted'] == true,
      removedBy: m['removedBy'] as String?,
    );
  }
}

class ArticleEngagementService {
  ArticleEngagementService._();
  static final instance = ArticleEngagementService._();

  static const maxLength = 2000;

  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _article(String a) => _db.collection('articles').doc(a);
  CollectionReference<Map<String, dynamic>> _responses(String a) => _article(a).collection('responses');

  // ── Reads ────────────────────────────────────────────────────────────────

  Stream<List<ArticleResponse>> watchResponses(String articleId) =>
      _responses(articleId).snapshots().map((s) => s.docs.map(ArticleResponse.fromDoc).toList());

  /// Whether the signed-in user has upvoted the article (responseId null) or a response.
  Stream<bool> watchMyVote(String articleId, {String? responseId}) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    final ref = responseId == null
        ? _article(articleId).collection('votes').doc(uid)
        : _responses(articleId).doc(responseId).collection('votes').doc(uid);
    return ref.snapshots().map((d) => d.exists);
  }

  /// IDs of the responses on this article the user has upvoted. One read per
  /// response would be N listeners; instead read each vote doc once per load.
  Future<Set<String>> myResponseVotes(String articleId, Iterable<String> responseIds) async {
    final uid = _uid;
    if (uid == null) return {};
    final hits = await Future.wait(responseIds.map((r) async {
      final d = await _responses(articleId).doc(r).collection('votes').doc(uid).get();
      return d.exists ? r : null;
    }));
    return hits.whereType<String>().toSet();
  }

  // ── Votes ────────────────────────────────────────────────────────────────

  /// Toggles the user's upvote. [currentlyVoted] is what the UI shows now.
  Future<void> setVote(String articleId, {String? responseId, required bool vote}) async {
    final uid = _uid;
    if (uid == null) throw StateError('signed-out');
    final target = responseId == null ? _article(articleId) : _responses(articleId).doc(responseId);
    final voteRef = target.collection('votes').doc(uid);
    final batch = _db.batch();
    if (vote) {
      batch.set(voteRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(target, {'upvotes': FieldValue.increment(1)});
    } else {
      batch.delete(voteRef);
      batch.update(target, {'upvotes': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  // ── Responses ────────────────────────────────────────────────────────────

  Future<void> respond(String articleId, String body, {String? parentId}) async {
    final uid = _uid;
    if (uid == null) throw StateError('signed-out');
    final profile = await ProfileService().getProfile(userId: uid);
    await _responses(articleId).add({
      'authorUid': uid,
      'authorName': profile?.name ?? '',
      'authorPhotoUrl': profile?.photoUrl,
      'body': body.trim(),
      'parentId': parentId,
      'createdAt': FieldValue.serverTimestamp(),
      'upvotes': 0,
      'deleted': false,
    });
  }

  Future<void> edit(String articleId, String responseId, String body) =>
      _responses(articleId).doc(responseId).update({'body': body.trim(), 'editedAt': FieldValue.serverTimestamp()});

  /// Author removes their own response, or the publishing organisation
  /// removes one from its article. Text is cleared; the slot stays.
  Future<void> remove(String articleId, String responseId, {required bool asOrganisation}) =>
      _responses(articleId).doc(responseId).update({
        'body': '',
        'deleted': true,
        'removedBy': asOrganisation ? 'organisation' : 'author',
      });
}
