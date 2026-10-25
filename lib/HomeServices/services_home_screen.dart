// lib/HomeServices/services_home_screen.dart
//
// Services home (SERVICES_HANDOFF §3.1).
//   First visit: "Book trusted local help" → three promises (free quotes ·
//     M-Pesa · licence-checked trades) → 2-col category grid → dashed
//     "Offer a service" tile.
//   Returning (has any booking either side): "Your bookings" first — anything
//     needing you on top with Your turn — → compact 4-col category row →
//     "Got a skill neighbours need?" card.
// App bar: My bookings · My listings. No emoji; bare category glyphs.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_booking.dart';
import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import 'browse_service_listings_screen.dart';
import 'create_service_listing_screen.dart';
import 'my_service_bookings_screen.dart';
import 'my_service_listings_screen.dart';
import 'service_booking_detail_screen.dart';
import 'services_ui.dart';

class ServicesHomeScreen extends StatefulWidget {
  const ServicesHomeScreen({super.key});

  @override
  State<ServicesHomeScreen> createState() => _ServicesHomeScreenState();
}

class _ServicesHomeScreenState extends State<ServicesHomeScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  Stream<List<(ServiceBooking, bool)>>? _bookings;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    final svc = ServiceMarketplaceService.instance;
    _bookings = _combine(
      svc.watchMyRequests(uid).map((l) => [for (final b in l) (b, false)]),
      svc.watchIncomingJobs(uid).map((l) => [for (final b in l) (b, true)]),
    );
  }

  /// Emits requests + incoming jobs together once both have loaded.
  static Stream<List<(ServiceBooking, bool)>> _combine(
      Stream<List<(ServiceBooking, bool)>> a, Stream<List<(ServiceBooking, bool)>> b) {
    late StreamController<List<(ServiceBooking, bool)>> c;
    List<(ServiceBooking, bool)>? la, lb;
    StreamSubscription? sa, sb;
    void emit() {
      if (la != null && lb != null) c.add([...la!, ...lb!]);
    }
    c = StreamController(
      onListen: () {
        sa = a.listen((v) {
          la = v;
          emit();
        }, onError: c.addError);
        sb = b.listen((v) {
          lb = v;
          emit();
        }, onError: c.addError);
      },
      onCancel: () {
        sa?.cancel();
        sb?.cancel();
      },
    );
    return c.stream;
  }

  void _browse(ServiceCategory c) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => BrowseServiceListingsScreen(category: c)));

  void _offer() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const CreateServiceListingScreen()));

  @override
  Widget build(BuildContext context) {
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Services', actions: [
        CanopyIconButton(
          icon: Icons.event_note_outlined,
          tooltip: 'My bookings',
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MyServiceBookingsScreen())),
        ),
        CanopyIconButton(
          icon: Icons.storefront_outlined,
          tooltip: 'My listings',
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MyServiceListingsScreen())),
        ),
      ]),
      body: _bookings == null
          ? _FirstVisit(onCategory: _browse, onOffer: _offer)
          : StreamBuilder<List<(ServiceBooking, bool)>>(
              stream: _bookings,
              builder: (context, snap) {
                if (!snap.hasData && !snap.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(CanopySpace.gutter),
                    children: const [
                      CanopySkeleton(height: 34, width: 240),
                      SizedBox(height: CanopySpace.s16),
                      CanopyListSkeleton(rows: 2),
                    ],
                  );
                }
                final all = snap.data ?? const [];
                if (all.isEmpty) return _FirstVisit(onCategory: _browse, onOffer: _offer);
                return _Returning(bookings: all, onCategory: _browse, onOffer: _offer);
              },
            ),
    );
  }
}

