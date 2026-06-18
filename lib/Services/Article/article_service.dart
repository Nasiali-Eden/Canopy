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

  Future<String> createArticle({
    required String heading,
    required String topic,
    required List<Map<String, dynamic>> body,
    XFile? coverPhoto,
    String? coverPhotoUrl,
    String? orgId,
    String? createdBy,
    String status = 'published',
  }) async {
    String? finalCoverUrl = coverPhotoUrl;
    if (coverPhoto != null) {
      final path = orgId != null
          ? 'organizations/$orgId/articles/${DateTime.now().millisecondsSinceEpoch}_cover.jpg'
          : 'articles/covers/${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
      final ref = _storage.ref().child(path);
      await ref.putFile(File(coverPhoto.path));
      finalCoverUrl = await ref.getDownloadURL();
    }

    final now = FieldValue.serverTimestamp();
    final org = orgId != null
        ? await _db.collection('organizations').doc(orgId).get()
        : null;
    final orgName = (org?.data()?['org_name'] ?? org?.data()?['name']) as String?;
    final orgLogoUrl = (org?.data()?['logoUrl'] ?? org?.data()?['profilePhoto']) as String?;

    final doc = await _db.collection('articles').add({
      'heading': heading,
      'title': heading,
      'topic': topic,
      'category': topic,
      'coverPhotoUrl': finalCoverUrl,
      'coverImageUrl': finalCoverUrl,
      'body': body,
      'orgId': orgId,
      'orgName': orgName,
      'orgLogoUrl': orgLogoUrl,
      'authorName': orgName ?? createdBy ?? '',
      'createdBy': createdBy,
      'status': status,
      'createdAt': now,
      'publishedAt': status == 'published' ? now : null,
      'updatedAt': now,
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
      'title': heading,
      'topic': topic,
      'category': topic,
      'coverPhotoUrl': coverUrl,
      'coverImageUrl': coverUrl,
      'body': body,
      'orgId': orgId,
      'createdBy': createdBy,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'publishedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> updateArticle({
    required String articleId,
    String? heading,
    String? topic,
    List<Map<String, dynamic>>? body,
    XFile? coverPhoto,
    String? coverPhotoUrl,
    String? status,
  }) async {
    String? finalCoverUrl = coverPhotoUrl;
    if (coverPhoto != null) {
      final doc = await _db.collection('articles').doc(articleId).get();
      final orgId = doc.data()?['orgId'] as String?;
      final path = orgId != null
          ? 'organizations/$orgId/articles/${DateTime.now().millisecondsSinceEpoch}_cover.jpg'
          : 'articles/covers/${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
      final ref = _storage.ref().child(path);
      await ref.putFile(File(coverPhoto.path));
      finalCoverUrl = await ref.getDownloadURL();
    }

    final now = FieldValue.serverTimestamp();
    await _db.collection('articles').doc(articleId).update({
      if (heading != null) ...{
        'heading': heading,
        'title': heading,
      },
      if (topic != null) ...{
        'topic': topic,
        'category': topic,
      },
      if (body != null) 'body': body,
      if (coverPhotoUrl != null) ...{
        'coverPhotoUrl': coverPhotoUrl,
        'coverImageUrl': coverPhotoUrl,
      },
      if (status != null) ...{
        'status': status,
        'publishedAt': status == 'published' ? now : null,
      },
      'updatedAt': now,
    });
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteArticle(String articleId) {
    return _db.collection('articles').doc(articleId).delete();
  }
}