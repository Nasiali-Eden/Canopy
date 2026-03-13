import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../Shared/Activities/activity.dart';

class ActivityService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  ActivityService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Stream<List<Activity>> watchActivities({String type = 'All'}) {
    Query<Map<String, dynamic>> query = _db.collection('activities');

    if (type != 'All') {
      query = query.where('type', isEqualTo: type);
    }

    query = query.orderBy('dateTime', descending: false);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map(Activity.fromFirestore).toList();
    });
  }

  Future<Activity?> getActivity(String id) async {
    final doc = await _db.collection('activities').doc(id).get();
    if (!doc.exists) return null;
    return Activity.fromFirestore(doc);
  }

  Future<String> createActivity({
    required String type,
    required String title,
    required String description,
    required Map<String, dynamic> location,
    required DateTime dateTime,
    required int requiredParticipants,
    String? createdBy,
    XFile? coverImage,
  }) async {
    String? coverUrl;
    if (coverImage != null) {
      final ref = _storage.ref().child(
          'activities/covers/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(coverImage.path));
      coverUrl = await ref.getDownloadURL();
    }

    final doc = await _db.collection('activities').add({
      'type': type,
      'title': title,
      'description': description,
      'location': location,
      'dateTime': Timestamp.fromDate(dateTime),
      'requiredParticipants': requiredParticipants,
      'participantIds': <String>[],
      'coverImageUrl': coverUrl,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> joinActivity(
      {required String activityId, required String userId}) {
    return _db.collection('activities').doc(activityId).set({
      'participantIds': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  Future<void> leaveActivity(
      {required String activityId, required String userId}) {
    return _db.collection('activities').doc(activityId).set({
      'participantIds': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
  }
}
