import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class CommunityOverview {
  final int activeInitiatives;
  final int membersParticipating;
  final int totalImpactPoints;

  const CommunityOverview({
    required this.activeInitiatives,
    required this.membersParticipating,
    required this.totalImpactPoints,
  });
}

/// Structured capacity result — always use getCapacityStatus(), never inline
/// capacity comparisons in widgets.
class ActivityCapacityStatus {
  final bool isUnlimited;
  final bool isFull;
  final int? spotsLeft;
  final double fillRatio;
  final String displayLabel;

  const ActivityCapacityStatus({
    required this.isUnlimited,
    required this.isFull,
    required this.spotsLeft,
    required this.fillRatio,
    required this.displayLabel,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class CommunityService {
  final FirebaseFirestore _db;

  CommunityService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Existing methods ───────────────────────────────────────────────────────

  Stream<CommunityOverview> watchOverview({String communityId = 'default'}) {
    // Firestore: communities/{communityId}
    return _db
        .collection('communities')
        .doc(communityId)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? {};
      return CommunityOverview(
        activeInitiatives: (data['activeInitiatives'] ?? 0) as int,
        membersParticipating: (data['membersParticipating'] ?? 0) as int,
        totalImpactPoints: (data['totalImpactPoints'] ?? 0) as int,
      );
    });
  }

  Stream<List<Map<String, dynamic>>> watchRecentActivityFeed({
    String communityId = 'default',
    int limit = 5,
  }) {
    // Firestore: communities/{communityId}/activity_feed
    return _db
        .collection('communities')
        .doc(communityId)
        .collection('activity_feed')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) => {'id': d.id, ...(d.data())}).toList();
    });
  }

  Future<String?> getUserRole({required String userId}) async {
    // Firestore: Users/{userId}
    final doc = await _db.collection('Users').doc(userId).get();
    if (!doc.exists) return null;
    return (doc.data()?['role'] as String?) ?? 'Member';
  }

  Stream<bool> watchPrototypeMode({required String userId}) {
    // Firestore: Users/{userId}
    return _db.collection('Users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return (data?['isPrototypeMode'] as bool?) ?? false;
    });
  }

  // ── User profile ───────────────────────────────────────────────────────────

  /// Fetch display name, email, and avatar for a user.
  Future<Map<String, dynamic>?> getUserProfile({required String userId}) async {
    // Firestore: Users/{userId}
    final doc = await _db.collection('Users').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // ── Capacity logic — single source of truth ────────────────────────────────

  /// Returns structured capacity info. Call this everywhere capacity is
  /// displayed — never inline registeredCount/maxParticipants comparisons.
  ActivityCapacityStatus getCapacityStatus({
    required int registeredCount,
    required int maxParticipants,
  }) {
    if (maxParticipants == 0) {
      return ActivityCapacityStatus(
        isUnlimited: true,
        isFull: false,
        spotsLeft: null,
        fillRatio: 0.0,
        displayLabel: '$registeredCount registered · Open',
      );
    }
    final spotsLeft = maxParticipants - registeredCount;
    final fillRatio =
        (registeredCount / maxParticipants).clamp(0.0, 1.0);
    final isFull = spotsLeft <= 0;
    return ActivityCapacityStatus(
      isUnlimited: false,
      isFull: isFull,
      spotsLeft: spotsLeft,
      fillRatio: fillRatio,
      displayLabel: isFull
          ? 'Full · $maxParticipants registered'
          : '$spotsLeft spot${spotsLeft == 1 ? '' : 's'} left of $maxParticipants',
    );
  }

  // ── Activity queries ───────────────────────────────────────────────────────

  /// Stream of upcoming open/full activities, newest-first by scheduled date.
  ///
  /// Requires a Firestore composite index: scheduledAt ASC + status ASC.
  /// Create at: Firebase Console → Firestore → Indexes → Composite.
  Stream<QuerySnapshot> getActivitiesStream({
    String? type,
    bool includeFull = false,
  }) {
    // Firestore: activities
    final statuses = includeFull ? ['open', 'full'] : ['open'];

    Query query = _db
        .collection('activities')
        .where('status', whereIn: statuses)
        .where('scheduledAt', isGreaterThan: Timestamp.now())
        .orderBy('scheduledAt');

    if (type != null) {
      // Adding type filter requires a composite index:
      // status (whereIn) + type (==) + scheduledAt (asc)
      query = _db
          .collection('activities')
          .where('status', whereIn: statuses)
          .where('type', isEqualTo: type)
          .where('scheduledAt', isGreaterThan: Timestamp.now())
          .orderBy('scheduledAt');
    }

    return query.limit(20).snapshots();
  }

  /// Real-time registration status for a specific user + activity combination.
  Stream<QuerySnapshot> getUserRegistrationStream({
    required String activityId,
    required String userId,
  }) {
    // Firestore: activity_registrations
    return _db
        .collection('activity_registrations')
        .where('activityId', isEqualTo: activityId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots();
  }

  /// All active registrations for an activity (organiser use only).
  ///
  /// PRIVACY NOTE: userEmail in each registration doc is restricted to the
  /// activity organiser via Firestore Security Rules (not enforced here).
  Future<QuerySnapshot> getActivityRegistrations(String activityId) {
    // Firestore: activity_registrations
    return _db
        .collection('activity_registrations')
        .where('activityId', isEqualTo: activityId)
        .where('status', isEqualTo: 'registered')
        .get();
  }

  /// Returns true if the activity is open and has available capacity.
  Future<bool> canRegister({required String activityId}) async {
    // Firestore: activities/{activityId}
    final doc =
        await _db.collection('activities').doc(activityId).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final status = data['status'] as String? ?? 'open';
    if (status != 'open') return false;
    final maxP = data['maxParticipants'] as int? ?? 0;
    if (maxP == 0) return true;
    final regCount = data['registeredCount'] as int? ?? 0;
    return regCount < maxP;
  }
}
