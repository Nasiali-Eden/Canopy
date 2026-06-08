// lib/EnvironmentalOps/Shared/zone_walk_capture.dart
//
// Walk-and-capture zone tracing — NO map tapping.
// The user physically walks the boundary and taps "Capture Point" at each
// corner; the device GPS fix becomes a vertex. A minimum number of points
// (default 10) is required. The map is a NON-interactive preview only — it
// is never used to select or place pins.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';
import 'zone_drawing_controller.dart' show ZoneDrawingResult, ZoneType;

class ZoneWalkCaptureController extends StatefulWidget {
  final ZoneType zoneType;
  final Color overlayColor;
  final int minPoints;
  final void Function(ZoneDrawingResult result) onZoneClosed;
  final VoidCallback? onCancel;
  final CameraPosition initialPosition;
  final String mapStyle;

  const ZoneWalkCaptureController({
    super.key,
    this.zoneType = ZoneType.collectionZone,
    this.overlayColor = const Color(0xFF2D7A4F),
    this.minPoints = 10,
    required this.onZoneClosed,
    this.onCancel,
    required this.initialPosition,
    this.mapStyle = '',
  });

  @override
  State<ZoneWalkCaptureController> createState() =>
      _ZoneWalkCaptureControllerState();
}

class _ZoneWalkCaptureControllerState extends State<ZoneWalkCaptureController> {
  GoogleMapController? _preview;
  StreamSubscription<Position>? _posSub;

  final List<LatLng> _points = [];
  final List<double> _accuracies = [];

