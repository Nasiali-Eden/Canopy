import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ContributionService {
  final FirebaseFirestore? _db;
  final FirebaseStorage? _storage;

  ContributionService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db,
        _storage = storage;

  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  /// Estimate impact points based on contribution details
  int estimateImpactPoints({
    required String type,
    String? workType,
    double? hours,
    String? effort,
    List<String> materials = const [],
  }) {
    // Base points calculation from original system
    int basePoints = 0;

    if (type == 'Time') {
      final h = hours ?? 0;
      basePoints = (h * 10).round().clamp(0, 500);
    } else if (type == 'Effort') {
      final len = (effort ?? '').trim().length;
      if (len == 0) {
        basePoints = 0;
      } else {
        basePoints = (20 + (len / 50).floor() * 5).clamp(0, 200);
      }
    } else if (type == 'Materials') {
      basePoints = (materials.length * 8).clamp(0, 300);
    }

    // Add bonus points based on work type (encourage specific activities)
    int workTypeBonus = 0;
    if (workType != null) {
      switch (workType) {
        case 'Tree Planting':
          workTypeBonus = 50; // Highest priority
          break;
        case 'School Upgrading':
          workTypeBonus = 40;
          break;
        case 'Water & Sanitation':
          workTypeBonus = 35;
          break;
        case 'Waste Management':
          workTypeBonus = 30;
          break;
        case 'Infrastructure':
          workTypeBonus = 30;
          break;
        case 'Cleanup':
          workTypeBonus = 25;
          break;
        default:
          workTypeBonus = 20;
      }
    }

    return basePoints + workTypeBonus;
  }

  /// Create a new contribution
  Future<int> createContribution({
    required String userId,
    required String title,
    required String workType,
    String? activityId,
    required String type,
    double? hours,
    String? effort,
    List<String> materials = const [],
    String? notes,
    List<XFile> beforePhotos = const [],
    List<XFile> afterPhotos = const [],
    String? location,
    double? latitude,
    double? longitude,
    String communityId = 'default',
  }) async {
    // Validate title
    if (title.trim().isEmpty || title.length > 50) {
      throw Exception('Title must be between 1 and 50 characters');
    }

    // Calculate points
    final points = estimateImpactPoints(
      type: type,
      workType: workType,
      hours: hours,
      effort: effort,
      materials: materials,
    );

    final contributionRef = db.collection('contributions').doc();
    final contributionId = contributionRef.id;

    // Upload before photos
    final beforePhotoUrls = <String>[];
    for (var i = 0; i < beforePhotos.length; i++) {
      final file = beforePhotos[i];
      final ref = storage.ref().child(
            'contributions/$userId/$contributionId/before/photo_$i.jpg',
          );
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      beforePhotoUrls.add(url);
    }

    // Upload after photos
    final afterPhotoUrls = <String>[];
    for (var i = 0; i < afterPhotos.length; i++) {
      final file = afterPhotos[i];
      final ref = storage.ref().child(
            'contributions/$userId/$contributionId/after/photo_$i.jpg',
          );
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      afterPhotoUrls.add(url);
    }

    final batch = db.batch();

    // Store contribution data with new fields
    batch.set(contributionRef, {
      // New fields
      'title': title.trim(),
      'workType': workType,
      
      // Original fields
      'userId': userId,
      'activityId': activityId,
      'type': type,
      'hours': hours,
      'effort': effort,
      'materials': materials,
      'notes': notes,
      
      // Photo URLs
      'beforeImages': beforePhotoUrls, // Changed from beforePhotoUrls for consistency
      'afterImages': afterPhotoUrls,   // Changed from afterPhotoUrls for consistency
      
      // Location data
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      
      // Metadata
      'points': points, // Changed from estimatedImpactPoints for simplicity
      'communityId': communityId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'pending', // Can be: pending, verified, rejected
      
      // Monthly tracking for Tree Planting
      'monthlyUpdates': workType == 'Tree Planting' ? [] : null,
    });

    // Update user stats
    final userRef = db.collection('users').doc(userId);
    batch.set(
      userRef,
      {
        'totalPoints': FieldValue.increment(points),
        'contributions': FieldValue.increment(1),
        'lastContribution': FieldValue.serverTimestamp(),
        'contributionsByType': {
          workType: FieldValue.increment(1),
        },
      },
      SetOptions(merge: true),
    );

    // Update community impact points
    batch.set(
      db.collection('communities').doc(communityId),
      {
        'totalImpactPoints': FieldValue.increment(points),
        'totalContributions': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'contributionsByType': {
          workType: FieldValue.increment(1),
        },
      },
      SetOptions(merge: true),
    );

    // Add to activity feed with more details
    batch.set(
      db
          .collection('communities')
          .doc(communityId)
          .collection('activity_feed')
          .doc(),
      {
        'text': title,
        'subtitle': '$workType • $points points',
        'userId': userId,
        'contributionId': contributionId,
        'type': 'contribution',
        'workType': workType,
        'points': points,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    return points;
  }

  /// Update monthly progress for Tree Planting contributions
  Future<void> updateTreePlantingProgress({
    required String contributionId,
    required List<XFile> monthlyPhotos,
    String? notes,
  }) async {
    final doc = await db.collection('contributions').doc(contributionId).get();
    
    if (!doc.exists) {
      throw Exception('Contribution not found');
    }

    final data = doc.data()!;
    final userId = data['userId'] as String;
    final workType = data['workType'] as String?;

    if (workType != 'Tree Planting') {
      throw Exception('This contribution is not a tree planting project');
    }

    // Upload monthly photos
    final monthlyPhotoUrls = <String>[];
    final monthYear = DateTime.now().toString().substring(0, 7); // YYYY-MM
    
    for (var i = 0; i < monthlyPhotos.length; i++) {
      final file = monthlyPhotos[i];
      final ref = storage.ref().child(
            'contributions/$userId/$contributionId/monthly/$monthYear/photo_$i.jpg',
          );
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      monthlyPhotoUrls.add(url);
    }

    // Update the contribution document
    final monthlyUpdates = List<Map<String, dynamic>>.from(
      data['monthlyUpdates'] ?? [],
    );

    monthlyUpdates.add({
      'month': monthYear,
      'photos': monthlyPhotoUrls,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await db.collection('contributions').doc(contributionId).update({
      'monthlyUpdates': monthlyUpdates,
      'afterImages': monthlyPhotoUrls, // Update main after images with latest
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Award bonus points for consistent updates
    final bonusPoints = 25;
    await db.collection('users').doc(userId).set(
      {
        'totalPoints': FieldValue.increment(bonusPoints),
      },
      SetOptions(merge: true),
    );
  }

  /// Get a specific contribution by ID
  Future<Map<String, dynamic>?> getContribution(String contributionId) async {
    final doc = await db.collection('contributions').doc(contributionId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Get all contributions for a user
  Stream<List<Map<String, dynamic>>> watchUserContributions({
    required String userId,
  }) {
    return db
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Get contributions for a user filtered by work type
  Stream<List<Map<String, dynamic>>> watchUserContributionsByType({
    required String userId,
    required String workType,
  }) {
    return db
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .where('workType', isEqualTo: workType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Get all contributions for a community
  Stream<List<Map<String, dynamic>>> watchCommunityContributions({
    required String communityId,
  }) {
    return db
        .collection('contributions')
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Get community contributions filtered by work type
  Stream<List<Map<String, dynamic>>> watchCommunityContributionsByType({
    required String communityId,
    required String workType,
  }) {
    return db
        .collection('contributions')
        .where('communityId', isEqualTo: communityId)
        .where('workType', isEqualTo: workType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Get user contribution statistics
  Future<Map<String, dynamic>> getUserStats({required String userId}) async {
    final userDoc = await db.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    final contributions = await db
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .get();

    final totalContributions = contributions.docs.length;
    final verifiedContributions = contributions.docs
        .where((doc) => doc.data()['status'] == 'verified')
        .length;

    final workTypeBreakdown = <String, int>{};
    for (final doc in contributions.docs) {
      final workType = doc.data()['workType'] as String? ?? 'Other';
      workTypeBreakdown[workType] = (workTypeBreakdown[workType] ?? 0) + 1;
    }

    return {
      'totalPoints': userData['totalPoints'] ?? 0,
      'totalContributions': totalContributions,
      'verifiedContributions': verifiedContributions,
      'pendingContributions': totalContributions - verifiedContributions,
      'workTypeBreakdown': workTypeBreakdown,
      'lastContribution': userData['lastContribution'],
      'contributionsByType': userData['contributionsByType'] ?? {},
    };
  }

  /// Get community contribution statistics
  Future<Map<String, dynamic>> getCommunityStats({
    required String communityId,
  }) async {
    final communityDoc = await db.collection('communities').doc(communityId).get();
    final communityData = communityDoc.data() ?? {};

    return {
      'totalImpactPoints': communityData['totalImpactPoints'] ?? 0,
      'totalContributions': communityData['totalContributions'] ?? 0,
      'contributionsByType': communityData['contributionsByType'] ?? {},
      'updatedAt': communityData['updatedAt'],
    };
  }

  /// Update contribution status (for admin/verification)
  Future<void> updateContributionStatus({
    required String contributionId,
    required String status, // pending, verified, rejected
    String? verifiedBy,
    String? rejectionReason,
  }) async {
    await db.collection('contributions').doc(contributionId).update({
      'status': status,
      'verifiedBy': verifiedBy,
      'rejectionReason': rejectionReason,
      'verifiedAt': status == 'verified' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a contribution (soft delete - mark as deleted)
  Future<void> deleteContribution({
    required String contributionId,
    required String userId,
  }) async {
    final doc = await db.collection('contributions').doc(contributionId).get();
    
    if (!doc.exists) {
      throw Exception('Contribution not found');
    }

    final data = doc.data()!;
    if (data['userId'] != userId) {
      throw Exception('You can only delete your own contributions');
    }

    // Soft delete - mark as deleted instead of actually deleting
    await db.collection('contributions').doc(contributionId).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // Optionally, deduct points from user
    final points = data['points'] as int? ?? 0;
    await db.collection('users').doc(userId).set(
      {
        'totalPoints': FieldValue.increment(-points),
        'contributions': FieldValue.increment(-1),
      },
      SetOptions(merge: true),
    );
  }

  /// Edit a contribution
  Future<void> editContribution({
    required String contributionId,
    required String userId,
    String? title,
    String? notes,
  }) async {
    final doc = await db.collection('contributions').doc(contributionId).get();
    
    if (!doc.exists) {
      throw Exception('Contribution not found');
    }

    final data = doc.data()!;
    if (data['userId'] != userId) {
      throw Exception('You can only edit your own contributions');
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null && title.trim().isNotEmpty) {
      if (title.length > 50) {
        throw Exception('Title must be 50 characters or less');
      }
      updates['title'] = title.trim();
    }

    if (notes != null) {
      updates['notes'] = notes.trim();
    }

    await db.collection('contributions').doc(contributionId).update(updates);
  }

  /// Get leaderboard for a community
  Future<List<Map<String, dynamic>>> getLeaderboard({
    required String communityId,
    int limit = 10,
  }) async {
    final contributions = await db
        .collection('contributions')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'verified')
        .get();

    final userPoints = <String, int>{};
    final userContributions = <String, int>{};

    for (final doc in contributions.docs) {
      final userId = doc.data()['userId'] as String;
      final points = doc.data()['points'] as int? ?? 0;

      userPoints[userId] = (userPoints[userId] ?? 0) + points;
      userContributions[userId] = (userContributions[userId] ?? 0) + 1;
    }

    final leaderboard = userPoints.entries.map((entry) {
      return {
        'userId': entry.key,
        'totalPoints': entry.value,
        'totalContributions': userContributions[entry.key] ?? 0,
      };
    }).toList();

    leaderboard.sort((a, b) => 
      (b['totalPoints'] as int).compareTo(a['totalPoints'] as int)
    );

    return leaderboard.take(limit).toList();
  }
}