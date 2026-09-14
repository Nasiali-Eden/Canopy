import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';

class OperationalFootprintMap extends StatefulWidget {
  final String orgId;
  final String operatingArea;

  const OperationalFootprintMap({
    super.key,
    required this.orgId,
    required this.operatingArea,
  });

  @override
  State<OperationalFootprintMap> createState() =>
      _OperationalFootprintMapState();
}

class _OperationalFootprintMapState extends State<OperationalFootprintMap> {
  static const _dumpsiteColor = Color(0xFFE05C45);
  static const _treeColor = Color(0xFF3A7D44);
  static const _sand = Color(0xFFE8D8A8);
  static const _mapStyle = '''
  [
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#DED9CE"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#716E66"}]},
    {"featureType":"landscape","stylers":[{"color":"#F2EFE6"}]},
    {"featureType":"water","stylers":[{"color":"#B9D1CC"}]},
    {"featureType":"poi.park","stylers":[{"color":"#D3E0CC"}]}
  ]
  ''';

  GoogleMapController? _controller;
  List<_FootprintZone> _zones = const [];
  List<_Dumpsite> _dumpsites = const [];
  List<_TreeGroup> _treeGroups = const [];
  int _treeCount = 0;
  bool _loading = true;
  String? _error;
  BitmapDescriptor? _dumpsiteMarker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OperationalFootprintMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orgId != widget.orgId) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.orgId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This profile is not linked to an organisation.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orgRef = FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId);
      final canonicalZonesFuture = orgRef.collection('collectionZones').get();
      final dumpsitesFuture = FirebaseFirestore.instance
          .collection('map_pins')
          .where('added_by_org_id', isEqualTo: widget.orgId)
          .get();
      final treesFuture = orgRef.collection('trees').get();

      final canonicalZones = await canonicalZonesFuture;
      QuerySnapshot<Map<String, dynamic>>? legacyZones;
      if (canonicalZones.docs.isEmpty) {
        legacyZones = await FirebaseFirestore.instance
            .collection('collection_zones')
            .where('org_id', isEqualTo: widget.orgId)
            .get();
      }

      final results = await Future.wait([dumpsitesFuture, treesFuture]);
      final pinSnapshot = results[0];
      final treeSnapshot = results[1];

      final zones = canonicalZones.docs.isNotEmpty
          ? canonicalZones.docs
              .map(_zoneFromCanonical)
              .whereType<_FootprintZone>()
              .toList()
          : (legacyZones?.docs ?? const [])
              .map(_zoneFromLegacy)
              .whereType<_FootprintZone>()
              .toList();

      final dumpsites = pinSnapshot.docs
          .where(
              (doc) => '${doc.data()['pin_type']}'.toLowerCase() == 'dumpsite')
          .map(_dumpsiteFromDocument)
          .whereType<_Dumpsite>()
          .toList();

      final groupedTrees = <String, _TreeGroupBuilder>{};
      for (final doc in treeSnapshot.docs) {
        final data = doc.data();
        final planting = _asMap(data['planting']);
        final location = _asMap(planting?['location']);
        final position = _latLngFromMap(location);
        if (position == null) continue;
        final key = '${position.latitude.toStringAsFixed(6)}:'
            '${position.longitude.toStringAsFixed(6)}';
        final species = _firstText([
          data['commonName'],
          data['species'],
        ], fallback: 'Tree');
        final quantity = _treeQuantity(data);
        groupedTrees
            .putIfAbsent(key, () => _TreeGroupBuilder(position))
            .add(species, quantity);
      }
      final treeGroups =
          groupedTrees.values.map((group) => group.build()).toList();
      final dumpsiteMarker = _dumpsiteMarker ?? await _createDumpsiteMarker();

      if (!mounted) return;
      setState(() {
        _zones = zones;
        _dumpsites = dumpsites;
        _treeGroups = treeGroups;
        _treeCount = treeGroups.fold(
          0,
          (total, group) => total + group.count,
        );
        _dumpsiteMarker = dumpsiteMarker;
        _loading = false;
      });
      await _fitCamera();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The operational footprint could not be loaded.';
      });
    }
  }

  _FootprintZone? _zoneFromCanonical(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final polygon = _asMap(data['polygon']);
    final rawCoordinates = polygon?['coordinates'];
    if (rawCoordinates is! List) return null;
    final points =
        rawCoordinates.map(_latLngFromValue).whereType<LatLng>().toList();
    if (points.length < 3) return null;
    return _FootprintZone(
      id: doc.id,
      label: _firstText([data['label'], data['name']], fallback: 'Territory'),
      points: points,
    );
  }

  _FootprintZone? _zoneFromLegacy(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawVertices = data['vertices'];
    if (rawVertices is! List) return null;
    final points =
        rawVertices.map(_latLngFromValue).whereType<LatLng>().toList();
    if (points.length < 3) return null;
    return _FootprintZone(
      id: doc.id,
      label: _firstText([data['name'], data['label']], fallback: 'Territory'),
      points: points,
    );
  }

  _Dumpsite? _dumpsiteFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final position = _latLngFromValue(data['location']);
    if (position == null) return null;
    return _Dumpsite(
      id: doc.id,
      name: _firstText([data['name']], fallback: 'Dumpsite'),
      position: position,
      isActive: data['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  LatLng? _latLngFromMap(Map<String, dynamic>? value) {
    if (value == null) return null;
    final lat = value['lat'] as num?;
    final lng = value['lng'] as num?;
    if (lat == null || lng == null) return null;
    return _validLatLng(lat.toDouble(), lng.toDouble());
  }

  LatLng? _latLngFromValue(dynamic value) {
    if (value is GeoPoint) {
      return _validLatLng(value.latitude, value.longitude);
    }
    return _latLngFromMap(_asMap(value));
  }

  LatLng? _validLatLng(double lat, double lng) {
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  String _firstText(List<dynamic> values, {required String fallback}) {
    for (final value in values) {
      final text = '$value'.trim();
      if (value != null && text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  int _treeQuantity(Map<String, dynamic> data) {
    // Canonical records currently store one tree per document. Supporting a
    // positive quantity keeps imported or batch-shaped canonical records
    // accurate without multiplying today's per-tree records.
    for (final field in const ['quantity', 'treeCount', 'count']) {
      final value = data[field];
      if (value is num && value.isFinite && value > 0) {
        return value.toInt();
      }
    }
    return 1;
  }

  Future<BitmapDescriptor> _createDumpsiteMarker() async {
    const width = 64.0;
    const height = 76.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = _dumpsiteColor;
    final shadow = Paint()..color = Colors.black.withOpacity(0.16);
    final pin = Path()
      ..moveTo(width / 2, height - 3)
      ..cubicTo(width * 0.43, height * 0.78, 9, height * 0.55, 9, 30)
      ..arcToPoint(
        const Offset(width - 9, 30),
        radius: const Radius.circular(23),
        clockwise: true,
      )
      ..cubicTo(width - 9, height * 0.55, width * 0.57, height * 0.78,
          width / 2, height - 3)
      ..close();
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(pin, shadow);
    canvas.restore();
    canvas.drawPath(pin, paint);
    canvas.drawCircle(
      const Offset(width / 2, 30),
      12,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(width / 2, 30),
      5,
      Paint()..color = _dumpsiteColor,
    );
    final image =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 32,
      height: 38,
    );
  }

  List<LatLng> get _allCoordinates => [
        for (final zone in _zones) ...zone.points,
        for (final dumpsite in _dumpsites) dumpsite.position,
        for (final group in _treeGroups) group.position,
      ];

  Future<void> _fitCamera() async {
    final controller = _controller;
    final points = _allCoordinates;
    if (controller == null || points.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (points.length == 1) {
      await controller
          .animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
      return;
    }
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points.skip(1)) {
      south = math.min(south, point.latitude);
      north = math.max(north, point.latitude);
      west = math.min(west, point.longitude);
      east = math.max(east, point.longitude);
    }
    if ((north - south).abs() < 0.00001 && (east - west).abs() < 0.00001) {
      await controller
          .animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(south, west), northeast: LatLng(north, east)),
        44,
      ),
    );
  }

  Set<Polygon> get _polygons => _zones
      .map(
        (zone) => Polygon(
          polygonId: PolygonId('profile_zone_${zone.id}'),
          points: zone.points,
          fillColor: AppTheme.primary.withOpacity(0.17),
          strokeColor: AppTheme.primary,
          strokeWidth: 2,
          consumeTapEvents: true,
          onTap: () => _showEvidence(
            icon: Icons.polyline_outlined,
            color: AppTheme.primary,
            eyebrow: 'TERRITORY',
            title: zone.label,
            detail: '${zone.points.length} recorded boundary points',
          ),
        ),
      )
      .toSet();

  Set<Marker> get _markers => _dumpsites
      .map(
        (dumpsite) => Marker(
          markerId: MarkerId('profile_dumpsite_${dumpsite.id}'),
          position: dumpsite.position,
          icon: _dumpsiteMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _showEvidence(
            icon: Icons.delete_sweep_outlined,
            color: _dumpsiteColor,
            eyebrow: 'DUMPSITE',
            title: dumpsite.name,
            detail: dumpsite.isActive
                ? 'Active site recorded by this organisation'
                : 'Inactive site recorded by this organisation',
          ),
        ),
      )
      .toSet();

  Set<Circle> get _circles => _treeGroups
      .map(
        (group) => Circle(
          circleId: CircleId('profile_trees_${group.key}'),
          center: group.position,
          radius:
              group.count == 1 ? 5 : math.min(12, 5 + group.count.toDouble()),
          fillColor: _treeColor.withOpacity(0.88),
          strokeColor: Colors.white,
          strokeWidth: 2,
          consumeTapEvents: true,
          onTap: () => _showEvidence(
            icon: Icons.park_outlined,
            color: _treeColor,
            eyebrow: 'PLANTING EVIDENCE',
            title: '${group.count} tree${group.count == 1 ? '' : 's'}',
            detail: group.speciesSummary,
          ),
        ),
      )
      .toSet();

  void _showEvidence({
    required IconData icon,
    required Color color,
    required String eyebrow,
    required String title,
    required String detail,
  }) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF6),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 20),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: TextStyle(
                        color: AppTheme.darkGreen.withOpacity(0.6),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close_rounded),
                color: AppTheme.darkGreen.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasGeometry = _allCoordinates.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AreaBanner(area: widget.operatingArea, onRefresh: _load),
          if (_loading)
            const SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_error != null)
            _FootprintMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Map evidence unavailable',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _load,
            )
          else if (!hasGeometry)
            const _FootprintMessage(
              icon: Icons.map_outlined,
              title: 'No spatial evidence yet',
              message:
                  'Saved territory boundaries, organisation dumpsites, and recorded tree locations will appear here.',
            )
          else
            SizedBox(
              height: 310,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _allCoordinates.first,
                  zoom: 14,
                ),
                onMapCreated: (controller) {
                  _controller = controller;
                  controller.setMapStyle(_mapStyle);
                  _fitCamera();
                },
                polygons: _polygons,
                markers: _markers,
                circles: _circles,
                compassEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          if (!_loading && _error == null)
            _LayerSummary(
              zoneCount: _zones.length,
              dumpsiteCount: _dumpsites.length,
              treeCount: _treeCount,
            ),
        ],
      ),
    );
  }
}

