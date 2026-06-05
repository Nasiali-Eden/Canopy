import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ─── Coordinate entry ─────────────────────────────────────────────────────────
class _CoordEntry {
  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;

  _CoordEntry()
      : latCtrl = TextEditingController(),
        lngCtrl = TextEditingController();

  LatLng? get latLng {
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  void dispose() {
    latCtrl.dispose();
    lngCtrl.dispose();
  }
}

// ─── Haversine distance in metres ─────────────────────────────────────────────
double _haversineM(LatLng a, LatLng b) {
  const R = 6371000.0;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return R * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
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
  final List<_CoordEntry> _entries = [];
  final ScrollController _scrollCtrl = ScrollController();
  ZoneDrawingState _drawState = ZoneDrawingState.drawing;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.config.minPins; i++) {
      _addEntry(notify: false);
    }
  }

  void _addEntry({bool notify = true}) {
    final entry = _CoordEntry();
    entry.latCtrl.addListener(_rebuild);
    entry.lngCtrl.addListener(_rebuild);
    _entries.add(entry);
    if (notify) setState(() {});
  }

  void _removeEntry(int index) {
    if (_entries.length <= widget.config.minPins) return;
    _entries[index].dispose();
    setState(() => _entries.removeAt(index));
  }

  void _rebuild() => setState(() {});

  List<LatLng> get _validPins =>
      _entries.map((e) => e.latLng).whereType<LatLng>().toList();

  int get _validCount => _validPins.length;

  bool get _canClose =>
      _validCount >= widget.config.minPins &&
      _drawState == ZoneDrawingState.drawing;

  void _closeZone() {
    if (!_canClose) return;
    setState(() => _drawState = ZoneDrawingState.closed);
    _fitMapToPins();
  }

  void _confirmZone() {
    final pins = _validPins;
    if (pins.length < widget.config.minPins) return;
    widget.onZoneClosed(ZoneDrawingResult(
      vertices: List.unmodifiable(pins),
      zoneType: widget.config.zoneType,
    ));
  }

  void _fitMapToPins() {
    final pins = _validPins;
    if (pins.length < 2 || _mapController == null) return;
    final bounds = pins.fold(
      LatLngBounds(southwest: pins.first, northeast: pins.first),
      (LatLngBounds acc, LatLng p) => LatLngBounds(
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
      CameraUpdate.newLatLngBounds(bounds, 48),
    );
  }

  Set<Marker> get _markers {
    final pins = _validPins;
    return pins.asMap().entries.map((e) {
      return Marker(
        markerId: MarkerId('pin_${e.key}'),
        position: e.value,
        icon: e.key == 0
            ? BitmapDescriptor.defaultMarkerWithHue(
                widget.config.zoneType == ZoneType.collectionZone
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueCyan)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }).toSet();
  }

  Set<Polyline> get _polylines {
    final pins = _validPins;
    if (pins.length < 2) return {};
    final points = [...pins];
    if (_drawState == ZoneDrawingState.closed) points.add(pins.first);
    return {
      Polyline(
        polylineId: const PolylineId('zone_outline'),
        points: points,
        color: widget.config.overlayColor,
        width: 3,
        patterns: _drawState == ZoneDrawingState.drawing
            ? [PatternItem.dash(16), PatternItem.gap(8)]
            : [],
      ),
    };
  }

  Set<Polygon> get _polygons {
    if (_drawState != ZoneDrawingState.closed) return {};
    final pins = _validPins;
    if (pins.length < 3) return {};
    return {
      Polygon(
        polygonId: const PolygonId('zone_fill'),
        points: pins,
        fillColor: widget.config.overlayColor.withOpacity(0.22),
        strokeColor: widget.config.overlayColor,
        strokeWidth: 3,
      ),
    };
  }

  @override
  void dispose() {
    for (final e in _entries) e.dispose();
    _scrollCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF7F5F0),
      body: Column(
        children: [
          Expanded(flex: 4, child: _buildMap()),
          Expanded(flex: 6, child: _buildInputPanel()),
        ],
      ),
    );
  }

  // ── Map preview ──────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: widget.initialPosition,
          onMapCreated: (c) {
            _mapController = c;
            if (widget.mapStyle.isNotEmpty) c.setMapStyle(widget.mapStyle);
          },
          markers: _markers,
          polylines: _polylines,
          polygons: _polygons,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: _MapBadge(
            color: widget.config.overlayColor,
            validCount: _validCount,
            drawState: _drawState,
          ),
        ),
        if (_validCount >= 2)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: _fitMapToPins,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6),
                  ],
                ),
                child: const Icon(Icons.fit_screen, size: 16,
                    color: AppTheme.accent),
              ),
            ),
          ),
      ],
    );
  }

  // ── Input panel ──────────────────────────────────────────────────────────────
  Widget _buildInputPanel() {
    final validCount = _validCount;
    final minPins = widget.config.minPins;
    final progress = (validCount / minPins).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.pin_drop_outlined,
                    size: 17, color: widget.config.overlayColor),
                const SizedBox(width: 8),
                const Text(
                  'Zone Coordinates',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen),
                ),
                const Spacer(),
                _PinCountBadge(
                    count: validCount,
                    min: minPins,
                    color: widget.config.overlayColor),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(
                    validCount >= minPins
                        ? widget.config.overlayColor
                        : AppTheme.tertiary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.straighten_outlined,
                    size: 12,
                    color: AppTheme.darkGreen.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  '~100 m recommended spacing between pins',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.45)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Coordinate rows
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: _entries.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _entries.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _addEntry();
                        Future.delayed(
                          const Duration(milliseconds: 120),
                          () {
                            if (_scrollCtrl.hasClients) {
                              _scrollCtrl.animateTo(
                                _scrollCtrl.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        );
                      },
                      icon: const Icon(Icons.add_location_alt_outlined,
                          size: 15),
                      label: const Text('Add Pin',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.config.overlayColor,
                        side: BorderSide(
                            color:
                                widget.config.overlayColor.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  );
                }
                return _buildCoordRow(i);
              },
            ),
          ),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildCoordRow(int index) {
    final entry = _entries[index];
    final pin = entry.latLng;
    final canDelete = _entries.length > widget.config.minPins;

    // Distance to next row's pin
    String? distLabel;
    if (pin != null && index < _entries.length - 1) {
      final next = _entries[index + 1].latLng;
      if (next != null) {
        final d = _haversineM(pin, next);
        distLabel = d >= 1000
            ? '${(d / 1000).toStringAsFixed(2)} km'
            : '${d.toStringAsFixed(0)} m';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: pin != null
                ? widget.config.overlayColor.withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: pin != null
                  ? widget.config.overlayColor.withOpacity(0.25)
                  : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Pin number badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: pin != null
                      ? widget.config.overlayColor
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        pin != null ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Latitude
              Expanded(
                child: _CoordField(
                  controller: entry.latCtrl,
                  label: 'Lat',
                  hint: '-1.3133',
                  color: widget.config.overlayColor,
                ),
              ),
              const SizedBox(width: 6),
              // Longitude
              Expanded(
                child: _CoordField(
                  controller: entry.lngCtrl,
                  label: 'Lng',
                  hint: '36.7862',
                  color: widget.config.overlayColor,
                ),
              ),
              const SizedBox(width: 4),
              // Delete
              GestureDetector(
                onTap: canDelete ? () => _removeEntry(index) : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.remove_circle_outline,
                    size: 17,
                    color: canDelete
                        ? Colors.red.shade300
                        : Colors.grey.shade200,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Distance indicator between consecutive pins
        if (distLabel != null)
          Padding(
            padding: const EdgeInsets.only(left: 46, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.arrow_downward_rounded,
                    size: 10,
                    color: AppTheme.darkGreen.withOpacity(0.35)),
                const SizedBox(width: 3),
                Text(
                  distLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkGreen.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    final canClose = _canClose;
    final isClosed = _drawState == ZoneDrawingState.closed;
    final remaining = math.max(0, widget.config.minPins - _validCount);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        color: Colors.white,
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
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          // Close Zone / Save Zone
          Expanded(
            flex: 2,
            child: isClosed
                ? ElevatedButton.icon(
                    onPressed: _confirmZone,
                    icon: const Icon(Icons.save_outlined,
                        size: 15, color: Colors.white),
                    label: const Text('Save Zone',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.overlayColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      canClose
                          ? 'Close Zone'
                          : '$remaining more needed',
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
    );
  }
}

// ─── Map badge ────────────────────────────────────────────────────────────────
class _MapBadge extends StatelessWidget {
  final Color color;
  final int validCount;
  final ZoneDrawingState drawState;

  const _MapBadge(
      {required this.color,
      required this.validCount,
      required this.drawState});

  @override
  Widget build(BuildContext context) {
    final label = drawState == ZoneDrawingState.closed
        ? 'Zone closed · $validCount pins'
        : '$validCount pin${validCount == 1 ? '' : 's'} placed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            drawState == ZoneDrawingState.closed
                ? Icons.check_circle_outline
                : Icons.map_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Pin count badge ──────────────────────────────────────────────────────────
class _PinCountBadge extends StatelessWidget {
  final int count;
  final int min;
  final Color color;

  const _PinCountBadge(
      {required this.count, required this.min, required this.color});

  @override
  Widget build(BuildContext context) {
    final met = count >= min;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met ? color.withOpacity(0.12) : AppTheme.tertiary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count / $min pins',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: met ? color : AppTheme.darkGreen.withOpacity(0.55),
        ),
      ),
    );
  }
}

// ─── Coordinate text field ────────────────────────────────────────────────────
class _CoordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final Color color;

  const _CoordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(signed: true, decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
      ],
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkGreen),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
        hintStyle:
            TextStyle(fontSize: 11, color: Colors.grey.shade400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
