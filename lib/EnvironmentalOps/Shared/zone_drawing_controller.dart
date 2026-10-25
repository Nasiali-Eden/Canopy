// lib/EnvironmentalOps/Shared/zone_drawing_controller.dart
//
// Tap mode (ENVOPS_HANDOFF §3.2): full map, GPS chip, instruction toast,
// numbered vertex pins (24 circle, surface, 2.5 ink ring; last one haloed),
// draft outline dashed in warning, and the TapModeSheet — "N points" +
// "Draft · kept on this phone", Undo + Close zone (56), Save zone disabled
// until closed. [onPointsChanged] lets the caller keep the draft on device.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import '../envops_ui.dart';

enum ZoneType { collectionZone, plantingZone }

class ZoneDrawingConfig {
  final ZoneType zoneType;

  /// Kept for call-site compatibility; overlays use field tokens.
  final Color overlayColor;
  final int minPins;
  final bool requireFollowUp;

  const ZoneDrawingConfig({required this.zoneType, required this.overlayColor, this.minPins = 3, this.requireFollowUp = false});

  static const ZoneDrawingConfig collectionDefault =
      ZoneDrawingConfig(zoneType: ZoneType.collectionZone, overlayColor: Color(0xFF2D7A4F));
  static const ZoneDrawingConfig plantingDefault =
      ZoneDrawingConfig(zoneType: ZoneType.plantingZone, overlayColor: Color(0xFF2D7A4F), requireFollowUp: true);
}

enum ZoneDrawingState { drawing, closed }

class ZoneDrawingResult {
  final List<LatLng> vertices;
  final ZoneType zoneType;

  const ZoneDrawingResult({required this.vertices, required this.zoneType});

  double get areaKm2 {
    if (vertices.length < 3) return 0;
    const r = 6371.0;
    var area = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      final j = (i + 1) % vertices.length;
      final xi = vertices[i].longitude * math.pi / 180, yi = vertices[i].latitude * math.pi / 180;
      final xj = vertices[j].longitude * math.pi / 180, yj = vertices[j].latitude * math.pi / 180;
      area += (xj - xi) * (2 + math.sin(yi) + math.sin(yj));
    }
    return (area * r * r / 2).abs();
  }
}

/// "0.042 km²" or "4,200 m²" for small areas.
String formatArea(double km2) {
  if (km2 < 0.01) {
    final m2 = (km2 * 1e6).round();
    return '${m2.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} m²';
  }
  return '${km2.toStringAsFixed(km2 < 1 ? 3 : 2)} km²';
}

/// Numbered vertex pin: 24 circle, surface fill, 2.5 ink ring, ink number.
Future<BitmapDescriptor> vertexPin(int n, {required Color surface, required Color ink, bool halo = false}) async {
  const s = 64.0; // drawn at ~2.7× for crispness, shown at 24 (+halo)
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const o = Offset(s / 2, s / 2);
  if (halo) c.drawCircle(o, s / 2, Paint()..color = ink.withAlpha(0x33));
  c.drawCircle(o, 18, Paint()..color = surface);
  c.drawCircle(o, 18, Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5);
  final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
    ..pushStyle(ui.TextStyle(color: ink, fontSize: n > 9 ? 15 : 18, fontWeight: ui.FontWeight.w800))
    ..addText('$n');
  final para = pb.build()..layout(const ui.ParagraphConstraints(width: s));
  c.drawParagraph(para, Offset(0, s / 2 - para.height / 2));
  final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: halo ? 34 : 30, height: halo ? 34 : 30);
}

class ZoneDrawingController extends StatefulWidget {
  final ZoneDrawingConfig config;
  final void Function(ZoneDrawingResult result) onZoneClosed;
  final VoidCallback? onCancel;
  final CameraPosition initialPosition;
  final ValueChanged<List<LatLng>>? onPointsChanged;
  final List<LatLng> initialPoints;

  /// Unused — the map follows the app theme. Kept for call sites.
  final String mapStyle;

  const ZoneDrawingController({
    super.key,
    required this.config,
    required this.onZoneClosed,
    this.onCancel,
    required this.initialPosition,
    this.onPointsChanged,
    this.initialPoints = const [],
    this.mapStyle = '',
  });

  @override
  State<ZoneDrawingController> createState() => ZoneDrawingControllerState();
}

