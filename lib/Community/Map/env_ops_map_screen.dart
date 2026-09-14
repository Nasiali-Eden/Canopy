// lib/Community/Map/env_ops_map_screen.dart
//
// Public, read-only environmental-operations map: shows collection zones
// (polygons) and dumpsites (markers) across the platform. Reached from the
// community map's "View Environmental Operations" button.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';
import '../../EnvironmentalOps/Territory/env_territory.dart'
    show CollectionZone;
import 'map_style.dart' as map_style;
import 'org_logo_cache.dart';
import '../Incidents/incidents_feed_screen.dart';
import '../../Shared/Inputs/post_incident.dart';

class EnvOpsMapScreen extends StatefulWidget {
  const EnvOpsMapScreen({super.key});

  @override
  State<EnvOpsMapScreen> createState() => _EnvOpsMapScreenState();
}

class _EnvOpsMapScreenState extends State<EnvOpsMapScreen> {
  List<CollectionZone> _zones = [];
  final List<_Dumpsite> _dumpsites = [];
  bool _loading = true;
  bool _showZoneLogos = false;
  final Map<String, BitmapDescriptor> _zoneLogos = {};
  final Map<String, String> _orgNames = {};

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
      await _loadZoneLogos(zones);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadZoneLogos(List<CollectionZone> zones) async {
    await Future.wait(zones
        .map((z) => z.orgId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .map((orgId) async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .get();
        final data = doc.data();
        if (data == null || !mounted) return;
        final url = [data['logoUrl'], data['profilePhoto']]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .firstOrNull;
        if (url == null) return;
        final bytes = await OrgLogoCache.instance.bytes(url);
        if (bytes == null || !mounted) return;
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
        try {
          final frame = await codec.getNextFrame();
          try {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            const bounds = Rect.fromLTWH(0, 0, 128, 128);
            canvas.drawCircle(
                const Offset(64, 64), 62, Paint()..color = Colors.white);
            canvas.save();
            canvas.clipPath(Path()..addOval(bounds.deflate(8)));
            paintImage(
                canvas: canvas,
                rect: bounds.deflate(12),
                image: frame.image,
                fit: BoxFit.contain);
            canvas.restore();
            canvas.drawCircle(
                const Offset(64, 64),
                62,
                Paint()
                  ..color = AppTheme.primary
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4);
            final picture = recorder.endRecording();
            final image = await picture.toImage(128, 128);
            picture.dispose();
            try {
              final png =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              if (png == null || !mounted) return;
              setState(() {
                _zoneLogos[orgId] = BitmapDescriptor.bytes(
                    png.buffer.asUint8List(),
                    width: 48,
                    height: 48);
                _orgNames[orgId] =
                    (data['name'] ?? data['orgName'] ?? 'Organization')
                        .toString();
              });
            } finally {
              image.dispose();
            }
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } catch (_) {
        // A missing or unavailable logo must not hide the mapped areas.
      }
    }));
  }

  // Choose the middle of the widest interior span at the area's mid-latitude.
  // Unlike averaging vertices, this keeps the logo inside concave zones too.
  LatLng _zoneCenter(List<LatLng> vertices) {
    final latitudes = vertices.map((v) => v.latitude).toList()..sort();
    final latitude = (latitudes.first + latitudes.last) / 2;
    final crossings = <double>[];
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      if ((a.latitude > latitude) != (b.latitude > latitude)) {
        crossings.add(a.longitude +
            (latitude - a.latitude) *
                (b.longitude - a.longitude) /
                (b.latitude - a.latitude));
      }
    }
    crossings.sort();
    var width = -1.0;
    var longitude = vertices.first.longitude;
    for (var i = 0; i + 1 < crossings.length; i += 2) {
      final span = crossings[i + 1] - crossings[i];
      if (span > width) {
        width = span;
        longitude = (crossings[i] + crossings[i + 1]) / 2;
      }
    }
    return LatLng(latitude, longitude);
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

  Set<Marker> get _markers => {
        if (_showZoneLogos)
          for (final zone in _zones)
            if (_zoneLogos.containsKey(zone.orgId))
              Marker(
                markerId: MarkerId('zone_logo_${zone.id}'),
                position: _zoneCenter(zone.vertices),
                anchor: const Offset(0.5, 0.5),
                icon: _zoneLogos[zone.orgId]!,
                infoWindow: InfoWindow(
                    title: _orgNames[zone.orgId], snippet: zone.name),
              ),
        ..._dumpsites
            .map((d) => Marker(
                  markerId: MarkerId('dump_${d.id}'),
                  position: d.position,
                  icon: BitmapDescriptor.defaultMarkerWithHue(d.isActive
                      ? BitmapDescriptor.hueRed
                      : BitmapDescriptor.hueOrange),
                  infoWindow: InfoWindow(
                      title: d.name,
                      snippet: d.isActive ? 'Active dumpsite' : 'Cleared'),
                ))
            .toSet(),
      };

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
            onCameraMove: (position) {
              final show = position.zoom >= 15;
              if (show != _showZoneLogos) {
                setState(() => _showZoneLogos = show);
              }
            },
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
                const SizedBox(width: 10),
                _circleBtn(
                  Icons.receipt_long_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IncidentsFeedScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                _circleBtn(
                  Icons.add_location_alt_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PostIncident()),
                  ),
                ),
              ],
            ),
          ),

          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
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
                  Container(width: 1, height: 36, color: Colors.grey.shade200),
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
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.55))),
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
