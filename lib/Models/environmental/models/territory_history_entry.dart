import 'package:cloud_firestore/cloud_firestore.dart';

// Append-only. Never update existing documents.

enum TerritoryEventType {
  zoneCreated,
  zoneUpdated,
  zoneDeactivated,
  siteAdded,
  siteUpdated,
  collectionVerified,
  zoneCreditThresholdMet;

  String get firestoreKey {
    switch (this) {
      case TerritoryEventType.zoneCreated:
        return 'zone_created';
      case TerritoryEventType.zoneUpdated:
        return 'zone_updated';
      case TerritoryEventType.zoneDeactivated:
        return 'zone_deactivated';
      case TerritoryEventType.siteAdded:
        return 'site_added';
      case TerritoryEventType.siteUpdated:
        return 'site_updated';
      case TerritoryEventType.collectionVerified:
        return 'collection_verified';
      case TerritoryEventType.zoneCreditThresholdMet:
        return 'zone_credit_threshold_met';
    }
  }

  String get displayLabel {
    switch (this) {
      case TerritoryEventType.zoneCreated:
        return 'Zone Created';
      case TerritoryEventType.zoneUpdated:
        return 'Zone Updated';
      case TerritoryEventType.zoneDeactivated:
        return 'Zone Deactivated';
      case TerritoryEventType.siteAdded:
        return 'Site Added';
      case TerritoryEventType.siteUpdated:
        return 'Site Updated';
      case TerritoryEventType.collectionVerified:
        return 'Collection Verified';
      case TerritoryEventType.zoneCreditThresholdMet:
        return 'Zone Credit Threshold Met';
    }
  }

  static TerritoryEventType fromFirestoreKey(String key) {
    return TerritoryEventType.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => TerritoryEventType.zoneUpdated,
    );
  }
}

class TerritoryHistoryEntry {
  final String entryId;
  final String orgId;
  final TerritoryEventType eventType;
  final String? zoneId;
  final String? siteMarkerId;
  final String label;
  final String actorUid;
  final DateTime? occurredAt;

  const TerritoryHistoryEntry({
    required this.entryId,
    required this.orgId,
    required this.eventType,
    this.zoneId,
    this.siteMarkerId,
    required this.label,
    required this.actorUid,
    this.occurredAt,
  });

  factory TerritoryHistoryEntry.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TerritoryHistoryEntry(
      entryId: doc.id,
      orgId: (data['orgId'] as String?) ?? '',
      eventType: TerritoryEventType.fromFirestoreKey(
        (data['eventType'] as String?) ?? 'zone_updated',
      ),
      zoneId: data['zoneId'] as String?,
      siteMarkerId: data['siteMarkerId'] as String?,
      label: (data['label'] as String?) ?? '',
      actorUid: (data['actorUid'] as String?) ?? '',
      occurredAt: (data['occurredAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orgId': orgId,
        'eventType': eventType.firestoreKey,
        'zoneId': zoneId,
        'siteMarkerId': siteMarkerId,
        'label': label,
        'actorUid': actorUid,
        'occurredAt':
            occurredAt != null ? Timestamp.fromDate(occurredAt!) : null,
      };

  TerritoryHistoryEntry copyWith({
    String? entryId,
    String? orgId,
    TerritoryEventType? eventType,
    String? zoneId,
    String? siteMarkerId,
    String? label,
    String? actorUid,
    DateTime? occurredAt,
  }) {
    return TerritoryHistoryEntry(
      entryId: entryId ?? this.entryId,
      orgId: orgId ?? this.orgId,
      eventType: eventType ?? this.eventType,
      zoneId: zoneId ?? this.zoneId,
      siteMarkerId: siteMarkerId ?? this.siteMarkerId,
      label: label ?? this.label,
      actorUid: actorUid ?? this.actorUid,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }
}
