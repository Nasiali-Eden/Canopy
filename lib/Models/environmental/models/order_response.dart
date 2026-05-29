import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderResponseStatus {
  pending,
  accepted,
  rejected,
  fulfilled,
  expired;

  String get firestoreKey {
    switch (this) {
      case OrderResponseStatus.pending:
        return 'pending';
      case OrderResponseStatus.accepted:
        return 'accepted';
      case OrderResponseStatus.rejected:
        return 'rejected';
      case OrderResponseStatus.fulfilled:
        return 'fulfilled';
      case OrderResponseStatus.expired:
        return 'expired';
    }
  }

  String get displayLabel {
    switch (this) {
      case OrderResponseStatus.pending:
        return 'Pending';
      case OrderResponseStatus.accepted:
        return 'Accepted';
      case OrderResponseStatus.rejected:
        return 'Rejected';
      case OrderResponseStatus.fulfilled:
        return 'Fulfilled';
      case OrderResponseStatus.expired:
        return 'Expired';
    }
  }

  static OrderResponseStatus fromFirestoreKey(String key) {
    return OrderResponseStatus.values.firstWhere(
      (e) => e.firestoreKey == key,
      orElse: () => OrderResponseStatus.pending,
    );
  }
}

class OrderResponse {
  final String responseId;
  final String orderId;
  final String orgId;
  final String collectorUid;
  final String collectorDisplayName;
  final String? collectorPhotoUrl;
  final double offeredKg;
  final DateTime? availableFrom;
  final String? notes;
  final OrderResponseStatus status;
  final DateTime? respondedAt;
  final DateTime? resolvedAt;

  const OrderResponse({
    required this.responseId,
    required this.orderId,
    required this.orgId,
    required this.collectorUid,
    required this.collectorDisplayName,
    this.collectorPhotoUrl,
    required this.offeredKg,
    this.availableFrom,
    this.notes,
    required this.status,
    this.respondedAt,
    this.resolvedAt,
  });

  factory OrderResponse.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return OrderResponse(
      responseId: doc.id,
      orderId: (data['orderId'] as String?) ?? '',
      orgId: (data['orgId'] as String?) ?? '',
      collectorUid: (data['collectorUid'] as String?) ?? '',
      collectorDisplayName: (data['collectorDisplayName'] as String?) ?? '',
      collectorPhotoUrl: data['collectorPhotoUrl'] as String?,
      offeredKg: (data['offeredKg'] as num?)?.toDouble() ?? 0.0,
      availableFrom: (data['availableFrom'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
      status: OrderResponseStatus.fromFirestoreKey(
        (data['status'] as String?) ?? 'pending',
      ),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'orderId': orderId,
        'orgId': orgId,
        'collectorUid': collectorUid,
        'collectorDisplayName': collectorDisplayName,
        'collectorPhotoUrl': collectorPhotoUrl,
        'offeredKg': offeredKg,
        'availableFrom':
            availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
        'notes': notes,
        'status': status.firestoreKey,
        'respondedAt':
            respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
        'resolvedAt':
            resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      };

  OrderResponse copyWith({
    String? responseId,
    String? orderId,
    String? orgId,
    String? collectorUid,
    String? collectorDisplayName,
    String? collectorPhotoUrl,
    double? offeredKg,
    DateTime? availableFrom,
    String? notes,
    OrderResponseStatus? status,
    DateTime? respondedAt,
    DateTime? resolvedAt,
  }) {
    return OrderResponse(
      responseId: responseId ?? this.responseId,
      orderId: orderId ?? this.orderId,
      orgId: orgId ?? this.orgId,
      collectorUid: collectorUid ?? this.collectorUid,
      collectorDisplayName: collectorDisplayName ?? this.collectorDisplayName,
      collectorPhotoUrl: collectorPhotoUrl ?? this.collectorPhotoUrl,
      offeredKg: offeredKg ?? this.offeredKg,
      availableFrom: availableFrom ?? this.availableFrom,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
