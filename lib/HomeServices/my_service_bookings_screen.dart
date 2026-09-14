// lib/HomeServices/my_service_bookings_screen.dart
//
// Two tabs over the same collection, split by which uid field matches the
// signed-in member — "My Requests" (requesterUid) and "Incoming Jobs"
// (providerUid). Both feed into the one ServiceBookingDetailScreen, which is
// where the actual respond-to-quote / accept / pay actions live (see that
// file's header) — this screen is deliberately just the two lists.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_booking.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../Shared/theme/app_theme.dart';
import 'service_booking_detail_screen.dart';

class MyServiceBookingsScreen extends StatefulWidget {
  const MyServiceBookingsScreen({super.key});

  @override
  State<MyServiceBookingsScreen> createState() => _MyServiceBookingsScreenState();
}

class _MyServiceBookingsScreenState extends State<MyServiceBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
        title: const Text('My Bookings',
            style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.45),
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'My Requests'),
            Tab(text: 'Incoming Jobs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _BookingList(stream: ServiceMarketplaceService.instance.watchMyRequests(_uid), asProvider: false),
          _BookingList(stream: ServiceMarketplaceService.instance.watchIncomingJobs(_uid), asProvider: true),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final Stream<List<ServiceBooking>> stream;
  final bool asProvider;

  const _BookingList({required this.stream, required this.asProvider});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceBooking>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookings = snap.data ?? const [];
        if (bookings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note_outlined, size: 36, color: AppTheme.darkGreen.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    asProvider ? 'No incoming jobs yet' : "You haven't requested a service yet",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          itemCount: bookings.length,
          itemBuilder: (context, i) => _BookingCard(
            booking: bookings[i],
            asProvider: asProvider,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ServiceBookingDetailScreen(bookingId: bookings[i].id)),
            ),
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final ServiceBooking booking;
  final bool asProvider;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.asProvider, required this.onTap});

  Color get _statusColor => switch (booking.status) {
        ServiceBookingStatus.requested => AppTheme.tertiary,
        ServiceBookingStatus.quoted => AppTheme.accent,
        ServiceBookingStatus.accepted => AppTheme.primary,
        ServiceBookingStatus.scheduled => AppTheme.primary,
        ServiceBookingStatus.completed => AppTheme.darkGreen,
        ServiceBookingStatus.declined => Colors.redAccent,
        ServiceBookingStatus.cancelled => Colors.grey,
      };

  bool get _needsAttention =>
      (asProvider && booking.needsProviderAction) || (!asProvider && booking.needsRequesterAction);

  @override
  Widget build(BuildContext context) {
    final otherParty = asProvider ? booking.requesterName : booking.providerName;
    final price = booking.agreedPriceKes ?? booking.quotedPriceKes;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _needsAttention ? Border.all(color: AppTheme.tertiary.withOpacity(0.5)) : null,
          boxShadow: [
            BoxShadow(color: AppTheme.primary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(booking.category.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
                  const SizedBox(height: 2),
                  Text(otherParty.isEmpty ? '—' : otherParty,
                      style: TextStyle(fontSize: 12, color: AppTheme.darkGreen.withOpacity(0.55))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(booking.status.label,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _statusColor)),
                      ),
                      if (price != null) ...[
                        const SizedBox(width: 8),
                        Text('KSh ${price.round()}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (_needsAttention)
              const Icon(Icons.fiber_manual_record, size: 10, color: AppTheme.tertiary)
            else
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.darkGreen.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
