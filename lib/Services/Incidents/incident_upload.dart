// lib/Services/Incidents/incident_upload.dart
//
// Write side of the `Incidents` collection. Throws on failure so the screen
// can say so — a report that didn't save must never look like it did.
// Location is stored both as the legacy "lat, lng" string and as numbers,
// plus an optional human place description.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class UploadIncident {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  static const maxPhotos = 4;

  /// Up to [max] photos from the gallery. image_picker handles its own
  /// permission prompts.
  Future<List<File>> pickImages({int max = maxPhotos}) async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 82, maxWidth: 1600);
    return picked.take(max).map((x) => File(x.path)).toList();
  }

  Future<File?> takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 1600);
    return x == null ? null : File(x.path);
  }

  /// Current position, or null when location is off or refused.
  Future<LatLng?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadIncident({
    required String headline,
    required String description,
    required String type,
    required List<File> images,
    required LatLng position,
    String place = '',
    void Function(int done, int total)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('signed-out');
    final id = const Uuid().v4();
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final ref = _storage.ref('incident_images/$id/${const Uuid().v4()}.jpg');
      await ref.putFile(images[i]);
      urls.add(await ref.getDownloadURL());
      onProgress?.call(i + 1, images.length);
    }
    await _db.collection('Incidents').doc(id).set({
      'incidentId': id,
      'headline': headline,
      'description': description,
      'type': type,
      'location': '${position.latitude}, ${position.longitude}',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'place': place,
      'images': urls,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': user.uid,
      // Every report starts pending; nothing assigns verifiers yet.
      'status': 'pending',
      'verifierIds': <String>[],
      'verifiedAt': null,
    });
  }
}
