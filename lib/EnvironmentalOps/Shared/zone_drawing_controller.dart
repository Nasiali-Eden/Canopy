import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    this.minPins = 10,
    this.requireFollowUp = false,
  });

  static const ZoneDrawingConfig collectionDefault = ZoneDrawingConfig(
    zoneType: ZoneType.collectionZone,
    overlayColor: Color(0xFF2D7A4F),
    minPins: 10,
    requireFollowUp: false,
  );

  static const ZoneDrawingConfig plantingDefault = ZoneDrawingConfig(
    zoneType: ZoneType.plantingZone,
    overlayColor: Color(0xFF388E3C),
    minPins: 3,
    requireFollowUp: true,
  );
}

// ─── Drawing state ────────────────────────────────────────────────────────────
enum ZoneDrawingState { idle, drawing, closed }

// ─── Result ───────────────────────────────────────────────────────────────────
class ZoneDrawingResult {
  final List<LatLng> vertices;
  final ZoneType zoneType;

  const ZoneDrawingResult({required this.vertices, required this.zoneType});

  double get areaKm2 {
    if (vertices.length < 3) return 0;
    // Shoelace formula on spherical coordinates (approximate)
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

// ─── Zone Drawing Controller ─────────────────────────────────────────────────
// Wraps a GoogleMap and manages the tap-to-pin drawing interaction.
// Calls [onZoneClosed] with the final polygon vertices when the zone is saved.
class ZoneDrawingController extends StatefulWidget {
  final ZoneDrawingConfig config;
  final void Function(ZoneDrawingResult result) onZoneClosed;
  final CameraPosition initialPosition;
  final String mapStyle;

  const ZoneDrawingController({
    super.key,
    required this.config,
    required this.onZoneClosed,
    required this.initialPosition,
    this.mapStyle = '',
  });

  @override
  State<ZoneDrawingController> createState() => ZoneDrawingControllerState();
}

class ZoneDrawingControllerState extends State<ZoneDrawingController>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  ZoneDrawingState _state = ZoneDrawingState.idle;
  final List<LatLng> _pins = [];
  final List<_RippleAnimation> _ripples = [];

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (int i = 0; i < _pins.length; i++) {
      markers.add(Marker(
        markerId: MarkerId('zone_pin_$i'),
        position: _pins[i],
        icon: i == 0
            ? BitmapDescriptor.defaultMarkerWithHue(
                widget.config.zoneType == ZoneType.collectionZone
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueCyan)
            : BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
        draggable: _state == ZoneDrawingState.drawing,
        onDrag: (newPos) => setState(() => _pins[i] = newPos),
      ));
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    if (_pins.length < 2) return {};
    final points = [..._pins];
    if (_state == ZoneDrawingState.closed) points.add(_pins.first);
    return {
      Polyline(
        polylineId: const PolylineId('zone_outline'),
        points: points,
        color: widget.config.overlayColor,
        width: 3,
        patterns: _state == ZoneDrawingState.drawing
            ? [PatternItem.dash(16), PatternItem.gap(8)]
            : [],
      ),
    };
  }

  Set<Polygon> get _polygons {
    if (_state != ZoneDrawingState.closed || _pins.length < 3) return {};
    return {
      Polygon(
        polygonId: const PolygonId('zone_fill'),
        points: _pins,
        fillColor: widget.config.overlayColor.withOpacity(0.22),
        strokeColor: widget.config.overlayColor,
        strokeWidth: 3,
      ),
    };
  }

  void startDrawing() {
    setState(() {
      _state = ZoneDrawingState.drawing;
      _pins.clear();
      _ripples.clear();
    });
  }

  void cancelDrawing() {
    setState(() {
      _state = ZoneDrawingState.idle;
      _pins.clear();
      _ripples.clear();
    });
  }

  void closeZone() {
    if (_pins.length < widget.config.minPins) return;
    setState(() => _state = ZoneDrawingState.closed);
  }

  void confirmZone() {
    if (_state != ZoneDrawingState.closed) return;
    widget.onZoneClosed(ZoneDrawingResult(
      vertices: List.unmodifiable(_pins),
      zoneType: widget.config.zoneType,
    ));
    setState(() {
      _state = ZoneDrawingState.idle;
      _pins.clear();
      _ripples.clear();
    });
  }

  void _onMapTap(LatLng pos) {
    if (_state != ZoneDrawingState.drawing) return;
    setState(() {
      _pins.add(pos);
      final controller = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      final ripple = _RippleAnimation(position: pos, controller: controller);
      _ripples.add(ripple);
      controller.forward().whenComplete(() {
        setState(() => _ripples.remove(ripple));
        controller.dispose();
      });
    });
  }

  @override
  void dispose() {
    for (final r in _ripples) {
      r.controller.dispose();
    }
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: widget.initialPosition,
          onMapCreated: (c) {
            _mapController = c;
            if (widget.mapStyle.isNotEmpty) c.setMapStyle(widget.mapStyle);
          },
          onTap: _onMapTap,
          markers: _markers,
          polylines: _polylines,
          polygons: _polygons,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // ── Ripple overlays ──
        ..._ripples.map((r) => _RippleWidget(ripple: r)),

        // ── Drawing controls overlay ──
        if (_state != ZoneDrawingState.idle)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pin count indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _state == ZoneDrawingState.closed
                      ? Icons.check_circle
                      : Icons.location_on,
                  size: 16,
                  color: widget.config.overlayColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _state == ZoneDrawingState.closed
                      ? 'Zone closed · ${_pins.length} pins'
                      : '${_pins.length} pin${_pins.length == 1 ? '' : 's'} · '
                          '${math.max(0, widget.config.minPins - _pins.length)} more needed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.config.overlayColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Cancel
              Expanded(
                child: OutlinedButton(
                  onPressed: cancelDrawing,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 10),
              // Close Zone or Confirm
              if (_state == ZoneDrawingState.drawing &&
                  _pins.length >= widget.config.minPins)
                Expanded(
                  child: ElevatedButton(
                    onPressed: closeZone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.overlayColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close Zone',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              if (_state == ZoneDrawingState.closed)
                Expanded(
                  child: ElevatedButton(
                    onPressed: confirmZone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.overlayColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Zone',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Ripple animation ─────────────────────────────────────────────────────────
class _RippleAnimation {
  final LatLng position;
  final AnimationController controller;

  _RippleAnimation({required this.position, required this.controller});
}

class _RippleWidget extends StatelessWidget {
  final _RippleAnimation ripple;

  const _RippleWidget({required this.ripple});

  @override
  Widget build(BuildContext context) {
    // Ripple is rendered as an overlay indicator — positioned at screen center
    // as an approximation (actual geo-to-screen projection needs map bounds).
    return AnimatedBuilder(
      animation: ripple.controller,
      builder: (_, __) {
        final t = Curves.easeOut.transform(ripple.controller.value);
        return Positioned(
          // Center of screen as placeholder — in a real impl use map projection
          left: MediaQuery.of(context).size.width / 2 - 30 - (30 * t),
          top: MediaQuery.of(context).size.height / 2 - 30 - (30 * t),
          child: Opacity(
            opacity: (1 - t).clamp(0, 1),
            child: Container(
              width: 60 + 60 * t,
              height: 60 + 60 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2D7A4F),
                  width: 2.0 * (1 - t),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
