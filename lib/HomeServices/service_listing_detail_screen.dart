// lib/HomeServices/service_listing_detail_screen.dart
//
// Listing detail (SERVICES_HANDOFF §3.3): photo or placeholder (220) →
// category label → title (display) → price → group: provider (+ New
// provider) · licence verified · area + radius → About → Offers → sticky
// "Request this service" + "Free to request…".
// Own listing: info callout, status labels, bookings / views, "Edit listing"
// + quiet "Pause"/"Resume". Unavailable: empty state + "See other [trade]s".
// No reviews or ratings in v1.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import 'browse_service_listings_screen.dart';
import 'create_service_listing_screen.dart';
import 'request_service_booking_screen.dart';
import 'services_ui.dart';

class ServiceListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ServiceListingDetailScreen({required this.listingId, super.key});

  @override
  State<ServiceListingDetailScreen> createState() => _ServiceListingDetailScreenState();
}

class _ServiceListingDetailScreenState extends State<ServiceListingDetailScreen> {
  final _svc = ServiceMarketplaceService.instance;
  late Stream<ServiceListing?> _stream = _svc.watchListingById(widget.listingId);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _svc.incrementListingView(widget.listingId);
  }

  Future<void> _togglePause(ServiceListing l) async {
    setState(() => _busy = true);
    try {
      await _svc.setListingStatus(
          l.id, l.isActive ? ServiceListingStatus.paused : ServiceListingStatus.active);
      if (mounted) showCanopySnack(context, l.isActive ? 'Listing paused.' : 'Listing is live again.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't update the listing.", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<ServiceListing?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyScaffold(
            appBar: canopyAppBar(context),
            body: CanopyErrorState(
                title: "Couldn't load this listing",
                onRetry: () => setState(() => _stream = _svc.watchListingById(widget.listingId))),
          );
        }
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return CanopyScaffold(
            appBar: canopyAppBar(context),
            body: ListView(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              children: const [
                CanopySkeleton(height: 220, radius: CanopyRadius.md),
                SizedBox(height: CanopySpace.s16),
                CanopySkeleton(height: 28, width: 240),
                SizedBox(height: CanopySpace.s16),
                CanopyListSkeleton(rows: 3),
              ],
            ),
          );
        }
        final l = snap.data;
        final own = l != null && l.postedByUid == uid;
        if (l == null || (!own && !l.isPubliclyListable)) {
          final cat = l?.category;
          return CanopyScaffold(
            appBar: canopyAppBar(context),
            body: CanopyEmptyState(
              icon: Icons.storefront_outlined,
              title: 'This listing isn\'t available',
              line: 'The provider may have paused or closed it.',
              actionLabel: cat == null ? null : 'See other ${cat.tradeNoun}s',
              onAction: cat == null
                  ? null
                  : () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BrowseServiceListingsScreen(category: cat))),
            ),
          );
        }
        return CanopyScaffold(
          appBar: canopyAppBar(context),
          body: _body(l, own),
          sticky: own
              ? StickyActionBar(children: [
                  CanopyButton(
                    label: 'Edit listing',
                    expand: true,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CreateServiceListingScreen(existing: l))),
                  ),
                  CanopyButton.quiet(
                    label: l.isActive ? 'Pause listing' : 'Resume listing',
                    expand: true,
                    loading: _busy,
                    onPressed: () => _togglePause(l),
                  ),
                ])
              : StickyActionBar(children: [
                  CanopyButton(
                    label: 'Request this service',
                    expand: true,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RequestServiceBookingScreen(listing: l))),
                  ),
                  Text('Free to request. You only pay once you accept a quote.',
                      textAlign: TextAlign.center,
                      style: CanopyType.caption.copyWith(color: context.canopy.inkMuted)),
                ]),
        );
      },
    );
  }

  Widget _body(ServiceListing l, bool own) {
    final p = context.canopy;
    final verified = l.requiresLicenseVerification &&
        l.licenseVerificationStatus == LicenseVerificationStatus.verified;
    final reg = own
        ? regulatoryCallout(l.category,
            status: l.licenseVerificationStatus, rejectionReason: l.licenseRejectionReason)
        : null;
    return ListView(
      padding: const EdgeInsets.only(bottom: CanopySpace.s32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.md),
            child: SizedBox(
              height: 220,
              child: l.coverImage == null
                  ? Stack(fit: StackFit.expand, children: [
                      const CanopyImageFallback(icon: Icons.handyman_outlined),
                      Center(child: CategoryGlyph(l.category, size: 48, color: p.primarySoft)),
                    ])
                  : CanopyImage(url: l.coverImage),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (own) ...[
                CanopyCallout(
                  text: 'This is your listing. Customers see it like this, with a Request button.',
                ),
                const SizedBox(height: CanopySpace.s12),
                LabelRow(children: [
                  StatusLabel(l.status.label,
                      color: l.isActive ? p.success : p.inkMuted),
                  if (l.requiresLicenseVerification)
                    StatusLabel(l.licenseVerificationStatus.label,
                        color: switch (l.licenseVerificationStatus) {
                          LicenseVerificationStatus.verified => p.success,
                          LicenseVerificationStatus.rejected => p.danger,
                          _ => p.warning,
                        }),
                ]),
                const SizedBox(height: CanopySpace.s8),
              ],
              StatusLabel(l.category.name2, color: p.inkMuted),
              const SizedBox(height: CanopySpace.s4),
              Text(l.title, style: CanopyType.display.copyWith(color: p.ink)),
              const SizedBox(height: CanopySpace.s8),
              PriceDisplay(l.pricing, fontSize: 18),
              if (reg != null) ...[
                const SizedBox(height: CanopySpace.s16),
                reg,
              ],
              if (own) ...[
                const SizedBox(height: CanopySpace.s16),
                Row(children: [
                  Expanded(child: CanopyStatTile(value: '${l.bookingCount}', label: 'Bookings')),
                  const SizedBox(width: CanopySpace.s12),
                  Expanded(child: CanopyStatTile(value: '${l.viewCount}', label: 'Views')),
                ]),
              ],
              const SizedBox(height: CanopySpace.section),
              CanopyListGroup(children: [
                CanopyListRow(
                  leading: CanopyAvatar(
                      url: l.provider.shopLogoUrl,
                      name: l.orgName?.isNotEmpty == true ? l.orgName! : l.provider.shopName,
                      size: 40,
                      org: l.orgId != null),
                  title: l.orgName?.isNotEmpty == true ? l.orgName! : l.provider.shopName,
                  subtitle: 'Provider',
                  below: l.bookingCount == 0 ? const NewProviderLabel() : null,
                ),
                if (verified)
                  CanopyListRow(
                    icon: Icons.verified_outlined,
                    titleColor: p.success,
                    title: '${l.category.licenceName} checked by Canopy',
                    subtitle: l.licenseVerifiedAt == null
                        ? null
                        : 'Verified ${serviceDate(l.licenseVerifiedAt!)}',
                  ),
                if (l.location.label.isNotEmpty || l.serviceRadiusKm > 0)
                  CanopyListRow(
                    icon: Icons.place_outlined,
                    title: l.location.label.isEmpty ? 'Area not stated' : l.location.label,
                    subtitle: l.serviceRadiusKm > 0
                        ? 'Serves up to ${l.serviceRadiusKm.round()} km away'
                        : 'Service area',
                  ),
              ]),
              if (l.description.trim().isNotEmpty) ...[
                const SizedBox(height: CanopySpace.section),
                const CanopySectionHeader(title: 'About', padding: EdgeInsets.zero),
                Text(l.description.trim(),
                    style: CanopyType.body.copyWith(color: p.ink, height: 22 / 14)),
              ],
              if (l.offerings.isNotEmpty) ...[
                const SizedBox(height: CanopySpace.section),
                const CanopySectionHeader(title: 'Offers', padding: EdgeInsets.zero),
                Text(l.offeringLabels.join(' · '),
                    style: CanopyType.body.copyWith(color: p.ink)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