class _AreaBanner extends StatelessWidget {
  final String area;
  final VoidCallback onRefresh;

  const _AreaBanner({required this.area, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final label = area.trim().isEmpty ? 'Not specified' : area.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F4E8),
        border: Border(
            bottom: BorderSide(color: _OperationalFootprintMapState._sand)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _OperationalFootprintMapState._sand.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.explore_outlined,
                size: 19, color: AppTheme.darkGreen),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Operating area · $label',
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh map evidence',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppTheme.darkGreen.withOpacity(0.62),
          ),
        ],
      ),
    );
  }
}

class _FootprintMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FootprintMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary.withOpacity(0.62), size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.58),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LayerSummary extends StatelessWidget {
  final int zoneCount;
  final int dumpsiteCount;
  final int treeCount;

  const _LayerSummary({
    required this.zoneCount,
    required this.dumpsiteCount,
    required this.treeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      child: Row(
        children: [
          Expanded(
            child: _LayerItem(
              color: AppTheme.primary,
              label: 'Territory',
              count: zoneCount,
              outlined: true,
            ),
          ),
          Expanded(
            child: _LayerItem(
              color: _OperationalFootprintMapState._dumpsiteColor,
              label: 'Dumpsites',
              count: dumpsiteCount,
            ),
          ),
          Expanded(
            child: _LayerItem(
              color: _OperationalFootprintMapState._treeColor,
              label: 'Trees',
              count: treeCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final bool outlined;

  const _LayerItem({
    required this.color,
    required this.label,
    required this.count,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count $label',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: outlined ? color.withOpacity(0.16) : color,
              borderRadius: BorderRadius.circular(outlined ? 2 : 5),
              border: outlined ? Border.all(color: color, width: 1.5) : null,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.56),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FootprintZone {
  final String id;
  final String label;
  final List<LatLng> points;

  const _FootprintZone(
      {required this.id, required this.label, required this.points});
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

class _TreeGroupBuilder {
  final LatLng position;
  final Map<String, int> _species = {};

  _TreeGroupBuilder(this.position);

  void add(String species, int quantity) {
    _species.update(
      species,
      (current) => current + quantity,
      ifAbsent: () => quantity,
    );
  }

  _TreeGroup build() => _TreeGroup(position: position, species: _species);
}

class _TreeGroup {
  final LatLng position;
  final Map<String, int> species;

  const _TreeGroup({required this.position, required this.species});

  int get count => species.values.fold(0, (total, value) => total + value);

  String get key => '${position.latitude.toStringAsFixed(6)}_'
      '${position.longitude.toStringAsFixed(6)}';

  String get speciesSummary => species.entries
      .map((entry) =>
          entry.value == 1 ? entry.key : '${entry.value} × ${entry.key}')
      .join(', ');
}
