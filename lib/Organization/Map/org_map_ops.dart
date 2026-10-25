// lib/Organization/Map/org_map_ops.dart
//
// Map pin (ORG_HANDOFF §3.8, T). Org reps add community pins — amenities,
// dumpsites, landmarks. You have to be AT the place: the pin is the phone's GPS
// position at that moment (never a tap or a drag on the map), and a photo taken
// right there is required. The sheet offers pin-type chips that depend on the
// org's role, a name, dumpsite ownership, then "Add pin". New pins are
// unverified until the community confirms them.

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../Shared/Inputs/pin_picker_screen.dart';
import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';

enum _PinRole { all, envOps, specialOps }

class _PinType {
  final String id;
  final String label;
  final IconData icon;
  final _PinRole role;
  final bool managed; // dumpsite: who manages it

  const _PinType(this.id, this.label, this.icon, this.role, {this.managed = false});
}

const _allPinTypes = <_PinType>[
  _PinType('police_station', 'Police station', Icons.local_police_outlined, _PinRole.all),
  _PinType('public_toilet', 'Public toilet', Icons.wc_outlined, _PinRole.all),
  _PinType('water_point', 'Water point', Icons.water_drop_outlined, _PinRole.all),
  _PinType('community_center', 'Community centre', Icons.people_outline, _PinRole.all),
  _PinType('market', 'Market', Icons.storefront_outlined, _PinRole.all),
  _PinType('school', 'School', Icons.school_outlined, _PinRole.all),
  _PinType('health_clinic', 'Clinic', Icons.local_hospital_outlined, _PinRole.all),
  _PinType('place_of_worship', 'Place of worship', Icons.church_outlined, _PinRole.all),
  _PinType('landmark', 'Landmark', Icons.location_city_outlined, _PinRole.all),
  _PinType('dumpsite', 'Dumpsite', Icons.delete_outline, _PinRole.envOps, managed: true),
  _PinType('recycling_dropoff', 'Recycling drop-off', Icons.recycling, _PinRole.envOps),
  _PinType('collection_site', 'Collection site', Icons.inventory_2_outlined, _PinRole.envOps),
  _PinType('scrap_buying_site', 'Scrap buyer', Icons.point_of_sale_outlined, _PinRole.envOps),
  _PinType('sorting_hub', 'Sorting hub', Icons.warehouse_outlined, _PinRole.envOps),
  _PinType('tree_site', 'Tree planting site', Icons.park_outlined, _PinRole.envOps),
  _PinType('cleanup_event', 'Clean-up site', Icons.cleaning_services_outlined, _PinRole.specialOps),
  _PinType('canopy_hub', 'Canopy hub', Icons.hub_outlined, _PinRole.specialOps),
];

class OrgMapOpsScreen extends StatefulWidget {
  final Map<String, dynamic> orgData;
  final String? initialPinTypeId;

  const OrgMapOpsScreen({super.key, required this.orgData, this.initialPinTypeId});

  @override
  State<OrgMapOpsScreen> createState() => _OrgMapOpsScreenState();
}

class _OrgMapOpsScreenState extends State<OrgMapOpsScreen> {
  GoogleMapController? _map;
  // Live GPS. The pin is wherever this phone is, once the fix is precise enough.
  static const double _maxAccuracyM = 25;
  StreamSubscription<Position>? _gps;
  Position? _fix;
  String? _gpsProblem;
  _PinType? _type;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _hours = TextEditingController();
  bool _selfManaged = true;
  (String, String)? _linkedOrg; // id, name
  File? _image;
  bool _saving = false, _showErrors = false, _moreOpen = false;

  // The exact place picked on the map instead of read from this phone's GPS.
  LatLng? _chosen;
  bool get _manual => _chosen != null;

  bool get _preciseEnough => _fix != null && _fix!.accuracy <= _maxAccuracyM && !_fix!.isMocked;

  Map<String, dynamic> get _org => widget.orgData;
  String get _orgId => _org['orgId'] as String? ?? '';
  String get _orgName => (_org['org_name'] ?? _org['name'] ?? '') as String;

  bool get _isEnvOrg => _org['sectorId'] == 'sector_env' || _org['envOpsStatus'] == 'approved';
  bool get _isSpecialOps => _org['envOpsStatus'] == 'approved' || _org['marketplaceStatus'] == 'approved';

  List<_PinType> get _types => _allPinTypes
      .where((t) =>
          t.role == _PinRole.all ||
          (t.role == _PinRole.envOps && _isEnvOrg) ||
          (t.role == _PinRole.specialOps && _isSpecialOps))
      .toList();

