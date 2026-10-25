// lib/HomeServices/services_ui.dart
//
// Services components (handoff/SERVICES_HANDOFF.md §2), built on the v2
// library. Every Services screen composes these:
//
//   CategoryGlyph · VerifiedLabel · NewProviderLabel · ListingCard ·
//   PriceDisplay · BookingLabels (booking / payment / payout) · YourTurn ·
//   BookingTimeline · FeeBreakdown (requester / recurring / provider) ·
//   QuoteComposer sheet · MpesaSheet (confirm → waiting → success → failed) ·
//   RegulatoryCallout.
//
// Money is always "KSh 2,650" — no decimals (CanopyFees.ksh). Paid is set
// only by the M-Pesa callback; nothing here can mark a booking paid.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_booking.dart';
import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import '../theme/tokens/services_tokens.dart' show CanopyFees;

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY
// ─────────────────────────────────────────────────────────────────────────────

extension ServiceCategoryUi on ServiceCategory {
  /// Material Symbols Outlined — never emoji.
  IconData get icon => switch (this) {
        ServiceCategory.trashCollection => Icons.delete_outline,
        ServiceCategory.landscaping => Icons.eco_outlined,
        ServiceCategory.junkRemoval => Icons.inventory_2_outlined,
        ServiceCategory.movingHauling => Icons.local_shipping_outlined,
        ServiceCategory.handyman => Icons.build_outlined,
        ServiceCategory.electrical => Icons.bolt_outlined,
        ServiceCategory.plumbing => Icons.water_drop_outlined,
      };

  /// Sentence case for UI ("Trash collection").
  String get name2 {
    final l = label;
    return l.isEmpty ? l : l[0] + l.substring(1).toLowerCase();
  }

  /// "electrician" / "plumber" etc. for browse copy.
  String get tradeNoun => switch (this) {
        ServiceCategory.trashCollection => 'trash collector',
        ServiceCategory.landscaping => 'landscaper',
        ServiceCategory.junkRemoval => 'junk remover',
        ServiceCategory.movingHauling => 'mover',
        ServiceCategory.handyman => 'handyman',
        ServiceCategory.electrical => 'electrician',
        ServiceCategory.plumbing => 'plumber',
      };

  String? get licenceName => switch (this) {
        ServiceCategory.electrical => 'EPRA licence',
        ServiceCategory.plumbing => 'NCA registration',
        _ => null,
      };
}

String ksh(num amount) => CanopyFees.ksh(amount.round());

/// Bare category icon; regulated categories carry a small success check.
class CategoryGlyph extends StatelessWidget {
  final ServiceCategory category;
  final double size;
  final Color? color;
  const CategoryGlyph(this.category, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(category.icon, size: size, color: color ?? p.ink),
          if (category.requiresLicenseVerification)
            Positioned(
              right: -2,
              top: -2,
              child: Icon(Icons.verified, size: size * 0.45, color: p.success),
            ),
        ],
      ),
    );
  }
}

/// "LICENCE VERIFIED" — only when the listing's licence is verified.
class VerifiedLabel extends StatelessWidget {
  const VerifiedLabel({super.key});

  @override
  Widget build(BuildContext context) => StatusLabel('Licence verified',
      color: context.canopy.success, icon: Icons.verified_outlined);
}

/// "· NEW PROVIDER" — no completed bookings yet. No ratings in v1.
class NewProviderLabel extends StatelessWidget {
  const NewProviderLabel({super.key});

  @override
  Widget build(BuildContext context) =>
      StatusLabel('New provider', color: context.canopy.inkMuted);
}

