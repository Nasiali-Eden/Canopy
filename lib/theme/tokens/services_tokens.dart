// services_tokens.dart — Services (booking local help)
// Builds on ../canopy_tokens.dart. Every value used by this area's screens resolves here or in core.

import 'package:flutter/material.dart';
import '../canopy_tokens.dart';

// ───────────────────────────────────────────────────────────── Services

class CanopyFees {
  static const bookingFeeKsh = 150; // waived for recurring/standing services
  static const commissionRate = 0.08; // taken from the provider's side
  static String ksh(int amount) {
    final s = amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return 'KSh $s';
  }
}

/// The seven categories. Icons are Material Symbols Outlined — never emoji.
enum ServiceCategory {
  trashCollection('Trash collection', 'delete', false),
  landscaping('Landscaping', 'eco', false),
  junkRemoval('Junk removal', 'inventory_2', false),
  movingHauling('Moving & hauling', 'local_shipping', false),
  handyman('Handyman', 'build', false), // must show the "no regulated work" callout
  electrical('Electrical', 'bolt', true), // EPRA licence required
  plumbing('Plumbing', 'water_drop', true); // NCA licence required

  const ServiceCategory(this.label, this.symbol, this.needsLicence);
  final String label;
  final String symbol;
  final bool needsLicence; // hidden from Browse until licence verified
}

enum RateType { perMonth, perVisit, quoteOnly } // "From KSh 800 /month" · "KSh 500 – 1,500 /visit" · "Quote on request"

enum BookingStatus { requested, quoted, accepted, scheduled, completed, declined, cancelled }
enum PaymentStatus { unpaid, awaitingMpesa, paid, failed } // only the M-Pesa callback sets paid
enum PayoutStatus { pending, paid, failed, manual }
enum LicenceStatus { pending, verified, rejected }

/// Status → label colour (labels are uppercase text, never capsules).
class ServiceStatusColors {
  static Color booking(BookingStatus s, CanopyPalette p) => switch (s) {
        BookingStatus.requested => p.inkMuted,
        BookingStatus.quoted => p.info,
        BookingStatus.accepted => p.primaryInk,
        BookingStatus.scheduled => p.info,
        BookingStatus.completed => p.success,
        BookingStatus.declined => p.inkMuted,
        BookingStatus.cancelled => p.danger,
      };
  static Color payment(PaymentStatus s, CanopyPalette p) => switch (s) {
        PaymentStatus.unpaid => p.inkMuted,
        PaymentStatus.awaitingMpesa => p.warning,
        PaymentStatus.paid => p.success,
        PaymentStatus.failed => p.danger,
      };
  static Color payout(PayoutStatus s, CanopyPalette p) => switch (s) {
        PayoutStatus.pending => p.warning,
        PayoutStatus.paid => p.success,
        PayoutStatus.failed => p.danger,
        PayoutStatus.manual => p.info,
      };
  static Color licence(LicenceStatus s, CanopyPalette p) => switch (s) {
        LicenceStatus.pending => p.warning,
        LicenceStatus.verified => p.success,
        LicenceStatus.rejected => p.danger,
      };
  /// "Your turn" marker: 7px dot + uppercase label in primaryInk; card gets a 1.5px primary border.
  static Color yourTurn(CanopyPalette p) => p.primaryInk;
}

class ServiceFees {
  static int requesterTotal(int agreed, {required bool recurring}) =>
      agreed + (recurring ? 0 : CanopyFees.bookingFeeKsh);
  static int commission(int agreed) => (agreed * CanopyFees.commissionRate).round();
  static int providerReceives(int agreed) => agreed - commission(agreed);
}
