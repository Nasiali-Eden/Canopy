import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SellerMapPage
//
//  Marketplace seller map. Based on community map structure.
//  Additive layers for seller-specific features:
//    — Canopy Hub pins (gold)
//    — Processor location pins (teal)
//    — Own listing pins if Processor role (primary green with badge)
//    — Layer toggle bottom sheet
//
//  Sellers see: community map + marketplace overlays
// ─────────────────────────────────────────────────────────────────────────────

class SellerMapPage extends StatefulWidget {
  const SellerMapPage({super.key});

  @override
  State<SellerMapPage> createState() => _SellerMapPageState();
}

class _SellerMapPageState extends State<SellerMapPage> {
  Set<Marker> _markers = {};

  // Layer visibility toggles
  bool _showCommunityLayers = true;
  bool _showCanopyHubs = true;
  bool _showProcessors = true;
  bool _showMyListings = true;

  // Initial Nairobi position
  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-1.2921, 36.8219),
    zoom: 13,
  );

  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  void _buildMarkers() {
    final newMarkers = <Marker>{};

    // TODO: Build community map markers (cleanup activities, collection points)
    // For now, we'll add marketplace-specific markers

    if (_showCanopyHubs) {
      newMarkers.addAll(_buildCanopyHubMarkers());
    }

    if (_showProcessors) {
      newMarkers.addAll(_buildProcessorMarkers());
    }

    if (_showMyListings && uid != null) {
      newMarkers.addAll(_buildMyListingMarkers());
    }

    setState(() => _markers = newMarkers);
  }

  Set<Marker> _buildCanopyHubMarkers() {
    // TODO: Stream from canopy_hubs collection
    return {
      Marker(
        markerId: const MarkerId('hub_001'),
        position: const LatLng(-1.2921, 36.8219),
        infoWindow: const InfoWindow(
          title: 'Canopy Hub — CBD',
          snippet: 'Buy prices: PET 8 KSh/kg, HDPE 6 KSh/kg',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        ),
        onTap: () => _showHubBottomSheet('Canopy Hub — CBD'),
      ),
      Marker(
        markerId: const MarkerId('hub_002'),
        position: const LatLng(-1.3120, 36.7810),
        infoWindow: const InfoWindow(
          title: 'Canopy Hub — Kibera',
          snippet: 'Buy prices: PET 8 KSh/kg, Metals 12 KSh/kg',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        ),
        onTap: () => _showHubBottomSheet('Canopy Hub — Kibera'),
      ),
    };
  }

  Set<Marker> _buildProcessorMarkers() {
    // TODO: Stream from marketplace_sellers where marketplace_role == 'Processor'
    return {
      Marker(
        markerId: const MarkerId('proc_001'),
        position: const LatLng(-1.3000, 36.7670),
        infoWindow: const InfoWindow(
          title: 'EcoCycle Processors',
          snippet: 'Materials: Plastics, Metals · Tap for details',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueCyan,
        ),
        onTap: () => _showProcessorBottomSheet('EcoCycle Processors'),
      ),
    };
  }

  Set<Marker> _buildMyListingMarkers() {
    // TODO: Stream from marketplace_transactions for current seller
    if (uid == null) return {};

    return {
      Marker(
        markerId: const MarkerId('my_listings'),
        position: const LatLng(-1.2850, 36.8100),
        infoWindow: const InfoWindow(
          title: 'My Active Listings',
          snippet: 'PET Bottles · 50 kg available',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        onTap: () => _showMyListingsBottomSheet(),
      ),
    };
  }

  void _showHubBottomSheet(String hubName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 20,
                    color: AppTheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hubName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Canopy collection and buying hub',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Accepted Plastics',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PriceChip(label: 'PET', price: '8 KSh/kg'),
                _PriceChip(label: 'HDPE', price: '6 KSh/kg'),
                _PriceChip(label: 'Mixed', price: '4 KSh/kg'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mon–Sat: 8:00 AM – 5:00 PM\nSunday: Closed',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkGreen.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Close'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.tertiary,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProcessorBottomSheet(String processorName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.factory_outlined,
                    size: 20,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        processorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Marketplace processor',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Materials Accepted',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MaterialChip(label: 'Plastics'),
                _MaterialChip(label: 'Metals'),
                _MaterialChip(label: 'Paper'),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                // TODO: Navigate to processor contact/details
                Navigator.pop(context);
              },
              icon: const Icon(Icons.phone_outlined),
              label: const Text('Contact Processor'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyListingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Active Listings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current sales & offers',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Listing items
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'PET Bottles',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '50 kg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Price: 8 KSh/kg · 2 active buyers',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                // TODO: Navigate to shop/listings
                Navigator.pop(context);
              },
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Manage Listings'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLayerToggleSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Map Layers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            _LayerToggle(
              label: 'Community Layers',
              subtitle: 'Activities & cleanup locations',
              value: _showCommunityLayers,
              onChanged: (v) => setState(() {
                _showCommunityLayers = v;
                _buildMarkers();
              }),
              color: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            _LayerToggle(
              label: 'Canopy Hubs',
              subtitle: 'Collection & buying hubs',
              value: _showCanopyHubs,
              onChanged: (v) => setState(() {
                _showCanopyHubs = v;
                _buildMarkers();
              }),
              color: AppTheme.tertiary,
            ),
            const SizedBox(height: 12),
            _LayerToggle(
              label: 'Processors',
              subtitle: 'Marketplace processors',
              value: _showProcessors,
              onChanged: (v) => setState(() {
                _showProcessors = v;
                _buildMarkers();
              }),
              color: AppTheme.accent,
            ),
            const SizedBox(height: 12),
            _LayerToggle(
              label: 'My Listings',
              subtitle: 'Your active listings',
              value: _showMyListings,
              onChanged: (v) => setState(() {
                _showMyListings = v;
                _buildMarkers();
              }),
              color: AppTheme.primary,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Marketplace Map',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (_) {},
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          // Layer toggle FAB
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _showLayerToggleSheet,
              backgroundColor: Colors.white,
              elevation: 4,
              child: Icon(Icons.layers_outlined, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final String price;
  const _PriceChip({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.tertiary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.tertiary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.tertiary,
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.tertiary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialChip extends StatelessWidget {
  final String label;
  const _MaterialChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  const _LayerToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                value ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }
}
