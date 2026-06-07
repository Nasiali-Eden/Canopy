// lib/EnvironmentalOps/Shared/zone_drawing_controller.dart
//
// Tap-on-map zone drawing — no manual lat/lng input.
// User taps the map to place numbered pins; polyline and polygon
// update live. "Close Zone" seals the shape; "Save Zone" confirms.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';

// ─── Zone type ────────────────────────────────────────────────────────────────
enum ZoneType { collectionZone, plantingZone }

// ─── Configuration ────────────────────────────────────────────────────────────
class ZoneDrawingConfig {
  final ZoneType zoneType;
  final Color overlayColor;
  final int minPins;
  final bool requireFollowUp;

  const ZoneDrawingConfig({
    required this.zoneType,
    required this.overlayColor,
    this.minPins = 3,
    this.requireFollowUp = false,
  });

  static const ZoneDrawingConfig collectionDefault = ZoneDrawingConfig(
    zoneType: ZoneType.collectionZone,
    overlayColor: Color(0xFF2D7A4F),
    minPins: 3,
  );

  static const ZoneDrawingConfig plantingDefault = ZoneDrawingConfig(
    zoneType: ZoneType.plantingZone,
    overlayColor: Color(0xFF388E3C),
    minPins: 3,
    requireFollowUp: true,
  );
}

// ─── Drawing state ────────────────────────────────────────────────────────────
enum ZoneDrawingState { drawing, closed }

// ─── Result ───────────────────────────────────────────────────────────────────
class ZoneDrawingResult {
  final List<LatLng> vertices;
  final ZoneType zoneType;

  const ZoneDrawingResult({required this.vertices, required this.zoneType});

  double get areaKm2 {
    if (vertices.length < 3) return 0;
    const earthRadius = 6371.0;
    double area = 0;
    final n = vertices.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = vertices[i].longitude * math.pi / 180;
      final yi = vertices[i].latitude * math.pi / 180;
      final xj = vertices[j].longitude * math.pi / 180;
      final yj = vertices[j].latitude * math.pi / 180;
      area += (xj - xi) * (2 + math.sin(yi) + math.sin(yj));
    }
    return (area * earthRadius * earthRadius / 2).abs();
  }
}

// ─── Zone Drawing Controller ──────────────────────────────────────────────────
class ZoneDrawingController extends StatefulWidget {
  final ZoneDrawingConfig config;
  final void Function(ZoneDrawingResult result) onZoneClosed;
  final VoidCallback? onCancel;
  final CameraPosition initialPosition;
  final String mapStyle;

  const ZoneDrawingController({
    super.key,
    required this.config,
    required this.onZoneClosed,
    this.onCancel,
    required this.initialPosition,
    this.mapStyle = '',
  });

  @override
  State<ZoneDrawingController> createState() => ZoneDrawingControllerState();
}

class ZoneDrawingControllerState extends State<ZoneDrawingController> {
  GoogleMapController? _mapController;

  final List<LatLng> _pins = [];
  ZoneDrawingState _drawState = ZoneDrawingState.drawing;

  // Cached numbered pin icons
  final Map<int, BitmapDescriptor> _pinIcons = {};

  // ── Tap handler ──────────────────────────────────────────────────────────
  void _onMapTap(LatLng pos) {
    if (_drawState == ZoneDrawingState.closed) return;
    if (_pins.length >= 50) return; // reasonable cap
    _ensurePinIcon(_pins.length + 1); // pre-generate next icon
    setState(() => _pins.add(pos));
  }

  void _undoLast() {
    if (_pins.isEmpty) return;
    setState(() {
      _drawState = ZoneDrawingState.drawing;
      _pins.removeLast();
    });
  }

  void _closeZone() {
    if (_pins.length < widget.config.minPins) return;
    setState(() => _drawState = ZoneDrawingState.closed);
    _fitBounds();
  }

  void _reopenZone() {
    setState(() => _drawState = ZoneDrawingState.drawing);
  }

  void _confirmZone() {
    if (_pins.length < widget.config.minPins) return;
    widget.onZoneClosed(ZoneDrawingResult(
      vertices: List.unmodifiable(_pins),
      zoneType: widget.config.zoneType,
    ));
  }

