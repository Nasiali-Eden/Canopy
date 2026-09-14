import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Models/contribution.dart';

class ImpactSummary {
  final int impactPoints;
  final int contributionsCount;
  final double hours;

  const ImpactSummary({
    required this.impactPoints,
    required this.contributionsCount,
    required this.hours,
  });
}

class ImpactService {
  final FirebaseFirestore _db;

  ImpactService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Stream<int> watchCommunityTotalImpactPoints(
      {String communityId = 'default'}) {
    return _db
        .collection('communities')
        .doc(communityId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      return (data?['totalImpactPoints'] as int?) ?? 0;
    });
  }

  Stream<int> watchUserImpactPoints({required String userId}) {
    return _db.collection('Users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return data?['rankingVersion'] == 1 ? (data?['impact_points'] as num?)?.toInt() ?? 0 : 0;
    });
  }

  Stream<List<Contribution>> watchUserContributions({
    required String userId,
    int limit = 150,
  }) {
    return _db
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(Contribution.fromDoc).toList();
    });
  }

  Stream<List<Contribution>> watchCommunityContributions({
    String communityId = 'default',
    int limit = 250,
  }) {
    return _db
        .collection('contributions')
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(Contribution.fromDoc).toList();
    });
  }

  ImpactSummary summarize(
      {required int impactPoints, required List<Contribution> contributions}) {
    double hours = 0;
    for (final c in contributions) {
      if (c.type == 'Time') {
        hours += c.hours ?? 0;
      }
    }

    return ImpactSummary(
      impactPoints: impactPoints,
      contributionsCount: contributions.length,
      hours: hours,
    );
  }

  Future<String> exportUserContributionsCsv({required String userId}) async {
    final snapshot = await _db
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();

    final lines = <String>[];
    lines.add(
        'id,createdAt,type,hours,effort,materials,estimatedImpactPoints,notes');

    for (final doc in snapshot.docs) {
      final c = Contribution.fromDoc(doc);
      final createdAt = c.createdAt?.toIso8601String() ?? '';
      final hours = c.hours?.toStringAsFixed(2) ?? '';
      final effort = _escape(c.effort ?? '');
      final materials = _escape(c.materials.join(';'));
      final notes = _escape(c.notes ?? '');

      lines.add(
        '${c.id},$createdAt,${_escape(c.type)},$hours,$effort,$materials,${c.estimatedImpactPoints},$notes',
      );
    }

    return lines.join('\n');
  }

  String _escape(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('\n') || value.contains('"');
    var v = value.replaceAll('"', '""');
    if (needsQuotes) v = '"$v"';
    return v;
  }
}
