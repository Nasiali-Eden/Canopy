import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

class UploadIncident {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = Uuid();

  /// Requests camera, storage, and location permissions.
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Crops an image and returns the cropped file.
  Future<File?> _cropImage(String imagePath) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
          ),
          IOSUiSettings(title: 'Crop Image'),
        ],
      );

      return croppedFile != null ? File(croppedFile.path) : null;
    } catch (e) {
      debugPrint("Error cropping image: $e");
      return null;
    }
  }

  /// Picks and crops up to 4 images from the gallery.
  Future<List<File>> pickAndCropImages() async {
    List<File> imageFiles = [];

    if (await _requestPermissions()) {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(imageQuality: 85);

      if (pickedFiles != null) {
        for (var file in pickedFiles.take(4)) {
          File? croppedFile = await _cropImage(file.path);
          if (croppedFile != null) imageFiles.add(croppedFile);
        }
      }
    } else {
      debugPrint("Permissions denied.");
    }

    return imageFiles;
  }

  /// Uploads images to Firebase Storage and returns their download URLs.
  Future<List<String>> _uploadImages(List<File> images, String incidentId) async {
    List<Future<String>> uploadTasks = images.map((image) async {
      try {
        final ref = _storage.ref().child('incident_images/$incidentId/${_uuid.v4()}.jpg');
        await ref.putFile(image);
        return await ref.getDownloadURL();
      } catch (e) {
        debugPrint("Error uploading image: $e");
        return "";
      }
    }).toList();

    List<String> uploadedUrls = await Future.wait(uploadTasks);
    return uploadedUrls.where((url) => url.isNotEmpty).toList();
  }

  /// Gets the current location as a string.
  Future<String?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      return "${position.latitude}, ${position.longitude}";
    } catch (e) {
      debugPrint("Error getting location: $e");
      return null;
    }
  }

  /// Uploads an incident to Firestore.
  Future<void> uploadIncident({
    required String headline,
    required String description,
    required String type,
    required List<File> images,
    LatLng? customLocation, // Add custom location parameter
    required BuildContext context,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        debugPrint("Error: User is not authenticated.");
        return;
      }

      // Use custom location if provided; otherwise, fetch current location
      String? location;
      if (customLocation != null) {
        location = "${customLocation.latitude}, ${customLocation.longitude}";
      } else {
        location = await getCurrentLocation();
      }

      if (location == null) {
        debugPrint("Error: Unable to get location.");
        return;
      }

      String incidentId = _uuid.v4();
      List<String> imageUrls = await _uploadImages(images, incidentId);

      Map<String, dynamic> incidentData = {
        "incidentId": incidentId,
        "headline": headline,
        "description": description,
        "type": type,
        "location": location,
        "images": imageUrls,
        "timestamp": FieldValue.serverTimestamp(),
        "userId": user.uid,
        // Status pipeline (Reported Issues feed / IncidentsService). Every
        // report starts "pending" — nothing in the app currently assigns
        // verifiers or advances status, so "verifying"/"confirmed"/
        // "resolved" are read-side states the UI supports but nothing
        // writes yet. Wiring that assignment is separate follow-up work.
        "status": "pending",
        "verifierIds": <String>[],
        "verifiedAt": null,
      };

      // Single source of truth: the flat 'Incidents' collection, queried by
      // userId (see IncidentsService.watchMine). This used to also fan out
      // to a per-user/org subcollection copy, but nothing ever read that
      // copy back and it had no Firestore rule covering it (would have
      // failed permission-denied the moment this screen became reachable) —
      // removed rather than securing a second copy of the same document.
      await _firestore.collection("Incidents").doc(incidentId).set(incidentData);

      debugPrint("Incident successfully uploaded.");

      // Navigate to the home page (replace 'HomePage' with your actual screen)
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint("Error uploading incident: $e");
    }
  }
}
