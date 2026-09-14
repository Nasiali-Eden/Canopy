// lib/HomeServices/service_booking_detail_screen.dart
//
// The one screen both sides of a booking land on — requester from "My
// Requests", provider from "Incoming Jobs" (my_service_bookings_screen.dart).
// Which actions render is decided by comparing FirebaseAuth's current uid to
// booking.requesterUid / booking.providerUid, not by two separate screens,
// so the status lifecycle only has to be described once. See
// ServiceBooking's file header for the full requested → quoted → accepted →
// scheduled → completed chain and the fee-split formula.
//
// Payment here is the mocked step called out in the file header: pressing
// "Pay Now" runs ServiceMarketplaceService.simulatedPay, which is the exact
// `await Future.delayed(const Duration(seconds: 2))` pattern
// marketplace_checkout.dart uses for its own M-Pesa STK push mock. No real
// payment integration happens here — see IMPLEMENTATION_NOTES_SERVICES.md.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_booking.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../Shared/theme/app_theme.dart';

class ServiceBookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const ServiceBookingDetailScreen({required this.bookingId, super.key});

  @override
  State<ServiceBookingDetailScreen> createState() =>
      _ServiceBookingDetailScreenState();
}

class _ServiceBookingDetailScreenState
    extends State<ServiceBookingDetailScreen> {
  bool _busy = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _run(Future<void> Function() action, {String? successMessage}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showQuoteSheet(ServiceBooking booking) async {
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send your quote',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
              const SizedBox(height: 4),
              Text('${booking.requesterName} — ${booking.listingTitle}',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.6))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
                  decoration: InputDecoration(
                    prefixText: 'KSh ',
                    hintText: 'Price for this job',
                    hintStyle: TextStyle(fontSize: 14, color: AppTheme.darkGreen.withOpacity(0.3)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: AppTheme.darkGreen),
                  decoration: InputDecoration(
                    hintText: 'Note (optional) — what this covers',
                    hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final price = double.tryParse(priceCtrl.text.trim());
                    if (price == null || price <= 0) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Enter a valid price')),
                      );
                      return;
                    }
                    Navigator.pop(sheetContext, true);
                    _run(
                      () => ServiceMarketplaceService.instance.submitQuote(
                        booking.id,
                        quotedPriceKes: price,
                        quoteNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      ),
                      successMessage: 'Quote sent',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Send Quote', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    priceCtrl.dispose();
    noteCtrl.dispose();
    if (result == true) return;
  }

  Future<void> _confirmCancelOrDecline(ServiceBooking booking, {required bool isDecline}) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isDecline ? 'Decline this request?' : 'Cancel this booking?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(isDecline ? 'Decline' : 'Cancel booking',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
      await _run(
        () => isDecline
            ? ServiceMarketplaceService.instance.decline(booking.id, reason: reason)
            : ServiceMarketplaceService.instance.cancel(booking.id, reason: reason),
      );
    }
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Booking',
            style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<ServiceBooking?>(
        stream: ServiceMarketplaceService.instance.watchBookingById(widget.bookingId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final booking = snap.data;
          if (booking == null) {
            return const Center(child: Text('This booking no longer exists'));
          }
          final isProvider = booking.providerUid == _uid;
          final isRequester = booking.requesterUid == _uid;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _StatusHeader(booking: booking),
              const SizedBox(height: 16),
              _JobCard(booking: booking, isProvider: isProvider),
              const SizedBox(height: 16),
              if (booking.quotedPriceKes != null || booking.agreedPriceKes != null)
                _QuoteCard(booking: booking),
              const SizedBox(height: 20),
              _Actions(
                booking: booking,
                isProvider: isProvider,
                isRequester: isRequester,
                busy: _busy,
                onSendQuote: () => _showQuoteSheet(booking),
                onAcceptQuote: () => _run(
                  () => ServiceMarketplaceService.instance.acceptQuote(booking.id),
                  successMessage: 'Quote accepted',
                ),
                onPay: () => _run(
                  () => ServiceMarketplaceService.instance.simulatedPay(booking.id),
                  successMessage: 'Payment received (simulated)',
                ),
                onMarkScheduled: () => _run(
                  () => ServiceMarketplaceService.instance.markScheduled(booking.id),
                  successMessage: 'Marked as scheduled',
                ),
                onMarkCompleted: () => _run(
                  () => ServiceMarketplaceService.instance.markCompleted(booking.id),
                  successMessage: 'Job marked complete',
                ),
                onDecline: () => _confirmCancelOrDecline(booking, isDecline: true),
                onCancel: () => _confirmCancelOrDecline(booking, isDecline: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final ServiceBooking booking;
  const _StatusHeader({required this.booking});

  Color get _color => switch (booking.status) {
        ServiceBookingStatus.requested => AppTheme.tertiary,
        ServiceBookingStatus.quoted => AppTheme.accent,
        ServiceBookingStatus.accepted => AppTheme.primary,
        ServiceBookingStatus.scheduled => AppTheme.primary,
        ServiceBookingStatus.completed => AppTheme.darkGreen,
        ServiceBookingStatus.declined => Colors.redAccent,
        ServiceBookingStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(booking.status.label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _color)),
          if (booking.isPaid) ...[
            const Spacer(),
            const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primary),
            const SizedBox(width: 4),
            const Text('Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ],
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final ServiceBooking booking;
  final bool isProvider;
  const _JobCard({required this.booking, required this.isProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(booking.listingTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
          const SizedBox(height: 4),
          Text(
            isProvider ? 'Requested by ${booking.requesterName}' : 'Provider: ${booking.providerName}',
            style: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.6)),
          ),
          if (booking.isRecurring) ...[
            const SizedBox(height: 6),
            const _Chip(label: 'Recurring — booking fee waived'),
          ],
          const Divider(height: 24),
          if (booking.requestMessage.isNotEmpty) ...[
            Text(booking.requestMessage,
                style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.8), height: 1.4)),
            const SizedBox(height: 10),
          ],
          if (booking.addressNote != null) _InfoRow(icon: Icons.place_outlined, text: booking.addressNote!),
          if (booking.preferredDate != null)
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text:
                  '${booking.preferredDate!.day}/${booking.preferredDate!.month}/${booking.preferredDate!.year}',
            ),
          if (booking.requesterPhone != null)
            _InfoRow(icon: Icons.phone_outlined, text: booking.requesterPhone!),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.darkGreen.withOpacity(0.45)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.7))),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final ServiceBooking booking;
  const _QuoteCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final agreed = booking.agreedPriceKes != null;
    final breakdown = agreed
        ? booking.feeBreakdown
        : ServiceFeeBreakdown.compute(
            agreedPriceKes: booking.quotedPriceKes ?? 0, isRecurring: booking.isRecurring);

    String fmt(double n) =>
        'KSh ${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(agreed ? 'Agreed price' : 'Quoted price',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
          const SizedBox(height: 4),
          Text(fmt(breakdown.agreedPriceKes),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          if (booking.quoteNote != null) ...[
            const SizedBox(height: 6),
            Text(booking.quoteNote!,
                style: TextStyle(fontSize: 12.5, color: AppTheme.darkGreen.withOpacity(0.65))),
          ],
          const Divider(height: 24),
          _FeeRow(label: 'Booking fee (you pay)', value: fmt(breakdown.requesterBookingFeeKes)),
          _FeeRow(label: 'You pay in total', value: fmt(breakdown.requesterTotalKes), emphasise: true),
          const SizedBox(height: 6),
          _FeeRow(label: 'Platform commission', value: '– ${fmt(breakdown.platformFeeKes)}'),
          _FeeRow(label: 'Provider receives', value: fmt(breakdown.providerPayoutKes), emphasise: true),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  const _FeeRow({required this.label, required this.value, this.emphasise = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.darkGreen.withOpacity(emphasise ? 0.85 : 0.55),
                  fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.darkGreen,
                  fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final ServiceBooking booking;
  final bool isProvider;
  final bool isRequester;
  final bool busy;
  final VoidCallback onSendQuote;
  final VoidCallback onAcceptQuote;
  final VoidCallback onPay;
  final VoidCallback onMarkScheduled;
  final VoidCallback onMarkCompleted;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const _Actions({
    required this.booking,
    required this.isProvider,
    required this.isRequester,
    required this.busy,
    required this.onSendQuote,
    required this.onAcceptQuote,
    required this.onPay,
    required this.onMarkScheduled,
    required this.onMarkCompleted,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    final status = booking.status;

    if (isProvider) {
      if (status == ServiceBookingStatus.requested) {
        buttons.add(_primary('Send Quote', Icons.request_quote_outlined, onSendQuote));
        buttons.add(_secondary('Decline', onDecline));
      } else if (status == ServiceBookingStatus.accepted) {
        buttons.add(_primary('Mark Scheduled', Icons.event_available_outlined, onMarkScheduled));
      } else if (status == ServiceBookingStatus.scheduled) {
        buttons.add(_primary('Mark Completed', Icons.task_alt_rounded, onMarkCompleted));
      }
    }

    if (isRequester) {
      if (status == ServiceBookingStatus.quoted) {
        buttons.add(_primary('Accept Quote', Icons.check_circle_outline_rounded, onAcceptQuote));
      } else if ((status == ServiceBookingStatus.accepted || status == ServiceBookingStatus.scheduled) &&
          !booking.isPaid) {
        buttons.add(_primary('Pay Now (Simulated)', Icons.payment_rounded, onPay));
      }
      if (status.isOpen && status != ServiceBookingStatus.scheduled) {
        buttons.add(_secondary('Cancel Request', onCancel));
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
      ],
    );
  }

  Widget _primary(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _secondary(String label, VoidCallback onTap) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.tertiary.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
    );
  }
}
