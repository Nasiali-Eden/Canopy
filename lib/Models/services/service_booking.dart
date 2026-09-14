// lib/Models/services/service_booking.dart
//
// A requester's job against a ServiceListing. Firestore path:
// /service_bookings/{bookingId} — a top-level collection, not a subcollection
// of the listing, for the same reason ListingResponse's sibling collection
// query would not have worked here: "my requests" (by requesterUid) and
// "incoming jobs" (by providerUid) are each a single equality predicate over
// the whole collection. Nesting under the listing would mean fanning out a
// query per listing to build either screen. See listing_service.dart's file
// header for the same reasoning applied to /listings.
//
// ── The quote flow ──
// requested → quoted → accepted → scheduled → completed
//                    ↘ declined              ↘ cancelled
//
// A requester opens a booking with a description of the job (no price yet —
// see ServiceListing's header on why pricing is soft). The provider reviews
// it and responds with a price (`quotedPriceKes`). Once the requester
// accepts, that number is locked into `agreedPriceKes` and the fee split
// below is computed from it. This is the answer to "who do we charge, the
// provider or the requester": both, the same way the goods Marketplace
// already does — marketplace_checkout.dart deducts a platform commission
// from what the seller receives AND adds a flat delivery fee to what the
// buyer pays. Services mirrors that shape exactly:
//
//   platformFeeKes        = agreedPriceKes × PlatformConstants.serviceCommissionDefaultPct
//   providerPayoutKes      = agreedPriceKes − platformFeeKes
//   requesterBookingFeeKes = PlatformConstants.serviceBookingFeeKes, waived when isRecurring
//   requesterTotalKes      = agreedPriceKes + requesterBookingFeeKes
//
// The booking fee is waived for recurring trash-collection subscriptions —
// charging a flat KSh 150 every single pickup would make weekly collection
// more expensive in fees than the collection itself.
//
// ── Payment ──
// paymentStatus mirrors marketplace_checkout.dart's mocked `_pay()`
// (`await Future.delayed(...); // M-Pesa STK push`) — this model carries the
// same 'unpaid' / 'simulated_paid' vocabulary so the checkout screen has
// real fields to flip once a payment method is actually wired up. See
// IMPLEMENTATION_NOTES_SERVICES.md for the deferred real-payment research.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../environmental/enums/payment_method.dart';
import '../environmental/shared/platform_constants.dart';
import '../geo/canopy_location.dart';
import 'service_listing.dart';

enum ServiceBookingStatus {
  requested,
  quoted,
  accepted,
  scheduled,
  completed,
  declined,
  cancelled;

  String get label => switch (this) {
        ServiceBookingStatus.requested => 'Requested',
        ServiceBookingStatus.quoted => 'Quoted',
        ServiceBookingStatus.accepted => 'Accepted',
        ServiceBookingStatus.scheduled => 'Scheduled',
        ServiceBookingStatus.completed => 'Completed',
        ServiceBookingStatus.declined => 'Declined',
        ServiceBookingStatus.cancelled => 'Cancelled',
      };

  /// Still an open thread either side can act on.
  bool get isOpen => this == ServiceBookingStatus.requested ||
      this == ServiceBookingStatus.quoted ||
      this == ServiceBookingStatus.accepted ||
      this == ServiceBookingStatus.scheduled;

  static ServiceBookingStatus fromString(String? v) => ServiceBookingStatus.values
      .firstWhere((e) => e.name == v, orElse: () => ServiceBookingStatus.requested);
}

/// Pure fee math, kept separate from the model so the request screen can
/// preview a breakdown before a booking document exists, and the provider's
/// quote screen can preview it the moment they type a figure.
class ServiceFeeBreakdown {
  final double agreedPriceKes;
  final double platformFeeKes;
  final double providerPayoutKes;
  final double requesterBookingFeeKes;
  final double requesterTotalKes;

  const ServiceFeeBreakdown({
    required this.agreedPriceKes,
    required this.platformFeeKes,
    required this.providerPayoutKes,
    required this.requesterBookingFeeKes,
    required this.requesterTotalKes,
  });

  static const zero = ServiceFeeBreakdown(
    agreedPriceKes: 0,
    platformFeeKes: 0,
    providerPayoutKes: 0,
    requesterBookingFeeKes: 0,
    requesterTotalKes: 0,
  );

