import 'package:cloud_firestore/cloud_firestore.dart';

class RankEntry {
  final String userId;
  final String name;
  final String? photoUrl;
  final int points;
  const RankEntry(
      {required this.userId,
      required this.name,
      required this.points,
      this.photoUrl});
  factory RankEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final name = (data['name'] as String?)?.trim();
    final photo = (data['photoUrl'] as String?)?.trim();
    return RankEntry(
        userId: doc.id,
        name: name == null || name.isEmpty ? 'Community member' : name,
        photoUrl: photo == null || photo.isEmpty ? null : photo,
        points: data['rankingVersion'] == 1
            ? (data['impact_points'] as num?)?.toInt() ?? 0
            : 0);
  }
}

class PersonalRank {
  final RankEntry entry;
  final int? rank;
  final int? pointsToNext;
  final int pendingPoints;
  const PersonalRank(this.entry, this.rank, this.pointsToNext, {this.pendingPoints = 0});
}

class LeaderboardService {
  final FirebaseFirestore _db;
  LeaderboardService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;
  Query<Map<String, dynamic>> get _eligible => _db
      .collection('Users')
      .where('rankingVersion', isEqualTo: 1)
      .where('impact_points', isGreaterThan: 0);
  Stream<List<RankEntry>> watchPeopleLeaderboard({int limit = 50}) => _eligible
      .orderBy('impact_points', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(RankEntry.fromDoc).toList());
  Stream<int> watchOwnPoints(String uid) => _db
      .collection('Users')
      .doc(uid)
      .snapshots()
      .map((doc) => RankEntry.fromDoc(doc).points);
  Future<PersonalRank> getPersonalRank(String uid) async {
    final entry =
        RankEntry.fromDoc(await _db.collection('Users').doc(uid).get());
    final pending = await _db.collection('contributions').where('userId', isEqualTo: uid).where('status', isEqualTo: 'pending').get();
    final pendingPoints = pending.docs.where((d) => d.data()['deleted'] != true).fold<int>(0, (total, d) => total + ((d.data()['estimatedImpactPoints'] as num?)?.toInt() ?? 0));
    if (entry.points <= 0) return PersonalRank(entry, null, null, pendingPoints: pendingPoints);
    final higher = _db
        .collection('Users')
        .where('rankingVersion', isEqualTo: 1)
        .where('impact_points', isGreaterThan: entry.points);
    final results = await Future.wait(
        [higher.count().get(), higher.orderBy('impact_points').limit(1).get()]);
    final count = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final next = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs;
    return PersonalRank(
        entry,
        count + 1,
        next.isEmpty
            ? null
            : (next.first.data()['impact_points'] as num).toInt() -
                entry.points +
                1, pendingPoints: pendingPoints);
  }

  // Competition ranking: 1, 1, 3. Ties never depend on document ordering.
  static int rankAt(List<RankEntry> entries, int index) =>
      entries.indexWhere((e) => e.points == entries[index].points) + 1;
  static int? positionOf(List<RankEntry> ranked, String uid) {
    final index = ranked.indexWhere((e) => e.userId == uid);
    return index < 0 ? null : rankAt(ranked, index);
  }
}