  CameraPosition get _start {
    final gp = _org['location'];
    final lat = gp is GeoPoint ? gp.latitude : (_org['lat'] as num?)?.toDouble();
    final lng = gp is GeoPoint ? gp.longitude : (_org['lng'] as num?)?.toDouble();
    return CameraPosition(target: LatLng(lat ?? -1.2921, lng ?? 36.8219), zoom: lat == null ? 12 : 15);
  }

  @override
  void initState() {
    super.initState();
    final id = widget.initialPinTypeId;
    if (id != null) {
      for (final t in _types) {
        if (t.id == id) _type = t;
      }
    }
    _startGps();
  }

  Future<void> _startGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsProblem = 'Turn on location for Canopy. You have to be at the place to map it.');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _gpsProblem = 'Turn on your phone\'s location (GPS).');
        return;
      }
      _gps?.cancel();
      _gps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0),
      ).listen((pos) {
        if (!mounted) return;
        final first = _fix == null;
        setState(() {
          _fix = pos;
          _gpsProblem = null;
        });
        if (first) _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 18));
      }, onError: (_) {
        if (mounted) setState(() => _gpsProblem = "Couldn't read your position. Move to open sky and try again.");
      });
    } catch (_) {
      if (mounted) setState(() => _gpsProblem = "Couldn't read your position. Try again.");
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _hours.dispose();
    _gps?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _chooseOnMap() async {
    final f = _fix;
    final start = _chosen ?? (f == null ? null : LatLng(f.latitude, f.longitude));
    final at = await pickPin(context, initial: start, title: 'Where is it?');
    if (at == null || !mounted) return;
    setState(() => _chosen = at);
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(at, 17));
  }

  Future<void> _recentre() async {
    final f = _fix;
    if (f != null) await _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(f.latitude, f.longitude), 18));
  }

  Future<void> _pickImage() async {
    // At the place, the photo is taken with the camera. When the place was chosen
    // on the map (you may not be there), a photo from the gallery is fine.
    var source = ImageSource.camera;
    if (_manual) {
      final picked = await showCanopySheet<ImageSource>(context, builder: (ctx) {
        return CanopySheetBody(title: 'Photo', children: [
          CanopyListGroup(children: [
            CanopyListRow(icon: Icons.photo_camera_outlined, title: 'Take a photo', chevron: false, onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            CanopyListRow(icon: Icons.photo_library_outlined, title: 'Choose from gallery', chevron: false, onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ]),
        ]);
      });
      if (picked == null) return;
      source = picked;
    }
    final f = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (f != null) setState(() => _image = File(f.path));
  }

  Future<void> _pickLinkedOrg() async {
    final picked = await showCanopySheet<(String, String)>(context, tall: true, builder: (_) => _OrgPicker(selfId: _orgId));
    if (picked != null) setState(() => _linkedOrg = picked);
  }

  String? get _error {
    if (!_manual) {
      if (_gpsProblem != null) return _gpsProblem;
      if (_fix == null) return 'Waiting for your location…';
      if (_fix!.isMocked) return 'A fake location is on. Turn it off to map a place.';
      if (!_preciseEnough) return 'Not precise enough yet (±${_fix!.accuracy.round()} m). Stand in the open and wait for ±${_maxAccuracyM.round()} m or better.';
    }
    if (_image == null) return _manual ? 'Add a photo of the place.' : 'Take a photo of the place. It has to be taken on the spot.';
    if (_type == null) return 'Choose what this pin is.';
    if (_name.text.trim().isEmpty) return 'Give it a name people will recognise.';
    if (_type!.managed && !_selfManaged && _linkedOrg == null) return 'Choose who manages it.';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (_error != null) return;
    setState(() => _saving = true);
    try {
      // The point is where this phone is right now: read fresh, not whatever the
      // last stream value was, and re-checked for precision.
      final chosen = _chosen;
      Position? pos;
      if (chosen == null) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)),
        );
        if (pos.isMocked || pos.accuracy > _maxAccuracyM) {
          if (mounted) {
            showCanopySnack(context, "Your position isn't precise enough (±${pos.accuracy.round()} m). Wait a moment in the open and try again.", error: true);
          }
          return;
        }
      }
      final lat = chosen?.latitude ?? pos!.latitude;
      final lng = chosen?.longitude ?? pos!.longitude;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final ref = FirebaseStorage.instance.ref('map_pins/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
      await ref.putFile(_image!);
      final imageUrl = await ref.getDownloadURL();
      final t = _type!;
      await FirebaseFirestore.instance.collection('map_pins').add({
        'pin_type': t.id,
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'location': GeoPoint(lat, lng),
        if (pos != null) 'location_accuracy_m': pos.accuracy,
        'location_source': chosen == null ? 'device_gps' : 'chosen_on_map',
        'captured_at': FieldValue.serverTimestamp(),
        'image_url': imageUrl,
        'operating_hours': _hours.text.trim().isEmpty ? null : _hours.text.trim(),
        'added_by_org_id': _orgId,
        'added_by_org_name': _orgName,
        'country': _org['country'] as String? ?? 'Kenya',
        'city': _org['city'] as String? ?? '',
        'area': _org['area'] as String? ?? '',
        'is_active': true,
        'is_verified': false,
        'created_at': FieldValue.serverTimestamp(),
        if (t.managed) ...{
          'managing_org_id': _selfManaged ? _orgId : _linkedOrg?.$1,
          'managing_org_name': _selfManaged ? _orgName : _linkedOrg?.$2,
          'self_managed': _selfManaged,
        },
      });
      if (!mounted) return;
      showCanopySnack(context, 'Pin added. It shows as unverified until the community confirms it.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't add the pin. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    return CanopyScaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: _start,
          style: canopyMapStyle(context),
          onMapCreated: (c) => _map = c,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          markers: {
            if (_chosen != null) Marker(markerId: const MarkerId('chosen'), position: _chosen!),
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        Positioned(
          top: top + CanopySpace.s8,
          left: CanopySpace.s12,
          right: CanopySpace.s12,
          child: Row(children: [
            CanopyIconButton(icon: Icons.arrow_back, tooltip: 'Back', float: true, onPressed: () => Navigator.maybePop(context)),
            const Spacer(),
            CanopyIconButton(icon: Icons.my_location, tooltip: 'Centre on me', float: true, onPressed: _recentre),
          ]),
        ),
        Align(alignment: Alignment.bottomCenter, child: _sheet(p)),
      ]),
    );
  }

  Widget _gpsStatus(CanopyPalette p) {
    if (_manual) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.push_pin_outlined, size: 18, color: p.success),
        const SizedBox(width: CanopySpace.s8),
        Expanded(
          child: Text('Place chosen on the map (${_chosen!.latitude.toStringAsFixed(5)}, ${_chosen!.longitude.toStringAsFixed(5)}).',
              style: CanopyType.caption.copyWith(color: p.success)),
        ),
        CanopyButton.quiet(label: 'Change', size: CanopyButtonSize.compact, onPressed: _chooseOnMap),
        CanopyButton.quiet(label: 'Use GPS', size: CanopyButtonSize.compact, onPressed: () => setState(() => _chosen = null)),
      ]);
    }
    final f = _fix;
    final IconData icon;
    final Color color;
    final String text;
    if (_gpsProblem != null) {
      icon = Icons.location_off_outlined;
      color = p.danger;
      text = _gpsProblem!;
    } else if (f == null) {
      icon = Icons.gps_not_fixed;
      color = p.inkMuted;
      text = 'Finding your exact position…';
    } else if (f.isMocked) {
      icon = Icons.gps_off;
      color = p.danger;
      text = 'A fake location is on. Turn it off.';
    } else if (f.accuracy <= _maxAccuracyM) {
      icon = Icons.gps_fixed;
      color = p.success;
      text = 'Exact position locked (±${f.accuracy.round()} m). The pin goes where you are standing.';
    } else {
      icon = Icons.gps_not_fixed;
      color = p.warning;
      text = 'Improving… ±${f.accuracy.round()} m. Stand in the open; it needs ±${_maxAccuracyM.round()} m or better.';
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: CanopySpace.s8),
      Expanded(child: Text(text, style: CanopyType.caption.copyWith(color: color))),
      if (_gpsProblem != null) CanopyButton.quiet(label: 'Retry', size: CanopyButtonSize.compact, onPressed: _startGps),
      CanopyButton.quiet(label: 'Choose on map', size: CanopyButtonSize.compact, onPressed: _chooseOnMap),
    ]);
  }

  Widget _sheet(CanopyPalette p) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .62),
      decoration: BoxDecoration(
        color: p.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(CanopyRadius.lg)),
        border: Border(top: BorderSide(color: p.outline)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s16 + bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Map this place', style: CanopyType.subhead.copyWith(color: p.ink)),
                const SizedBox(height: CanopySpace.s4),
                _gpsStatus(p),
                const SizedBox(height: CanopySpace.s12),
                Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
                  for (final t in _types)
                    CanopyFilterChip(
                      label: t.label,
                      icon: t.icon,
                      selected: _type == t,
                      onTap: () => setState(() => _type = t),
                    ),
                ]),
                const SizedBox(height: CanopySpace.s16),
                CanopyTextField(
                  label: 'Name',
                  hint: 'e.g. Kibera Market water tap',
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                ),
                if (_type?.managed ?? false) ...[
                  const SizedBox(height: CanopySpace.s12),
                  CanopySwitchRow(
                    title: 'We manage this site',
                    value: _selfManaged,
                    onChanged: (v) => setState(() => _selfManaged = v),
                  ),
                  if (!_selfManaged)
                    CanopyPickerField(
                      label: 'Managed by',
                      value: _linkedOrg?.$2,
                      placeholder: 'Choose organisation',
                      onTap: _pickLinkedOrg,
                    ),
                ],
                const SizedBox(height: CanopySpace.s8),
                const SizedBox(height: CanopySpace.s12),
                Text('Photo (required)', style: CanopyType.label.copyWith(color: p.ink)),
                const SizedBox(height: CanopySpace.s8),
                if (_image == null)
                  CanopyButton.secondary(label: 'Take a photo of the place', expand: true, onPressed: _pickImage)
                else
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(CanopyRadius.xs),
                      child: Image.file(_image!, width: 72, height: 72, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: CanopySpace.s12),
                    CanopyButton.quiet(label: 'Retake', size: CanopyButtonSize.compact, onPressed: _pickImage),
                  ]),
                const SizedBox(height: CanopySpace.s8),
                if (!_moreOpen)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CanopyButton.quiet(
                        label: 'Add details',
                        size: CanopyButtonSize.compact,
                        onPressed: () => setState(() => _moreOpen = true)),
                  )
                else ...[
                  CanopyTextField(label: 'Description (optional)', controller: _desc, minLines: 2, maxLines: 4),
                  const SizedBox(height: CanopySpace.s12),
                  CanopyTextField(label: 'Opening hours (optional)', hint: 'e.g. Mon–Sat 7am–6pm', controller: _hours),
                ],
                if (_showErrors && _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: CanopySpace.s8),
                    child: Text(_error!, style: CanopyType.caption.copyWith(color: p.danger)),
                  ),
                const SizedBox(height: CanopySpace.s16),
                CanopyButton(label: 'Add pin here', expand: true, loading: _saving, onPressed: (_manual || _preciseEnough) ? _submit : null),
              ]),
      ),
    );
  }
}

