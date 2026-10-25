// lib/Community/Map/env_ops_map_screen.dart
//
// Public, read-only environmental operations map (v2): collection zones and
// dumpsites across the platform, with a legend that doubles as the list.
// Org logos appear inside zones once you zoom in. Reached from the
// community map's layers sheet.

import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../EnvironmentalOps/Territory/env_territory.dart' show CollectionZone;
import '../../EnvironmentalOps/envops_ui.dart' show CanopyField, MapLegend;
import '../../Shared/Inputs/post_incident.dart';
import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import '../Incidents/incidents_feed_screen.dart';
import 'org_logo_cache.dart';

class EnvOpsMapScreen extends StatefulWidget {
  const EnvOpsMapScreen({super.key});

  @override
  State<EnvOpsMapScreen> createState() => _EnvOpsMapScreenState();
}

class _Dumpsite {
  final String id, name;
  final LatLng position;
  final bool active;
  const _Dumpsite(this.id, this.name, this.position, this.active);
}

class _EnvOpsMapScreenState extends State<EnvOpsMapScreen> {
  List<CollectionZone> _zones = const [];
  List<_Dumpsite> _dumpsites = const [];
  bool _loading = true, _failed = false, _showLogos = false;
  final Map<String, BitmapDescriptor> _logos = {};
  final Map<String, String> _orgNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final db = FirebaseFirestore.instance;
      final r = await Future.wait([
        db.collection('collection_zones').limit(200).get(),
        db.collection('map_pins').where('pin_type', isEqualTo: 'dumpsite').limit(300).get(),
      ]);
      final zones = r[0].docs.map(CollectionZone.fromFirestore).where((z) => z.vertices.length >= 3).toList();
      final dumps = <_Dumpsite>[];
      for (final d in r[1].docs) {
        final m = d.data();
        final gp = m['location'];
        if (gp is! GeoPoint) continue;
        dumps.add(_Dumpsite(d.id, '${m['name'] ?? 'Dumpsite'}', LatLng(gp.latitude, gp.longitude), m['is_active'] as bool? ?? true));
      }
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _dumpsites = dumps;
        _loading = false;
      });
      _loadLogos(zones);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _loadLogos(List<CollectionZone> zones) async {
    final ring = context.canopy.ink;
    for (final orgId in zones.map((z) => z.orgId).where((id) => id.isNotEmpty).toSet()) {
      try {
        final data = (await FirebaseFirestore.instance.collection('organizations').doc(orgId).get()).data();
        if (data == null || !mounted) continue;
        _orgNames[orgId] = '${data['org_name'] ?? data['name'] ?? 'Organisation'}';
        final url = [data['logoUrl'], data['profilePhoto']].whereType<String>().where((v) => v.trim().isNotEmpty).firstOrNull;
        if (url == null) continue;
        final bytes = await OrgLogoCache.instance.bytes(url);
        if (bytes == null || !mounted) continue;
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
        final frame = await codec.getNextFrame();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        const b = Rect.fromLTWH(0, 0, 128, 128);
        c.drawCircle(const Offset(64, 64), 62, Paint()..color = const Color(0xFFFFFFFF));
        c.save();
        c.clipPath(Path()..addOval(b.deflate(8)));
        paintImage(canvas: c, rect: b.deflate(12), image: frame.image, fit: BoxFit.contain);
        c.restore();
        c.drawCircle(const Offset(64, 64), 62, Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
        final img = await rec.endRecording().toImage(128, 128);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        codec.dispose();
        img.dispose();
        if (png == null || !mounted) continue;
        setState(() => _logos[orgId] = BitmapDescriptor.bytes(png.buffer.asUint8List(), width: 44, height: 44));
      } catch (_) {
        // A missing logo must not hide the mapped areas.
      }
    }
  }

  /// Middle of the widest interior span at mid-latitude — stays inside
  /// concave zones, unlike a vertex average.
  LatLng _inside(List<LatLng> v) {
    final lats = v.map((x) => x.latitude).toList()..sort();
    final lat = (lats.first + lats.last) / 2;
    final xs = <double>[];
    for (var i = 0; i < v.length; i++) {
      final a = v[i], b = v[(i + 1) % v.length];
      if ((a.latitude > lat) != (b.latitude > lat)) {
        xs.add(a.longitude + (lat - a.latitude) * (b.longitude - a.longitude) / (b.latitude - a.latitude));
      }
    }
    xs.sort();
    var best = -1.0, lng = v.first.longitude;
    for (var i = 0; i + 1 < xs.length; i += 2) {
      if (xs[i + 1] - xs[i] > best) {
        best = xs[i + 1] - xs[i];
        lng = (xs[i] + xs[i + 1]) / 2;
      }
    }
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CanopyScaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(-1.2921, 36.8219), zoom: 12),
          style: canopyMapStyle(context),
          polygons: {
            for (final z in _zones)
              Polygon(
                polygonId: PolygonId('z_${z.id}'),
                points: z.vertices,
                fillColor: CanopyField.zoneFill(p),
                strokeColor: CanopyField.zoneStroke(p),
                strokeWidth: 2,
              ),
          },
          markers: {
            if (_showLogos)
              for (final z in _zones)
                if (_logos.containsKey(z.orgId))
                  Marker(
                    markerId: MarkerId('logo_${z.id}'),
                    position: _inside(z.vertices),
                    anchor: const Offset(.5, .5),
                    icon: _logos[z.orgId]!,
                    infoWindow: InfoWindow(title: _orgNames[z.orgId], snippet: z.name),
                  ),
            for (final d in _dumpsites)
              Marker(
                markerId: MarkerId('d_${d.id}'),
                position: d.position,
                icon: BitmapDescriptor.defaultMarkerWithHue(d.active ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange),
                infoWindow: InfoWindow(title: d.name, snippet: d.active ? 'Active dumpsite' : 'Cleared'),
              ),
          },
          onCameraMove: (pos) {
            final show = pos.zoom >= 15;
            if (show != _showLogos) setState(() => _showLogos = show);
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        Positioned(
          top: top + CanopySpace.s8,
          left: CanopySpace.s12,
          right: CanopySpace.s12,
          child: Row(children: [
            CanopyIconButton(icon: Icons.arrow_back, tooltip: 'Back', float: true, onPressed: () => Navigator.maybePop(context)),
            const SizedBox(width: CanopySpace.s8),
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(CanopyRadius.pill),
                  border: Border.all(color: p.outline),
                ),
                child: Text('Environmental operations', style: CanopyType.subhead.copyWith(color: p.ink)),
              ),
            ),
            const SizedBox(width: CanopySpace.s8),
            CanopyIconButton(
              icon: Icons.receipt_long_outlined,
              tooltip: 'Reports',
              float: true,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentsFeedScreen())),
            ),
            const SizedBox(width: CanopySpace.s8),
            CanopyIconButton(
              icon: Icons.add_location_alt_outlined,
              tooltip: 'Report a problem',
              float: true,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostIncident())),
            ),
          ]),
        ),
        Positioned(
          left: CanopySpace.gutter,
          right: CanopySpace.gutter,
          bottom: bottom + CanopySpace.s16,
          child: Container(
            padding: const EdgeInsets.all(CanopySpace.s16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(CanopyRadius.md),
              border: Border.all(color: p.outline),
            ),
            child: _loading
                ? const LinearProgressIndicator()
                : _failed
                    ? CanopyErrorState(inline: true, title: "Couldn't load the map layers.", onRetry: _load)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        MapLegend(items: [
                          (CanopyField.zoneStroke(p), '${_zones.length} collection zone${_zones.length == 1 ? '' : 's'}'),
                          (p.danger, '${_dumpsites.length} dumpsite${_dumpsites.length == 1 ? '' : 's'}'),
                        ]),
                        const SizedBox(height: CanopySpace.s4),
                        Text('Zoom in to see which organisation works each zone.',
                            style: CanopyType.caption.copyWith(color: p.inkMuted)),
                      ]),
          ),
        ),
      ]),
    );
  }
}