  factory ServiceFeeBreakdown.compute({
    required double agreedPriceKes,
    required bool isRecurring,
  }) {
    final fee =
        agreedPriceKes * (PlatformConstants.serviceCommissionDefaultPct / 100);
    final bookingFee = isRecurring ? 0.0 : PlatformConstants.serviceBookingFeeKes;
    return ServiceFeeBreakdown(
      agreedPriceKes: agreedPriceKes,
      platformFeeKes: fee,
      providerPayoutKes: agreedPriceKes - fee,
      requesterBookingFeeKes: bookingFee,
      requesterTotalKes: agreedPriceKes + bookingFee,
    );
  }
}

class ServiceBooking {
  final String id;
  final String listingId;
  final String listingTitle;
  final ServiceCategory category;

  // ── Requester ──
  final String requesterUid;
  final String requesterName;
  final String? requesterPhone;

  // ── Provider ──
  final String providerUid;
  final String providerName;
  final String? providerOrgId;
  final String? providerOrgName;

  // ── The job ──
  final CanopyLocation serviceLocation;
  final String? addressNote;
  final DateTime? preferredDate;

  /// True for a standing trash-collection arrangement rather than a one-off
  /// job — waives the requester booking fee. See the file header.
  final bool isRecurring;

  final String requestMessage;
  final ServiceBookingStatus status;

  // ── Quote / agreed price ──
  final double? quotedPriceKes;
  final String? quoteNote;
  final double? agreedPriceKes;

  // ── Fee split, locked in once agreedPriceKes is set ──
  final double platformFeeKes;
  final double providerPayoutKes;
  final double requesterBookingFeeKes;
  final double requesterTotalKes;

  // ── Payment — mocked; see file header ──
  final PaymentMethod paymentMethod;

  /// 'unpaid' | 'simulated_paid'
  final String paymentStatus;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? quotedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? cancellationReason;

  const ServiceBooking({
    required this.id,
    required this.listingId,
    this.listingTitle = '',
    this.category = ServiceCategory.trashCollection,
    required this.requesterUid,
    this.requesterName = '',
    this.requesterPhone,
    required this.providerUid,
    this.providerName = '',
    this.providerOrgId,
    this.providerOrgName,
    this.serviceLocation = CanopyLocation.empty,
    this.addressNote,
    this.preferredDate,
    this.isRecurring = false,
    this.requestMessage = '',
    this.status = ServiceBookingStatus.requested,
    this.quotedPriceKes,
    this.quoteNote,
    this.agreedPriceKes,
    this.platformFeeKes = 0,
    this.providerPayoutKes = 0,
    this.requesterBookingFeeKes = 0,
    this.requesterTotalKes = 0,
    this.paymentMethod = PaymentMethod.mpesa,
    this.paymentStatus = 'unpaid',
    required this.createdAt,
    this.updatedAt,
    this.quotedAt,
    this.acceptedAt,
    this.completedAt,
    this.cancellationReason,
  });

  ServiceFeeBreakdown get feeBreakdown => agreedPriceKes != null
      ? ServiceFeeBreakdown(
          agreedPriceKes: agreedPriceKes!,
          platformFeeKes: platformFeeKes,
          providerPayoutKes: providerPayoutKes,
          requesterBookingFeeKes: requesterBookingFeeKes,
          requesterTotalKes: requesterTotalKes,
        )
      : ServiceFeeBreakdown.zero;

  bool get isPaid => paymentStatus == 'simulated_paid';
  bool get needsRequesterAction =>
      status == ServiceBookingStatus.quoted || status == ServiceBookingStatus.accepted;
  bool get needsProviderAction => status == ServiceBookingStatus.requested;

