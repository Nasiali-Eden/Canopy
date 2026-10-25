import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Models/announcement.dart';

/// Reads organisation broadcasts from the top-level `announcements`
/// collection — the one the org BroadcastComposer writes and Home shows.
/// (This used to read communities/default/announcements, which nothing
/// writes, so the list was always empty and Home's taps opened "not found".)
class AnnouncementService {
  final FirebaseFirestore _db;

  AnnouncementService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Live, unexpired, urgent first then newest. Single-field order — index-free.
  Stream<List<Announcement>> watchAnnouncements({int limit = 60}) {
    return _db.collection('announcements').orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) {
      final list = s.docs.map(Announcement.fromDoc).where((a) => !a.isExpired).toList();
      list.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });
      return list;
    });
  }

  Future<Announcement?> getAnnouncement(String id) async {
    final doc = await _db.collection('announcements').doc(id).get();
    return doc.exists ? Announcement.fromDoc(doc) : null;
  }
}
