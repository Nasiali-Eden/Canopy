// lib/EnvironmentalOps/Territory/env_territory.dart
//
// Territory (ENVOPS_HANDOFF §3.2). Zones: map (330) + legend + list
// (selected row outlined) + sticky "Map something". Mapping choice: an area
// (Walk the boundary — most accurate / Tap it on the map) or a single place
// (Dumpsite / Collection point). Capture keeps its points on the phone as a
// draft after every change; Name & save shows area, points and method.
// Not linked or save failed → the draft stays on the phone with Retry.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../Organization/Map/org_map_ops.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import '../Shared/zone_drawing_controller.dart';
import '../Shared/zone_walk_capture.dart';
import '../envops_ui.dart';

class CollectionZone {
  final String id;
  final String name;
  final List<LatLng> vertices;
  final DateTime createdAt;
  final String status; // draft | active | completed
  final double areaKm2;
  final String orgId;

  const CollectionZone({
    required this.id,
    this.orgId = '',
    required this.name,
    required this.vertices,
    required this.createdAt,
    required this.status,
    required this.areaKm2,
  });

  factory CollectionZone.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CollectionZone(
      id: doc.id,
      name: d['name'] as String? ?? 'Unnamed zone',
      vertices: [
        for (final v in (d['vertices'] as List? ?? const []))
          if (v is Map && v['lat'] is num && v['lng'] is num) LatLng((v['lat'] as num).toDouble(), (v['lng'] as num).toDouble()),
      ],
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'active',
      areaKm2: (d['area_km2'] as num?)?.toDouble() ?? 0,
      orgId: d['org_id'] as String? ?? '',
    );
  }
}

enum _MapChoice { walk, tap, dumpsite, collectionPoint, otherPlace }

class EnvTerritoryScreen extends StatefulWidget {
  const EnvTerritoryScreen({super.key});

  @override
  State<EnvTerritoryScreen> createState() => _EnvTerritoryScreenState();
}

class _EnvTerritoryScreenState extends State<EnvTerritoryScreen> {
  EnvironmentOpsContext? _ctx;
  List<CollectionZone> _zones = const [];
  List<ZoneDraft> _drafts = const [];
  String? _selected;
  bool _loading = true, _failed = false;
  GoogleMapController? _map;
  CameraPosition _camera = const CameraPosition(target: LatLng(-1.2921, 36.8219), zoom: 13);

  @override
  void initState() {
    super.initState();
    _load();
    _locate();
    FieldDraftStore.instance.revision.addListener(_loadDrafts);
  }