List<Widget> listingTrustLabels(ServiceListing l) => [
      if (l.requiresLicenseVerification &&
          l.licenseVerificationStatus == LicenseVerificationStatus.verified)
        const VerifiedLabel(),
      if (l.bookingCount == 0) const NewProviderLabel(),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// PRICE
// ─────────────────────────────────────────────────────────────────────────────

/// "From KSh 800 /month" · "KSh 500 – 1,500 /visit" · "Quote on request".
class PriceDisplay extends StatelessWidget {
  final ServicePricing pricing;
  final double fontSize;
  const PriceDisplay(this.pricing, {super.key, this.fontSize = 15});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final money = CanopyType.money.copyWith(fontSize: fontSize, color: p.ink);
    final muted = CanopyType.body.copyWith(fontSize: fontSize - 2, color: p.inkMuted);
    if (pricing.isQuoteOnly) {
      return Text.rich(TextSpan(children: [
        TextSpan(text: 'Quote on request', style: money),
        TextSpan(text: ' · free to ask', style: muted),
      ]));
    }
    final range = pricing.toKes != null && pricing.toKes! > pricing.fromKes!;
    return Text.rich(TextSpan(children: [
      if (!range) TextSpan(text: 'From ', style: muted),
      TextSpan(
          text: range
              ? '${ksh(pricing.fromKes!)} – ${CanopyFees.ksh(pricing.toKes!.round()).substring(4)}'
              : ksh(pricing.fromKes!),
          style: money),
      if (pricing.rateType.suffix.isNotEmpty)
        TextSpan(text: ' ${pricing.rateType.suffix}', style: muted),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS
// ─────────────────────────────────────────────────────────────────────────────

Color bookingStatusColor(ServiceBookingStatus s, CanopyPalette p) => switch (s) {
      ServiceBookingStatus.requested => p.inkMuted,
      ServiceBookingStatus.quoted => p.info,
      ServiceBookingStatus.accepted => p.primaryInk,
      ServiceBookingStatus.scheduled => p.info,
      ServiceBookingStatus.completed => p.success,
      ServiceBookingStatus.declined => p.inkMuted,
      ServiceBookingStatus.cancelled => p.danger,
    };

/// Whose move it is on this booking, from the viewer's side.
bool isYourTurn(ServiceBooking b, {required bool asProvider}) {
  if (asProvider) {
    return b.status == ServiceBookingStatus.requested ||
        b.status == ServiceBookingStatus.accepted ||
        b.status == ServiceBookingStatus.scheduled;
  }
  return b.status == ServiceBookingStatus.quoted;
}

/// Who a waiting state is waiting on, as a sentence.
String? waitingOn(ServiceBooking b, {required bool asProvider}) {
  if (isYourTurn(b, asProvider: asProvider)) return null;
  final other = asProvider
      ? (b.requesterName.isEmpty ? 'the customer' : b.requesterName)
      : (b.providerName.isEmpty ? 'the provider' : b.providerName);
  return switch (b.status) {
    ServiceBookingStatus.requested => 'Waiting for $other to send a quote',
    ServiceBookingStatus.quoted => 'Waiting for $other to accept your quote',
    ServiceBookingStatus.accepted => 'Waiting for $other to schedule the job',
    ServiceBookingStatus.scheduled => 'Waiting for $other to mark the job done',
    _ => null,
  };
}

/// Booking · payment · payout labels with hairlines, + Your turn.
class BookingLabels extends StatelessWidget {
  final ServiceBooking booking;
  final bool asProvider;
  const BookingLabels({super.key, required this.booking, required this.asProvider});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final b = booking;
    return LabelRow(children: [
      if (isYourTurn(b, asProvider: asProvider)) const YourTurnLabel(),
      StatusLabel(b.status.label, color: bookingStatusColor(b.status, p)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE
// ─────────────────────────────────────────────────────────────────────────────

class BookingTimeline extends StatelessWidget {
  final ServiceBooking booking;
  const BookingTimeline({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final s = b.status;
    if (s == ServiceBookingStatus.declined || s == ServiceBookingStatus.cancelled) {
      return CanopyTimeline(steps: [
        const TimelineStep('Requested', state: TimelineState.done),
        TimelineStep(s == ServiceBookingStatus.declined ? 'Declined' : 'Cancelled',
            line: b.cancellationReason, state: TimelineState.failed),
      ]);
    }
    const order = [
      ServiceBookingStatus.requested,
      ServiceBookingStatus.quoted,
      ServiceBookingStatus.accepted,
      ServiceBookingStatus.scheduled,
      ServiceBookingStatus.completed,
    ];
    final idx = order.indexOf(s);
    TimelineState at(int i) => i < idx
        ? TimelineState.done
        : i == idx
            ? (s == ServiceBookingStatus.completed ? TimelineState.done : TimelineState.now)
            : TimelineState.todo;
    return CanopyTimeline(steps: [
      TimelineStep('Requested', state: at(0)),
      TimelineStep('Quoted',
          line: b.quotedPriceKes == null ? null : ksh(b.quotedPriceKes!), state: at(1)),
      TimelineStep('Accepted', line: 'Price and payment agreed directly', state: at(2)),
      TimelineStep('Scheduled',
          line: b.preferredDate == null ? null : _date(b.preferredDate!),
          state: s == ServiceBookingStatus.completed || s == ServiceBookingStatus.scheduled
              ? TimelineState.done
              : TimelineState.todo),
      TimelineStep('Completed', state: at(4) == TimelineState.done ? TimelineState.done : TimelineState.todo),
    ]);
  }
}

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String serviceDate(DateTime d) => _date(d);

// ─────────────────────────────────────────────────────────────────────────────
// FEE BREAKDOWN
// ─────────────────────────────────────────────────────────────────────────────

enum FeeSide { requester, provider }

/// Rows 14/20, values tabular; total row with 1px top rule. Always from the
/// viewer's side.
class FeeBreakdown extends StatelessWidget {
  final ServiceFeeBreakdown fees;
  final bool recurring;
  final FeeSide side;
  final String? title;
  const FeeBreakdown(
      {super.key, required this.fees, required this.recurring, required this.side, this.title});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    Widget row(String label, String value, {Color? color, bool total = false}) => Padding(
          padding: EdgeInsets.only(top: total ? CanopySpace.s12 : CanopySpace.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(label,
                    style: (total ? CanopyType.bodyStrong : CanopyType.body)
                        .copyWith(color: p.ink, fontSize: total ? 15 : 14)),
              ),
              Text(value,
                  style: total
                      ? CanopyType.money.copyWith(fontSize: 18, color: p.ink)
                      : CanopyType.bodyStrong.copyWith(
                          color: color ?? p.ink,
                          fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        );
    final children = [row('Agreed price', ksh(fees.agreedPriceKes), total: true)];
    return CanopyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!.toUpperCase(), style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
          ...children,
          const SizedBox(height: CanopySpace.s8),
          Text('You settle payment directly with ${side == FeeSide.provider ? 'the customer' : 'the provider'}. Canopy doesn\'t handle money.',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING CARD
// ─────────────────────────────────────────────────────────────────────────────

class ListingCard extends StatelessWidget {
  final ServiceListing listing;
  final VoidCallback onTap;
  final List<Widget>? extraLabels;
  const ListingCard(
      {super.key, required this.listing, required this.onTap, this.extraLabels});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final l = listing;
    final labels = [...?extraLabels, ...listingTrustLabels(l)];
    final area = [
      if (l.location.label.isNotEmpty) l.location.label,
      if (l.serviceRadiusKm > 0) 'serves ${l.serviceRadiusKm.round()} km',
    ].join(' · ');
    return CanopyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(CanopySpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.sm),
            child: SizedBox(
              width: 92,
              height: 92,
              child: l.coverImage == null
                  ? Stack(fit: StackFit.expand, children: [
                      const CanopyImageFallback(icon: Icons.handyman_outlined),
                      Center(child: CategoryGlyph(l.category, size: 32, color: p.primarySoft)),
                    ])
                  : CanopyImage(url: l.coverImage),
            ),
          ),
          const SizedBox(width: CanopySpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (labels.isNotEmpty) ...[
                  LabelRow(children: labels),
                  const SizedBox(height: CanopySpace.s2),
                ],
                Text(l.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                Text(l.orgName?.isNotEmpty == true ? l.orgName! : l.provider.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CanopyType.caption.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s4),
                PriceDisplay(l.pricing, fontSize: 14),
                if (area.isNotEmpty)
                  Text(area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGULATORY CALLOUT
// ─────────────────────────────────────────────────────────────────────────────

/// Handyman: "doesn't include regulated work" · regulated & unverified:
/// "won't appear in Browse until verified" · rejected + reason.
Widget? regulatoryCallout(ServiceCategory c,
    {LicenseVerificationStatus? status, String? rejectionReason}) {
  if (status == LicenseVerificationStatus.rejected) {
    return CanopyCallout(
      kind: CalloutKind.danger,
      title: 'Licence not accepted',
      text: rejectionReason?.isNotEmpty == true
          ? rejectionReason!
          : 'Canopy couldn\'t verify the document. Upload a clearer photo of your ${c.licenceName ?? 'licence'}.',
    );
  }
  if (c.requiresLicenseVerification && status != LicenseVerificationStatus.verified) {
    return CanopyCallout(
      kind: CalloutKind.warning,
      text:
          "${c.name2} listings need a verified ${c.licenceName}. This listing won't appear in Browse until Canopy has checked it.",
    );
  }
  if (c == ServiceCategory.handyman) {
    return const CanopyCallout(
      kind: CalloutKind.info,
      text:
          "Handyman listings don't include regulated work — wiring, gas and structural jobs need a licensed provider.",
    );
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// QUOTE COMPOSER
// ─────────────────────────────────────────────────────────────────────────────

/// Provider's quote sheet. Returns true when a quote was sent, 'decline' when
/// the provider chose to decline instead.
Future<Object?> showQuoteComposer(BuildContext context, ServiceBooking booking) =>
    showCanopySheet<Object>(context, builder: (_) => _QuoteComposer(booking: booking));

class _QuoteComposer extends StatefulWidget {
  final ServiceBooking booking;
  const _QuoteComposer({required this.booking});

  @override
  State<_QuoteComposer> createState() => _QuoteComposerState();
}

class _QuoteComposerState extends State<_QuoteComposer> {
  final _price = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;
  bool _showError = false;
  bool _failed = false;

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_price.text.trim());

  Future<void> _send() async {
    setState(() => _showError = true);
    final a = _amount;
    if (a == null || a <= 0) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await ServiceMarketplaceService.instance.submitQuote(widget.booking.id,
          quotedPriceKes: a.toDouble(),
          quoteNote: _note.text.trim().isEmpty ? null : _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final a = _amount;
    final receive = a == null ? null : ServiceFeeBreakdown.compute(
        agreedPriceKes: a.toDouble(), isRecurring: widget.booking.isRecurring);
    return CanopySheetBody(
      title: 'Send a quote',
      caption: '${widget.booking.requesterName.isEmpty ? 'Customer' : widget.booking.requesterName} · ${widget.booking.listingTitle}',
      children: [
        CanopyTextField.money(
          label: 'Your price for this job',
          controller: _price,
          autofocus: true,
          helper: receive == null
              ? "You'll see what you receive after Canopy's 8% commission."
              : "You'll receive ${ksh(receive.providerPayoutKes)} after Canopy's 8% commission.",
          error: _showError && (a == null || a <= 0) ? 'Enter a price in shillings.' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(
          label: 'Note (optional)',
          hint: 'What the price covers',
          controller: _note,
          minLines: 2,
          maxLines: 4,
          maxLength: 300,
        ),
        if (_failed) ...[
          const SizedBox(height: CanopySpace.s8),
          const CanopyCallout(
              kind: CalloutKind.danger, text: "Your quote didn't send. Try again."),
        ],
        const SizedBox(height: CanopySpace.s4),
        Text('Nothing is charged until the customer accepts and pays.',
            style: CanopyType.caption.copyWith(color: p.inkMuted)),
      ],
      actions: [
        CanopyButton(label: 'Send quote', expand: true, loading: _sending, onPressed: _send),
        CanopyButton.quietDanger(
            label: 'Decline this job',
            expand: true,
            onPressed: () => Navigator.pop(context, 'decline')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACT SHEET — payment and logistics are arranged directly
// ─────────────────────────────────────────────────────────────────────────────

/// The other person's number, with Call and WhatsApp. [asProvider] is the
/// viewer's side, so the sheet shows the other party.
Future<void> showContactSheet(BuildContext context, String bookingId, {required bool asProvider}) =>
    showCanopySheet<void>(
      context,
      builder: (_) => _ContactSheet(bookingId: bookingId, asProvider: asProvider),
    );

class _ContactSheet extends StatelessWidget {
  final String bookingId;
  final bool asProvider;
  const _ContactSheet({required this.bookingId, required this.asProvider});

  Future<String?> _phone(ServiceBooking b) async {
    if (asProvider) return b.requesterPhone;
    try {
      final d = (await FirebaseFirestore.instance.collection('service_listings').doc(b.listingId).get()).data();
      return d?['contactPhone'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<ServiceBooking?>(
      stream: ServiceMarketplaceService.instance.watchBookingById(bookingId),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return const Padding(padding: EdgeInsets.all(CanopySpace.s32), child: Center(child: CircularProgressIndicator()));
        }
        final other = asProvider ? (b.requesterName.isEmpty ? 'the customer' : b.requesterName) : (b.providerName.isEmpty ? 'the provider' : b.providerName);
        return FutureBuilder<String?>(
          future: _phone(b),
          builder: (context, ph) {
            final raw = ph.data ?? '';
            var d = raw.replaceAll(RegExp(r'\D'), '');
            if (d.startsWith('0')) d = '254${d.substring(1)}';
            if (d.length == 9) d = '254$d';
            final has = d.length >= 12;
            return CanopySheetBody(
              title: 'Contact $other',
              caption: 'Agree the date, the price and how you will pay directly. Canopy doesn\'t handle money.',
              children: [
                if (ph.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (!has)
                  CanopyCallout(text: '$other hasn\'t shared a phone number yet. You can still agree details by message from your bookings.')
                else
                  CanopyListGroup(children: [
                    CanopyListRow(icon: Icons.call_outlined, title: 'Call', subtitle: '+$d', onTap: () => launchUrl(Uri.parse('tel:+$d'))),
                    CanopyListRow(
                      icon: Icons.chat_outlined,
                      title: 'WhatsApp',
                      subtitle: 'Message about "${b.listingTitle}"',
                      onTap: () => launchUrl(
                          Uri.parse('https://wa.me/$d?text=${Uri.encodeComponent('Hi, about my Canopy booking "${b.listingTitle}".')}'),
                          mode: LaunchMode.externalApplication),
                    ),
                  ]),
                const SizedBox(height: CanopySpace.s8),
                Text('Your number is only shared with people you book.', style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ],
              actions: [CanopyButton(label: 'Done', expand: true, onPressed: () => Navigator.pop(context))],
            );
          },
        );
      },
    );
  }
}
