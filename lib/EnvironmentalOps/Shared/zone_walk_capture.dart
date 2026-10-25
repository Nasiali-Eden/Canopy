// lib/EnvironmentalOps/Shared/zone_walk_capture.dart
//
// Walk mode (ENVOPS_HANDOFF §3.2) — the most accurate way to map an area.
// Stand at each corner and capture; the phone's GPS fix becomes a point.
// The preview map is non-interactive and follows you, with an accuracy
// circle. WalkModePanel: "7 / 10 points minimum" (64), instruction, capture
// button 120, Undo last + Finish (enabled at the minimum). GPS state is
// always shown: ≤10 m good, ≤25 m allowed but flagged, worse is blocked
// with the reason, and no fix after 30 s says so.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import '../envops_ui.dart';
import 'zone_drawing_controller.dart' show ZoneDrawingResult, ZoneType, formatArea, vertexPin;

class ZoneWalkCaptureController extends StatefulWidget {
  final ZoneType zoneType;

  /// Kept for call-site compatibility; overlays use field tokens.
  final Color overlayColor;
  final int minPoints;
  final void Function(ZoneDrawingResult result) onZoneClosed;
  final VoidCallback? onCancel;
  final CameraPosition initialPosition;
  final ValueChanged<List<LatLng>>? onPointsChanged;
  final List<LatLng> initialPoints;
  final String mapStyle;

  const ZoneWalkCaptureController({
    super.key,
    this.zoneType = ZoneType.collectionZone,
    this.overlayColor = const Color(0xFF2D7A4F),
    this.minPoints = CanopyField.walkMinPoints,
    required this.onZoneClosed,
    this.onCancel,
    required this.initialPosition,
    this.onPointsChanged,
    this.initialPoints = const [],
    this.mapStyle = '',
  });

  @override
  State<ZoneWalkCaptureController> createState() => _ZoneWalkCaptureControllerState();
}

