// lib/Services/Incidents/incidents_service.dart
//
// Read side of the Incidents collection (environmental issue reports — see
// post_incident.dart for the write side). Backs IncidentsFeedScreen.
//
// Status is a 4-stage pipeline: pending -> verifying -> confirmed -> resolved.
// Today every document is written as "pending" and nothing in the app ever
// advances it — there's no verifier-assignment mechanism yet. This service
// and the feed screen render all four stages correctly so the UI is ready
// the moment that assignment exists; until then, expect every real report to
// show as "pending". Same honesty pattern as the Organisations leaderboard
// ("coming soon" rather than a fabricated ranking).

import 'package:cloud_firestore/cloud_firestore.dart';

enum IncidentStatus { pending, verifying, confirmed, resolved }

IncidentStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'verifying':
      return IncidentStatus.verifying;
    case 'confirmed':
      return IncidentStatus.confirmed;
    case 'resolved':
      return IncidentStatus.resolved;
    case 'pending':
    default:
      return IncidentStatus.pending;
  }
}

class IncidentReport {
  final String id;
  final String headline;
  final String description;
  final String type;
  final String location;
  final List<String> images;
  final String userId;
  final IncidentStatus status;
  final DateTime? timestamp;

  const IncidentReport({
    required this.id,
    required this.headline,
    required this.description,
    required this.type,
    required this.location,
    required this.images,
    required this.userId,
    required this.status,
    required this.timestamp,
  });

  /// Which of the 4 pipeline steps are "done" (filled) — used to draw the
  /// progress strip. pending=1, verifying=2, confirmed=3, resolved=4.
  int get stepsDone {
    switch (status) {
      case IncidentStatus.pending:
        return 1;
      case IncidentStatus.verifying:
        return 2;
      case IncidentStatus.confirmed:
        return 3;
      case IncidentStatus.resolved:
        return 4;
    }
  }

  String get statusLabel {
    switch (status) {
      case IncidentStatus.pending:
        return 'PENDING';
      case IncidentStatus.verifying:
        return 'VERIFYING';
      case IncidentStatus.confirmed:
        return 'CONFIRMED';
      case IncidentStatus.resolved:
        return 'RESOLVED';
    }
  }

  factory IncidentReport.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['timestamp'];
    return IncidentReport(
      id: doc.id,
      headline: (data['headline'] as String?)?.trim().isNotEmpty == true
          ? data['headline'] as String
          : 'Untitled report',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'Other',
      location: data['location'] as String? ?? '',
      images: (data['images'] as List?)?.whereType<String>().toList() ?? const [],
      userId: data['userId'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class IncidentsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All reports, newest first. Firestore orders documents with a pending
  /// server timestamp last until it resolves, so a just-submitted report can
  /// briefly appear at the bottom rather than the top of this stream.
  Stream<List<IncidentReport>> watchAll({int limit = 50}) {
    return _db
        .collection('Incidents')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(IncidentReport.fromDoc).toList());
  }

  Stream<List<IncidentReport>> watchMine(String userId, {int limit = 50}) {
    return _db
        .collection('Incidents')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(IncidentReport.fromDoc).toList());
  }
}
