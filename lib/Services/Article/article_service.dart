import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Handles org-authored Articles ("Community Updates").
///
/// Single flat collection — no subcollections, no composite indexes required.
/// Every doc carries dual field aliases so all reader surfaces work:
///   • heading / title           ← same value
///   • topic / category          ← same value (e.g. 'news')
///   • coverPhotoUrl / coverImageUrl
///   • status ('draft'|'published') / isPublished (bool)
///
/// Firestore layout — articles/{articleId}:
///   heading, title              : String
///   topic, category             : String
///   coverPhotoUrl, coverImageUrl: String?
///   body                        : String   ← rich text. Lines beginning
///                                            '# ' / '## ' / '### ' render as
///                                            h1 / h2 / h3; everything else is
///                                            a paragraph. Blocks separated by
///                                            a blank line.
///   orgId                       : String?
///   orgName, authorName         : String?
///   orgLogoUrl, authorAvatarUrl : String?
///   createdBy                   : String?  ← uid
///   status                      : 'draft' | 'published'
///   isPublished                 : bool
///   readTimeMinutes             : int
///   createdAt                   : Timestamp
///   publishedAt                 : Timestamp?   (null while draft)
///   updatedAt                   : Timestamp
class ArticleService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  ArticleService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Articles authored by a specific organisation, newest first.
  /// Index-free: single-field order on `createdAt`.
  Stream<List<Map<String, dynamic>>> watchOrgArticles(String orgId) {
    return _db
        .collection('articles')
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final ta = a['createdAt'] as Timestamp?;
        final tb = b['createdAt'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getArticle(String id) async {
    final doc = await _db.collection('articles').doc(id).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  // ── Create / publish ────────────────────────────────────────────────────────

  /// Creates a new article. [publish] decides whether it goes live immediately
  /// or is parked as a draft.
  Future<String> createArticle({
    required String heading,
    required String category,
    required String body,
    XFile? coverPhoto,
    String? coverPhotoUrl,
    String? orgId,
    String? createdBy,
    bool publish = true,
  }) async {
    final docRef = _db.collection('articles').doc();

    String? finalCoverUrl = coverPhotoUrl;
    if (coverPhoto != null) {
      finalCoverUrl = await _uploadCover(docRef.id, orgId, coverPhoto);
    }

    final org = await _orgIdentity(orgId);
    final now = FieldValue.serverTimestamp();

    await docRef.set({
      'heading': heading,
      'title': heading,
      'topic': category,
      'category': category,
      'coverPhotoUrl': finalCoverUrl,
      'coverImageUrl': finalCoverUrl,
      'body': body,
      'orgId': orgId,
      'orgName': org.name,
      'authorName': org.name ?? createdBy ?? 'Organisation',
      'orgLogoUrl': org.logo,
      'authorAvatarUrl': org.logo,
      'createdBy': createdBy,
      'status': publish ? 'published' : 'draft',
      'isPublished': publish,
      'readTimeMinutes': _readMinutes(body),
      'createdAt': now,
      'publishedAt': publish ? now : null,
      'updatedAt': now,
    });

    return docRef.id;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Updates an existing article. Pass [publish] to flip live/draft state.
  Future<void> updateArticle({
    required String articleId,
    required String heading,
    required String category,
    required String body,
    XFile? coverPhoto,
    String? coverPhotoUrl,
    String? orgId,
    bool? publish,
  }) async {
    String? finalCoverUrl = coverPhotoUrl;
    if (coverPhoto != null) {
      finalCoverUrl = await _uploadCover(articleId, orgId, coverPhoto);
    }

    final now = FieldValue.serverTimestamp();
    final doc = _db.collection('articles').doc(articleId);

    final data = <String, dynamic>{
      'heading': heading,
      'title': heading,
      'topic': category,
      'category': category,
      'body': body,
      'readTimeMinutes': _readMinutes(body),
      'updatedAt': now,
      if (finalCoverUrl != null) ...{
        'coverPhotoUrl': finalCoverUrl,
        'coverImageUrl': finalCoverUrl,
      },
    };

    if (publish != null) {
      data['status'] = publish ? 'published' : 'draft';
      data['isPublished'] = publish;
      // Stamp publishedAt the first time it goes live; clear when unpublished.
      final snap = await doc.get();
      final already = snap.data()?['publishedAt'];
      if (publish) {
        data['publishedAt'] = already ?? now;
      } else {
        data['publishedAt'] = null;
      }
    }

    await doc.update(data);
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> deleteArticle(String articleId) {
    return _db.collection('articles').doc(articleId).delete();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _uploadCover(
      String articleId, String? orgId, XFile coverPhoto) async {
    final path = orgId != null
        ? 'organizations/$orgId/articles/${articleId}_cover.jpg'
        : 'articles/covers/${articleId}_cover.jpg';
    final ref = _storage.ref().child(path);
    await ref.putFile(File(coverPhoto.path));
    return ref.getDownloadURL();
  }

  Future<({String? name, String? logo})> _orgIdentity(String? orgId) async {
    if (orgId == null) return (name: null, logo: null);
    try {
      final org = await _db.collection('organizations').doc(orgId).get();
      final d = org.data();
      final name = (d?['org_name'] ?? d?['name']) as String?;
      final logo = (d?['logoUrl'] ?? d?['profilePhoto']) as String?;
      return (name: name, logo: logo);
    } catch (_) {
      return (name: null, logo: null);
    }
  }

  /// ~200 words per minute, floor of 1.
  int _readMinutes(String body) {
    final words =
        body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final mins = (words / 200).ceil();
    return mins < 1 ? 1 : mins;
  }
}