class _ZoneWalkCaptureControllerState extends State<ZoneWalkCaptureController> {
  GoogleMapController? _preview;
  StreamSubscription<Position>? _sub;
  Timer? _timeout;
  late final List<LatLng> _points = [...widget.initialPoints];
  late final List<double?> _acc = List.filled(widget.initialPoints.length, null, growable: true);
  Position? _here;
  bool _timedOut = false, _capturing = false;
  String? _problem;
  final Map<String, BitmapDescriptor> _icons = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _timeout = Timer(CanopyField.gpsTimeout, () {
      if (mounted && _here == null) setState(() => _timedOut = true);
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _problem = 'Location is switched off on this phone. Turn it on to walk the boundary.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _problem = 'Canopy isn\'t allowed to use location. You can tap the boundary on the map instead.');
        return;
      }
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _here = pos;
          _timedOut = false;
        });
        _preview?.moveCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
      }, onError: (_) {});
    } catch (_) {
      if (mounted) setState(() => _problem = "GPS couldn't start.");
    }
  }

  GpsState get _gps => gpsStateFor(_here?.accuracy, timedOut: _timedOut);
  bool get _canCapture => !_capturing && (_gps == GpsState.good || _gps == GpsState.weak);

  Future<void> _capture() async {
    if (!_canCapture) return;
    setState(() => _capturing = true);
    try {
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation))
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        pos = _here!;
      }
      if (pos.accuracy > CanopyField.gpsWeakMax) {
        if (mounted) showCanopySnack(context, 'Signal dropped to ±${pos.accuracy.round()} m — not captured. Move into the open and try again.', error: true);
        return;
      }
      setState(() {
        _points.add(LatLng(pos.latitude, pos.longitude));
        _acc.add(pos.accuracy);
      });
      widget.onPointsChanged?.call(List.unmodifiable(_points));
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't get a GPS fix. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() {
      _points.removeLast();
      if (_acc.isNotEmpty) _acc.removeLast();
    });
    widget.onPointsChanged?.call(List.unmodifiable(_points));
  }

  void _finish() {
    if (_points.length < widget.minPoints) return;
    widget.onZoneClosed(ZoneDrawingResult(vertices: List.unmodifiable(_points), zoneType: widget.zoneType));
  }

  Future<void> _icon(int n, bool last, CanopyPalette p) async {
    final k = '$n$last${p.ink.toARGB32()}';
    if (_icons.containsKey(k)) return;
    final i = await vertexPin(n, surface: p.surface, ink: p.ink, halo: last);
    if (mounted) setState(() => _icons[k] = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final count = _points.length;
    final ready = count >= widget.minPoints;
    final flagged = _acc.whereType<double>().where((a) => a > CanopyField.gpsGood).length;
    final here = _here;

    final markers = <Marker>{};
    for (var i = 0; i < count; i++) {
      final last = i == count - 1;
      _icon(i + 1, last, p);
      markers.add(Marker(
        markerId: MarkerId('w$i'),
        position: _points[i],
        anchor: const Offset(.5, .5),
        icon: _icons['${i + 1}$last${p.ink.toARGB32()}'] ?? BitmapDescriptor.defaultMarker,
      ));
    }

    final instruction = _problem ??
        switch (_gps) {
          GpsState.finding => 'Finding your location… stay in the open.',
          GpsState.failed => GpsChip.reasonFor(GpsState.failed),
          GpsState.blocked => GpsChip.reasonFor(GpsState.blocked),
          _ => count == 0
              ? 'Stand at the first corner of the area, then capture.'
              : ready
                  ? 'Enough points. Capture more corners for a closer fit, or finish.'
                  : 'Walk to the next corner and capture.',
        };

    return Scaffold(
      backgroundColor: p.canvas,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(CanopySpace.s12, top + CanopySpace.s8, CanopySpace.s12, CanopySpace.s8),
          child: Row(children: [
            CanopyIconButton(icon: Icons.close, tooltip: 'Leave walk mode', onPressed: widget.onCancel),
            const SizedBox(width: CanopySpace.s8),
            Expanded(child: Text('Walk the boundary', style: CanopyType.subhead.copyWith(color: p.ink))),
            GpsChip(accuracyM: here?.accuracy, timedOut: _timedOut),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: IgnorePointer(
                child: GoogleMap(
                  initialCameraPosition: widget.initialPosition,
                  style: canopyMapStyle(context),
                  onMapCreated: (c) => _preview = c,
                  markers: markers,
                  circles: {
                    if (here != null)
                      Circle(
                        circleId: const CircleId('acc'),
                        center: LatLng(here.latitude, here.longitude),
                        radius: here.accuracy,
                        fillColor: CanopyField.accuracyFill,
                        strokeColor: CanopyField.accuracyStroke,
                        strokeWidth: 1,
                      ),
                  },
                  polylines: {
                    if (count >= 2)
                      Polyline(
                        polylineId: const PolylineId('trace'),
                        points: [..._points, if (ready) _points.first],
                        color: ready ? CanopyField.zoneStroke(p) : CanopyField.zoneDraftStroke(p),
                        width: 3,
                        patterns: ready ? const [] : [PatternItem.dash(8), PatternItem.gap(6)],
                      ),
                  },
                  polygons: {
                    if (ready)
                      Polygon(polygonId: const PolygonId('fill'), points: _points, fillColor: CanopyField.zoneFill(p), strokeWidth: 0),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),
              ),
            ),
          ]),
        ),
        // ── WalkModePanel ─────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s16 + bottom),
          decoration: BoxDecoration(color: p.canvas, border: Border(top: BorderSide(color: p.outline))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$count', style: CanopyField.bigNumber.copyWith(fontSize: 64, color: p.ink)),
              const SizedBox(width: CanopySpace.s8),
              Expanded(
                child: Text(
                  ready ? 'points · ${formatArea(ZoneDrawingResult(vertices: _points, zoneType: widget.zoneType).areaKm2)}' : '/ ${widget.minPoints} points minimum',
                  style: CanopyType.subhead.copyWith(color: p.inkMuted),
                ),
              ),
            ]),
            if (flagged > 0)
              Text('$flagged point${flagged == 1 ? '' : 's'} captured on a weak signal — flagged.',
                  style: CanopyType.caption.copyWith(color: p.warning)),
            if (widget.onPointsChanged != null && count > 0)
              Text('Draft · kept on this phone', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            const SizedBox(height: CanopySpace.s8),
            Text(instruction,
                style: CanopyType.body.copyWith(color: _problem != null || _gps == GpsState.blocked || _gps == GpsState.failed ? p.danger : p.ink)),
            const SizedBox(height: CanopySpace.s16),
            Center(
              child: _capturing
                  ? const SizedBox(width: 132, height: 132, child: Center(child: CircularProgressIndicator()))
                  : CaptureButton(label: 'Capture\npoint', size: 120, onPressed: _canCapture ? _capture : null),
            ),
            const SizedBox(height: CanopySpace.s16),
            Row(children: [
              Expanded(child: FieldButton.secondary(label: 'Undo last', icon: Icons.undo, onPressed: count == 0 ? null : _undo)),
              const SizedBox(width: CanopySpace.s12),
              Expanded(child: FieldButton(label: ready ? 'Finish' : '${math.max(0, widget.minPoints - count)} to go', onPressed: ready ? _finish : null)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