class _OrgPicker extends StatefulWidget {
  final String selfId;
  const _OrgPicker({required this.selfId});

  @override
  State<_OrgPicker> createState() => _OrgPickerState();
}

class _OrgPickerState extends State<_OrgPicker> {
  String _q = '';
  late final Future<List<(String, String, String)>> _orgs = FirebaseFirestore.instance
      .collection('organizations')
      .get()
      .then((s) => s.docs
          .where((d) => d.id != widget.selfId)
          .map((d) => (
                d.id,
                ((d.data()['org_name'] ?? d.data()['name'] ?? '') as String).trim(),
                (d.data()['city'] as String?) ?? '',
              ))
          .where((o) => o.$2.isNotEmpty)
          .toList()
        ..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase())));

  @override
  Widget build(BuildContext context) {
    return CanopySheetBody(title: 'Managed by', children: [
      CanopyTextField.search(hint: 'Organisation name', autofocus: true, onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
      const SizedBox(height: CanopySpace.s12),
      FutureBuilder<List<(String, String, String)>>(
        future: _orgs,
        builder: (context, snap) {
          if (snap.hasError) return const CanopyErrorState(inline: true, title: "Couldn't load organisations.");
          if (!snap.hasData) return const CanopyListSkeleton(rows: 4);
          final list = snap.data!.where((o) => o.$2.toLowerCase().contains(_q)).take(40).toList();
          if (list.isEmpty) return const CanopyEmptyState(boxed: true, icon: Icons.apartment_outlined, title: 'No organisations match');
          return CanopyListGroup(children: [
            for (final o in list)
              CanopyListRow(
                title: o.$2,
                subtitle: o.$3.isEmpty ? null : o.$3,
                chevron: false,
                onTap: () => Navigator.pop(context, (o.$1, o.$2)),
              ),
          ]);
        },
      ),
    ]);
  }
}
