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
    String? orgId,
    String? organizerName,
    List<XFile?> images = const [],
    RegistrationState registrationState = RegistrationState.open,
  }) async {
    final docRef = _db.collection('activities').doc();
    final activityId = docRef.id;

    // Preserve slot order (0 = cover). Firestore arrays cannot hold nulls.
    final imageSlots = List<String>.filled(4, '');
    for (var i = 0; i < images.length && i < 4; i++) {
      final file = images[i];
      if (file == null) continue;

      final ref =
          _storage.ref().child('activities/$activityId/gallery_$i.jpg');
      await ref.putFile(File(file.path));
      imageSlots[i] = await ref.getDownloadURL();
    }

    final coverUrl = imageSlots.firstWhere(
      (url) => url.isNotEmpty,
      orElse: () => '',
    );
    final coverUrlOrNull = coverUrl.isEmpty ? null : coverUrl;
    final scheduledAt = Timestamp.fromDate(dateTime);
    final status =
        registrationState == RegistrationState.closed ? 'closed' : 'open';
    final locationName = _locationLabel(location);

    await docRef.set({
      'type': type,
      'title': title,
      'name': title,
      'description': description,
      'location': location,
      'locationName': locationName,
      'dateTime': scheduledAt,
      'scheduledAt': scheduledAt,
      'date': scheduledAt,
      'requiredParticipants': requiredParticipants,
      'maxParticipants': requiredParticipants,
      'participantIds': <String>[],
      'participants': 0,
      'registeredCount': 0,
      'images': imageSlots,
      'coverImageUrl': coverUrlOrNull,
      'registrationState': registrationState.name,
      'status': status,
      'orgId': orgId,
      'organizerName': organizerName,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return activityId;
  }

  static String _locationLabel(Map<String, dynamic> location) {
    final venue = location['venue'] as String? ?? '';
    final area = location['area'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    return [
      if (venue.isNotEmpty) venue,
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
    ].join(', ');
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