  factory ServiceBooking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceBooking.fromMap(doc.id, d);
  }

  factory ServiceBooking.fromMap(String id, Map<String, dynamic> d) {
    return ServiceBooking(
      id: id,
      listingId: d['listingId'] as String? ?? '',
      listingTitle: d['listingTitle'] as String? ?? '',
      category: ServiceCategory.fromString(d['category'] as String?),
      requesterUid: d['requesterUid'] as String? ?? '',
      requesterName: d['requesterName'] as String? ?? '',
      requesterPhone: d['requesterPhone'] as String?,
      providerUid: d['providerUid'] as String? ?? '',
      providerName: d['providerName'] as String? ?? '',
      providerOrgId: d['providerOrgId'] as String?,
      providerOrgName: d['providerOrgName'] as String?,
      serviceLocation: CanopyLocation.fromFirestore(d),
      addressNote: d['addressNote'] as String?,
      preferredDate: (d['preferredDate'] as Timestamp?)?.toDate(),
      isRecurring: d['isRecurring'] as bool? ?? false,
      requestMessage: d['requestMessage'] as String? ?? '',
      status: ServiceBookingStatus.fromString(d['status'] as String?),
      quotedPriceKes: (d['quotedPriceKes'] as num?)?.toDouble(),
      quoteNote: d['quoteNote'] as String?,
      agreedPriceKes: (d['agreedPriceKes'] as num?)?.toDouble(),
      platformFeeKes: (d['platformFeeKes'] as num?)?.toDouble() ?? 0,
      providerPayoutKes: (d['providerPayoutKes'] as num?)?.toDouble() ?? 0,
      requesterBookingFeeKes:
          (d['requesterBookingFeeKes'] as num?)?.toDouble() ?? 0,
      requesterTotalKes: (d['requesterTotalKes'] as num?)?.toDouble() ?? 0,
      paymentMethod:
          PaymentMethod.fromFirestoreKey(d['paymentMethod'] as String? ?? 'mpesa'),
      paymentStatus: d['paymentStatus'] as String? ?? 'unpaid',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      quotedAt: (d['quotedAt'] as Timestamp?)?.toDate(),
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      cancellationReason: d['cancellationReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'listingId': listingId,
        'listingTitle': listingTitle,
        'category': category.firestoreKey,
        'requesterUid': requesterUid,
        'requesterName': requesterName,
        'requesterPhone': requesterPhone,
        'providerUid': providerUid,
        'providerName': providerName,
        'providerOrgId': providerOrgId,
        'providerOrgName': providerOrgName,
        'addressNote': addressNote,
        'preferredDate':
            preferredDate != null ? Timestamp.fromDate(preferredDate!) : null,
        'isRecurring': isRecurring,
        'requestMessage': requestMessage,
        'status': status.name,
        'quotedPriceKes': quotedPriceKes,
        'quoteNote': quoteNote,
        'agreedPriceKes': agreedPriceKes,
        'platformFeeKes': platformFeeKes,
        'providerPayoutKes': providerPayoutKes,
        'requesterBookingFeeKes': requesterBookingFeeKes,
        'requesterTotalKes': requesterTotalKes,
        'paymentMethod': paymentMethod.firestoreKey,
        'paymentStatus': paymentStatus,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'quotedAt': quotedAt != null ? Timestamp.fromDate(quotedAt!) : null,
        'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'cancellationReason': cancellationReason,
        // Geography spread flat, same convention as CanopyListing / ServiceListing.
        ...serviceLocation.toFirestore(),
      };

  ServiceBooking copyWith({
    ServiceBookingStatus? status,
    double? quotedPriceKes,
    String? quoteNote,
    double? agreedPriceKes,
    double? platformFeeKes,
    double? providerPayoutKes,
    double? requesterBookingFeeKes,
    double? requesterTotalKes,
    String? paymentStatus,
    DateTime? updatedAt,
    DateTime? quotedAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? cancellationReason,
  }) {
    return ServiceBooking(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      category: category,
      requesterUid: requesterUid,
      requesterName: requesterName,
      requesterPhone: requesterPhone,
      providerUid: providerUid,
      providerName: providerName,
      providerOrgId: providerOrgId,
      providerOrgName: providerOrgName,
      serviceLocation: serviceLocation,
      addressNote: addressNote,
      preferredDate: preferredDate,
      isRecurring: isRecurring,
      requestMessage: requestMessage,
      status: status ?? this.status,
      quotedPriceKes: quotedPriceKes ?? this.quotedPriceKes,
      quoteNote: quoteNote ?? this.quoteNote,
      agreedPriceKes: agreedPriceKes ?? this.agreedPriceKes,
      platformFeeKes: platformFeeKes ?? this.platformFeeKes,
      providerPayoutKes: providerPayoutKes ?? this.providerPayoutKes,
      requesterBookingFeeKes:
          requesterBookingFeeKes ?? this.requesterBookingFeeKes,
      requesterTotalKes: requesterTotalKes ?? this.requesterTotalKes,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      quotedAt: quotedAt ?? this.quotedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}
