// lib/Community/Map/env_ops_map_screen.dart
//
// Public, read-only environmental-operations map: shows collection zones
// (polygons) and dumpsites (markers) across the platform. Reached from the
// community map's "View Environmental Operations" button.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';
import '../../EnvironmentalOps/Territory/env_territory.dart' show CollectionZone;
import 'map_style.dart' as map_style;

class EnvOpsMapScreen extends StatefulWidget {
  const EnvOpsMapScreen({super.key});

  @override
  State<EnvOpsMapScreen> createState() => _EnvOpsMapScreenState();
}

class _EnvOpsMapScreenState extends State<EnvOpsMapScreen> {
  List<CollectionZone> _zones = [];
  final List<_Dumpsite> _dumpsites = [];
  bool _loading = true;

  static const CameraPosition _initial = CameraPosition(
    target: LatLng(-1.2921, 36.8219),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('collection_zones')
            .limit(100)
            .get(),
        FirebaseFirestore.instance
            .collection('map_pins')
            .where('pin_type', isEqualTo: 'dumpsite')
            .limit(200)
            .get(),
      ]);

      final zones = (results[0])
          .docs
          .map(CollectionZone.fromFirestore)
          .where((z) => z.vertices.length >= 3)
          .toList();

      final dumps = <_Dumpsite>[];
      for (final d in (results[1]).docs) {
        final data = d.data();
        final gp = data['location'] as GeoPoint?;
        if (gp == null) continue;
        dumps.add(_Dumpsite(
          id: d.id,
          name: (data['name'] ?? 'Dumpsite') as String,
          position: LatLng(gp.latitude, gp.longitude),
          isActive: data['is_active'] as bool? ?? true,
        ));
      }

      if (!mounted) return;
      setState(() {
        _zones = zones;
        _dumpsites
          ..clear()
          ..addAll(dumps);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<Polygon> get _polygons => _zones
      .map((z) => Polygon(
            polygonId: PolygonId('zone_${z.id}'),
            points: z.vertices,
            fillColor: AppTheme.primary.withOpacity(0.18),
            strokeColor: AppTheme.primary,
            strokeWidth: 2,
          ))
      .toSet();

  Set<Marker> get _markers => _dumpsites
      .map((d) => Marker(
            markerId: MarkerId('dump_${d.id}'),
            position: d.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                d.isActive ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
                title: d.name, snippet: d.isActive ? 'Active dumpsite' : 'Cleared'),
          ))
      .toSet();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initial,
            onMapCreated: (c) => c.setMapStyle(map_style.kCanopyMapStyle),
            polygons: _polygons,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Header
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _circleBtn(
                  Icons.arrow_back_ios_new_rounded,
                  () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12),
                      ],
                    ),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        Icon(Icons.recycling_rounded,
                            color: AppTheme.primary, size: 20),
                        SizedBox(width: 10),
                        Text('Environmental Operations',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkGreen)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_loading)
            const Positioned(
              top: 0, left: 0, right: 0, bottom: 0,
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2),
              ),
            ),

          // Legend / summary
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPad + 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  _legend(
                    color: AppTheme.primary,
                    icon: Icons.layers_outlined,
                    value: '${_zones.length}',
                    label: 'Collection zones',
                  ),
                  Container(
                      width: 1, height: 36, color: Colors.grey.shade200),
                  _legend(
                    color: const Color(0xFFE53935),
                    icon: Icons.delete_outline,
                    value: '${_dumpsites.length}',
                    label: 'Dumpsites',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend({
    required Color color,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.55))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10),
          ],
        ),
        child: Icon(icon, size: 18, color: AppTheme.darkGreen),
      ),
    );
  }
}

class _Dumpsite {
  final String id;
  final String name;
  final LatLng position;
  final bool isActive;
  const _Dumpsite({
    required this.id,
    required this.name,
    required this.position,
    required this.isActive,
  });
}
