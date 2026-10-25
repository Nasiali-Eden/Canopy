// lib/HomeServices/service_booking_detail_screen.dart
//
// Booking detail — the matrix (SERVICES_HANDOFF §3.6). Both sides land here;
// the viewer's side is decided by comparing the signed-in uid to
// requesterUid / providerUid. Exactly one next action per status per side:
//
//   Status             Requester                         Provider
//   Requested          — (quiet cancel)                  Send quote / decline
//   Quoted             Accept and pay KSh X / cancel     — waiting
//   Accepted, unpaid   Pay with M-Pesa                   — waiting
//   Awaiting M-Pesa    — waiting sheet                   — waiting
//   Payment failed     Try again                         — waiting
//   Paid               — waiting                         Schedule
//   Scheduled          — waiting                         Mark completed
//   Completed          — receipt                         — payout status
//   Declined/Cancelled — reason (+ Find another provider) — reason
//
// Layout: head (labels + Your turn, title sentence, quote note) → fee
// breakdown (viewer side) → timeline → details → sticky action. Paid is set
// only by the M-Pesa callback (watchBookingById re-renders when it lands).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_booking.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import 'browse_service_listings_screen.dart';
import 'services_ui.dart';

class ServiceBookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const ServiceBookingDetailScreen({required this.bookingId, super.key});

  @override
  State<ServiceBookingDetailScreen> createState() => _ServiceBookingDetailScreenState();
}

