// lib/Services/Events/events_service.dart
//
// "Log Work" via QR check-in — genuinely new, nothing like it existed
// before (the Home quick-action tile was a locked "coming soon" stub; see
// home_feed.dart). Organisations create an Event and display its QR;
// individual Users scan it to check in and get points immediately. This is
// deliberately a different concept from Contributions (self-logged project
// work, verified over time) — Orgs and Users play different roles here:
// only an org creates/ends an event, only a user checks in.
//
// Points are awarded by the `checkInToEvent` Cloud Function
// (functions/src/index.ts), not written from this client. firestore.rules
// makes Users.impact_points and Events/{id}/checkins server-write-only, the
// same trust boundary confirmContribution already enforces for
// Contributions — so the client's job here is just to validate the scanned
// code looks like ours before spending a network call, and call the
// function. Deploying the function (`firebase deploy --only functions`) and
// running `flutter pub get` for the new `cloud_functions` dependency are
// both required before check-in actually works end to end.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CanopyEvent {
  final String id;
  final String orgId;
  final String orgName;
  final String title;
  final int pointsPerCheckin;
  final bool active;
  final String qrToken;
  final DateTime? createdAt;
  final DateTime? scheduledAt;
  final String? meetingPoint;
  final int? spots;
  final String? coverImageUrl;
  final DateTime? endedAt;

  const CanopyEvent({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.title,
    required this.pointsPerCheckin,
    required this.active,
    required this.qrToken,
    required this.createdAt,
    this.scheduledAt,
    this.meetingPoint,
    this.spots,
    this.coverImageUrl,
    this.endedAt,
  });

  /// The payload encoded into the QR code image.
  String get qrPayload => jsonEncode({'eventId': id, 'token': qrToken});

  factory CanopyEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final ts = data['createdAt'];
    return CanopyEvent(
      id: doc.id,
      orgId: data['orgId'] as String? ?? '',
      orgName: data['orgName'] as String? ?? 'Organiser',
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'Community Event',
      pointsPerCheckin: (data['pointsPerCheckin'] as num?)?.toInt() ?? 10,
      active: data['active'] as bool? ?? false,
      qrToken: data['qrToken'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      meetingPoint: data['meetingPoint'] as String?,
      spots: (data['spots'] as num?)?.toInt(),
      coverImageUrl: data['coverImageUrl'] as String?,
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Thrown by [EventsService.checkIn] with a reason the scan screen can show
/// directly — never a raw Firestore/Functions error.
class CheckInException implements Exception {
  final String message;
  const CheckInException(this.message);
  @override
  String toString() => message;
}

class CheckInResult {
  final int pointsAwarded;
  final bool alreadyCheckedIn;
  const CheckInResult({required this.pointsAwarded, required this.alreadyCheckedIn});
}

class EventsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('Events');

  /// Org side: create + display. Direct client write is fine here — event
  /// metadata (title, active flag, qrToken) isn't a protected field, only
  /// the points side is.
  Future<CanopyEvent> createEvent({
    required String orgId,
    required String orgName,
    required String title,
    int pointsPerCheckin = 10,
    DateTime? scheduledAt,
    String? meetingPoint,
    int? spots,
    String? coverImageUrl,
  }) async {
    final ref = _events.doc();
    final token = ref.id.substring(0, 8) +
        DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    await ref.set({
      'orgId': orgId,
      'orgName': orgName,
      'title': title,
      'pointsPerCheckin': pointsPerCheckin,
      'active': true,
      'qrToken': token,
      'createdAt': FieldValue.serverTimestamp(),
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt),
      if (meetingPoint != null && meetingPoint.isNotEmpty) 'meetingPoint': meetingPoint,
      if (spots != null && spots > 0) 'spots': spots,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    });
    final snap = await ref.get();
    return CanopyEvent.fromDoc(snap);
  }

  /// Ends the event and rotates its token, so a previously-issued QR image
  /// (screenshot, printout) stops validating even after the fact.
  Future<void> endEvent(String eventId) {
    return _events.doc(eventId).update({
      'active': false,
      'qrToken': 'ended-${DateTime.now().millisecondsSinceEpoch}',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// One event, live (organiser's QR screen).
  Stream<CanopyEvent?> watchEvent(String eventId) => _events
      .doc(eventId)
      .snapshots()
      .map((d) => d.exists ? CanopyEvent.fromDoc(d) : null);

  /// Check-ins for an event, newest first (organiser only — see rules).
  Stream<List<Map<String, dynamic>>> watchCheckins(String eventId) => _events
      .doc(eventId)
      .collection('checkins')
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()
        ..sort((a, b) => ((b['checkedInAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
            .compareTo((a['checkedInAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)));

  Stream<List<CanopyEvent>> watchOrgEvents(String orgId) {
    return _events
        .where('orgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CanopyEvent.fromDoc).toList());
  }

  /// Parses a scanned QR payload. Returns null for anything that isn't ours,
  /// so the scan screen can say "not a Canopy event code" up front instead
  /// of spending a function call on it.
  static ({String eventId, String token})? parsePayload(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['eventId'] is String && data['token'] is String) {
        return (eventId: data['eventId'] as String, token: data['token'] as String);
      }
    } catch (_) {
      // Not JSON, or not our shape.
    }
    return null;
  }

  /// Calls the `checkInToEvent` Cloud Function, which validates the code and
  /// awards points server-side. Throws [CheckInException] with a
  /// user-facing reason on any rejection.
  Future<CheckInResult> checkIn({required String eventId, required String token}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('checkInToEvent');
      final result = await callable.call<Map<String, dynamic>>({
        'eventId': eventId,
        'token': token,
      });
      final data = result.data;
      return CheckInResult(
        pointsAwarded: (data['pointsAwarded'] as num?)?.toInt() ?? 0,
        alreadyCheckedIn: data['alreadyCheckedIn'] as bool? ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      throw CheckInException(e.message ?? 'Could not check in — please try again.');
    }
  }

  /// For the profile "Log Work" summary banner.
  Stream<List<Map<String, dynamic>>> watchMyCheckins(String userId, {int limit = 20}) {
    return _db
        .collectionGroup('checkins')
        .where('userId', isEqualTo: userId)
        .orderBy('checkedInAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}
