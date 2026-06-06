import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../Models/programme.dart';
import '../../../Models/programme_enquiry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROGRAMME LOGIC
//
// All Firestore reads/writes for the Programmes feature live here.
// No UI, no state — screens/providers call these static methods.
//
// Required Firestore composite indexes:
//   programmes          (orgId ASC, createdAt DESC)
//   programme_enquiries (orgId ASC, createdAt DESC)
// ─────────────────────────────────────────────────────────────────────────────

class ProgrammeLogic {
  static final _db = FirebaseFirestore.instance;

  // ── Programmes ─────────────────────────────────────────────────────────────

  /// All programmes for [orgId], ordered newest-first.
  /// Sorted client-side to avoid requiring a composite Firestore index.
  static Stream<List<Programme>> streamProgrammes(String orgId) {
    return _db
        .collection('programmes')
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(Programme.fromFirestore).toList();
      list.sort((a, b) {
        final at = a.createdAt ?? DateTime(0);
        final bt = b.createdAt ?? DateTime(0);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  /// Creates a new programme doc and returns its generated id.
  static Future<String> createProgramme(Programme p) async {
    final ref = await _db.collection('programmes').add(p.toFirestore());
    return ref.id;
  }

  /// Overwrites the programme doc with [id].
  static Future<void> updateProgramme(Programme p) async {
    await _db.collection('programmes').doc(p.id).update(p.toFirestore());
  }

  /// Soft-delete by archiving.
  static Future<void> archiveProgramme(String id) async {
    await _db.collection('programmes').doc(id).update({'status': 'archived'});
  }

  // ── Enquiries ──────────────────────────────────────────────────────────────

  /// All enquiries for [orgId], newest-first.
  /// Sorted client-side to avoid requiring a composite Firestore index.
  static Stream<List<ProgrammeEnquiry>> streamEnquiries(String orgId) {
    return _db
        .collection('programme_enquiries')
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ProgrammeEnquiry.fromFirestore).toList();
      list.sort((a, b) {
        final at = a.createdAt ?? DateTime(0);
        final bt = b.createdAt ?? DateTime(0);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  /// Dual-write: create the enquiry + signal the org's inbox atomically.
  static Future<void> sendEnquiry(ProgrammeEnquiry enquiry) async {
    final batch = _db.batch();

    // Primary enquiry document
    final enquiryRef = _db.collection('programme_enquiries').doc();
    batch.set(enquiryRef, enquiry.toFirestore());

    // Org inbox signal — increments unread counter in the org doc
    final orgRef = _db.collection('organizations').doc(enquiry.orgId);
    batch.update(orgRef, {
      'unreadEnquiries': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Mark an enquiry as read.
  static Future<void> markRead(String enquiryId) async {
    await _db
        .collection('programme_enquiries')
        .doc(enquiryId)
        .update({'status': 'read'});
  }
}
