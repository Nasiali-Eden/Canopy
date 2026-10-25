// lib/Services/Incidents/map_selection.dart
//
// Pin-drop (v2): the map moves under a fixed centre pin; "Use this spot"
// returns the centre. Starts at [initial] (or Nairobi) and has a locate
// button. Returns a LatLng or null.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import 'incident_upload.dart';

class MapSelectionScreen extends StatefulWidget {
  final LatLng? initial;
  const MapSelectionScreen({super.key, this.initial});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  static const _nairobi = LatLng(-1.286389, 36.817223);
  GoogleMapController? _map;
  late LatLng _centre = widget.initial ?? _nairobi;
  bool _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    final here = await UploadIncident().currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (here == null) {
      showCanopySnack(context, "Couldn't get your location. Move the map instead.", error: true);
      return;
    }
    _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 17));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Where is it?'),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _centre, zoom: widget.initial == null ? 12 : 17),
          style: canopyMapStyle(context),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) => _map = c,
          onCameraMove: (pos) => _centre = pos.target,
        ),
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on, size: 44, color: p.danger),
            ),
          ),
        ),
        Positioned(
          top: CanopySpace.s12,
          left: CanopySpace.gutter,
          right: CanopySpace.gutter,
          child: CanopyCard(
            padding: const EdgeInsets.all(CanopySpace.s12),
            child: Text('Move the map so the pin sits on the problem.', style: CanopyType.label.copyWith(color: p.ink)),
          ),
        ),
        Positioned(
          right: CanopySpace.gutter,
          bottom: CanopySpace.s16,
          child: _locating
              ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
              : CanopyIconButton(icon: Icons.my_location, tooltip: 'Go to my location', float: true, onPressed: _locate),
        ),
      ]),
      sticky: StickyActionBar(children: [
        CanopyButton(label: 'Use this spot', expand: true, onPressed: () => Navigator.pop(context, _centre)),
      ]),
    );
  }
}
