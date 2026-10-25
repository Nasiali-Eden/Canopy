// lib/Shared/Inputs/pin_picker_screen.dart
//
// Pin a location: a full-screen map with a fixed pin in the middle. Pan and
// zoom until the pin sits on the spot, or tap "Use my location" when you are
// there, then "Use this location". Used for events and culture entries, which
// must each carry an exact point. (Mapping things in the field — dumpsites,
// trees, places — is GPS-only and never uses this.)

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';

/// Opens the picker and returns the chosen point, or null if dismissed.
Future<LatLng?> pickPin(BuildContext context, {LatLng? initial, String title = 'Pin the location'}) =>
    Navigator.of(context).push<LatLng>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinPickerScreen(initial: initial, title: title),
    ));

class PinPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final String title;
  const PinPickerScreen({super.key, this.initial, required this.title});

  @override
  State<PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<PinPickerScreen> {
  static const _nairobi = LatLng(-1.2921, 36.8219);
  GoogleMapController? _map;
  late LatLng _center = widget.initial ?? _nairobi;
  bool _locating = false;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showCanopySnack(context, 'Allow location access to use where you are.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)));
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 18));
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't read your position.", error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    return CanopyScaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _center, zoom: widget.initial == null ? 13 : 17),
          style: canopyMapStyle(context),
          onMapCreated: (c) => _map = c,
          onCameraMove: (pos) => _center = pos.target,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        // The pin never moves; the map moves under it. Its tip sits on the centre.
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on, size: 44, color: p.danger),
            ),
          ),
        ),
        Positioned(
          top: top + CanopySpace.s8,
          left: CanopySpace.s12,
          right: CanopySpace.s12,
          child: Row(children: [
            CanopyIconButton(icon: Icons.close, tooltip: 'Close', float: true, onPressed: () => Navigator.pop(context)),
            const SizedBox(width: CanopySpace.s12),
            Expanded(child: Text(widget.title, style: CanopyType.title.copyWith(color: p.ink))),
            CanopyIconButton(icon: Icons.my_location, tooltip: 'Use my location', float: true, onPressed: _locating ? null : _useMyLocation),
          ]),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(CanopySpace.gutter),
              child: CanopyCard(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Move the map until the pin is exactly on the spot.', style: CanopyType.body.copyWith(color: p.ink)),
                  const SizedBox(height: CanopySpace.s12),
                  CanopyButton(label: 'Use this location', expand: true, onPressed: () => Navigator.pop(context, _center)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
