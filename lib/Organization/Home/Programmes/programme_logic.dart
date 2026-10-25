import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../Models/programme.dart';
import '../../../Models/programme_enquiry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROGRAMME LOGIC
//
// All Firestore reads/writes for the Programmes feature live here.
// No UI, no state — screens/providers call these static methods.
//
// Index-free: single-field equality queries, sorted client-side.
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
    // Keep the caller's id — images are already stored under it.
    final ref = p.id.isEmpty ? _db.collection('programmes').doc() : _db.collection('programmes').doc(p.id);
    await ref.set(p.toFirestore());
    return ref.id;
  }

  /// Creates or overwrites the programme doc with [p.id] (editor autosave).
  static Future<void> saveProgramme(Programme p) async {
    await _db.collection('programmes').doc(p.id).set(p.toFirestore());
  }

  static Future<void> deleteProgramme(String id) async {
    await _db.collection('programmes').doc(id).delete();
  }

  /// Six editor sections: Type · Basic info · Schedule · Location ·
  /// Engagement & contact · Images & status. Used for the "4 of 6" bar.
  static List<bool> sectionsDone(Programme p) => [
        true,
        p.title.trim().isNotEmpty && p.summary.trim().isNotEmpty,
        p.schedule.startDate != null || p.schedule.recurrence == RecurrencePattern.ongoing,
        p.schedule.isOnline || p.schedule.location != null,
        (p.details.engagementModel != EngagementModel.paid || (p.details.price ?? 0) > 0) &&
            (p.contact.enquiryEnabled || (p.contact.externalLink?.isNotEmpty ?? false)),
        p.coverImageUrl != null,
      ];

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

  /// Creates the enquiry. The org inbox counts unread enquiries from this
  /// collection directly (members can't write the org doc).
  static Future<void> sendEnquiry(ProgrammeEnquiry enquiry) async {
    await _db.collection('programme_enquiries').add(enquiry.toFirestore());
  }

  /// Mark an enquiry as responded (after the org replies or calls).
  static Future<void> markResponded(String enquiryId) async {
    await _db.collection('programme_enquiries').doc(enquiryId).update({'status': 'responded'});
  }

  /// Mark an enquiry as read.
  static Future<void> markRead(String enquiryId) async {
    await _db
        .collection('programme_enquiries')
        .doc(enquiryId)
        .update({'status': 'read'});
  }
}