class ZoneDrawingControllerState extends State<ZoneDrawingController> {
  GoogleMapController? _map;
  late final List<LatLng> _pins = [...widget.initialPoints];
  ZoneDrawingState _state = ZoneDrawingState.drawing;
  final Map<String, BitmapDescriptor> _icons = {};
  StreamSubscription<Position>? _gps;
  double? _accuracy;
  bool _gpsTimedOut = false;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _startGps();
  }

  @override
  void dispose() {
    _gps?.cancel();
    _gpsTimer?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _startGps() async {
    _gpsTimer = Timer(CanopyField.gpsTimeout, () {
      if (mounted && _accuracy == null) setState(() => _gpsTimedOut = true);
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      _gps = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
          .listen((p) => mounted ? setState(() => _accuracy = p.accuracy) : null, onError: (_) {});
    } catch (_) {}
  }

  void _changed() => widget.onPointsChanged?.call(List.unmodifiable(_pins));

  void _onTap(LatLng pos) {
    if (_state == ZoneDrawingState.closed || _pins.length >= 50) return;
    setState(() => _pins.add(pos));
    _changed();
  }

  void _undo() {
    if (_pins.isEmpty) return;
    setState(() {
      _state = ZoneDrawingState.drawing;
      _pins.removeLast();
    });
    _changed();
  }

  void _close() {
    if (_pins.length < widget.config.minPins) return;
    setState(() => _state = ZoneDrawingState.closed);
    _fit();
  }

  void _save() {
    if (_state != ZoneDrawingState.closed) return;
    widget.onZoneClosed(ZoneDrawingResult(vertices: List.unmodifiable(_pins), zoneType: widget.config.zoneType));
  }

  void _fit() {
    if (_pins.length < 2 || _map == null) return;
    var s = _pins.first.latitude, n = s, w = _pins.first.longitude, e = w;
    for (final p in _pins) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    _map!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)), 70));
  }

  Future<void> _ensureIcon(int n, bool last, CanopyPalette p) async {
    final key = '$n$last${p.ink.toARGB32()}';
    if (_icons.containsKey(key)) return;
    final icon = await vertexPin(n, surface: p.surface, ink: p.ink, halo: last);
    if (mounted) setState(() => _icons[key] = icon);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final closed = _state == ZoneDrawingState.closed;
    final canClose = _pins.length >= widget.config.minPins;
    final remaining = math.max(0, widget.config.minPins - _pins.length);

    final markers = <Marker>{};
    for (var i = 0; i < _pins.length; i++) {
      final last = i == _pins.length - 1 && !closed;
      final key = '${i + 1}$last${p.ink.toARGB32()}';
      _ensureIcon(i + 1, last, p);
      markers.add(Marker(
        markerId: MarkerId('v$i'),
        position: _pins[i],
        icon: _icons[key] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(.5, .5),
        zIndex: last ? 2 : 1,
        draggable: !closed,
        onDragEnd: (np) {
          setState(() => _pins[i] = np);
          _changed();
        },
      ));
    }

    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: _pins.isNotEmpty ? CameraPosition(target: _pins.last, zoom: 17) : widget.initialPosition,
            style: canopyMapStyle(context),
            onMapCreated: (c) {
              _map = c;
              if (_pins.length > 1) _fit();
            },
            onTap: _onTap,
            markers: markers,
            polylines: {
              if (_pins.length >= 2 && !closed)
                Polyline(
                  polylineId: const PolylineId('draft'),
                  points: _pins,
                  color: CanopyField.zoneDraftStroke(p),
                  width: 3,
                  patterns: [PatternItem.dash(8), PatternItem.gap(6)],
                ),
            },
            polygons: {
              if (closed && _pins.length >= 3)
                Polygon(
                  polygonId: const PolygonId('zone'),
                  points: _pins,
                  fillColor: CanopyField.zoneFill(p),
                  strokeColor: CanopyField.zoneStroke(p),
                  strokeWidth: 3,
                ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
        Positioned(
          top: top + CanopySpace.s8,
          left: CanopySpace.s12,
          right: CanopySpace.s12,
          child: Row(children: [
            CanopyIconButton(icon: Icons.close, tooltip: 'Leave tap mode', float: true, onPressed: widget.onCancel),
            const Spacer(),
            GpsChip(accuracyM: _accuracy, timedOut: _gpsTimedOut),
            const SizedBox(width: CanopySpace.s8),
            if (_pins.length >= 2) CanopyIconButton(icon: Icons.fit_screen, tooltip: 'Fit the zone', float: true, onPressed: _fit),
          ]),
        ),
        if (!closed)
          Positioned(
            top: top + 64,
            left: CanopySpace.gutter,
            right: CanopySpace.gutter,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s16, vertical: CanopySpace.s8),
                decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(CanopyRadius.pill)),
                child: Text(
                  _pins.isEmpty ? 'Tap each corner of the area, in order' : 'Tap the next corner · drag a point to move it',
                  style: CanopyType.label.copyWith(color: p.canvas),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s16 + bottom),
            decoration: BoxDecoration(
              color: p.canvas,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(CanopyRadius.lg)),
              border: Border(top: BorderSide(color: p.outline)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${_pins.length}', style: CanopyField.signalValue.copyWith(color: p.ink)),
                const SizedBox(width: CanopySpace.s8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      closed
                          ? 'points · ${formatArea(ZoneDrawingResult(vertices: _pins, zoneType: widget.config.zoneType).areaKm2)}'
                          : 'point${_pins.length == 1 ? '' : 's'}${remaining > 0 ? ' · $remaining more to close' : ''}',
                      style: CanopyType.body.copyWith(color: p.inkMuted),
                    ),
                  ),
                ),
              ]),
              Text(widget.onPointsChanged != null ? 'Draft · kept on this phone' : 'Draft', style: CanopyType.caption.copyWith(color: p.inkMuted)),
              const SizedBox(height: CanopySpace.s12),
              Row(children: [
                Expanded(child: FieldButton.secondary(label: 'Undo', icon: Icons.undo, onPressed: _pins.isEmpty ? null : _undo)),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: closed
                      ? FieldButton.secondary(label: 'Reopen', onPressed: () => setState(() => _state = ZoneDrawingState.drawing))
                      : FieldButton.secondary(label: 'Close zone', onPressed: canClose ? _close : null),
                ),
              ]),
              const SizedBox(height: CanopySpace.s12),
              FieldButton(label: 'Save zone', onPressed: closed ? _save : null),
            ]),
          ),
        ),
      ]),
    );
  }
}
