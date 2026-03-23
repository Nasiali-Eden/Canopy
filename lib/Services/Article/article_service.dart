import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Handles org-authored Articles.
///
/// Firestore layout:
///   articles/{articleId}             ← flat doc
///     heading: String
///     topic: String                  ← 'Community' | 'Health' | 'Environment'
///                                       | 'Tech' | 'Education' | 'Policy'
///     coverPhotoUrl: String?
///     body: [                        ← ordered list of block maps — no subcollection
///       { type: 'h1' | 'h2' | 'h3' | 'paragraph', text: String },
///       ...
///     ]
///     orgId: String?
///     createdBy: String?             ← uid
///     status: 'draft' | 'published'
///     createdAt: Timestamp
///     publishedAt: Timestamp?
class ArticleService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  ArticleService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// All published articles, newest first.
  Stream<List<Map<String, dynamic>>> watchArticles() {
    return _db
        .collection('articles')
        .where('status', isEqualTo: 'published')
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  /// Articles filtered by topic.
  Stream<List<Map<String, dynamic>>> watchArticlesByTopic(String topic) {
    return _db
        .collection('articles')
        .where('status', isEqualTo: 'published')
        .where('topic', isEqualTo: topic)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  /// Articles authored by a specific organisation.
  Stream<List<Map<String, dynamic>>> watchOrgArticles(String orgId) {
    return _db
        .collection('articles')
        .where('orgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getArticle(String id) async {
    final doc = await _db.collection('articles').doc(id).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  // ── Create ────────────────────────────────────────────────────────────────

  /// Publishes an article immediately.
  /// [body] is an ordered list of block maps: `{ type, text }`.
  /// Stored directly on the doc as an array — avoids a body subcollection
  /// while keeping reads to a single document fetch.
  Future<String> createArticle({
    required String heading,
    required String topic,
    required List<Map<String, dynamic>> body,
    required XFile coverPhoto,
    String? orgId,
    String? createdBy,
  }) async {
    // Upload cover photo
    final path = orgId != null
        ? 'organizations/$orgId/articles/${DateTime.now().millisecondsSinceEpoch}_cover.jpg'
        : 'articles/covers/${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
    final ref = _storage.ref().child(path);
    await ref.putFile(File(coverPhoto.path));
    final coverUrl = await ref.getDownloadURL();

    final now = FieldValue.serverTimestamp();

    final doc = await _db.collection('articles').add({
      'heading': heading,
      'topic': topic,
      'coverPhotoUrl': coverUrl,
      // Body stored as an ordered array of block maps — one read, full article
      'body': body,
      'orgId': orgId,
      'createdBy': createdBy,
      'status': 'published',
      'createdAt': now,
      'publishedAt': now,
    });

    return doc.id;
  }

  /// Saves an article as a draft without publishing.
  Future<String> saveDraft({
    required String heading,
    required String topic,
    required List<Map<String, dynamic>> body,
    XFile? coverPhoto,
    String? orgId,
    String? createdBy,
  }) async {
    String? coverUrl;
    if (coverPhoto != null) {
      final path = orgId != null
          ? 'organizations/$orgId/articles/drafts/${DateTime.now().millisecondsSinceEpoch}_cover.jpg'
          : 'articles/drafts/${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
      final ref = _storage.ref().child(path);
      await ref.putFile(File(coverPhoto.path));
      coverUrl = await ref.getDownloadURL();
    }

    final doc = await _db.collection('articles').add({
      'heading': heading,
      'topic': topic,
      'coverPhotoUrl': coverUrl,
      'body': body,
      'orgId': orgId,
      'createdBy': createdBy,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'publishedAt': null,
    });

    return doc.id;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Updates a draft's content and optionally publishes it.
  Future<void> updateArticle({
    required String articleId,
    String? heading,
    String? topic,
    List<Map<String, dynamic>>? body,
    bool publish = false,
  }) {
    return _db.collection('articles').doc(articleId).update({
      if (heading != null) 'heading': heading,
      if (topic != null) 'topic': topic,
      if (body != null) 'body': body,
      if (publish) 'status': 'published',
      if (publish) 'publishedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteArticle(String articleId) {
    return _db.collection('articles').doc(articleId).delete();
  }
}