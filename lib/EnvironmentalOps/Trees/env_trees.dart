// lib/EnvironmentalOps/Trees/env_trees.dart
//
// Operations › Trees (ENVOPS_HANDOFF §3.4). List/Map switch over the
// organisation's planting posts (count, place, planted date, pin or zone,
// Pending verification / Verified), the monthly count report, and a sticky
// "Record a planting".
//
// New planting: Record (count, stage, species, date) → Photos → Location
// (pin or zone; GPS acquiring state with a manual pin fallback) → Review →
// "Save planting" (becomes Pending verification). Survival is counted, not
// carbon — nothing here promises credits.

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../Models/environmental/enums/tree_species.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import '../Shared/zone_drawing_controller.dart';
import '../envops_ui.dart';
import 'tree_count_report_screen.dart';

enum VerificationStage { pending, stage1, full }

class PlantingPost {
  final String id;
  final String species;
  final int quantity;
  final DateTime plantedDate;
  final double lat, lng;
  final List<String> photoUrls;
  final VerificationStage stage;
  final bool hasZone;
  final String? growthStage;

  const PlantingPost({
    required this.id,
    required this.species,
    required this.quantity,
    required this.plantedDate,
    required this.lat,
    required this.lng,
    required this.photoUrls,
    required this.stage,
    this.hasZone = false,
    this.growthStage,
  });

  factory PlantingPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PlantingPost(
      id: doc.id,
      species: d['species'] as String? ?? 'Tree',
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      plantedDate: (d['planted_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      photoUrls: List<String>.from(d['photo_urls'] as List? ?? const []),
      stage: VerificationStage.values.firstWhere((s) => s.name == (d['stage'] as String? ?? 'pending'),
          orElse: () => VerificationStage.pending),
      hasZone: (d['zone_vertices'] as List?)?.isNotEmpty ?? false,
      growthStage: d['growth_stage'] as String?,
    );
  }

  bool get hasPoint => !(lat == 0 && lng == 0);
}

class EnvTreesScreen extends StatefulWidget {
  const EnvTreesScreen({super.key});