class _ServiceBookingDetailScreenState extends State<ServiceBookingDetailScreen> {
  final _svc = ServiceMarketplaceService.instance;
  late Stream<ServiceBooking?> _stream = _svc.watchBookingById(widget.bookingId);
  bool _busy = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) showCanopySnack(context, done);
    } catch (_) {
      if (mounted) showCanopySnack(context, "That didn't go through. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendQuote(ServiceBooking b) async {
    final r = await showQuoteComposer(context, b);
    if (!mounted) return;
    if (r == true) showCanopySnack(context, 'Quote sent.');
    if (r == 'decline') await _decline(b);
  }

  Future<String?> _reason(String title, String confirm, {required bool danger}) async {
    final ctrl = TextEditingController();
    final ok = await showCanopySheet<bool>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: title,
        children: [
          CanopyTextField(
            label: 'Reason (optional)',
            hint: 'Shared with the other side',
            controller: ctrl,
            minLines: 2,
            maxLines: 4,
          ),
        ],
        actions: [
          danger
              ? CanopyButton.danger(label: confirm, expand: true, onPressed: () => Navigator.pop(ctx, true))
              : CanopyButton(label: confirm, expand: true, onPressed: () => Navigator.pop(ctx, true)),
          CanopyButton.quiet(label: 'Keep it', expand: true, onPressed: () => Navigator.pop(ctx, false)),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    return ok == true ? text : null;
  }

  Future<void> _decline(ServiceBooking b) async {
    final r = await _reason('Decline this job?', 'Decline job', danger: true);
    if (r == null) return;
    await _run(() => _svc.decline(b.id, reason: r.isEmpty ? null : r), done: 'Job declined.');
  }

  Future<void> _cancel(ServiceBooking b) async {
    final r = await _reason('Cancel this request?', 'Cancel request', danger: true);
    if (r == null) return;
    await _run(() => _svc.cancel(b.id, reason: r.isEmpty ? null : r), done: 'Request cancelled.');
  }

  Future<void> _acceptAndPay(ServiceBooking b) async {
    await _run(() => _svc.acceptQuote(b.id));
    if (mounted) await showContactSheet(context, b.id, asProvider: false);
  }

  Future<void> _schedule(ServiceBooking b) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: b.preferredDate != null && b.preferredDate!.isAfter(now) ? b.preferredDate! : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Confirm the job date',
    );
    if (date == null) return;
    await _run(() => _svc.markScheduled(b.id, confirmedDate: date),
        done: 'Scheduled for ${serviceDate(date)}.');
  }

  Future<void> _complete(ServiceBooking b) async {
    final ok = await showCanopyConfirm(
      context,
      title: 'Mark this job completed?',
      message: 'The customer is told the job is done, and your payout starts.',
      confirmLabel: 'Mark completed',
    );
    if (ok) await _run(() => _svc.markCompleted(b.id), done: 'Marked completed.');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ServiceBooking?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyScaffold(
            appBar: canopyAppBar(context, title: 'Booking'),
            body: CanopyErrorState(
                title: "Couldn't load this booking",
                onRetry: () => setState(() => _stream = _svc.watchBookingById(widget.bookingId))),
          );
        }
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return CanopyScaffold(
            appBar: canopyAppBar(context, title: 'Booking'),
            body: ListView(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              children: const [
                CanopySkeleton(height: 80),
                SizedBox(height: CanopySpace.s16),
                CanopySkeleton(height: 160, radius: CanopyRadius.md),
                SizedBox(height: CanopySpace.s16),
                CanopyListSkeleton(rows: 3),
              ],
            ),
          );
        }
        final b = snap.data;
        if (b == null) {
          return CanopyScaffold(
            appBar: canopyAppBar(context, title: 'Booking'),
            body: const CanopyEmptyState(
                icon: Icons.receipt_long_outlined, title: 'This booking no longer exists'),
          );
        }
        final asProvider = b.providerUid == _uid;
        return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Booking'),
          body: _body(b, asProvider),
          sticky: _action(b, asProvider),
        );
      },
    );
  }

  Widget _body(ServiceBooking b, bool asProvider) {
    final p = context.canopy;
    final other = asProvider
        ? (b.requesterName.isEmpty ? 'a customer' : b.requesterName)
        : (b.providerName.isEmpty ? 'your provider' : b.providerName);
    final title = asProvider
        ? '${b.category.name2} for $other'
        : '${b.category.name2} with $other';
    final wait = waitingOn(b, asProvider: asProvider);
    final hasPrice = b.agreedPriceKes != null || b.quotedPriceKes != null;
    final fees = b.agreedPriceKes != null
        ? b.feeBreakdown
        : ServiceFeeBreakdown.compute(
            agreedPriceKes: b.quotedPriceKes ?? 0, isRecurring: b.isRecurring);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
      children: [
        BookingLabels(booking: b, asProvider: asProvider),
        const SizedBox(height: CanopySpace.s8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryGlyph(b.category, size: 28),
            const SizedBox(width: CanopySpace.s12),
            Expanded(child: Text(title, style: CanopyType.display.copyWith(color: p.ink))),
          ],
        ),
        if (b.listingTitle.isNotEmpty)
          Text(b.listingTitle, style: CanopyType.body.copyWith(color: p.inkMuted)),
        if (wait != null) ...[
          const SizedBox(height: CanopySpace.s8),
          Text(wait, style: CanopyType.bodyStrong.copyWith(color: p.inkMuted)),
        ],
        if (b.quoteNote?.isNotEmpty ?? false) ...[
          const SizedBox(height: CanopySpace.s12),
          Container(
            padding: const EdgeInsets.only(left: CanopySpace.s12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: p.ink, width: 2))),
            child: Text('"${b.quoteNote!}"', style: CanopyType.body.copyWith(color: p.ink)),
          ),
        ],
        if (hasPrice) ...[
          const SizedBox(height: CanopySpace.section),
          FeeBreakdown(
            fees: fees,
            recurring: b.isRecurring,
            side: asProvider ? FeeSide.provider : FeeSide.requester,
            title: b.agreedPriceKes != null ? 'Agreed price' : 'Quote',
          ),
        ],
        const SizedBox(height: CanopySpace.section),
        const CanopySectionHeader(title: 'Progress', padding: EdgeInsets.zero),
        CanopyCard(child: BookingTimeline(booking: b)),
        const SizedBox(height: CanopySpace.section),
        const CanopySectionHeader(title: 'Details', padding: EdgeInsets.zero),
        CanopyListGroup(children: [
          if (b.requestMessage.isNotEmpty)
            CanopyListRow(icon: Icons.notes_outlined, title: b.requestMessage, subtitle: 'The job'),
          if (b.addressNote?.isNotEmpty ?? false)
            CanopyListRow(icon: Icons.place_outlined, title: b.addressNote!, subtitle: 'Where'),
          if (b.serviceLocation.label.isNotEmpty)
            CanopyListRow(icon: Icons.map_outlined, title: b.serviceLocation.label, subtitle: 'Area'),
          if (b.preferredDate != null)
            CanopyListRow(
                icon: Icons.calendar_today_outlined,
                title: serviceDate(b.preferredDate!),
                subtitle: b.status == ServiceBookingStatus.scheduled ||
                        b.status == ServiceBookingStatus.completed
                    ? 'Confirmed date'
                    : 'Preferred date'),
          if (asProvider && (b.requesterPhone?.isNotEmpty ?? false))
            CanopyListRow(icon: Icons.phone_outlined, title: b.requesterPhone!, subtitle: 'Customer phone'),
          if (b.isRecurring)
            const CanopyListRow(
                icon: Icons.repeat, title: 'Standing service', subtitle: 'Booking fee waived'),
          CanopyListRow(
              icon: Icons.schedule_outlined,
              title: serviceDate(b.createdAt),
              subtitle: 'Requested on'),
        ]),
      ],
    );
  }

  Widget? _action(ServiceBooking b, bool asProvider) {
    final p = context.canopy;
    final s = b.status;
    Widget line(String t) => Text(t,
        textAlign: TextAlign.center, style: CanopyType.body.copyWith(color: p.inkMuted));

    if (s == ServiceBookingStatus.declined || s == ServiceBookingStatus.cancelled) {
      final reason = b.cancellationReason?.isNotEmpty == true ? ' · ${b.cancellationReason}' : '';
      return StickyActionBar(children: [
        line('${s == ServiceBookingStatus.declined ? 'Declined' : 'Cancelled'}$reason'),
        if (!asProvider)
          CanopyButton.secondary(
            label: 'Find another provider',
            expand: true,
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => BrowseServiceListingsScreen(category: b.category)),
            ),
          ),
      ]);
    }

    if (asProvider) {
      if (s == ServiceBookingStatus.requested) {
        return StickyActionBar(children: [
          CanopyButton(label: 'Send quote', expand: true, loading: _busy, onPressed: () => _sendQuote(b)),
          CanopyButton.quietDanger(label: 'Decline', expand: true, onPressed: () => _decline(b)),
        ]);
      }
      if (s == ServiceBookingStatus.accepted) {
        return StickyActionBar(children: [
          CanopyButton(label: 'Schedule', expand: true, loading: _busy, onPressed: () => _schedule(b)),
          CanopyButton.secondary(label: 'Contact customer', expand: true, onPressed: () => showContactSheet(context, b.id, asProvider: true)),
        ]);
      }
      if (s == ServiceBookingStatus.scheduled) {
        return StickyActionBar(children: [
          CanopyButton(label: 'Mark completed', expand: true, loading: _busy, onPressed: () => _complete(b)),
          CanopyButton.secondary(label: 'Contact customer', expand: true, onPressed: () => showContactSheet(context, b.id, asProvider: true)),
        ]);
      }
      return null; // waiting / completed — the head says who we're waiting on
    }

    // Requester
    switch (s) {
      case ServiceBookingStatus.requested:
        return StickyActionBar(children: [
          line('Nothing is charged until you accept a quote.'),
          CanopyButton.quietDanger(label: 'Cancel request', expand: true, onPressed: () => _cancel(b)),
        ]);
      case ServiceBookingStatus.quoted:
        final total = ServiceFeeBreakdown.compute(
                agreedPriceKes: b.quotedPriceKes ?? 0, isRecurring: b.isRecurring)
            .requesterTotalKes;
        return StickyActionBar(children: [
          CanopyButton(
              label: 'Accept quote · ${ksh(total)}',
              expand: true,
              loading: _busy,
              onPressed: () => _acceptAndPay(b)),
          CanopyButton.quietDanger(label: 'Cancel request', expand: true, onPressed: () => _cancel(b)),
        ]);
      case ServiceBookingStatus.accepted:
      case ServiceBookingStatus.scheduled:
        return StickyActionBar(children: [
          CanopyButton(label: 'Contact provider', expand: true, onPressed: () => showContactSheet(context, b.id, asProvider: false)),
          if (s == ServiceBookingStatus.accepted)
            CanopyButton.quietDanger(label: 'Cancel request', expand: true, onPressed: () => _cancel(b)),
        ]);
      default:
        return null; // completed
    }
  }
}