  @override
  void dispose() {
    FieldDraftStore.instance.revision.removeListener(_loadDrafts);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      _ctx = await EnvironmentOpsService.instance.resolveContext();
      final orgId = _ctx?.orgId;
      var zones = <CollectionZone>[];
      if (orgId != null) {
        final snap = await FirebaseFirestore.instance.collection('collection_zones').where('org_id', isEqualTo: orgId).limit(100).get();
        zones = snap.docs.map(CollectionZone.fromFirestore).where((z) => z.vertices.length >= 3).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _loading = false;
      });
      _fitAll();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
    await _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final d = await FieldDraftStore.instance.zones();
    if (mounted) setState(() => _drafts = d);
  }

  Future<void> _locate() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() => _camera = CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 15));
        if (_zones.isEmpty) _map?.moveCamera(CameraUpdate.newCameraPosition(_camera));
      }
    } catch (_) {}
  }

  void _fitAll() {
    final pts = [for (final z in _zones) ...z.vertices];
    if (_map == null || pts.isEmpty) return;
    _fit(pts);
  }

  void _fit(List<LatLng> pts) {
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    _map?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)), 40));
  }

  void _select(CollectionZone z) {
    setState(() => _selected = _selected == z.id ? null : z.id);
    if (_selected != null) _fit(z.vertices);
  }

  Map<String, dynamic>? get _orgData => _ctx == null ? null : {..._ctx!.orgData, 'orgId': _ctx!.orgId};

  // ── Map something ────────────────────────────────────────────────────────

  Future<void> _mapSomething() async {
    final choice = await showCanopySheet<_MapChoice>(context, builder: (ctx) {
      final p = ctx.canopy;
      Widget row(_MapChoice c, IconData icon, String title, String line) => CanopyListRow(
            icon: icon,
            title: title,
            subtitle: line,
            onTap: () => Navigator.pop(ctx, c),
          );
      return CanopySheetBody(title: 'Map something', children: [
        Text('AN AREA · BOUNDARY', style: CanopyField.fieldEyebrow.copyWith(color: p.inkMuted)),
        const SizedBox(height: CanopySpace.s8),
        CanopyListGroup(children: [
          row(_MapChoice.walk, Icons.directions_walk, 'Walk the boundary', 'Most exact — capture each corner with your phone GPS'),
          row(_MapChoice.tap, Icons.touch_app_outlined, 'Select it on the map', 'Choose the exact corners on the map'),
        ]),
        const SizedBox(height: CanopySpace.s16),
        Text('A SINGLE PLACE · POINT', style: CanopyField.fieldEyebrow.copyWith(color: p.inkMuted)),
        const SizedBox(height: CanopySpace.s8),
        CanopyListGroup(children: [
          row(_MapChoice.dumpsite, Icons.delete_outline, 'Dumpsite', 'A place where waste is dumped'),
          row(_MapChoice.collectionPoint, Icons.inventory_2_outlined, 'Collection point', 'Where material is gathered or bought'),
          row(_MapChoice.otherPlace, Icons.add_location_alt_outlined, 'Another kind of place', 'Water point, sorting hub, tree site…'),
        ]),
      ]);
    });
    if (choice == null || !mounted) return;
    switch (choice) {
      case _MapChoice.walk:
        _capture(walk: true);
      case _MapChoice.tap:
        _capture(walk: false);
      case _MapChoice.dumpsite:
      case _MapChoice.collectionPoint:
      case _MapChoice.otherPlace:
        final org = _orgData;
        if (org == null) {
          showCanopySnack(context, 'Link an organisation before mapping places.', error: true);
          return;
        }
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrgMapOpsScreen(
            orgData: org,
            initialPinTypeId: switch (choice) {
              _MapChoice.dumpsite => 'dumpsite',
              _MapChoice.collectionPoint => 'collection_site',
              _ => null,
            },
          ),
        ));
    }
  }

  // ── Capture → name → save ────────────────────────────────────────────────

  Future<void> _capture({required bool walk, ZoneDraft? resume}) async {
    final draftId = resume?.id ?? 'z${DateTime.now().millisecondsSinceEpoch}';
    final method = resume?.method ?? (walk ? 'walk' : 'tap');
    var latest = resume?.points ?? const <LatLng>[];
    void keep(List<LatLng> pts) {
      latest = pts;
      if (pts.isEmpty) {
        FieldDraftStore.instance.removeZone(draftId);
      } else {
        FieldDraftStore.instance.putZone(ZoneDraft(id: draftId, name: resume?.name ?? '', points: pts, method: method, capturedAt: DateTime.now()));
      }
    }

    final result = await Navigator.of(context).push<ZoneDrawingResult>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) {
        Future<void> cancel() async {
          if (latest.isEmpty) {
            Navigator.pop(ctx);
            return;
          }
          final discard = await showCanopyConfirm(ctx,
              title: 'Leave this zone?',
              message: '${latest.length} points are kept on this phone as a draft. You can finish it from Territory.',
              confirmLabel: 'Keep draft and leave',
              cancelLabel: 'Keep mapping');
          if (discard && ctx.mounted) Navigator.pop(ctx);
        }

        return method == 'walk'
            ? ZoneWalkCaptureController(
                initialPosition: _camera,
                initialPoints: resume?.points ?? const [],
                onPointsChanged: keep,
                onCancel: cancel,
                onZoneClosed: (r) => Navigator.pop(ctx, r),
              )
            : ZoneDrawingController(
                config: ZoneDrawingConfig.collectionDefault,
                initialPosition: _camera,
                initialPoints: resume?.points ?? const [],
                onPointsChanged: keep,
                onCancel: cancel,
                onZoneClosed: (r) => Navigator.pop(ctx, r),
              );
      },
    ));
    if (result == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _NameZoneScreen(result: result, method: method, draftId: draftId, ctx: _ctx, initialName: resume?.name ?? ''),
    ));
    if (saved == true) _load();
  }

  Future<void> _retryDraft(ZoneDraft d) async {
    if (d.points.length < 3) {
      _capture(walk: d.method == 'walk', resume: d);
      return;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _NameZoneScreen(
        result: ZoneDrawingResult(vertices: d.points, zoneType: ZoneType.collectionZone),
        method: d.method,
        draftId: d.id,
        ctx: _ctx,
        initialName: d.name,
      ),
    ));
    if (saved == true) _load();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.md),
              child: SizedBox(
                height: 330,
                child: _loading
                    ? const CanopySkeleton(height: 330)
                    : GoogleMap(
                        initialCameraPosition: _camera,
                        style: canopyMapStyle(context),
                        onMapCreated: (c) {
                          _map = c;
                          _fitAll();
                        },
                        polygons: {
                          for (final z in _zones)
                            Polygon(
                              polygonId: PolygonId(z.id),
                              points: z.vertices,
                              fillColor: CanopyField.zoneFill(p),
                              strokeColor: _selected == z.id ? CanopyField.zoneSelectedStroke(p) : CanopyField.zoneStroke(p),
                              strokeWidth: _selected == z.id ? 4 : 3,
                              zIndex: _selected == z.id ? 2 : 1,
                              consumeTapEvents: true,
                              onTap: () => _select(z),
                            ),
                          for (final d in _drafts.where((d) => d.points.length >= 3))
                            Polygon(
                              polygonId: PolygonId('draft_${d.id}'),
                              points: d.points,
                              fillColor: Colors.transparent,
                              strokeColor: CanopyField.zoneDraftStroke(p),
                              strokeWidth: 3,
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
            MapLegend(items: [
              (CanopyField.zoneStroke(p), '${_zones.length} zone${_zones.length == 1 ? '' : 's'}'),
              if (_drafts.isNotEmpty) (CanopyField.zoneDraftStroke(p), '${_drafts.length} draft${_drafts.length == 1 ? '' : 's'} on this phone'),
            ]),
            if (_ctx == null && !_loading) ...[
              const SizedBox(height: CanopySpace.s16),
              const CanopyCallout(
                kind: CalloutKind.warning,
                title: 'Link an organisation before saving',
                text: 'You can still map. Points are kept on this phone as drafts until the workspace is linked.',
              ),
            ],
            if (_drafts.isNotEmpty) ...[
              const FieldEyebrow('Drafts on this phone'),
              CanopyListGroup(children: [
                for (final d in _drafts)
                  CanopyListRow(
                    icon: d.method == 'walk' ? Icons.directions_walk : Icons.touch_app_outlined,
                    title: d.name.isEmpty ? 'Unnamed zone' : d.name,
                    subtitle: '${d.points.length} points · ${fieldNoteTime(d.capturedAt)}${d.lastError == null ? '' : ' · not sent'}',
                    trailing: CanopyButton.secondary(
                      label: d.points.length < 3 ? 'Continue' : 'Save',
                      size: CanopyButtonSize.compact,
                      onPressed: () => _retryDraft(d),
                    ),
                    onTap: () => _capture(walk: d.method == 'walk', resume: d),
                  ),
              ]),
            ],
            const FieldEyebrow('Zones'),
            if (_failed)
              CanopyErrorState(inline: true, title: "Couldn't load your zones.", onRetry: _load)
            else if (_loading)
              const CanopyListSkeleton(rows: 3)
            else if (_zones.isEmpty)
              const CanopyEmptyState(
                boxed: true,
                icon: Icons.polyline_outlined,
                title: 'No zones yet',
                line: 'Map the area you collect from or work in.',
              )
            else
              for (final z in _zones) ...[
                CanopyCard(
                  borderColor: _selected == z.id ? p.ink : null,
                  borderWidth: _selected == z.id ? 1.5 : 1,
                  padding: const EdgeInsets.all(CanopySpace.s12),
                  onTap: () => _select(z),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(z.name, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                        Text('${formatArea(z.areaKm2)} · ${z.vertices.length} points · ${DateFormat('d MMM yyyy').format(z.createdAt)}',
                            style: CanopyType.caption.copyWith(color: p.inkMuted)),
                      ]),
                    ),
                    StatusLabel(
                      switch (z.status) { 'completed' => 'Completed', 'draft' => 'Draft', _ => 'Active' },
                      color: switch (z.status) { 'completed' => p.inkMuted, 'draft' => p.warning, _ => p.success },
                    ),
                  ]),
                ),
                const SizedBox(height: CanopySpace.s8),
              ],
          ],
        ),
      ),
      sticky: StickyActionBar(children: [FieldButton(label: 'Map something', icon: Icons.add_location_alt_outlined, onPressed: _mapSomething)]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAME & SAVE
// ─────────────────────────────────────────────────────────────────────────────

class _NameZoneScreen extends StatefulWidget {
  final ZoneDrawingResult result;
  final String method;
  final String draftId;
  final EnvironmentOpsContext? ctx;
  final String initialName;
  const _NameZoneScreen({required this.result, required this.method, required this.draftId, required this.ctx, this.initialName = ''});

  @override
  State<_NameZoneScreen> createState() => _NameZoneScreenState();
}

class _NameZoneScreenState extends State<_NameZoneScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  bool _saving = false, _showErrors = false;
  String? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _keepDraft({String? error}) => FieldDraftStore.instance.putZone(ZoneDraft(
        id: widget.draftId,
        name: _name.text.trim(),
        points: widget.result.vertices,
        method: widget.method,
        capturedAt: DateTime.now(),
        lastError: error,
      ));

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (_name.text.trim().isEmpty) return;
    final c = widget.ctx;
    if (c == null) {
      await _keepDraft(error: 'Not linked to an organisation');
      setState(() => _failure = 'blocked');
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await EnvironmentOpsService.instance.createZone(
        orgId: c.orgId,
        uid: c.uid,
        name: _name.text.trim(),
        vertices: widget.result.vertices.toList(),
        areaKm2: widget.result.areaKm2,
      );
      await FieldDraftStore.instance.removeZone(widget.draftId);
      if (!mounted) return;
      showCanopySnack(context, 'Zone saved.');
      Navigator.pop(context, true);
    } catch (_) {
      await _keepDraft(error: "Couldn't save — still on this phone");
      if (mounted) setState(() => _failure = 'failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    final ok = await showCanopyConfirm(context,
        title: 'Discard this zone?',
        message: '${widget.result.vertices.length} captured points will be deleted from this phone.',
        confirmLabel: 'Discard',
        danger: true);
    if (!ok) return;
    await FieldDraftStore.instance.removeZone(widget.draftId);
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Name this zone'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          SignalGrid(signals: [
            SignalCard(value: formatArea(widget.result.areaKm2), caption: 'Area'),
            SignalCard(value: '${widget.result.vertices.length}', caption: widget.method == 'walk' ? 'Points · walked' : 'Points · tapped'),
          ]),
          const SizedBox(height: CanopySpace.section),
          CanopyTextField(
            label: 'Zone name',
            hint: 'e.g. Kibera Zone A',
            controller: _name,
            autofocus: true,
            error: _showErrors && _name.text.trim().isEmpty ? 'Give the zone a name your team will recognise.' : null,
            onChanged: (_) => setState(() {}),
          ),
          if (_failure == 'blocked') ...[
            const SizedBox(height: CanopySpace.s16),
            const CanopyCallout(
              kind: CalloutKind.warning,
              title: 'Link an organisation before saving',
              text: 'Your points are kept on this phone as a draft. Save it from Territory once the workspace is linked.',
            ),
          ],
          if (_failure == 'failed') ...[
            const SizedBox(height: CanopySpace.s16),
            const CanopyCallout(
              kind: CalloutKind.danger,
              title: "The zone didn't save",
              text: 'Nothing is lost — the points are kept on this phone. Retry when you have signal, or leave and finish later from Territory.',
            ),
          ],
          const SizedBox(height: CanopySpace.section),
          Center(child: CanopyButton.quietDanger(label: 'Discard zone', onPressed: _saving ? null : _discard)),
          if (_failure != null)
            Center(
              child: CanopyButton.quiet(label: 'Leave — keep the draft', onPressed: () => Navigator.pop(context, false)),
            ),
        ],
      ),
      sticky: StickyActionBar(children: [
        FieldButton(label: _failure == 'failed' ? 'Retry save' : 'Save zone', loading: _saving, onPressed: _save),
      ]),
    );
  }
}
