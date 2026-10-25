// lib/Community/Heritage/heritage_map_screen.dart
//
// The culture map. Every public entry is pinned, and each pin is a round photo
// of the entry (like organisation pins), ringed in its category colour. There
// is no "All": filters are the organisations and each kind of entry (Food,
// Stories, Music…), all on to start with; tap one to hide it. Tapping a pin
// lifts a card with the entry and a way into it.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Culture/Heritage/Services/heritage_bundled_images.dart';
import '../../Culture/Heritage/Services/heritage_content_types.dart';
import '../../Culture/Heritage/Services/heritage_data_service.dart';
import '../../Organization/Explorer/org_view_screen.dart';
import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import '../Map/org_logo_cache.dart';
import 'heritage_item_screen.dart';
import 'heritage_ui.dart';

class _CulturalOrg {
  final String id, name;
  final String? logo;
  final LatLng at;
  final Map<String, dynamic> raw;
  const _CulturalOrg(this.id, this.name, this.logo, this.at, this.raw);
}

class HeritageMapScreen extends StatefulWidget {
  const HeritageMapScreen({super.key});

  @override
  State<HeritageMapScreen> createState() => _HeritageMapScreenState();
}

class _HeritageMapScreenState extends State<HeritageMapScreen> {
  static const _orgsKey = '_orgs';
  final _service = HeritageDataService();
  late final Stream<List<HeritageItem>> _stream = _service.streamMapped();
  late final Future<List<_CulturalOrg>> _orgsFuture = _loadOrgs();
  final Map<String, BitmapDescriptor> _icons = {};
  final Set<String> _building = {};
  GoogleMapController? _map;
  // Everything is on to start with; there is no "All".
  late final Set<String> _on = {_orgsKey, for (final t in HeritageContentTypes.ordered) t.key};
  Object? _selected; // HeritageItem | _CulturalOrg
  bool _fitted = false;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<List<_CulturalOrg>> _loadOrgs() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('organizations').where('culturalStatus', isEqualTo: 'approved').get();
      final out = <_CulturalOrg>[];
      for (final d in snap.docs) {
        final m = d.data();
        final gp = m['location'];
        final lat = gp is GeoPoint ? gp.latitude : (m['lat'] as num?)?.toDouble();
        final lng = gp is GeoPoint ? gp.longitude : (m['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        out.add(_CulturalOrg(d.id, '${m['org_name'] ?? m['name'] ?? 'Organisation'}', (m['logoUrl'] ?? m['profilePhoto']) as String?,
            LatLng(lat, lng), m));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  // ── Round photo markers ─────────────────────────────────────────────────

  Future<Uint8List?> _bytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (HeritageBundledImages.isAsset(url)) {
      try {
        return (await rootBundle.load(HeritageBundledImages.assetPath(url))).buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }
    return OrgLogoCache.instance.bytes(url);
  }

  void _ensure(String key, String? url, Color ring, IconData glyph) {
    if (_icons.containsKey(key) || _building.contains(key)) return;
    _building.add(key);
    _photoMarker(url, ring, glyph).then((d) {
      _building.remove(key);
      if (mounted) setState(() => _icons[key] = d);
    }).catchError((_) {
      _building.remove(key);
    });
  }

  /// A circle of the photo with a white ring, a category-coloured outer ring
  /// and a small glyph badge. Falls back to a coloured disc with the glyph.
  Future<BitmapDescriptor> _photoMarker(String? url, Color ring, IconData glyph) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const logical = 52.0;
    final size = logical * dpr;
    final bytes = await _bytes(url);
    ui.Image? photo;
    if (bytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 200);
        photo = (await codec.getNextFrame()).image;
      } catch (_) {}
    }
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final centre = Offset(size / 2, size / 2);
    final r = size / 2 - 6 * dpr;
    c.drawCircle(centre.translate(0, 1.5 * dpr), r + 3 * dpr,
        Paint()..color = const Color(0x55000000)..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * dpr));
    c.drawCircle(centre, r + 3 * dpr, Paint()..color = ring);
    c.drawCircle(centre, r + 1.5 * dpr, Paint()..color = Colors.white);
    if (photo != null) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
      final side = photo.width < photo.height ? photo.width.toDouble() : photo.height.toDouble();
      c.drawImageRect(
        photo,
        Rect.fromCenter(center: Offset(photo.width / 2, photo.height / 2), width: side, height: side),
        Rect.fromCircle(center: centre, radius: r),
        Paint()..filterQuality = FilterQuality.medium,
      );
      c.restore();
    } else {
      c.drawCircle(centre, r, Paint()..color = ring);
      _glyph(c, glyph, 24 * dpr, Colors.white, centre);
    }
    // Category badge, bottom-right.
    final badge = centre.translate(r * 0.72, r * 0.72);
    c.drawCircle(badge, 9 * dpr, Paint()..color = Colors.white);
    c.drawCircle(badge, 7.5 * dpr, Paint()..color = ring);
    _glyph(c, glyph, 10 * dpr, Colors.white, badge);
    final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
    final out = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(out!.buffer.asUint8List(), imagePixelRatio: dpr);
  }

  void _glyph(Canvas c, IconData icon, double fontSize, Color color, Offset centre) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textDirection: ui.TextDirection.ltr))
      ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize, fontFamily: icon.fontFamily, fontFamilyFallback: const []))
      ..addText(String.fromCharCode(icon.codePoint));
    final para = pb.build()..layout(ui.ParagraphConstraints(width: fontSize * 2));
    c.drawParagraph(para, Offset(centre.dx - para.longestLine / 2, centre.dy - para.height / 2));
  }

  String? _coverFor(HeritageItem i) =>
      (i.coverImageUrl ?? '').isNotEmpty ? i.coverImageUrl : HeritageBundledImages.forContentType(i.contentType);

  // ── Fit ────────────────────────────────────────────────────────────────────

  void _fit(List<LatLng> pts) {
    if (_fitted || _map == null || pts.isEmpty) return;
    _fitted = true;
    if (pts.length == 1) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 11));
      return;
    }
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _map!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 90));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    return CanopyScaffold(
      body: FutureBuilder<List<_CulturalOrg>>(
        future: _orgsFuture,
        builder: (context, orgSnap) => StreamBuilder<List<HeritageItem>>(
          stream: _stream,
          builder: (context, snap) {
            final orgs = orgSnap.data ?? const <_CulturalOrg>[];
            final items = (snap.data ?? const <HeritageItem>[]).where((i) => _on.contains(i.contentType)).toList();
            final showOrgs = _on.contains(_orgsKey) ? orgs : const <_CulturalOrg>[];

            final markers = <Marker>{};
            for (final i in items) {
              final cat = heritageCategoryFor(i.contentType);
              final cover = _coverFor(i);
              final key = 'e:${i.id}:${cover ?? ''}';
              _ensure(key, cover, cat.fill, heritageIconFor(i.contentType));
              markers.add(Marker(
                markerId: MarkerId('e_${i.id}'),
                position: LatLng(i.lat!, i.lng!),
                icon: _icons[key] ?? BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                onTap: () => setState(() => _selected = i),
              ));
            }
            for (final o in showOrgs) {
              final key = 'o:${o.id}:${o.logo ?? ''}';
              _ensure(key, o.logo, p.ink, Icons.apartment_outlined);
              markers.add(Marker(
                markerId: MarkerId('o_${o.id}'),
                position: o.at,
                icon: _icons[key] ?? BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                onTap: () => setState(() => _selected = o),
              ));
            }
            final everything = [for (final i in (snap.data ?? const <HeritageItem>[])) LatLng(i.lat!, i.lng!), for (final o in orgs) o.at];

            return Stack(children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(target: LatLng(-0.0236, 37.9062), zoom: 5.5),
                style: canopyMapStyle(context),
                onMapCreated: (c) {
                  _map = c;
                  _fit(everything);
                },
                onTap: (_) => setState(() => _selected = null),
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                markers: markers,
              ),
              Positioned(
                top: top + CanopySpace.s8,
                left: 0,
                right: 0,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CanopySpace.s12),
                    child: Row(children: [
                      CanopyIconButton(icon: Icons.arrow_back, tooltip: 'Back', float: true, onPressed: () => Navigator.maybePop(context)),
                      const SizedBox(width: CanopySpace.s12),
                      Expanded(child: Text('Culture map', style: CanopyType.title.copyWith(color: p.ink))),
                    ]),
                  ),
                  const SizedBox(height: CanopySpace.s8),
                  CanopyChipRail(chips: [
                    CanopyFilterChip(
                      label: 'Organisations',
                      icon: Icons.apartment_outlined,
                      selected: _on.contains(_orgsKey),
                      float: true,
                      onTap: () => setState(() => _on.contains(_orgsKey) ? _on.remove(_orgsKey) : _on.add(_orgsKey)),
                    ),
                    for (final t in HeritageContentTypes.ordered)
                      CanopyFilterChip(
                        label: t.label,
                        icon: t.icon,
                        selected: _on.contains(t.key),
                        float: true,
                        onTap: () => setState(() => _on.contains(t.key) ? _on.remove(t.key) : _on.add(t.key)),
                      ),
                  ]),
                ]),
              ),
              if (snap.hasData && everything.isEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(CanopySpace.gutter),
                      child: CanopyCard(
                        child: Row(children: [
                          Icon(Icons.travel_explore_outlined, color: p.inkMuted),
                          const SizedBox(width: CanopySpace.s12),
                          Expanded(
                            child: Text('Entries appear here as organisations pin where they are. Check back soon.',
                                style: CanopyType.body.copyWith(color: p.ink)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              if (_selected != null) Align(alignment: Alignment.bottomCenter, child: _card(context, p, _selected!)),
            ]);
          },
        ),
      ),
    );
  }

  Widget _card(BuildContext context, CanopyPalette p, Object sel) {
    if (sel is _CulturalOrg) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CanopySpace.gutter),
          child: CanopyCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrgViewScreen(orgId: sel.id, orgData: sel.raw))),
            child: Row(children: [
              CanopyAvatar(url: sel.logo, name: sel.name, size: 56, org: true),
              const SizedBox(width: CanopySpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sel.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: CanopyType.subhead.copyWith(color: p.ink)),
                  Text('Cultural organisation', style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ]),
              ),
              Icon(Icons.chevron_right, color: p.inkMuted),
            ]),
          ),
        ),
      );
    }
    final it = sel as HeritageItem;
    final cat = heritageCategoryFor(it.contentType);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CanopySpace.gutter),
        child: CanopyCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeritageItemScreen(item: it))),
          child: Row(children: [
            ClipOval(
              child: SizedBox(width: 64, height: 64, child: HeritageMedia(url: _coverFor(it), category: cat, icon: heritageIconFor(it.contentType))),
            ),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CategoryLabel(it.contentTypeLabel, category: cat),
                Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: CanopyType.subhead.copyWith(color: p.ink)),
                if ((it.communityName ?? '').isNotEmpty) Text(it.communityName!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ]),
            ),
            Icon(Icons.chevron_right, color: p.inkMuted),
          ]),
        ),
      ),
    );
  }
}
