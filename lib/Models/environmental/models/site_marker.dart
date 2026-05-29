import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:impact_trail/models/environmental/enums/marker_type.dart';
import 'package:impact_trail/models/environmental/shared/gps_coordinate.dart';

class SiteMarker {
  final String markerId;
  final String orgId;
  final MarkerType markerType;
  final String label;
  final String? description;
  final GpsCoordinate location;
  final String? operatingHours;
  final List<String> photos;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Hub-specific — only populated when markerType == processingHub
  final List<String>? acceptedMaterials;
  final Map<String, double>? currentBuyPrices;
  final bool? hasWeighingScale;
  final bool? hasStorageFacility;
  final String? mpesaPaybill;

  // Drop-off specific — only populated when markerType == dropOffPoint
  final bool? requiresAppointment;
  final String? linkedHubId;

  const SiteMarker({
    required this.markerId,
    required this.orgId,
    required this.markerType,
    required this.label,
    this.description,
    required this.location,
    this.operatingHours,
    required this.photos,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.acceptedMaterials,
    this.currentBuyPrices,
    this.hasWeighingScale,
    this.hasStorageFacility,
    this.mpesaPaybill,
    this.requiresAppointment,
    this.linkedHubId,
  });

  factory SiteMarker.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final locationData =
        (data['location'] as Map<String, dynamic>?) ?? {};
    final hubData =
        (data['hub_specific'] as Map<String, dynamic>?) ?? {};
    final dropOffData =
        (data['dropOff_specific'] as Map<String, dynamic>?) ?? {};

    final rawPrices = hubData['currentBuyPrices'] as Map?;
    final Map<String, double>? buyPrices = rawPrices?.map(
      (k, v) => MapEntry(k as String, (v as num).toDouble()),
    );

    final hubAccepted =
        (hubData['acceptedMaterials'] as List?)?.cast<String>();
    final dropOffAccepted =
        (dropOffData['acceptedMaterials'] as List?)?.cast<String>();

    return SiteMarker(
      markerId: doc.id,
      orgId: (data['orgId'] as String?) ?? '',
      markerType: MarkerType.fromFirestoreKey(
        (data['markerType'] as String?) ?? 'active_collection_site',
      ),
      label: (data['label'] as String?) ?? '',
      description: data['description'] as String?,
      location: GpsCoordinate.fromMap(locationData),
      operatingHours: data['operatingHours'] as String?,
      photos: (data['photos'] as List?)?.cast<String>() ?? const [],
      isActive: (data['isActive'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      acceptedMaterials: hubAccepted ?? dropOffAccepted,
      currentBuyPrices: buyPrices,
      hasWeighingScale: hubData['hasWeighingScale'] as bool?,
      hasStorageFacility: hubData['hasStorageFacility'] as bool?,
      mpesaPaybill: hubData['mpesaPaybill'] as String?,
      requiresAppointment: dropOffData['requiresAppointment'] as bool?,
      linkedHubId: dropOffData['linkedHubId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'orgId': orgId,
      'markerType': markerType.firestoreKey,
      'label': label,
      'description': description,
      'location': location.toMap(),
      'operatingHours': operatingHours,
      'photos': photos,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
    if (markerType == MarkerType.processingHub) {
      map['hub_specific'] = {
        'acceptedMaterials': acceptedMaterials,
        'currentBuyPrices': currentBuyPrices,
        'hasWeighingScale': hasWeighingScale,
        'hasStorageFacility': hasStorageFacility,
        'mpesaPaybill': mpesaPaybill,
      };
    }
    if (markerType == MarkerType.dropOffPoint) {
      map['dropOff_specific'] = {
        'acceptedMaterials': acceptedMaterials,
        'requiresAppointment': requiresAppointment,
        'linkedHubId': linkedHubId,
      };
    }
    return map;
  }

  SiteMarker copyWith({
    String? markerId,
    String? orgId,
    MarkerType? markerType,
    String? label,
    String? description,
    GpsCoordinate? location,
    String? operatingHours,
    List<String>? photos,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? acceptedMaterials,
    Map<String, double>? currentBuyPrices,
    bool? hasWeighingScale,
    bool? hasStorageFacility,
    String? mpesaPaybill,
    bool? requiresAppointment,
    String? linkedHubId,
  }) {
    return SiteMarker(
      markerId: markerId ?? this.markerId,
      orgId: orgId ?? this.orgId,
      markerType: markerType ?? this.markerType,
      label: label ?? this.label,
      description: description ?? this.description,
      location: location ?? this.location,
      operatingHours: operatingHours ?? this.operatingHours,
      photos: photos ?? this.photos,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedMaterials: acceptedMaterials ?? this.acceptedMaterials,
      currentBuyPrices: currentBuyPrices ?? this.currentBuyPrices,
      hasWeighingScale: hasWeighingScale ?? this.hasWeighingScale,
      hasStorageFacility: hasStorageFacility ?? this.hasStorageFacility,
      mpesaPaybill: mpesaPaybill ?? this.mpesaPaybill,
      requiresAppointment: requiresAppointment ?? this.requiresAppointment,
      linkedHubId: linkedHubId ?? this.linkedHubId,
    );
  }
}
