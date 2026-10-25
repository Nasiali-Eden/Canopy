// lib/EnvironmentalOps/Profile/operational_footprint_map.dart
//
// Operational footprint (ENVOPS_HANDOFF §3.1 / §3.6): territory zones,
// the org's dumpsites and recorded trees on one map, with a legend that is
// also the list ("3 zones · 6 dumpsites · 40 trees"). With [onOpen] the map
// is a non-interactive preview that opens Territory when tapped.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import '../envops_ui.dart';

class OperationalFootprintMap extends StatefulWidget {
  final String orgId;
  final String operatingArea;
  final double height;
  final VoidCallback? onOpen;

  const OperationalFootprintMap({
    super.key,
    required this.orgId,
    required this.operatingArea,
    this.height = 280,
    this.onOpen,
  });

  @override
  State<OperationalFootprintMap> createState() => _OperationalFootprintMapState();
}

class _OperationalFootprintMapState extends State<OperationalFootprintMap> {
  GoogleMapController? _controller;
  List<_Zone> _zones = const [];
  List<_Site> _dumpsites = const [];
  List<_TreeGroup> _trees = const [];
  bool _loading = true;
  String? _error;
  BitmapDescriptor? _dumpsiteIcon;
  BitmapDescriptor? _treeIcon;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe place to read the theme; runs once, before the first frame is shown.
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant OperationalFootprintMap old) {
    super.didUpdateWidget(old);
    if (old.orgId != widget.orgId) _load();
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
        _error = 'This workspace is not linked to an organisation.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final pal = context.canopy;
    try {
      final db = FirebaseFirestore.instance;
      final org = db.collection('organizations').doc(widget.orgId);
      final results = await Future.wait([
        org.collection('collectionZones').get(),
        db.collection('map_pins').where('added_by_org_id', isEqualTo: widget.orgId).get(),
        org.collection('trees').get(),
      ]);
      var zoneDocs = results[0].docs;
      final canonical = zoneDocs.isNotEmpty;
      if (!canonical) {
        zoneDocs = (await db.collection('collection_zones').where('org_id', isEqualTo: widget.orgId).get()).docs;
      }
      final zones = <_Zone>[];
      for (final d in zoneDocs) {
        final m = d.data();
        final raw = canonical ? (_map(m['polygon'])?['coordinates']) : m['vertices'];
        if (raw is! List) continue;
        final pts = raw.map(_latLng).whereType<LatLng>().toList();
        if (pts.length < 3) continue;
        zones.add(_Zone(d.id, _text([m['label'], m['name']], 'Territory'), pts));
      }
      final dumpsites = <_Site>[];
      for (final d in results[1].docs) {
        final m = d.data();
        if ('${m['pin_type']}'.toLowerCase() != 'dumpsite') continue;
        final pos = _latLng(m['location']);
        if (pos == null) continue;
        dumpsites.add(_Site(d.id, _text([m['name']], 'Dumpsite'), pos, m['is_active'] as bool? ?? true));
      }
      final grouped = <String, _TreeGroup>{};
      for (final d in results[2].docs) {
        final m = d.data();
        final pos = _latLng(_map(_map(m['planting'])?['location']));
        if (pos == null) continue;
        final key = '${pos.latitude.toStringAsFixed(6)}_${pos.longitude.toStringAsFixed(6)}';
        final qty = [m['quantity'], m['treeCount'], m['count']].whereType<num>().where((n) => n > 0).map((n) => n.toInt()).firstOrNull ?? 1;
        grouped.putIfAbsent(key, () => _TreeGroup(key, pos)).add(_text([m['commonName'], m['species']], 'Tree'), qty);
      }
      _dumpsiteIcon ??= await _teardrop(pal.danger, pal.surface);
      _treeIcon ??= await _treeDot(pal.primaryDim, pal.surface);
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _dumpsites = dumpsites;
        _trees = grouped.values.toList();
        _loading = false;
      });
      _fit();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "The field map couldn't load.";
        });
      }
    }
  }

  static Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

  static LatLng? _latLng(dynamic v) {
    double? lat, lng;
    if (v is GeoPoint) {
      lat = v.latitude;
      lng = v.longitude;
    } else if (v is Map) {
      lat = (v['lat'] as num?)?.toDouble();
      lng = (v['lng'] as num?)?.toDouble();
    }
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return null;
    if (lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  static String _text(List<dynamic> vs, String fallback) {
    for (final v in vs) {
      final t = '${v ?? ''}'.trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return fallback;
  }

  /// Planted trees: a 26dp green disc with a white tree glyph and a surface ring.
  static Future<BitmapDescriptor> _treeDot(Color fill, Color ring) async {
    const s = 78.0; // 26dp @3x
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const ctr = Offset(s / 2, s / 2);
    c.drawCircle(ctr, s / 2 - 1, Paint()..color = ring);
    c.drawCircle(ctr, s / 2 - 7, Paint()..color = fill);
    const icon = Icons.park;
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textDirection: ui.TextDirection.ltr))
      ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF), fontSize: 38, fontFamily: icon.fontFamily, fontFamilyFallback: const []))
      ..addText(String.fromCharCode(icon.codePoint));
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 80));
    c.drawParagraph(para, Offset(ctr.dx - para.longestLine / 2, ctr.dy - para.height / 2));
    final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 26, height: 26);
  }

  /// Teardrop 30, white glyph dot, 2.5 surface ring.
  static Future<BitmapDescriptor> _teardrop(Color fill, Color ring) async {
    const w = 60.0, h = 72.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final pin = Path()
      ..moveTo(w / 2, h - 2)
      ..cubicTo(w * .42, h * .78, 7, h * .55, 7, 28)
      ..arcToPoint(const Offset(w - 7, 28), radius: const Radius.circular(23))
      ..cubicTo(w - 7, h * .55, w * .58, h * .78, w / 2, h - 2)
      ..close();
    c.drawPath(pin, Paint()..color = ring);
    c.save();
    c.translate(w / 2, h / 2);
    c.scale(.84);
    c.translate(-w / 2, -h / 2 - 2);
    c.drawPath(pin, Paint()..color = fill);
    c.restore();
    c.drawCircle(const Offset(w / 2, 27), 7, Paint()..color = const Color(0xFFFFFFFF));
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 30, height: 36);
  }

  List<LatLng> get _all => [
        for (final z in _zones) ...z.points,
        for (final d in _dumpsites) d.position,
        for (final t in _trees) t.position,
      ];

  int get _treeCount => _trees.fold(0, (s, t) => s + t.count);

  Future<void> _fit() async {
    final c = _controller;
    final pts = _all;
    if (c == null || pts.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts.skip(1)) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    if ((n - s).abs() < 1e-5 && (e - w).abs() < 1e-5) {
      await c.moveCamera(CameraUpdate.newLatLngZoom(pts.first, 16));
    } else {
      await c.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)), 40));
    }
  }

  void _evidence(String eyebrow, String title, String detail) {
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    showCanopySheet(context, builder: (_) => CanopySheetBody(title: title, caption: eyebrow, children: [
          Text(detail, style: CanopyType.body.copyWith(color: context.canopy.ink)),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final preview = widget.onOpen != null;
    Widget body;
    if (_loading) {
      body = SizedBox(height: widget.height, child: const CanopySkeleton(height: double.infinity));
    } else if (_error != null) {
      body = SizedBox(height: widget.height, child: CanopyErrorState(title: _error!, onRetry: _load, inline: true));
    } else if (_all.isEmpty) {
      body = SizedBox(
        height: widget.height * .7,
        child: const CanopyEmptyState(
          icon: Icons.map_outlined,
          title: 'No spatial evidence yet',
          line: 'Territory boundaries, dumpsites and recorded trees appear here.',
        ),
      );
    } else {
      body = SizedBox(
        height: widget.height,
        child: Stack(children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _all.first, zoom: 14),
            style: canopyMapStyle(context),
            onMapCreated: (c) {
              _controller = c;
              _fit();
            },
            polygons: {
              for (final z in _zones)
                Polygon(
                  polygonId: PolygonId('fp_${z.id}'),
                  points: z.points,
                  fillColor: CanopyField.zoneFill(p),
                  strokeColor: CanopyField.zoneStroke(p),
                  strokeWidth: 2,
                  consumeTapEvents: true,
                  onTap: () => _evidence('Territory', z.label, '${z.points.length} boundary points'),
                ),
            },
            markers: {
              for (final d in _dumpsites)
                Marker(
                  markerId: MarkerId('fp_${d.id}'),
                  position: d.position,
                  icon: _dumpsiteIcon ?? BitmapDescriptor.defaultMarker,
                  onTap: () => _evidence('Dumpsite', d.name, d.active ? 'Active site' : 'Inactive site'),
                ),
              for (final t in _trees)
                Marker(
                  markerId: MarkerId('fp_${t.key}'),
                  position: t.position,
                  icon: _treeIcon ?? BitmapDescriptor.defaultMarker,
                  anchor: const Offset(0.5, 0.5),
                  onTap: () => _evidence('Planting', '${t.count} tree${t.count == 1 ? '' : 's'}', t.summary),
                ),
            },
            scrollGesturesEnabled: !preview,
            zoomGesturesEnabled: !preview,
            rotateGesturesEnabled: !preview,
            tiltGesturesEnabled: !preview,
            compassEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          if (preview)
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Open territory',
                child: Material(color: Colors.transparent, child: InkWell(onTap: widget.onOpen)),
              ),
            ),
        ]),
      );
    }
    final area = widget.operatingArea.trim();
    return CanopyCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(CanopyRadius.md - 1)), child: body),
        Padding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.s12, CanopySpace.s8, CanopySpace.s4, CanopySpace.s8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MapLegend(items: [
                  (CanopyField.zoneStroke(p), '${_zones.length} zone${_zones.length == 1 ? '' : 's'}'),
                  (p.danger, '${_dumpsites.length} dumpsite${_dumpsites.length == 1 ? '' : 's'}'),
                  (p.primaryDim, '$_treeCount tree${_treeCount == 1 ? '' : 's'}'),
                ]),
                if (area.isNotEmpty) Text('Operating in $area', style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ]),
            ),
            if (preview)
              Icon(Icons.chevron_right, color: p.inkFaint)
            else
              CanopyIconButton(icon: Icons.refresh, tooltip: 'Refresh map', onPressed: _load),
          ]),
        ),
      ]),
    );
  }
}

class _Zone {
  final String id;
  final String label;
  final List<LatLng> points;
  const _Zone(this.id, this.label, this.points);
}

class _Site {
  final String id;
  final String name;
  final LatLng position;
  final bool active;
  const _Site(this.id, this.name, this.position, this.active);
}

class _TreeGroup {
  final String key;
  final LatLng position;
  final Map<String, int> species = {};
  _TreeGroup(this.key, this.position);

  void add(String s, int n) => species.update(s, (c) => c + n, ifAbsent: () => n);
  int get count => species.values.fold(0, (a, b) => a + b);
  String get summary => species.entries.map((e) => e.value == 1 ? e.key : '${e.value} × ${e.key}').join(', ');
}
