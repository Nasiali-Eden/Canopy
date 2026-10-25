// lib/HomeServices/my_service_listings_screen.dart
//
// My listings (SERVICES_HANDOFF §3.7): a card per listing with status +
// licence labels, bookings/views, rejection callout + "Resubmit licence",
// Pause/Resume, and a sticky "New listing" (the create flow's first step is
// the category grid, where regulated rows say which licence they need).

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Models/services/service_listing.dart';
import '../Services/HomeServices/service_marketplace_service.dart';
import '../theme/canopy_components.dart';
import 'create_service_listing_screen.dart';
import 'service_listing_detail_screen.dart';
import 'services_ui.dart';

class MyServiceListingsScreen extends StatefulWidget {
  const MyServiceListingsScreen({super.key});

  @override
  State<MyServiceListingsScreen> createState() => _MyServiceListingsScreenState();
}

class _MyServiceListingsScreenState extends State<MyServiceListingsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  late Stream<List<ServiceListing>> _stream =
      ServiceMarketplaceService.instance.watchListingsByProvider(_uid);
  final Set<String> _busy = {};

  void _new() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const CreateServiceListingScreen()));

  Future<void> _toggle(ServiceListing l) async {
    setState(() => _busy.add(l.id));
    try {
      await ServiceMarketplaceService.instance.setListingStatus(
          l.id, l.isActive ? ServiceListingStatus.paused : ServiceListingStatus.active);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't update the listing.", error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(l.id));
    }
  }

  /// Re-upload the licence for a rejected electrical/plumbing listing — sends
  /// it back to 'pending' (the only client-allowed transition).
  Future<void> _resubmit(ServiceListing l) async {
    final source = await showCanopySheet<ImageSource>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: 'Photo of your ${l.category.licenceName}',
        caption: 'Make sure your name and the licence number are readable.',
        children: [
          CanopyListGroup(children: [
            CanopyListRow(
                icon: Icons.photo_camera_outlined,
                title: 'Take a photo',
                onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            CanopyListRow(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ]),
        ],
      ),
    );
    if (source == null) return;
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (x == null || !mounted) return;
    setState(() => _busy.add(l.id));
    try {
      final ref = FirebaseStorage.instance.ref(
          'service_provider_licenses/$_uid/${DateTime.now().millisecondsSinceEpoch}_${l.category.name}.jpg');
      await ref.putFile(File(x.path));
      await ServiceMarketplaceService.instance
          .resubmitLicenseDocument(l.id, await ref.getDownloadURL());
      if (mounted) {
        showCanopySnack(context, "Licence sent. We'll check it before your listing goes live.");
      }
    } catch (_) {
      if (mounted) {
        showCanopySnack(context, "Couldn't upload your licence.",
            error: true, actionLabel: 'Retry', onAction: () => _resubmit(l));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(l.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'My listings'),
      body: StreamBuilder<List<ServiceListing>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(
                title: "Couldn't load your listings",
                onRetry: () => setState(() => _stream =
                    ServiceMarketplaceService.instance.watchListingsByProvider(_uid)));
          }
          if (!snap.hasData) {
            return ListView(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              children: const [CanopyListSkeleton(rows: 2, leadingSize: 56)],
            );
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const CanopyEmptyState(
              icon: Icons.storefront_outlined,
              title: "You haven't listed a service yet",
              line: 'Offer trash collection, landscaping, repairs and more.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s32),
            children: [
              for (final l in list) ...[
                CanopyCard(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ServiceListingDetailScreen(listingId: l.id))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CategoryGlyph(l.category, size: 26),
                          const SizedBox(width: CanopySpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                const SizedBox(height: CanopySpace.s2),
                                Text(l.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                                PriceDisplay(l.pricing, fontSize: 13),
                                Text('${l.bookingCount} bookings · ${l.viewCount} views',
                                    style: CanopyType.caption.copyWith(color: p.inkMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (l.isLicenseVerificationRejected) ...[
                        const SizedBox(height: CanopySpace.s12),
                        regulatoryCallout(l.category,
                            status: l.licenseVerificationStatus,
                            rejectionReason: l.licenseRejectionReason)!,
                      ] else if (l.isPendingLicenseVerification) ...[
                        const SizedBox(height: CanopySpace.s12),
                        regulatoryCallout(l.category, status: l.licenseVerificationStatus)!,
                      ],
                      Row(
                        children: [
                          if (l.isLicenseVerificationRejected)
                            CanopyButton.secondary(
                              label: 'Resubmit licence',
                              size: CanopyButtonSize.compact,
                              loading: _busy.contains(l.id),
                              onPressed: () => _resubmit(l),
                            ),
                          const Spacer(),
                          if (l.status != ServiceListingStatus.closed)
                            CanopyButton.quiet(
                              label: l.isActive ? 'Pause' : 'Resume',
                              size: CanopyButtonSize.compact,
                              loading: _busy.contains(l.id) && !l.isLicenseVerificationRejected,
                              onPressed: () => _toggle(l),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CanopySpace.s12),
              ],
            ],
          );
        },
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(label: 'New listing', expand: true, onPressed: _new),
      ]),
    );
  }
}