  Position? _current;
  bool _capturing = false;
  String? _status; // null = ok; otherwise a problem message

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _preview?.dispose();
    super.dispose();
  }

  // ── Location tracking ──────────────────────────────────────────────────────
  Future<void> _startTracking() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _status = 'Location services are off. Enable GPS.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permission denied.');
        return;
      }

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _current = pos;
          _status = null;
        });
        // Follow the user while still building the boundary.
        if (_points.isEmpty) {
          _preview?.moveCamera(
            CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
          );
        }
      }, onError: (_) {
        if (mounted) setState(() => _status = 'Waiting for GPS signal…');
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not start GPS.');
    }
  }

  // ── Capture / undo ─────────────────────────────────────────────────────────
  Future<void> _capturePoint() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      // Prefer a fresh high-accuracy fix; fall back to the last streamed one.
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        if (_current == null) rethrow;
        pos = _current!;
      }
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _points.add(p);
        _accuracies.add(pos.accuracy);
      });
      _fitPreview();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get a GPS fix — try again')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() {
      _points.removeLast();
      if (_accuracies.isNotEmpty) _accuracies.removeLast();
    });
    _fitPreview();
  }

  void _save() {
    if (_points.length < widget.minPoints) return;
    widget.onZoneClosed(ZoneDrawingResult(
      vertices: List.unmodifiable(_points),
      zoneType: widget.zoneType,
    ));
  }

  void _fitPreview() {
    if (_preview == null || _points.isEmpty) return;
    if (_points.length == 1) {
      _preview!.moveCamera(CameraUpdate.newLatLngZoom(_points.first, 17));
      return;
    }
    final bounds = _points.fold<LatLngBounds>(
      LatLngBounds(southwest: _points.first, northeast: _points.first),
      (acc, p) => LatLngBounds(
        southwest: LatLng(
          math.min(acc.southwest.latitude, p.latitude),
          math.min(acc.southwest.longitude, p.longitude),
        ),
        northeast: LatLng(
          math.max(acc.northeast.latitude, p.latitude),
          math.max(acc.northeast.longitude, p.longitude),
        ),
      ),
    );
    _preview!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  // ── Derived ────────────────────────────────────────────────────────────────
  double get _areaKm2 => ZoneDrawingResult(
        vertices: _points,
        zoneType: widget.zoneType,
      ).areaKm2;

  double? get _accuracy => _current?.accuracy;

  Color get _accuracyColor {
    final a = _accuracy;
    if (a == null) return Colors.grey;
    if (a <= 10) return const Color(0xFF2E7D32);
    if (a <= 25) return AppTheme.tertiary;
    return Colors.orange.shade700;
  }

  Set<Marker> get _markers {
    final m = <Marker>{};
    for (var i = 0; i < _points.length; i++) {
      m.add(Marker(
        markerId: MarkerId('p$i'),
        position: _points[i],
        icon: BitmapDescriptor.defaultMarkerWithHue(
          i == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
        ),
      ));
    }
    return m;
  }

  Set<Polyline> get _polylines {
    if (_points.length < 2) return {};
    final pts = [..._points];
    if (_points.length >= widget.minPoints) pts.add(_points.first); // close ring
    return {
      Polyline(
        polylineId: const PolylineId('trace'),
        points: pts,
        color: widget.overlayColor,
        width: 4,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Polygon> get _polygons {
    if (_points.length < 3) return {};
    return {
      Polygon(
        polygonId: const PolygonId('fill'),
        points: _points,
        fillColor: widget.overlayColor.withOpacity(0.18),
        strokeColor: widget.overlayColor,
        strokeWidth: 2,
      ),
    };
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final count = _points.length;
    final remaining = math.max(0, widget.minPoints - count);
    final canSave = count >= widget.minPoints;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: AppTheme.darkGreen),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Walk the Boundary',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGreen)),
                      Text('Capture a GPS point at each corner',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Map PREVIEW (non-interactive) ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.32,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: widget.initialPosition,
                      onMapCreated: (c) {
                        _preview = c;
                        if (widget.mapStyle.isNotEmpty) {
                          c.setMapStyle(widget.mapStyle);
                        }
                      },
                      markers: _markers,
                      polylines: _polylines,
                      polygons: _polygons,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      // Preview only — disable ALL interaction.
                      zoomGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                    ),
                    // "Preview" badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 13, color: Colors.white),
                            SizedBox(width: 5),
                            Text('Preview',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Live status + progress + points ─────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                _liveCard(),
                const SizedBox(height: 12),
                _progressCard(count, remaining, canSave),
                if (_points.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _pointsCard(),
                ],
              ],
            ),
          ),

          // ── Action bar ──────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: Row(
              children: [
                if (_points.isNotEmpty) ...[
                  _squareBtn(
                    icon: Icons.undo_rounded,
                    onTap: _undo,
                  ),
                  const SizedBox(width: 10),
                ],
                // Capture
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _capturing ? null : _capturePoint,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _capturing
                            ? widget.overlayColor.withOpacity(0.6)
                            : widget.overlayColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.overlayColor.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _capturing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.my_location_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text('Capture Point',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Save
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: canSave ? _save : null,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: canSave
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          canSave ? 'Save Zone' : '$remaining to go',
                          style: TextStyle(
                            color: canSave
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-cards ────────────────────────────────────────────────────────────
  Widget _liveCard() {
    final acc = _accuracy;
    final hasFix = acc != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _accuracyColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFix ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
              color: _accuracyColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status ??
                      (hasFix
                          ? 'GPS ready · ±${acc.toStringAsFixed(0)} m'
                          : 'Acquiring GPS…'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _status != null
                        ? Colors.orange.shade800
                        : AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _current == null
                      ? 'Stand at a corner of the boundary'
                      : '${_current!.latitude.toStringAsFixed(5)}, ${_current!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(int count, int remaining, bool canSave) {
    final pct = (count / widget.minPoints).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$count point${count == 1 ? '' : 's'} captured',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkGreen)),
              const Spacer(),
              if (canSave)
                Text('${_areaKm2.toStringAsFixed(3)} km²',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.overlayColor))
              else
                Text('min ${widget.minPoints}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: widget.overlayColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                  canSave ? const Color(0xFF2E7D32) : widget.overlayColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canSave
                ? 'Boundary ready — walk more corners or save'
                : 'Capture $remaining more point${remaining == 1 ? '' : 's'} to trace the zone',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _pointsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Captured points',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_points.length, (i) {
              final acc = i < _accuracies.length ? _accuracies[i] : null;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.overlayColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: widget.overlayColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: widget.overlayColor)),
                    if (acc != null) ...[
                      const SizedBox(width: 5),
                      Text('±${acc.toStringAsFixed(0)}m',
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.black45)),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _squareBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, color: AppTheme.darkGreen, size: 22),
      ),
    );
  }
}
