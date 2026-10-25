// lib/HomeServices/my_service_bookings_screen.dart
//
// My bookings (SERVICES_HANDOFF §3.5). RoleSwitch "My requests / Incoming
// jobs" (count badges = bookings needing you; hidden for people with no
// listing and no incoming jobs) → groups: requests "Needs you" / "In
// progress" / "Done"; incoming "Needs you" / "Waiting on the customer" /
// "Done". Rows = BookingRow (glyph, title, money, party + date, labels +
// Your turn). Empty per tab.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_booking.dart';
import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import 'create_service_listing_screen.dart';
import 'services_home_screen.dart' show BookingRow, ServicesHomeScreen;
import 'services_ui.dart';

enum _Side { requests, incoming }

class MyServiceBookingsScreen extends StatefulWidget {
  const MyServiceBookingsScreen({super.key});

  @override
  State<MyServiceBookingsScreen> createState() => _MyServiceBookingsScreenState();
}

class _MyServiceBookingsScreenState extends State<MyServiceBookingsScreen> {
  final _svc = ServiceMarketplaceService.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  late final _requests = _svc.watchMyRequests(_uid).asBroadcastStream();
  late final _incoming = _svc.watchIncomingJobs(_uid).asBroadcastStream();
  late final _listings = _svc.watchListingsByProvider(_uid).asBroadcastStream();
  _Side _side = _Side.requests;

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return CanopyScaffold(
        appBar: canopyAppBar(context, title: 'My bookings'),
        body: const CanopySignedOutState(line: 'Sign in to see your bookings.'),
      );
    }
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'My bookings'),
      body: StreamBuilder<List<ServiceBooking>>(
        stream: _requests,
        builder: (context, req) => StreamBuilder<List<ServiceBooking>>(
          stream: _incoming,
          builder: (context, inc) => StreamBuilder<List<ServiceListing>>(
            stream: _listings,
            builder: (context, lst) {
              final requests = req.data ?? const <ServiceBooking>[];
              final incoming = inc.data ?? const <ServiceBooking>[];
              final isProvider = (lst.data?.isNotEmpty ?? false) || incoming.isNotEmpty;
              final side = isProvider ? _side : _Side.requests;
              final needReq = requests.where((b) => isYourTurn(b, asProvider: false)).length;
              final needInc = incoming.where((b) => isYourTurn(b, asProvider: true)).length;
              final loading = side == _Side.requests ? !req.hasData : !inc.hasData;
              final error = side == _Side.requests ? req.hasError : inc.hasError;

              return Column(
                children: [
                  if (isProvider)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter,
                          CanopySpace.s4, CanopySpace.gutter, CanopySpace.s12),
                      child: CanopySegmented<_Side>(
                        options: const [
                          (_Side.requests, 'My requests'),
                          (_Side.incoming, 'Incoming jobs'),
                        ],
                        value: side,
                        counts: {_Side.requests: needReq, _Side.incoming: needInc},
                        onChanged: (v) => setState(() => _side = v),
                      ),
                    ),
                  Expanded(
                    child: error
                        ? const CanopyErrorState(title: "Couldn't load your bookings")
                        : loading
                            ? ListView(
                                padding: const EdgeInsets.all(CanopySpace.gutter),
                                children: const [CanopyListSkeleton(rows: 3)],
                              )
                            : _list(side == _Side.requests ? requests : incoming,
                                side == _Side.incoming),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _list(List<ServiceBooking> all, bool asProvider) {
    if (all.isEmpty) {
      return asProvider
          ? CanopyEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No jobs yet',
              line: 'Requests from customers show up here.',
              actionLabel: 'Offer another service',
              onAction: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateServiceListingScreen())),
            )
          : CanopyEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No bookings yet',
              line: 'Request a service and your bookings show up here.',
              actionLabel: 'Book a service',
              onAction: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const ServicesHomeScreen())),
            );
    }
    final needs = all.where((b) => isYourTurn(b, asProvider: asProvider)).toList();
    final open =
        all.where((b) => b.status.isOpen && !isYourTurn(b, asProvider: asProvider)).toList();
    final done = all.where((b) => !b.status.isOpen).toList();
    final groups = [
      ('Needs you', needs),
      (asProvider ? 'Waiting on the customer' : 'In progress', open),
      ('Done', done),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
      children: [
        for (final g in groups)
          if (g.$2.isNotEmpty) ...[
            CanopySectionHeader(title: '${g.$1} · ${g.$2.length}', padding: EdgeInsets.zero),
            for (final b in g.$2) ...[
              BookingRow(booking: b, asProvider: asProvider),
              const SizedBox(height: CanopySpace.s8),
            ],
            const SizedBox(height: CanopySpace.s12),
          ],
      ],
    );
  }
}