  void _fitBounds() {
    if (_pins.length < 2 || _mapController == null) return;
    final bounds = _pins.fold<LatLngBounds>(
      LatLngBounds(southwest: _pins.first, northeast: _pins.first),
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
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
  }

  // ── Marker icons ─────────────────────────────────────────────────────────
  Future<void> _ensurePinIcon(int number) async {
    if (_pinIcons.containsKey(number)) return;
    final icon = await _buildNumberedPin(
      number: number,
      color: number == 1
          ? widget.config.overlayColor
          : widget.config.overlayColor.withOpacity(0.75),
      size: 60.0,
    );
    if (mounted) setState(() => _pinIcons[number] = icon);
  }

  Future<BitmapDescriptor> _buildNumberedPin({
    required int number,
    required Color color,
    required double size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;

    // Drop shadow
    canvas.drawCircle(
      Offset(r, r + 3),
      r - 6,
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Circle fill
    canvas.drawCircle(
      Offset(r, r),
      r - 6,
      Paint()..color = color,
    );
    // White ring
    canvas.drawCircle(
      Offset(r, r),
      r - 7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Number text
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, textDirection: ui.TextDirection.ltr),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: size * 0.32,
        fontWeight: ui.FontWeight.w800,
      ))
      ..addText('$number');
    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(para, Offset(0, r - para.height / 2));

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ── Map objects ──────────────────────────────────────────────────────────
  Set<Marker> get _markers {
    return _pins.asMap().entries.map((e) {
      final n = e.key + 1;
      final icon = _pinIcons[n] ??
          BitmapDescriptor.defaultMarkerWithHue(
              widget.config.zoneType == ZoneType.collectionZone
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueCyan);
      return Marker(
        markerId: MarkerId('pin_$n'),
        position: e.value,
        icon: icon,
        zIndex: e.key == 0 ? 2.0 : 1.0,
        infoWindow: InfoWindow.noText,
        draggable: _drawState == ZoneDrawingState.drawing,
        onDragEnd: (newPos) {
          setState(() => _pins[e.key] = newPos);
        },
      );
    }).toSet();
  }

  Set<Polyline> get _polylines {
    if (_pins.length < 2) return {};
    final points = [..._pins];
    if (_drawState == ZoneDrawingState.closed) points.add(_pins.first);
    return {
      Polyline(
        polylineId: const PolylineId('zone_outline'),
        points: points,
        color: widget.config.overlayColor,
        width: 3,
        patterns: _drawState == ZoneDrawingState.drawing
            ? [PatternItem.dash(16), PatternItem.gap(8)]
            : [],
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Polygon> get _polygons {
    if (_drawState != ZoneDrawingState.closed || _pins.length < 3) return {};
    return {
      Polygon(
        polygonId: const PolygonId('zone_fill'),
        points: _pins,
        fillColor: widget.config.overlayColor.withOpacity(0.20),
        strokeColor: widget.config.overlayColor,
        strokeWidth: 3,
      ),
    };
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Pre-generate icons on first build
    for (int i = 1; i <= widget.config.minPins; i++) {
      _ensurePinIcon(i);
    }

    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isClosed = _drawState == ZoneDrawingState.closed;
    final canClose = _pins.length >= widget.config.minPins;
    final remaining = math.max(0, widget.config.minPins - _pins.length);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ─────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: widget.initialPosition,
              onMapCreated: (c) {
                _mapController = c;
                if (widget.mapStyle.isNotEmpty) c.setMapStyle(widget.mapStyle);
              },
              onTap: _onMapTap,
              markers: _markers,
              polylines: _polylines,
              polygons: _polygons,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // ── Top status badge ────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.10), blurRadius: 12)
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isClosed
                          ? const Color(0xFF2E7D32)
                          : widget.config.overlayColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isClosed
                          ? Icons.check_rounded
                          : Icons.edit_location_alt_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isClosed
                              ? 'Zone closed  ·  ${_pins.length} pins'
                              : '${_pins.length} pin${_pins.length == 1 ? '' : 's'} placed',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                        Text(
                          isClosed
                              ? '${_computeResult()?.areaKm2.toStringAsFixed(4) ?? "0"} km²'
                              : canClose
                                  ? 'Tap map to refine — ready to close'
                                  : '$remaining more needed to close zone',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.darkGreen.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Cancel / back ───────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            right: 16,
            child: _FloatButton(
              icon: Icons.close,
              color: Colors.white,
              bg: Colors.black.withOpacity(0.45),
              onTap: widget.onCancel ?? () {},
            ),
          ),

          // ── Undo last pin ───────────────────────────────────────────────
          if (_pins.isNotEmpty && !isClosed)
            Positioned(
              bottom: bottomPad + 90,
              right: 16,
              child: _FloatButton(
                icon: Icons.undo_rounded,
                color: Colors.white,
                bg: Colors.black.withOpacity(0.45),
                onTap: _undoLast,
                label: 'Undo',
              ),
            ),

          // ── Fit bounds button ───────────────────────────────────────────
          if (_pins.length >= 2)
            Positioned(
              bottom: bottomPad + 160,
              right: 16,
              child: _FloatButton(
                icon: Icons.fit_screen_rounded,
                color: AppTheme.primary,
                bg: Colors.white,
                onTap: _fitBounds,
              ),
            ),

          // ── Hint bar (drawing mode) ─────────────────────────────────────
          if (!isClosed)
            Positioned(
              bottom: bottomPad + 90,
              left: 16,
              right: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 15,
                        color: widget.config.overlayColor),
                    const SizedBox(width: 8),
                    Text(
                      _pins.isEmpty
                          ? 'Tap the map to place zone pins'
                          : 'Tap to add · drag pins to adjust',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom action bar ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Close Zone / Save Zone / Edit Zone
                  Expanded(
                    flex: 2,
                    child: isClosed
                        ? Row(
                            children: [
                              // Edit
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _reopenZone,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: widget.config.overlayColor
                                            .withOpacity(0.5)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: widget.config.overlayColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Save
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _confirmZone,
                                  icon: const Icon(Icons.save_rounded,
                                      size: 15, color: Colors.white),
                                  label: const Text(
                                    'Save Zone',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        widget.config.overlayColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: canClose ? _closeZone : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canClose
                                  ? widget.config.overlayColor
                                  : Colors.grey.shade100,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: Text(
                              canClose
                                  ? 'Close Zone'
                                  : '$remaining more pin${remaining == 1 ? '' : 's'} needed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: canClose
                                    ? Colors.white
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ZoneDrawingResult? _computeResult() {
    if (_pins.length < 3) return null;
    return ZoneDrawingResult(
        vertices: _pins, zoneType: widget.config.zoneType);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// ─── Float button ─────────────────────────────────────────────────────────────
class _FloatButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  final String? label;

  const _FloatButton({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12), blurRadius: 10)
          ],
        ),
        child: label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 5),
                  Text(label!,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              )
            : Icon(icon, size: 19, color: color),
      ),
    );
  }
}