  @override
  State<EnvTreesScreen> createState() => _EnvTreesScreenState();
}

class _EnvTreesScreenState extends State<EnvTreesScreen> {
  bool _map = false;
  List<PlantingPost> _posts = const [];
  bool _loading = true, _failed = false;
  EnvironmentOpsContext? _ctx;

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
      _ctx ??= await EnvironmentOpsService.instance.resolveContext();
      final col = FirebaseFirestore.instance.collection('planting_posts');
      final byId = <String, PlantingPost>{};
      // Index-free single-equality reads: the org's posts, plus older posts
      // written before org_id was stored (matched by author).
      if (_ctx != null) {
        for (final d in (await col.where('org_id', isEqualTo: _ctx!.orgId).limit(200).get()).docs) {
          byId[d.id] = PlantingPost.fromFirestore(d);
        }
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        for (final d in (await col.where('created_by', isEqualTo: uid).limit(200).get()).docs) {
          byId.putIfAbsent(d.id, () => PlantingPost.fromFirestore(d));
        }
      }
      if (!mounted) return;
      setState(() {
        _posts = byId.values.toList()..sort((a, b) => b.plantedDate.compareTo(a.plantedDate));
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _record() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PlantingWizard()));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final planted = _posts.fold(0, (s, x) => s + x.quantity);
    final pending = _posts.where((x) => x.stage != VerificationStage.full).fold(0, (s, x) => s + x.quantity);
    final verified = planted - pending;
    return CanopyScaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
          children: [
            SignalGrid(signals: [
              SignalCard(value: '$planted', caption: 'Trees planted'),
              SignalCard(value: '$verified', caption: 'Verified alive'),
            ]),
            const SizedBox(height: CanopySpace.s12),
            CanopyListGroup(children: [
              CanopyListRow(
                icon: Icons.summarize_outlined,
                title: 'Monthly count report',
                subtitle: 'Planted this month and survival at each check',
                onTap: _ctx == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TreeCountReportScreen(orgId: _ctx!.orgId))),
              ),
            ]),
            const SizedBox(height: CanopySpace.s16),
            CanopySegmented<bool>(options: const [(false, 'List'), (true, 'Map')], value: _map, onChanged: (v) => setState(() => _map = v)),
            const SizedBox(height: CanopySpace.s12),
            if (_failed)
              CanopyErrorState(inline: true, title: "Couldn't load plantings.", onRetry: _load)
            else if (_loading)
              const CanopyListSkeleton(rows: 3)
            else if (_posts.isEmpty)
              CanopyEmptyState(
                boxed: true,
                icon: Icons.park_outlined,
                title: 'No plantings recorded',
                line: 'Record what you plant — count, species and place. Survival is checked at 30, 60 and 90 days.',
                actionLabel: 'Record a planting',
                onAction: _record,
              )
            else if (_map)
              _mapView(p)
            else
              for (final post in _posts) ...[_card(post, p), const SizedBox(height: CanopySpace.s12)],
          ],
        ),
      ),
      sticky: StickyActionBar(children: [FieldButton(label: 'Record a planting', icon: Icons.park_outlined, onPressed: _record)]),
    );
  }

  Widget _card(PlantingPost post, CanopyPalette p) {
    final (label, color) = switch (post.stage) {
      VerificationStage.full => ('Verified', p.success),
      VerificationStage.stage1 => ('First check done', p.info),
      VerificationStage.pending => ('Pending verification', p.warning),
    };
    final ageDays = DateTime.now().difference(post.plantedDate).inDays;
    final nextCheck = [30, 60, 90].firstWhere((d) => d > ageDays, orElse: () => 0);
    return CanopyCard(
      padding: EdgeInsets.zero,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(CanopyRadius.md - 1)),
          child: SizedBox(
            width: 88,
            height: 108,
            child: CanopyImage(url: post.photoUrls.isEmpty ? null : post.photoUrls.first, fallbackIcon: Icons.park_outlined),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(CanopySpace.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StatusLabel(label, color: color),
              const SizedBox(height: CanopySpace.s2),
              Text('${post.quantity} ${post.species}', style: CanopyType.bodyStrong.copyWith(color: p.ink)),
              Text(
                [
                  'Planted ${DateFormat('d MMM yyyy').format(post.plantedDate)}',
                  if (post.growthStage != null) 'as ${post.growthStage}',
                  post.hasZone ? 'Zone' : (post.hasPoint ? 'Pin' : 'No location'),
                ].join(' · '),
                style: CanopyType.caption.copyWith(color: p.inkMuted),
              ),
              if (post.stage != VerificationStage.full && nextCheck > 0)
                Text('Next survival check at $nextCheck days', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _mapView(CanopyPalette p) {
    final pts = _posts.where((x) => x.hasPoint).toList();
    if (pts.isEmpty) {
      return Text('None of these plantings have a location yet.', style: CanopyType.body.copyWith(color: p.inkMuted));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(CanopyRadius.md),
        child: SizedBox(
          height: 360,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(pts.first.lat, pts.first.lng), zoom: 14),
            style: canopyMapStyle(context),
            circles: {
              for (final x in pts)
                Circle(
                  circleId: CircleId(x.id),
                  center: LatLng(x.lat, x.lng),
                  radius: 6 + x.quantity.clamp(0, 20).toDouble() / 2,
                  fillColor: p.primaryDim,
                  strokeColor: p.surface,
                  strokeWidth: 2,
                ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
      ),
      const SizedBox(height: CanopySpace.s8),
      MapLegend(items: [(p.primaryDim, '${pts.length} planting site${pts.length == 1 ? '' : 's'}')]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW PLANTING
// ─────────────────────────────────────────────────────────────────────────────

class _PlantingWizard extends StatefulWidget {
  const _PlantingWizard();

  @override
  State<_PlantingWizard> createState() => _PlantingWizardState();
}

class _PlantingWizardState extends State<_PlantingWizard> {
  static const _steps = ['Record', 'Photos', 'Location', 'Review'];
  static const _stages = ['Seedling', 'Sapling', 'Young tree'];
  static const _minPhotos = 3;

  int _step = 0;
  String _count = '';
  String? _stage;
  TreeSpecies? _species;
  final _otherSpecies = TextEditingController();
  DateTime _planted = DateTime.now();
  final List<File> _photos = [];
  bool _useZone = false;
  LatLng? _pin;
  bool _pinFromGps = false;
  ZoneDrawingResult? _zone;
  Position? _gps;
  bool _gpsTimedOut = false;
  StreamSubscription<Position>? _gpsSub;
  Timer? _gpsTimer;
  bool _saving = false, _showErrors = false;
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _startGps();
  }

  @override
  void dispose() {
    _otherSpecies.dispose();
    _gpsSub?.cancel();
    _gpsTimer?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _startGps() async {
    _gpsTimer = Timer(CanopyField.gpsTimeout, () {
      if (mounted && _gps == null) setState(() => _gpsTimedOut = true);
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsTimedOut = true);
        return;
      }
      _gpsSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).listen((pos) {
        if (!mounted) return;
        setState(() {
          _gps = pos;
          _gpsTimedOut = false;
          // Follow GPS until the person places the pin themselves.
          if ((_pin == null || _pinFromGps) && pos.accuracy <= CanopyField.gpsWeakMax) {
            _pin = LatLng(pos.latitude, pos.longitude);
            _pinFromGps = true;
          }
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  int get _countN => int.tryParse(_count) ?? 0;
  String get _speciesName => _species == TreeSpecies.other ? _otherSpecies.text.trim() : (_species?.displayLabel ?? '');

  String? _errorFor(int s) => switch (s) {
        0 => _countN <= 0
            ? 'Enter how many trees.'
            : _species == null || _speciesName.isEmpty
                ? 'Choose the species.'
                : null,
        1 => _photos.length < _minPhotos ? 'Add at least $_minPhotos photos — they are how the planting gets verified.' : null,
        2 => _useZone ? (_zone == null ? 'Draw the planting area.' : null) : (_pin == null ? 'Place the pin.' : null),
        _ => null,
      };

  void _next() {
    if (_errorFor(_step) != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _showErrors = false;
        _step--;
      });
    }
  }

  Future<void> _addPhotos(ImageSource source) async {
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x != null) setState(() => _photos.add(File(x.path)));
    } else {
      final xs = await picker.pickMultiImage(imageQuality: 85);
      setState(() {
        for (final x in xs) {
          if (_photos.length < 10) _photos.add(File(x.path));
        }
      });
    }
  }

  Future<void> _drawZone() async {
    final start = _pin ?? (_gps == null ? const LatLng(-1.2921, 36.8219) : LatLng(_gps!.latitude, _gps!.longitude));
    final r = await Navigator.of(context).push<ZoneDrawingResult>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => ZoneDrawingController(
        config: ZoneDrawingConfig.plantingDefault,
        initialPosition: CameraPosition(target: start, zoom: 17),
        initialPoints: _zone?.vertices ?? const [],
        onCancel: () => Navigator.pop(ctx),
        onZoneClosed: (res) => Navigator.pop(ctx, res),
      ),
    ));
    if (r != null) setState(() => _zone = r);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final service = EnvironmentOpsService.instance;
      final ctx = await service.resolveContext();
      if (ctx == null) throw StateError('not linked');
      final uid = FirebaseAuth.instance.currentUser?.uid ?? ctx.uid;
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final ref = FirebaseStorage.instance.ref('planting_photos/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putFile(_photos[i]);
        urls.add(await ref.getDownloadURL());
      }
      final centre = _useZone && _zone != null ? _centroid(_zone!.vertices) : _pin!;
      await service.createTreePlanting(
        orgId: ctx.orgId,
        uid: uid,
        speciesName: _speciesName,
        quantity: _countN,
        plantedDate: _planted,
        lat: centre.latitude,
        lng: centre.longitude,
        photoUrls: urls,
        area: ctx.area,
        zoneVertices: _useZone ? _zone?.vertices : null,
        growthStage: _stage?.toLowerCase(),
        locationIsGps: !_useZone && _pinFromGps,
      );
      if (!mounted) return;
      showCanopySnack(context, 'Planting saved — pending verification.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showCanopySnack(
            context,
            e is StateError
                ? 'Link an organisation before saving plantings.'
                : "Couldn't save. Nothing is lost — try again when you have signal.",
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static LatLng _centroid(List<LatLng> v) =>
      LatLng(v.fold(0.0, (s, p) => s + p.latitude) / v.length, v.fold(0.0, (s, p) => s + p.longitude) / v.length);

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final last = _step == _steps.length - 1;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CanopyScaffold(
        appBar: canopyAppBar(
          context,
          title: 'Record a planting',
          leading: IconButton(icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back), tooltip: _step == 0 ? 'Close' : 'Back', onPressed: _back),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
          children: [
            CanopyStepper(step: _step + 1, total: _steps.length, label: _steps[_step], stepLabels: _steps),
            const SizedBox(height: CanopySpace.section),
            ..._body(p),
            if (_showErrors && _errorFor(_step) != null)
              Padding(
                padding: const EdgeInsets.only(top: CanopySpace.s16),
                child: Text(_errorFor(_step)!, style: CanopyType.body.copyWith(color: p.danger)),
              ),
          ],
        ),
        sticky: StickyActionBar(children: [
          FieldButton(label: last ? 'Save planting' : 'Continue', loading: _saving, onPressed: last ? _submit : _next),
        ]),
      ),
    );
  }

  List<Widget> _body(CanopyPalette p) {
    switch (_step) {
      case 0:
        return [
          BigNumberInput(value: _count, unit: _countN == 1 ? 'tree' : 'trees'),
          const SizedBox(height: CanopySpace.s12),
          FieldKeypad(value: _count, decimal: false, maxLength: 4, onChanged: (v) => setState(() => _count = v)),
          const FieldEyebrow('Species'),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final s in TreeSpecies.values)
              CanopyFilterChip(label: s.displayLabel, selected: _species == s, onTap: () => setState(() => _species = s)),
          ]),
          if (_species == TreeSpecies.other) ...[
            const SizedBox(height: CanopySpace.s12),
            CanopyTextField(label: 'Species name', controller: _otherSpecies, onChanged: (_) => setState(() {})),
          ],
          const FieldEyebrow('Planted as (optional)'),
          CanopySegmented<String?>(
            options: [for (final s in _stages) (s, s)],
            value: _stage,
            onChanged: (v) => setState(() => _stage = _stage == v ? null : v),
          ),
          const FieldEyebrow('Date planted'),
          CanopyPickerField(
            label: 'Date',
            value: DateFormat('EEE d MMM yyyy').format(_planted),
            placeholder: 'Pick',
            icon: Icons.calendar_today_outlined,
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _planted, firstDate: DateTime(2015), lastDate: DateTime.now());
              if (d != null) setState(() => _planted = d);
            },
          ),
        ];
      case 1:
        return [
          Text('${_photos.length} of $_minPhotos photos', style: CanopyField.signalValue.copyWith(color: p.ink)),
          Text('Show the trees in the ground and the place around them. Photos are how the planting is verified.',
              style: CanopyType.body.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s16),
          Row(children: [
            Expanded(child: FieldButton(label: 'Take photo', icon: Icons.photo_camera_outlined, onPressed: () => _addPhotos(ImageSource.camera))),
            const SizedBox(width: CanopySpace.s12),
            Expanded(child: FieldButton.secondary(label: 'From gallery', onPressed: () => _addPhotos(ImageSource.gallery))),
          ]),
          const SizedBox(height: CanopySpace.s16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: CanopySpace.s8,
            crossAxisSpacing: CanopySpace.s8,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Stack(fit: StackFit.expand, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(CanopyRadius.sm), child: Image.file(_photos[i], fit: BoxFit.cover)),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: CanopyIconButton(
                        icon: Icons.close, tooltip: 'Remove photo', onImage: true, onPressed: () => setState(() => _photos.removeAt(i))),
                  ),
                ]),
            ],
          ),
        ];
      case 2:
        return [
          CanopySegmented<bool>(
            options: const [(false, 'A pin'), (true, 'An area')],
            value: _useZone,
            onChanged: (v) => setState(() => _useZone = v),
          ),
          const SizedBox(height: CanopySpace.s12),
          if (_useZone) ...[
            if (_zone == null)
              Text('Draw the outline of where the trees are.', style: CanopyType.body.copyWith(color: p.ink))
            else
              Text('Area drawn · ${formatArea(_zone!.areaKm2)} · ${_zone!.vertices.length} points',
                  style: CanopyType.bodyStrong.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s12),
            FieldButton(label: _zone == null ? 'Draw the planting area' : 'Redraw', onPressed: _drawZone),
          ] else ...[
            Row(children: [
              GpsChip(accuracyM: _gps?.accuracy, timedOut: _gpsTimedOut),
              const Spacer(),
              if (_pin != null && !_pinFromGps) Text('Placed by hand', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
            const SizedBox(height: CanopySpace.s8),
            if (_gps == null)
              Padding(
                padding: const EdgeInsets.only(bottom: CanopySpace.s8),
                child: CanopyCallout(
                  kind: _gpsTimedOut ? CalloutKind.warning : CalloutKind.info,
                  text: _gpsTimedOut
                      ? 'No GPS fix. Tap the map where the trees are to place the pin by hand.'
                      : 'Finding your location… or tap the map to place the pin yourself.',
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.md),
              child: SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _pin ?? const LatLng(-1.2921, 36.8219), zoom: _pin == null ? 12 : 17),
                  style: canopyMapStyle(context),
                  onMapCreated: (c) => _map = c,
                  onTap: (pos) => setState(() {
                    _pin = pos;
                    _pinFromGps = false;
                  }),
                  markers: {
                    if (_pin != null)
                      Marker(
                        markerId: const MarkerId('pin'),
                        position: _pin!,
                        draggable: true,
                        onDragEnd: (pos) => setState(() {
                          _pin = pos;
                          _pinFromGps = false;
                        }),
                      ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: CanopySpace.s8),
            if (_gps != null)
              Align(
                alignment: Alignment.centerLeft,
                child: CanopyButton.quiet(
                  label: 'Use my location',
                  size: CanopyButtonSize.compact,
                  onPressed: () {
                    final here = LatLng(_gps!.latitude, _gps!.longitude);
                    setState(() {
                      _pin = here;
                      _pinFromGps = true;
                    });
                    _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 17));
                  },
                ),
              ),
          ],
        ];
      default:
        return [
          CanopyListGroup(children: [
            CanopyFactRow(label: 'Trees', value: '$_countN $_speciesName'),
            if (_stage != null) CanopyFactRow(label: 'Planted as', value: _stage!),
            CanopyFactRow(label: 'Date', value: DateFormat('d MMM yyyy').format(_planted)),
            CanopyFactRow(label: 'Photos', value: '${_photos.length}'),
            CanopyFactRow(
              label: 'Location',
              value: _useZone
                  ? 'Area · ${formatArea(_zone?.areaKm2 ?? 0)}'
                  : (_pinFromGps ? 'Pin from GPS ±${_gps?.accuracy.round() ?? '?'} m' : 'Pin placed by hand'),
            ),
          ]),
          const SizedBox(height: CanopySpace.s16),
          const CanopyCallout(
            text: 'Saved as Pending verification. Survival is checked at about 30, 60 and 90 days. This is a count of living trees, not a carbon estimate.',
          ),
        ];
    }
  }
}
