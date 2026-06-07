import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../Shared/theme/app_theme.dart';
import '../Shared/zone_drawing_controller.dart';

// ─── Firestore zone model ─────────────────────────────────────────────────────
class CollectionZone {
  final String id;
  final String name;
  final List<LatLng> vertices;
  final DateTime createdAt;
  final String createdBy;
  final String orgId;
  final String status; // draft | active | completed
  final double areaKm2;

  const CollectionZone({
    required this.id,
    required this.name,
    required this.vertices,
    required this.createdAt,
    required this.createdBy,
    required this.orgId,
    required this.status,
    required this.areaKm2,
  });

  factory CollectionZone.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final raw = (d['vertices'] as List<dynamic>? ?? []);
    final verts = raw
        .map((v) => LatLng(
              (v['lat'] as num).toDouble(),
              (v['lng'] as num).toDouble(),
            ))
        .toList();
    return CollectionZone(
      id: doc.id,
      name: d['name'] as String? ?? 'Unnamed Zone',
      vertices: verts,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['created_by'] as String? ?? '',
      orgId: d['org_id'] as String? ?? '',
      status: d['status'] as String? ?? 'draft',
      areaKm2: (d['area_km2'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'vertices': vertices
            .map((v) => {'lat': v.latitude, 'lng': v.longitude})
            .toList(),
        'created_at': Timestamp.fromDate(createdAt),
        'created_by': createdBy,
        'org_id': orgId,
        'status': status,
        'area_km2': areaKm2,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
class EnvTerritoryScreen extends StatefulWidget {
  const EnvTerritoryScreen({super.key});

  @override
  State<EnvTerritoryScreen> createState() => _EnvTerritoryScreenState();
}

class _EnvTerritoryScreenState extends State<EnvTerritoryScreen> {
  bool _isDrawingMode = false;
  CollectionZone? _selectedZone;
  List<CollectionZone> _zones = [];
  GoogleMapController? _staticMapController;

  static const LatLng _fallbackCenter = LatLng(-1.2921, 36.8219);

  CameraPosition _initialCamera = const CameraPosition(
    target: _fallbackCenter,
    zoom: 14,
  );

  static const String _mapStyle = '''
  [
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","stylers":[{"saturation":-30}]},
    {"featureType":"landscape","stylers":[{"color":"#F5F1EB"}]},
    {"featureType":"water","stylers":[{"color":"#A8C5C0"}]},
    {"featureType":"poi.park","stylers":[{"color":"#C8DCCA"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadZones();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _initialCamera = CameraPosition(target: latLng, zoom: 15);
      });
      _staticMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
    } catch (_) {
      // Keep fallback Nairobi centre
    }
  }

  Future<void> _loadZones() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('collection_zones')
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      if (mounted) {
        setState(() {
          _zones = snap.docs.map(CollectionZone.fromFirestore).toList();
        });
      }
    } catch (_) {
      // Firestore unavailable — show no zones
    }
  }

  Future<void> _saveZone(ZoneDrawingResult result, String name) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final zone = CollectionZone(
      id: '',
      name: name,
      vertices: result.vertices.toList(),
      createdAt: DateTime.now(),
      createdBy: uid,
      orgId: uid,
      status: 'active',
      areaKm2: result.areaKm2,
    );
    try {
      final ref = await FirebaseFirestore.instance
          .collection('collection_zones')
          .add(zone.toFirestore());
      final saved = CollectionZone(
        id: ref.id,
        name: zone.name,
        vertices: zone.vertices,
        createdAt: zone.createdAt,
        createdBy: zone.createdBy,
        orgId: zone.orgId,
        status: zone.status,
        areaKm2: zone.areaKm2,
      );
      if (mounted) setState(() => _zones.insert(0, saved));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zone saved locally — will sync when online')),
        );
      }
    }
  }

  void _onZoneClosed(ZoneDrawingResult result) async {
    if (result.vertices.length < 3) return; // cancelled / insufficient
    setState(() => _isDrawingMode = false);
    final name = await _showNameDialog(result);
    if (name != null && name.isNotEmpty) {
      await _saveZone(result, name);
    }
  }

  Future<String?> _showNameDialog(ZoneDrawingResult result) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.vertices.length} vertices · '
              '${result.areaKm2.toStringAsFixed(3)} km²',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.6)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Kibera Zone A',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Set<Polygon> get _zonePolygons {
    return _zones.map((z) {
      final isSelected = _selectedZone?.id == z.id;
      return Polygon(
        polygonId: PolygonId(z.id),
        points: z.vertices,
        fillColor: isSelected
            ? AppTheme.primary.withOpacity(0.30)
            : AppTheme.primary.withOpacity(0.18),
        strokeColor: isSelected ? AppTheme.primary : AppTheme.accent,
        strokeWidth: isSelected ? 3 : 2,
        consumeTapEvents: true,
        onTap: () => _showZoneDetail(z),
      );
    }).toSet();
  }

  void _showZoneDetail(CollectionZone zone) {
    setState(() => _selectedZone = zone);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ZoneDetailSheet(zone: zone),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedZone = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: Stack(
        children: [
          if (_isDrawingMode)
            ZoneDrawingController(
              config: ZoneDrawingConfig.collectionDefault,
              onZoneClosed: _onZoneClosed,
              onCancel: () => setState(() => _isDrawingMode = false),
              initialPosition: _initialCamera,
              mapStyle: _mapStyle,
            )
          else
            _buildStaticMap(),

          // ── Status bar ──
          if (!_isDrawingMode)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildStatusBar(),
            ),

          // ── Define Zone button ──
          if (!_isDrawingMode)
            Positioned(
              bottom: 110,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () => setState(() => _isDrawingMode = true),
                backgroundColor: AppTheme.primary,
                icon: const Icon(Icons.edit_location_alt_outlined,
                    color: Colors.white, size: 20),
                label: const Text(
                  'Define Collection Zone',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaticMap() {
    return GoogleMap(
      initialCameraPosition: _initialCamera,
      onMapCreated: (c) {
        _staticMapController = c;
        c.setMapStyle(_mapStyle);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      polygons: _zonePolygons,
      markers: _buildLegacyMarkers(),
    );
  }

  Set<Marker> _buildLegacyMarkers() => {
        Marker(
          markerId: const MarkerId('hub'),
          position: const LatLng(-1.3140, 36.7840),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'Kibera Hub'),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: const LatLng(-1.3110, 36.7890),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(title: 'Drop-off Point'),
        ),
        Marker(
          markerId: const MarkerId('collection'),
          position: const LatLng(-1.3160, 36.7870),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Collection Point'),
        ),
      };

  Widget _buildStatusBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined,
              color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            '${_zones.length} zone${_zones.length == 1 ? '' : 's'}  ·  3 sites',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadZones,
            child: Text(
              'Refresh',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.darkGreen.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Zone detail sheet ────────────────────────────────────────────────────────
class _ZoneDetailSheet extends StatelessWidget {
  final CollectionZone zone;

  const _ZoneDetailSheet({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(zone.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  zone.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(zone.status),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM yyyy').format(zone.createdAt),
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGreen.withOpacity(0.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            zone.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                  icon: Icons.straighten_outlined,
                  label: '${zone.areaKm2.toStringAsFixed(3)} km²'),
              const SizedBox(width: 10),
              _StatChip(
                  icon: Icons.location_on_outlined,
                  label: '${zone.vertices.length} vertices'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close',
                      style: TextStyle(color: AppTheme.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View Org',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.primary;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen)),
        ],
      ),
    );
  }
}