class _FirstVisit extends StatelessWidget {
  final ValueChanged<ServiceCategory> onCategory;
  final VoidCallback onOffer;
  const _FirstVisit({required this.onCategory, required this.onOffer});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    Widget promise(IconData i, String t, String c) => Padding(
          padding: const EdgeInsets.only(bottom: CanopySpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, size: CanopyIconSize.nav, color: p.ink),
              const SizedBox(width: CanopySpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                    Text(c, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
      children: [
        Text('Book trusted local help', style: CanopyType.display.copyWith(color: p.ink)),
        const SizedBox(height: CanopySpace.s16),
        promise(Icons.request_quote_outlined, 'Free quotes',
            'Providers set their own price. You only commit when you accept a quote.'),
        promise(Icons.phone_iphone_outlined, 'Deal directly',
            'Once you accept a quote you get the provider\'s number. Agree payment between yourselves.'),
        promise(Icons.verified_outlined, 'Licence-checked trades',
            'Electricians and plumbers only appear once Canopy has checked their licence.'),
        const SizedBox(height: CanopySpace.s12),
        const CanopySectionHeader(title: 'What do you need?', padding: EdgeInsets.zero),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: CanopySpace.s12,
          crossAxisSpacing: CanopySpace.s12,
          childAspectRatio: 1.25,
          children: [
            for (final c in ServiceCategory.values)
              CanopyCard(
                onTap: () => onCategory(c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryGlyph(c, size: 28),
                    const Spacer(),
                    Text(c.name2, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                    Text(c.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  ],
                ),
              ),
            DashedBorder(
              color: p.outlineStrong,
              radius: CanopyRadius.md,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onOffer,
                  borderRadius: BorderRadius.circular(CanopyRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.all(CanopySpace.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.add, size: 28, color: p.ink),
                        const Spacer(),
                        Text('Offer a service',
                            style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                        Text('List what you do and get booked by neighbours',
                            maxLines: 2,
                            style: CanopyType.caption.copyWith(color: p.inkMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Returning extends StatelessWidget {
  final List<(ServiceBooking, bool)> bookings;
  final ValueChanged<ServiceCategory> onCategory;
  final VoidCallback onOffer;
  const _Returning({required this.bookings, required this.onCategory, required this.onOffer});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final open = bookings.where((e) => e.$1.status.isOpen).toList()
      ..sort((a, b) {
        final ta = isYourTurn(a.$1, asProvider: a.$2) ? 0 : 1;
        final tb = isYourTurn(b.$1, asProvider: b.$2) ? 0 : 1;
        if (ta != tb) return ta.compareTo(tb);
        return b.$1.createdAt.compareTo(a.$1.createdAt);
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
      children: [
        CanopySectionHeader(
          title: 'Your bookings',
          padding: EdgeInsets.zero,
          onAction: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MyServiceBookingsScreen())),
        ),
        if (open.isEmpty)
          const CanopyEmptyState(
            boxed: true,
            icon: Icons.task_alt_outlined,
            title: 'Nothing open right now',
            line: 'Finished bookings are in My bookings.',
          )
        else
          for (final e in open.take(4)) ...[
            BookingRow(booking: e.$1, asProvider: e.$2),
            const SizedBox(height: CanopySpace.s8),
          ],
        const SizedBox(height: CanopySpace.section),
        const CanopySectionHeader(title: 'Book help', padding: EdgeInsets.zero),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: CanopySpace.s8,
          crossAxisSpacing: CanopySpace.s8,
          childAspectRatio: 0.9,
          children: [
            for (final c in ServiceCategory.values)
              InkWell(
                onTap: () => onCategory(c),
                borderRadius: BorderRadius.circular(CanopyRadius.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CategoryGlyph(c, size: 26),
                    const SizedBox(height: CanopySpace.s4),
                    Text(c.name2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: CanopyType.micro.copyWith(color: p.ink, letterSpacing: 0)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: CanopySpace.section),
        CanopyCard(
          onTap: onOffer,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Got a skill neighbours need?',
                        style: CanopyType.subhead.copyWith(color: p.ink)),
                    Text('List a service and agree the price directly with customers.',
                        style: CanopyType.caption.copyWith(color: p.inkMuted)),
                  ],
                ),
              ),
              Text('Offer a service', style: CanopyType.label.copyWith(color: p.primaryInk)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Booking row: glyph, title, money, party + date, labels + Your turn. A row
/// that needs the viewer gets a 1.5px primary border.
class BookingRow extends StatelessWidget {
  final ServiceBooking booking;
  final bool asProvider;
  const BookingRow({super.key, required this.booking, required this.asProvider});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final b = booking;
    final yours = isYourTurn(b, asProvider: asProvider);
    final amount = b.agreedPriceKes ?? b.quotedPriceKes;
    final party = asProvider ? b.requesterName : b.providerName;
    return CanopyCard(
      borderColor: yours ? p.primary : null,
      borderWidth: yours ? 1.5 : 1,
      padding: const EdgeInsets.all(CanopySpace.s12),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ServiceBookingDetailScreen(bookingId: b.id))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryGlyph(b.category, size: 24),
          const SizedBox(width: CanopySpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookingLabels(booking: b, asProvider: asProvider),
                const SizedBox(height: CanopySpace.s2),
                Text(b.listingTitle.isEmpty ? b.category.name2 : b.listingTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                Text(
                  [
                    if (party.isNotEmpty) party,
                    serviceDate(b.preferredDate ?? b.createdAt),
                  ].join(' · '),
                  style: CanopyType.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
          if (amount != null)
            Text(ksh(amount), style: CanopyType.money.copyWith(fontSize: 15, color: p.ink)),
        ],
      ),
    );
  }
}
