// lib/Community/Map/map.dart
//
// Community Map + org sheet (DESIGN_HANDOFF.md §3, markers §2 / CanopyMarkers).
//
//   • Map styled from CanopyMapColors, light and dark (POI/transit off).
//   • Markers: six place types in CanopyMarkers colours (white glyph, 2.5
//     surface ring, shadow), org pins (logo or primaryDeep disc), reports
//     (Incidents with coordinates — "Reports" filter replaces the old
//     Incidents feed entry point), selected = larger with an ink ring,
//     "you" = the platform location dot.
//   • Floating search (organisations, places, reports; also the way into the
//     org explorer and the env-ops map) and float filter chips; re-tapping an
//     active chip opens its sub-filters.
//   • Selection sheet: org (identity, verified label, about, upcoming
//     activities as compact ActivityCards, View organisation + call/website),
//     place (directions), report (status, see all reports).
//   • Everything on the map is also reachable as a list via search.
//
// Only real Firestore data is shown — no placeholder orgs or pins.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Organization/Explorer/org_explorer_screen.dart';
import '../../Organization/Explorer/org_view_screen.dart';
import '../../Organization/Map/org_map_ops.dart';
import '../../Services/Incidents/incidents_service.dart';
import '../../Shared/Activities/activity_card.dart';
import '../../Shared/Activities/activity_detail_screen.dart';
import '../../theme/canopy_components.dart';
import '../../theme/canopy_map_style.dart';
import 'env_ops_map_screen.dart';
import 'org_logo_cache.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLACE TYPES
// ─────────────────────────────────────────────────────────────────────────────

enum AmenityType {
  waterPoint,
  recyclingDropOff,
  dumpsite,
  canopyHub,
  cleanupEvent,
  treeSite,
  collectionSite,
  sortingHub,
  scrapBuyer,
  policeStation,
  publicToilet,
  communityCentre,
  market,
  school,
  clinic,
  placeOfWorship,
  landmark,
}

/// Pins that belong to the Environment layer.
const _envAmenities = {
  AmenityType.dumpsite,
  AmenityType.recyclingDropOff,
  AmenityType.collectionSite,
  AmenityType.sortingHub,
  AmenityType.scrapBuyer,
  AmenityType.treeSite,
};

/// Pins that are happenings rather than permanent places.
const _eventAmenities = {AmenityType.cleanupEvent, AmenityType.treeSite};

extension AmenityTypeX on AmenityType {
  String get label => switch (this) {
        AmenityType.waterPoint => 'Water point',
        AmenityType.recyclingDropOff => 'Recycling drop-off',
        AmenityType.dumpsite => 'Dumpsite',
        AmenityType.canopyHub => 'Canopy hub',
        AmenityType.cleanupEvent => 'Clean-up event',
        AmenityType.treeSite => 'Tree planting site',
        AmenityType.collectionSite => 'Collection site',
        AmenityType.sortingHub => 'Sorting hub',
        AmenityType.scrapBuyer => 'Scrap buyer',
        AmenityType.policeStation => 'Police station',
        AmenityType.publicToilet => 'Public toilet',
        AmenityType.communityCentre => 'Community centre',
        AmenityType.market => 'Market',
        AmenityType.school => 'School',
        AmenityType.clinic => 'Clinic',
        AmenityType.placeOfWorship => 'Place of worship',
        AmenityType.landmark => 'Landmark',
      };

  IconData get icon => switch (this) {
        AmenityType.waterPoint => Icons.water_drop_outlined,
        AmenityType.recyclingDropOff => Icons.recycling_outlined,
        AmenityType.dumpsite => Icons.delete_outline,
        AmenityType.canopyHub => Icons.hub_outlined,
        AmenityType.cleanupEvent => Icons.cleaning_services_outlined,
        AmenityType.treeSite => Icons.park_outlined,
        AmenityType.collectionSite => Icons.inventory_2_outlined,
        AmenityType.sortingHub => Icons.warehouse_outlined,
        AmenityType.scrapBuyer => Icons.point_of_sale_outlined,
        AmenityType.policeStation => Icons.local_police_outlined,
        AmenityType.publicToilet => Icons.wc_outlined,
        AmenityType.communityCentre => Icons.people_outline,
        AmenityType.market => Icons.storefront_outlined,
        AmenityType.school => Icons.school_outlined,
        AmenityType.clinic => Icons.local_hospital_outlined,
        AmenityType.placeOfWorship => Icons.church_outlined,
        AmenityType.landmark => Icons.location_city_outlined,
      };

  Color markerColor(CanopyPalette p) => switch (this) {
        AmenityType.waterPoint => CanopyMarkers.waterPoint(p),
        AmenityType.recyclingDropOff => CanopyMarkers.recycling(p),
        AmenityType.dumpsite => CanopyMarkers.dumpsite(p),
        AmenityType.canopyHub => CanopyMarkers.canopyHub(p),
        AmenityType.cleanupEvent => CanopyMarkers.cleanupEvent(p),
        AmenityType.treeSite => CanopyMarkers.treeSite(p),
        AmenityType.collectionSite => CanopyMarkers.recycling(p),
        AmenityType.sortingHub => CanopyMarkers.canopyHub(p),
        AmenityType.scrapBuyer => CanopyMarkers.recycling(p),
        AmenityType.policeStation ||
        AmenityType.publicToilet ||
        AmenityType.communityCentre ||
        AmenityType.market ||
        AmenityType.school ||
        AmenityType.clinic ||
        AmenityType.placeOfWorship ||
        AmenityType.landmark =>
          CanopyMarkers.waterPoint(p),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class MapAmenity {
  final String id;
  final String name;
  final AmenityType amenityType;
  final LatLng location;
  final String description;
  final String? reportedBy;
  final DateTime? verifiedAt;
  final bool isActive;
  final String? operatingHours;
  final List<String> acceptedMaterials;

  const MapAmenity({
    required this.id,
    required this.name,
    required this.amenityType,
    required this.location,
    required this.description,
    this.reportedBy,
    this.verifiedAt,
    this.isActive = true,
    this.operatingHours,
    this.acceptedMaterials = const [],
  });
}

class MapOrganization {
  final String id;
  final String name;
  final String description;
  final LatLng location;
  final String sectorId;
  final String orgTypeId;
  final List<String> subTypeIds;
  final List<String> beneficiaryGroupIds;
  final List<String> facilityTypeIds;
  final List<String> subFacilityIds;
  final String? logoUrl;
  final String? coverImageUrl;
  final String legalDesignation;
  final String country;
  final String city;
  final String area;
  final bool verified;
  final String? phone;
  final String? website;
  final Map<String, dynamic> raw;

  const MapOrganization({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.sectorId,
    required this.orgTypeId,
    required this.subTypeIds,
    required this.beneficiaryGroupIds,
    required this.facilityTypeIds,
    this.subFacilityIds = const [],
    this.logoUrl,
    this.coverImageUrl,
    required this.legalDesignation,
    required this.country,
    required this.city,
    required this.area,
    this.verified = false,
    this.phone,
    this.website,
    this.raw = const {},
  });

  String get place => [area, city].where((s) => s.isNotEmpty).join(', ');
}

/// An Incidents report that carries coordinates ("lat, lng").
class _MapReport {
  final IncidentReport report;
  final LatLng location;
  const _MapReport(this.report, this.location);

  static final _coords =
      RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)');

  static _MapReport? from(IncidentReport r) {
    final m = _coords.firstMatch(r.location);
    if (m == null) return null;
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return _MapReport(r, LatLng(lat, lng));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTERS
// ─────────────────────────────────────────────────────────────────────────────

enum _Layer { organisations, places, events, environment }

extension on _Layer {
  String get label => switch (this) {
        _Layer.organisations => 'Organisations',
        _Layer.places => 'Places',
        _Layer.events => 'Events',
        _Layer.environment => 'Environment',
      };

  IconData get icon => switch (this) {
        _Layer.organisations => Icons.apartment_outlined,
        _Layer.places => Icons.place_outlined,
        _Layer.events => Icons.event_outlined,
        _Layer.environment => Icons.eco_outlined,
      };

  /// The filter button appears only where there is something to filter by.
  bool get hasFilters => this == _Layer.organisations || this == _Layer.places || this == _Layer.environment;
}

const _sectors = <(String, String)>[
  ('sector_env', 'Environment'),
  ('sector_social', 'Social'),
  ('sector_health', 'Health'),
  ('sector_education', 'Education'),
  ('sector_economic', 'Economic'),
  ('sector_legal', 'Legal'),
  ('sector_faith', 'Faith'),
  ('sector_community', 'Community'),
];

const _beneficiaries = <(String, String)>[
  ('bg_women', 'Women'),
  ('bg_girls', 'Girls (under 18)'),
  ('bg_men', 'Men'),
  ('bg_boys', 'Boys (under 18)'),
  ('bg_children', 'Children'),
  ('bg_youth', 'Youth (15–35)'),
  ('bg_elderly', 'Elderly (60+)'),
  ('bg_pwd', 'Persons with disabilities'),
  ('bg_refugees', 'Refugees & IDPs'),
  ('bg_orphans', 'Orphans & OVCs'),
  ('bg_teen_mothers', 'Teen mothers'),
  ('bg_general', 'General community'),
];

const _facilities = {
  'facility_clinic': 'Clinic',
  'facility_school': 'School',
  'facility_training_center': 'Training centre',
  'facility_collection_point': 'Collection point',
  'facility_drop_off': 'Drop-off point',
  'facility_workshop': 'Workshop',
  'facility_shelter': 'Shelter',
  'facility_community_center': 'Community centre',
  'facility_water_point': 'Water point',
  'facility_youth_center': 'Youth centre',
  'facility_food_bank': 'Food bank',
  'facility_rehabilitation_center': 'Rehab centre',
  'facility_legal_aid_office': 'Legal aid office',
  'facility_gallery': 'Gallery',
  'facility_office': 'Office',
  'facility_sports_ground': 'Sports ground',
  'facility_drop_in_center': 'Drop-in centre',
};

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

sealed class _Selection {
  const _Selection();
}

class _SelOrg extends _Selection {
  final MapOrganization org;
  const _SelOrg(this.org);
}

class _SelPlace extends _Selection {
  final MapAmenity place;
  const _SelPlace(this.place);
}

/// A tapped collection zone: what the organisation does inside its boundary.
class _SelZone extends _Selection {
  final _MapZone zone;
  final MapOrganization? org;
  final int dumpsites, sites, trees, reports;
  const _SelZone(this.zone, this.org, {this.dumpsites = 0, this.sites = 0, this.trees = 0, this.reports = 0});
}

class _SelReport extends _Selection {
  final _MapReport report;
  const _SelReport(this.report);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _nairobi = CameraPosition(target: LatLng(-1.2921, 36.8219), zoom: 13);
  static const _dpr = 3.0;

  GoogleMapController? _map;
  // The map opens on organisations; there is no "All".
  _Layer _layer = _Layer.organisations;
  // Filters. Organisations: sector + who they serve. Places / Environment: the
  // kinds of thing to show ('zones', 'trees' and 'reports' are Environment only).
  final Set<String> _sub = {};
  final Set<String> _subServed = {};
  List<_MapTree> _trees = const [];
  List<_MapEvent> _events = const [];
  bool _treesRequested = false;
  _Selection? _selected;

  List<MapOrganization> _orgs = [];
  List<MapAmenity> _places = [];
  List<_MapReport> _reports = [];
  bool _orgsLoaded = false;
  bool _placesLoaded = false;
  bool _failed = false;
  final List<StreamSubscription> _subs = [];

  Map<String, dynamic>? _myOrg;
  bool _locating = false;

  // Territory zones: real traced outlines, one colour per organisation.
  List<_MapZone> _zones = const [];

  // Marker icon caches; cleared when brightness changes.
  Brightness? _iconBrightness;
  final Map<String, BitmapDescriptor> _icons = {};
  final Set<String> _building = {};

  @override
  void initState() {
    super.initState();
    _listen();
    _loadMyOrg();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final b = context.brightness;
    if (_iconBrightness != b) {
      _iconBrightness = b;
      _icons.clear();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _map?.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────

  void _listen() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    setState(() => _failed = false);
    final db = FirebaseFirestore.instance;
    _subs.add(db.collection('organizations').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _orgs = snap.docs.map((d) => _org(d.id, d.data())).whereType<MapOrganization>().toList();
        _orgsLoaded = true;
      });
    }, onError: (_) => mounted ? setState(() => _failed = true) : null));
    // Every event carries an exact pin; upcoming ones show on the map.
    _subs.add(db.collection('activities').limit(500).snapshots().listen((snap) {
      if (!mounted) return;
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      final list = <_MapEvent>[];
      for (final d in snap.docs) {
        final m = d.data();
        final when = (m['dateTime'] as Timestamp?)?.toDate();
        final coords = ((m['location'] as Map?)?['coordinates'] as Map?) ?? const {};
        final lat = (coords['lat'] as num?)?.toDouble();
        final lng = (coords['lng'] as num?)?.toDouble();
        if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
        if (when != null && when.isBefore(cutoff)) continue;
        list.add(_MapEvent(d.id, '${m['title'] ?? 'Event'}', LatLng(lat, lng), when));
      }
      setState(() => _events = list);
    }, onError: (_) {}));
    _subs.add(db.collection('collection_zones').limit(500).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => _zones = snap.docs.map((d) => _zone(d.id, d.data())).whereType<_MapZone>().toList());
    }, onError: (_) {}));
    _subs.add(db.collection('map_pins').limit(1000).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _places = snap.docs
            .where((d) => d.data()['is_active'] != false)
            .map((d) => _pin(d.id, d.data()))
            .whereType<MapAmenity>()
            .toList();
        _placesLoaded = true;
      });
    }, onError: (_) => mounted ? setState(() => _failed = true) : null));
    // Reports are best-effort: a read failure just leaves the layer empty.
    _subs.add(IncidentsService().watchAll(limit: 100).listen((list) {
      if (!mounted) return;
      setState(() => _reports = list.map(_MapReport.from).whereType<_MapReport>().toList());
    }, onError: (_) {}));
  }

  MapOrganization? _org(String id, Map<String, dynamic> data) {
    try {
      final gp = data['location'];
      final lat = gp is GeoPoint ? gp.latitude : (data['lat'] as num?)?.toDouble();
      final lng = gp is GeoPoint ? gp.longitude : (data['lng'] as num?)?.toDouble();
      // An org without coordinates isn't placed at a made-up spot.
      if (lat == null || lng == null) return null;
      // Field reality: description → 'background', logo → 'profilePhoto',
      // designation → 'orgDesignation'.
      return MapOrganization(
        id: id,
        name: (data['org_name'] ?? data['name'] ?? 'Organisation') as String,
        description: (data['background'] ?? data['description'] ?? data['bio'] ?? '') as String,
        location: LatLng(lat, lng),
        sectorId: data['sectorId'] as String? ?? 'sector_community',
        orgTypeId: data['orgTypeId'] as String? ?? '',
        subTypeIds: List<String>.from(data['subTypeIds'] ?? const []),
        beneficiaryGroupIds: List<String>.from(data['beneficiaryGroupIds'] ?? const []),
        facilityTypeIds: List<String>.from(data['facilityTypeIds'] ?? const []),
        subFacilityIds: List<String>.from(data['subFacilityIds'] ?? const []),
        logoUrl: (data['logoUrl'] ?? data['profilePhoto']) as String?,
        coverImageUrl: (data['coverImageUrl'] ?? data['background_image']) as String?,
        legalDesignation: (data['orgDesignation'] ?? data['designation'] ?? '') as String,
        country: data['country'] as String? ?? '',
        city: data['city'] as String? ?? '',
        area: data['area'] as String? ?? '',
        verified: data['verified'] as bool? ?? false,
        phone: data['phone'] as String?,
        website: data['website'] as String?,
        raw: data,
      );
    } catch (_) {
      return null;
    }
  }

  MapAmenity? _pin(String id, Map<String, dynamic> data) {
    try {
      final gp = data['location'] as GeoPoint?;
      if (gp == null) return null;
      const types = {
        'water_point': AmenityType.waterPoint,
        'waterPoint': AmenityType.waterPoint,
        'recycling_dropoff': AmenityType.recyclingDropOff,
        'recyclingDropOff': AmenityType.recyclingDropOff,
        'dumpsite': AmenityType.dumpsite,
        'canopy_hub': AmenityType.canopyHub,
        'canopyHub': AmenityType.canopyHub,
        'cleanup_event': AmenityType.cleanupEvent,
        'cleanupEvent': AmenityType.cleanupEvent,
        'tree_site': AmenityType.treeSite,
        'treeSite': AmenityType.treeSite,
        'collection_site': AmenityType.collectionSite,
        'sorting_hub': AmenityType.sortingHub,
        'scrap_buying_site': AmenityType.scrapBuyer,
        'police_station': AmenityType.policeStation,
        'public_toilet': AmenityType.publicToilet,
        'community_center': AmenityType.communityCentre,
        'market': AmenityType.market,
        'school': AmenityType.school,
        'health_clinic': AmenityType.clinic,
        'place_of_worship': AmenityType.placeOfWorship,
        'landmark': AmenityType.landmark,
      };
      final type = types[data['pin_type'] as String? ?? ''];
      if (type == null) return null;
      return MapAmenity(
        id: id,
        name: data['name'] as String? ?? type.label,
        amenityType: type,
        location: LatLng(gp.latitude, gp.longitude),
        description: data['description'] as String? ?? '',
        operatingHours: data['operating_hours'] as String?,
        isActive: data['is_active'] as bool? ?? true,
        reportedBy: data['added_by_org_name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadMyOrg() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final orgId = (await db.collection('Users').doc(user.uid).get()).data()?['orgId'] as String?;
      if (orgId == null) return;
      final org = await db.collection('organizations').doc(orgId).get();
      if (!org.exists || !mounted) return;
      setState(() => _myOrg = {...org.data()!, 'orgId': orgId});
    } catch (_) {}
  }

  // ── Filtering ───────────────────────────────────────────────────────────

  int get _filterCount => _sub.length + (_layer == _Layer.organisations ? _subServed.length : 0);

  List<MapOrganization> get _visibleOrgs => switch (_layer) {
        _Layer.organisations => [
            for (final o in _orgs)
              if ((_sub.isEmpty || _sub.contains(o.sectorId)) &&
                  (_subServed.isEmpty || o.beneficiaryGroupIds.any(_subServed.contains)))
                o,
          ],
        _ => const [],
      };

  bool _wantsPin(AmenityType t) => _sub.isEmpty || _sub.contains(t.name);

  List<MapAmenity> get _visiblePlaces => switch (_layer) {
        _Layer.places => [
            for (final a in _places)
              if (!_envAmenities.contains(a.amenityType) && !_eventAmenities.contains(a.amenityType) && _wantsPin(a.amenityType)) a,
          ],
        _Layer.events => [for (final a in _places) if (_eventAmenities.contains(a.amenityType)) a],
        _Layer.environment => [
            for (final a in _places)
              if (_envAmenities.contains(a.amenityType) && _wantsPin(a.amenityType)) a,
          ],
        _ => const [],
      };

  // Incident reports of dumping count as dumpsites, so they show in All and Environment.
  List<_MapReport> get _visibleReports =>
      _layer == _Layer.environment && (_sub.isEmpty || _sub.contains('reports')) ? _reports : const [];

  List<_MapEvent> get _visibleEvents =>
      _layer == _Layer.events ? _events : const [];

  List<_MapTree> get _visibleTrees =>
      _layer == _Layer.environment && (_sub.isEmpty || _sub.contains('trees')) ? _trees : const [];

  static bool _inside(LatLng p, List<LatLng> poly) {
    var in_ = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
        in_ = !in_;
      }
    }
    return in_;
  }

  /// What is mapped inside this zone's boundary right now.
  _SelZone _zoneSelection(_MapZone z) {
    final org = _orgs.where((o) => o.id == z.orgId).firstOrNull;
    var dump = 0, sites = 0;
    for (final a in _places) {
      if (!_inside(a.location, z.points)) continue;
      if (a.amenityType == AmenityType.dumpsite) {
        dump++;
      } else if (_envAmenities.contains(a.amenityType)) {
        sites++;
      }
    }
    var trees = 0;
    for (final t in _trees) {
      if (_inside(t.position, z.points)) trees += t.count;
    }
    final reports = _reports.where((r) => _inside(r.location, z.points)).length;
    return _SelZone(z, org, dumpsites: dump, sites: sites, trees: trees, reports: reports);
  }

  // ── Markers ─────────────────────────────────────────────────────────────

  Set<Marker> _markers(CanopyPalette p) {
    final out = <Marker>{};
    final sel = _selected;
    for (final o in _visibleOrgs) {
      final selected = sel is _SelOrg && sel.org.id == o.id;
      final key = 'org:${o.id}:$selected';
      _ensureIcon(key, () => _orgIcon(o, p, selected));
      out.add(Marker(
        markerId: MarkerId('org_${o.id}'),
        position: o.location,
        icon: _icons[key] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: selected ? 5 : 2,
        consumeTapEvents: true,
        onTap: () => _select(_SelOrg(o), o.location),
      ));
    }
    for (final e in _visibleEvents) {
      _ensureIcon('event', () => _disc(CanopyMarkers.cleanupEvent(p), Icons.event_outlined, p, false));
      out.add(Marker(
        markerId: MarkerId('event_${e.id}'),
        position: e.at,
        icon: _icons['event'] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: 2,
        infoWindow: InfoWindow(
            title: e.title, snippet: e.when == null ? 'Tap to open' : '${DateFormat('EEE d MMM').format(e.when!)} · tap to open',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: e.id)))),
      ));
    }
    for (final t in _visibleTrees) {
      _ensureIcon('tree', () => _disc(CanopyMarkers.treeSite(p), Icons.park_outlined, p, false));
      out.add(Marker(
        markerId: MarkerId('tree_${t.key}'),
        position: t.position,
        icon: _icons['tree'] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1,
        infoWindow: InfoWindow(title: '${t.count} tree${t.count == 1 ? '' : 's'} planted', snippet: t.label),
      ));
    }
    for (final z in _visibleZones) {
      final o = _orgs.where((o) => o.id == z.orgId).firstOrNull;
      if (o == null) continue;
      final key = 'org:${o.id}:false';
      _ensureIcon(key, () => _orgIcon(o, p, false));
      out.add(Marker(
        markerId: MarkerId('zone_${z.id}'),
        position: z.centroid,
        icon: _icons[key] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: 2,
        consumeTapEvents: true,
        onTap: () => _select(_zoneSelection(z), z.centroid),
      ));
    }
    for (final a in _visiblePlaces) {
      final selected = sel is _SelPlace && sel.place.id == a.id;
      final key = 'place:${a.amenityType.name}:$selected';
      _ensureIcon(key,
          () => _disc(a.amenityType.markerColor(p), a.amenityType.icon, p, selected));
      out.add(Marker(
        markerId: MarkerId('place_${a.id}'),
        position: a.location,
        icon: _icons[key] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: selected ? 5 : 1,
        consumeTapEvents: true,
        onTap: () => _select(_SelPlace(a), a.location),
      ));
    }
    for (final r in _visibleReports) {
      final selected = sel is _SelReport && sel.report.report.id == r.report.id;
      final key = 'report:$selected';
      _ensureIcon(key, () => _disc(p.danger, Icons.flag_outlined, p, selected));
      out.add(Marker(
        markerId: MarkerId('report_${r.report.id}'),
        position: r.location,
        icon: _icons[key] ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: selected ? 5 : 1,
        consumeTapEvents: true,
        onTap: () => _select(_SelReport(r), r.location),
      ));
    }
    return out;
  }

  // Distinct, readable hues; an organisation keeps its colour across sessions.
  // No reds or oranges: those belong to dumpsites and reports.
  static const _areaHues = [200.0, 150.0, 290.0, 175.0, 250.0, 100.0, 215.0, 265.0];

  Color _areaColor(String id) {
    final h = _areaHues[id.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff) % _areaHues.length];
    return HSLColor.fromAHSL(1, h, 0.62, 0.48).toColor();
  }

  /// Each territory zone drawn as its real traced outline, in its
  /// organisation's colour; tapping it opens the organisation.
  Set<Polygon> _zonePolygons(CanopyPalette p) {
    final out = <Polygon>{};
    for (final z in _visibleZones) {
      final c = _areaColor(z.orgId);
      out.add(Polygon(
        polygonId: PolygonId('zone_${z.id}'),
        points: z.points,
        fillColor: c.withAlpha(0x40),
        strokeColor: c,
        strokeWidth: 3,
        consumeTapEvents: true,
        onTap: () => _select(_zoneSelection(z), z.centroid),
      ));
    }
    return out;
  }

  // Collection zones are traced outlines, shown in the Environment layer.
  List<_MapZone> get _visibleZones =>
      _layer == _Layer.environment && (_sub.isEmpty || _sub.contains('zones')) ? _zones : const [];

  _MapZone? _zone(String id, Map<String, dynamic> data) {
    try {
      final raw = data['vertices'];
      if (raw is! List) return null;
      final pts = <LatLng>[];
      for (final v in raw) {
        if (v is GeoPoint) {
          pts.add(LatLng(v.latitude, v.longitude));
        } else if (v is Map) {
          final lat = (v['lat'] as num?)?.toDouble();
          final lng = (v['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) pts.add(LatLng(lat, lng));
        }
      }
      if (pts.length < 3) return null;
      if ('${data['status'] ?? 'active'}' == 'inactive') return null;
      final orgId = (data['org_id'] ?? data['orgId'] ?? '') as String;
      return _MapZone(id, orgId, '${data['name'] ?? data['label'] ?? 'Territory'}', pts);
    } catch (_) {
      return null;
    }
  }

  void _ensureIcon(String key, Future<BitmapDescriptor> Function() build) {
    if (_icons.containsKey(key) || _building.contains(key)) return;
    _building.add(key);
    build().then((icon) {
      _building.remove(key);
      if (mounted) setState(() => _icons[key] = icon);
    }).catchError((_) {
      _building.remove(key);
    });
  }

  /// Filled disc + white glyph + 2.5 surface ring + soft shadow. Selected is
  /// larger with a 3.5 ink ring.
  Future<BitmapDescriptor> _disc(
      Color fill, IconData icon, CanopyPalette p, bool selected) async {
    final logical = selected ? 48.0 : 34.0;
    final size = logical * _dpr;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final center = Offset(size / 2, size / 2);
    final r = size / 2 - 6 * _dpr;
    c.drawCircle(center.translate(0, 1.5 * _dpr), r + 2.5 * _dpr,
        Paint()
          ..color = Colors.black.withAlpha(0x40)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _dpr));
    if (selected) {
      c.drawCircle(center, r + 3.5 * _dpr, Paint()..color = p.ink);
    }
    c.drawCircle(center, r + 2.5 * _dpr * (selected ? 0.4 : 1), Paint()..color = p.surface);
    c.drawCircle(center, r, Paint()..color = fill);
    _glyph(c, icon, r * 1.15, CanopyPalette.onHero, center);
    return _toDescriptor(rec, size);
  }

  Future<BitmapDescriptor> _orgIcon(
      MapOrganization o, CanopyPalette p, bool selected) async {
    ui.Image? logo;
    if (o.logoUrl != null && o.logoUrl!.isNotEmpty) {
      try {
        final bytes = await OrgLogoCache.instance.bytes(o.logoUrl!);
        if (bytes != null) {
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 160);
          logo = (await codec.getNextFrame()).image;
        }
      } catch (_) {}
    }
    if (logo == null) {
      return _disc(CanopyMarkers.canopyHub(p), Icons.groups_outlined, p, selected);
    }
    final logical = selected ? 56.0 : 42.0;
    final size = logical * _dpr;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final center = Offset(size / 2, size / 2);
    final r = size / 2 - 6 * _dpr;
    c.drawCircle(center.translate(0, 1.5 * _dpr), r + 2.5 * _dpr,
        Paint()
          ..color = Colors.black.withAlpha(0x40)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _dpr));
    if (selected) c.drawCircle(center, r + 3.5 * _dpr, Paint()..color = p.ink);
    c.drawCircle(center, r + 2.5 * _dpr * (selected ? 0.4 : 1), Paint()..color = p.surface);
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    c.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromCircle(center: center, radius: r),
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.restore();
    return _toDescriptor(rec, size);
  }

  void _glyph(Canvas c, IconData icon, double fontSize, Color color, Offset center) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textDirection: ui.TextDirection.ltr))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: icon.fontFamily,
        fontFamilyFallback: const [],
      ))
      ..addText(String.fromCharCode(icon.codePoint));
    final para = pb.build()..layout(ui.ParagraphConstraints(width: fontSize * 2));
    c.drawParagraph(para,
        Offset(center.dx - para.longestLine / 2, center.dy - para.height / 2));
  }

  Future<BitmapDescriptor> _toDescriptor(ui.PictureRecorder rec, double size) async {
    final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: _dpr);
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _select(_Selection s, LatLng at) {
    setState(() => _selected = s);
    _map?.animateCamera(CameraUpdate.newLatLngZoom(at, 15));
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          showCanopySnack(context, 'Location access is off. Turn it on in Settings.',
              actionLabel: 'Settings', onAction: Geolocator.openAppSettings);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _map?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15));
    } catch (_) {
      if (mounted) {
        showCanopySnack(context, "Couldn't find your location.", error: true);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onChip(_Layer l) {
    if (_layer == l) return;
    setState(() {
      _layer = l;
      _sub.clear();
      _subServed.clear();
      _selected = null;
    });
    if (l == _Layer.environment) _loadTrees();
  }

  /// Planted trees of environmental organisations, loaded the first time the
  /// Environment layer opens.
  Future<void> _loadTrees() async {
    if (_treesRequested) return;
    _treesRequested = true;
    final db = FirebaseFirestore.instance;
    final env = _orgs.where((o) => o.raw['envOpsStatus'] == 'approved' || o.sectorId == 'sector_env').toList();
    final grouped = <String, _MapTree>{};
    await Future.wait(env.map((o) async {
      try {
        final snap = await db.collection('organizations').doc(o.id).collection('trees').get();
        for (final d in snap.docs) {
          final m = d.data();
          final loc = (m['planting'] as Map?)?['location'];
          double? lat, lng;
          if (loc is GeoPoint) {
            lat = loc.latitude;
            lng = loc.longitude;
          } else if (loc is Map) {
            lat = (loc['lat'] as num?)?.toDouble();
            lng = (loc['lng'] as num?)?.toDouble();
          }
          if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
          final key = '${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}';
          final qty = [m['quantity'], m['treeCount'], m['count']].whereType<num>().where((n) => n > 0).map((n) => n.toInt()).firstOrNull ?? 1;
          final species = '${m['commonName'] ?? m['species'] ?? ''}'.trim();
          final t = grouped.putIfAbsent(key, () => _MapTree(key, LatLng(lat!, lng!), o.name));
          t.add(species, qty);
        }
      } catch (_) {}
    }));
    if (mounted) setState(() => _trees = grouped.values.toList());
  }

  /// Sections for the current layer's filter sheet.
  List<(String, List<(String, String)>, Set<String>)> get _filterSections => switch (_layer) {
        _Layer.organisations => [('What they do', _sectors, _sub), ('Who they serve', _beneficiaries, _subServed)],
        _Layer.places => [
            ('Kind of place', [
              for (final t in AmenityType.values)
                if (!_envAmenities.contains(t) && !_eventAmenities.contains(t)) (t.name, t.label),
            ], _sub),
          ],
        _Layer.environment => [
            ('What to show', [
              for (final t in AmenityType.values)
                if (_envAmenities.contains(t)) (t.name, t.label),
              ('zones', 'Collection zones'),
              ('trees', 'Planted trees'),
              ('reports', 'Dumping reports'),
            ], _sub),
          ],
        _ => const [],
      };

  Future<void> _openFilters() async {
    final sections = _filterSections;
    if (sections.isEmpty) return;
    await showCanopySheet<void>(
      context,
      tall: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => CanopySheetBody(
          title: 'Filter ${_layer.label.toLowerCase()}',
          caption: 'Show only what you pick. Nothing picked shows everything.',
          children: [
            for (final (title, options, set) in sections) ...[
              Padding(
                padding: const EdgeInsets.only(top: CanopySpace.s8, bottom: CanopySpace.s8),
                child: Text(title.toUpperCase(), style: CanopyType.eyebrow.copyWith(color: ctx.canopy.inkMuted)),
              ),
              Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
                for (final o in options)
                  CanopyFilterChip(
                    label: o.$2,
                    selected: set.contains(o.$1),
                    onTap: () {
                      setState(() => set.contains(o.$1) ? set.remove(o.$1) : set.add(o.$1));
                      setSheet(() {});
                    },
                  ),
              ]),
            ],
          ],
          actions: [
            CanopyButton(label: 'Done', expand: true, onPressed: () => Navigator.pop(ctx)),
            CanopyButton.quiet(
              label: 'Clear',
              expand: true,
              onPressed: () {
                setState(() {
                  _sub.clear();
                  _subServed.clear();
                });
                setSheet(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final picked = await showCanopySheet<_Selection>(
      context,
      tall: true,
      builder: (_) => _SearchSheet(orgs: _orgs, places: _places, reports: _reports),
    );
    if (picked == null) return;
    final at = switch (picked) {
      _SelOrg(:final org) => org.location,
      _SelPlace(:final place) => place.location,
      _SelReport(:final report) => report.location,
      _SelZone(:final zone) => zone.centroid,
    };
    // Make sure the picked item's layer is visible.
    setState(() {
      _layer = switch (picked) {
        _SelOrg() => _Layer.organisations,
        _SelPlace(:final place) => _envAmenities.contains(place.amenityType)
            ? _Layer.environment
            : (_eventAmenities.contains(place.amenityType) ? _Layer.events : _Layer.places),
        _SelReport() || _SelZone() => _Layer.environment,
      };
      _sub.clear();
      _subServed.clear();
    });
    _select(picked, at);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final top = MediaQuery.paddingOf(context).top;
    final loaded = _orgsLoaded && _placesLoaded;
    final empty = loaded &&
        _visibleOrgs.isEmpty &&
        _visiblePlaces.isEmpty &&
        _visibleZones.isEmpty &&
        _visibleEvents.isEmpty &&
        _visibleTrees.isEmpty &&
        _visibleReports.isEmpty;

    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _nairobi,
            style: canopyMapStyle(context),
            markers: _markers(p),
            polygons: _zonePolygons(p),
            onMapCreated: (c) => _map = c,
            onTap: (_) => setState(() => _selected = null),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Search + chips ────────────────────────────────────────────
          Positioned(
            top: top + CanopySpace.s12,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                  child: Row(children: [
                    Expanded(child: _SearchPill(onTap: _openSearch)),
                    // Only where there is something to filter by.
                    if (_layer.hasFilters) ...[
                      const SizedBox(width: CanopySpace.s8),
                      _FilterButton(count: _filterCount, onTap: _openFilters),
                    ],
                  ]),
                ),
                const SizedBox(height: CanopySpace.s4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                  child: Wrap(
                    spacing: CanopySpace.s8,
                    runSpacing: CanopySpace.s4,
                    children: [
                      for (final l in _Layer.values)
                        CanopyFilterChip(
                          label: l.label,
                          selected: _layer == l,
                          icon: l.icon,
                          float: true,
                          onTap: () => _onChip(l),
                        ),
                    ],
                  ),
                ),
                if (_failed || empty || !loaded) ...[
                  const SizedBox(height: CanopySpace.s4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CanopySpace.gutter),
                    child: _MapNotice(
                      loading: !loaded && !_failed,
                      failed: _failed,
                      layer: _layer,
                      onRetry: _listen,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Map buttons ───────────────────────────────────────────────
          Positioned(
            right: CanopySpace.gutter,
            bottom: CanopySpace.s20,
            child: Column(
              children: [
                if (_myOrg != null) ...[
                  CanopyIconButton(
                    icon: Icons.add_location_alt_outlined,
                    tooltip: 'Add a pin for your organisation',
                    float: true,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OrgMapOpsScreen(orgData: _myOrg!)),
                    ),
                  ),
                  const SizedBox(height: CanopySpace.s12),
                ],
                _locating
                    ? Container(
                        width: CanopySpace.minTouch,
                        height: CanopySpace.minTouch,
                        decoration: BoxDecoration(
                          color: p.surface,
                          shape: BoxShape.circle,
                          boxShadow: CanopyElevation.e1(context.brightness),
                        ),
                        padding: const EdgeInsets.all(15),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : CanopyIconButton(
                        icon: Icons.my_location_outlined,
                        tooltip: 'Go to my location',
                        float: true,
                        onPressed: _locate,
                      ),
              ],
            ),
          ),

          // ── Selection sheet ───────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSwitcher(
              duration: context.reduceMotion ? CanopyMotion.reduced : CanopyMotion.sheetOpen,
              reverseDuration: CanopyMotion.sheetClose,
              switchInCurve: CanopyMotion.emphasised,
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(anim),
                child: child,
              ),
              child: _selected == null
                  ? const SizedBox.shrink()
                  : _SelectionSheet(
                      key: ValueKey(_selected),
                      selection: _selected!,
                      onClose: () => setState(() => _selected = null),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING PIECES
// ─────────────────────────────────────────────────────────────────────────────

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Semantics(
      button: true,
      label: 'Search the map',
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CanopyRadius.sm),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              boxShadow: CanopyElevation.e1(context.brightness),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: CanopyIconSize.button, color: p.inkMuted),
                const SizedBox(width: CanopySpace.s12),
                Expanded(
                  child: Text('Search organisations, places, reports',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CanopyType.body.copyWith(fontSize: 15, color: p.inkFaint)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  final bool loading;
  final bool failed;
  final _Layer layer;
  final VoidCallback onRetry;
  const _MapNotice(
      {required this.loading, required this.failed, required this.layer, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final text = failed
        ? "Couldn't load the map's places."
        : loading
            ? 'Loading places…'
            : 'Nothing mapped under ${layer.label.toLowerCase()} yet.';
    return Container(
      padding: const EdgeInsets.only(left: 14, right: CanopySpace.s4),
      constraints: const BoxConstraints(minHeight: CanopySpace.minTouch),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: CanopyElevation.e1(context.brightness),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(failed ? Icons.error_outline : Icons.info_outline,
                size: CanopyIconSize.s18, color: failed ? p.danger : p.info),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: CanopyType.body.copyWith(color: p.ink))),
          if (failed) CanopyButton.quiet(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH SHEET — every map item as a list
// ─────────────────────────────────────────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  final List<MapOrganization> orgs;
  final List<MapAmenity> places;
  final List<_MapReport> reports;
  const _SearchSheet({required this.orgs, required this.places, required this.reports});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _q = '';

  bool _match(String s) => s.toLowerCase().contains(_q.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final orgs = widget.orgs
        .where((o) => _match(o.name) || _match(o.place))
        .take(_q.isEmpty ? 8 : 30)
        .toList();
    final places = widget.places
        .where((a) => _match(a.name) || _match(a.amenityType.label))
        .take(_q.isEmpty ? 8 : 30)
        .toList();
    final reports = widget.reports
        .where((r) => _match(r.report.headline) || _match(r.report.type))
        .take(_q.isEmpty ? 5 : 20)
        .toList();
    final nothing = orgs.isEmpty && places.isEmpty && reports.isEmpty;

    return CanopySheetBody(
      title: 'Search the map',
      children: [
        CanopyTextField.search(
          hint: 'Organisations, places, reports',
          autofocus: true,
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
        const SizedBox(height: CanopySpace.s16),
        if (_q.isEmpty) ...[
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.apartment_outlined,
              title: 'Browse all organisations',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OrgExplorerScreen()));
              },
            ),
            CanopyListRow(
              icon: Icons.layers_outlined,
              title: 'Environmental operations map',
              subtitle: 'Zones, collection points and planting sites',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EnvOpsMapScreen()));
              },
            ),
          ]),
          const SizedBox(height: CanopySpace.s16),
        ],
        if (nothing)
          CanopyEmptyState(
            boxed: true,
            icon: Icons.search_off_outlined,
            title: _q.isEmpty ? 'Nothing is mapped yet' : 'Nothing matches "$_q"',
          ),
        if (orgs.isNotEmpty)
          CanopyListGroup(header: 'Organisations', children: [
            for (final o in orgs)
              CanopyListRow(
                leading: CanopyAvatar(url: o.logoUrl, name: o.name, size: 40, org: true),
                title: o.name,
                subtitle: [if (o.legalDesignation.isNotEmpty) o.legalDesignation, o.place]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                onTap: () => Navigator.pop(context, _SelOrg(o)),
              ),
          ]),
        if (places.isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s16),
          CanopyListGroup(header: 'Places', children: [
            for (final a in places)
              CanopyListRow(
                leading: Icon(a.amenityType.icon,
                    size: CanopyIconSize.nav, color: a.amenityType.markerColor(p)),
                title: a.name,
                subtitle: a.amenityType.label,
                onTap: () => Navigator.pop(context, _SelPlace(a)),
              ),
          ]),
        ],
        if (reports.isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s16),
          CanopyListGroup(header: 'Reports', children: [
            for (final r in reports)
              CanopyListRow(
                leading: Icon(Icons.flag_outlined, size: CanopyIconSize.nav, color: p.danger),
                title: r.report.headline,
                subtitle: r.report.type,
                onTap: () => Navigator.pop(context, _SelReport(r)),
              ),
          ]),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTION SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionSheet extends StatelessWidget {
  final _Selection selection;
  final VoidCallback onClose;
  const _SelectionSheet({super.key, required this.selection, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(CanopyRadius.xl)),
        boxShadow: CanopyElevation.e2(context.brightness),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: CanopySpace.minTouch),
              Expanded(
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.outlineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              CanopyIconButton(icon: Icons.close, tooltip: 'Close', onPressed: onClose),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s20),
              child: switch (selection) {
                _SelOrg(:final org) => _OrgBody(org: org),
                _SelPlace(:final place) => _PlaceBody(place: place),
                _SelReport(:final report) => _ReportBody(report: report),
                _SelZone() => _ZoneBody(sel: selection as _SelZone),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgBody extends StatefulWidget {
  final MapOrganization org;
  const _OrgBody({required this.org});

  @override
  State<_OrgBody> createState() => _OrgBodyState();
}

class _OrgBodyState extends State<_OrgBody> {
  // Single equality filter (index-free); upcoming + soonest-first client-side.
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _upcoming =
      FirebaseFirestore.instance
          .collection('activities')
          .where('orgId', isEqualTo: widget.org.id)
          .limit(30)
          .get()
          .then((s) {
    final now = DateTime.now();
    final list = s.docs.where((d) {
      final at = (d.data()['scheduledAt'] as Timestamp?)?.toDate();
      return at != null && at.isAfter(now) && d.data()['status'] != 'cancelled';
    }).toList()
      ..sort((a, b) => (a.data()['scheduledAt'] as Timestamp)
          .compareTo(b.data()['scheduledAt'] as Timestamp));
    return list.take(2).toList();
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final o = widget.org;
    final facilities = o.facilityTypeIds.map((f) => _facilities[f] ?? '').where((s) => s.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CanopyAvatar(url: o.logoUrl, name: o.name, size: 56, org: true),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.name, style: CanopyType.title.copyWith(color: p.ink)),
                  const SizedBox(height: CanopySpace.s2),
                  LabelRow(children: [
                    if (o.verified)
                      StatusLabel('Verified', color: p.success, icon: Icons.verified_outlined),
                    if (o.legalDesignation.isNotEmpty)
                      StatusLabel(o.legalDesignation, color: p.inkMuted),
                  ]),
                  if (o.place.isNotEmpty)
                    Text(o.place, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
          ],
        ),
        if (o.description.trim().isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s12),
          Text(o.description.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: CanopyType.body.copyWith(color: p.ink)),
        ],
        if (facilities.isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s8),
          Text(facilities.join(' · '),
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ],
        FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          future: _upcoming,
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: CanopySpace.s16),
                Text('UPCOMING', style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s8),
                for (final d in list) ...[
                  ActivityCard(activityId: d.id, activity: d.data(), compact: true),
                  const SizedBox(height: CanopySpace.s8),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyButton(
          label: 'View organisation',
          expand: true,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrgViewScreen(orgId: o.id, orgData: o.raw)),
          ),
        ),
        if ((o.phone?.isNotEmpty ?? false) || (o.website?.isNotEmpty ?? false))
          Row(
            children: [
              if (o.phone?.isNotEmpty ?? false)
                Expanded(
                  child: CanopyButton.quiet(
                    label: 'Call',
                    onPressed: () => launchUrl(Uri.parse('tel:${o.phone}')),
                  ),
                ),
              if (o.website?.isNotEmpty ?? false)
                Expanded(
                  child: CanopyButton.quiet(
                    label: 'Website',
                    onPressed: () {
                      final w = o.website!;
                      launchUrl(Uri.parse(w.startsWith('http') ? w : 'https://$w'),
                          mode: LaunchMode.externalApplication);
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

Future<void> _directions(LatLng at) => launchUrl(
      Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${at.latitude},${at.longitude}'),
      mode: LaunchMode.externalApplication,
    );

class _PlaceBody extends StatelessWidget {
  final MapAmenity place;
  const _PlaceBody({required this.place});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final t = place.amenityType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(t.icon, size: CanopyIconSize.s32, color: t.markerColor(p)),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusLabel(t.label, color: t.markerColor(p)),
                  Text(place.name, style: CanopyType.title.copyWith(color: p.ink)),
                ],
              ),
            ),
          ],
        ),
        if (place.description.trim().isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s12),
          Text(place.description.trim(), style: CanopyType.body.copyWith(color: p.ink)),
        ],
        const SizedBox(height: CanopySpace.s12),
        CanopyListGroup(children: [
          if (place.operatingHours?.isNotEmpty ?? false)
            CanopyListRow(icon: Icons.schedule_outlined, title: place.operatingHours!, subtitle: 'Hours'),
          if (place.acceptedMaterials.isNotEmpty)
            CanopyListRow(
                icon: Icons.recycling_outlined,
                title: place.acceptedMaterials.join(' · '),
                subtitle: 'Accepts'),
          if (place.reportedBy?.isNotEmpty ?? false)
            CanopyListRow(icon: Icons.groups_outlined, title: place.reportedBy!, subtitle: 'Added by'),
          CanopyListRow(
            icon: Icons.place_outlined,
            title:
                '${place.location.latitude.toStringAsFixed(5)}, ${place.location.longitude.toStringAsFixed(5)}',
            subtitle: 'Location',
          ),
        ]),
        const SizedBox(height: CanopySpace.s16),
        CanopyButton(
            label: 'Get directions', expand: true, onPressed: () => _directions(place.location)),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  final _MapReport report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final r = report.report;
    final (label, color) = switch (r.status) {
      IncidentStatus.pending => ('Reported', p.warning),
      IncidentStatus.verifying => ('Being verified', p.info),
      IncidentStatus.confirmed => ('Confirmed', p.danger),
      IncidentStatus.resolved => ('Resolved', p.success),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelRow(children: [
          StatusLabel(label, color: color),
          StatusLabel(r.type, color: p.inkMuted),
        ]),
        const SizedBox(height: CanopySpace.s4),
        Text(r.headline, style: CanopyType.title.copyWith(color: p.ink)),
        if (r.timestamp != null)
          Text(_ago(r.timestamp!), style: CanopyType.caption.copyWith(color: p.inkMuted)),
        if (r.images.isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s12),
          ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.sm),
            child: AspectRatio(
                aspectRatio: 16 / 9, child: CanopyImage(url: r.images.first)),
          ),
        ],
        if (r.description.trim().isNotEmpty) ...[
          const SizedBox(height: CanopySpace.s12),
          Text(r.description.trim(),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: CanopyType.body.copyWith(color: p.ink)),
        ],
        const SizedBox(height: CanopySpace.s16),
        CanopyButton.secondary(
          label: 'See all reports',
          expand: true,
          onPressed: () => Navigator.pushNamed(context, '/incidents'),
        ),
        CanopyButton.quiet(
          label: 'Get directions',
          expand: true,
          onPressed: () => _directions(report.location),
        ),
      ],
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inHours < 1) return '${math.max(1, d.inMinutes)}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}


/// A traced territory (collection_zones): outline + the organisation it belongs to.
class _MapZone {
  final String id;
  final String orgId;
  final String name;
  final List<LatLng> points;
  const _MapZone(this.id, this.orgId, this.name, this.points);

  LatLng get centroid {
    var lat = 0.0, lng = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }
}


/// Square filter button beside the search pill; carries a count when filters are on.
class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _FilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final on = count > 0;
    return Semantics(
      button: true,
      label: on ? 'Filters, $count active' : 'Filters',
      child: Material(
        color: on ? p.ink : p.surface,
        borderRadius: BorderRadius.circular(CanopyRadius.sm),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(CanopyRadius.sm),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CanopyRadius.sm),
              boxShadow: CanopyElevation.e1(context.brightness),
            ),
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.tune, color: on ? p.canvas : p.ink),
              if (on)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: p.canvas, borderRadius: BorderRadius.circular(8)),
                    child: Text('$count', style: CanopyType.micro.copyWith(color: p.ink)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Trees planted at one spot (grouped by position).
class _MapTree {
  final String key;
  final LatLng position;
  final String orgName;
  int count = 0;
  final Set<String> species = {};
  _MapTree(this.key, this.position, this.orgName);

  void add(String sp, int qty) {
    count += qty;
    if (sp.isNotEmpty) species.add(sp);
  }

  String get label => [if (species.isNotEmpty) species.join(', '), orgName].where((e) => e.isNotEmpty).join(' · ');
}


/// An upcoming event with an exact pin.
class _MapEvent {
  final String id, title;
  final LatLng at;
  final DateTime? when;
  const _MapEvent(this.id, this.title, this.at, this.when);
}


/// What an organisation does inside a collection zone: its schedule, what it
/// collects, how much it has verified, and what is mapped within the boundary.
class _ZoneBody extends StatefulWidget {
  final _SelZone sel;
  const _ZoneBody({required this.sel});

  @override
  State<_ZoneBody> createState() => _ZoneBodyState();
}

class _ZoneBodyState extends State<_ZoneBody> {
  // The detailed record (schedule, materials, stats) lives under the organisation.
  late final Future<Map<String, dynamic>> _detail = FirebaseFirestore.instance
      .collection('organizations')
      .doc(widget.sel.zone.orgId)
      .collection('collectionZones')
      .doc(widget.sel.zone.id)
      .get()
      .then((d) => d.data() ?? const <String, dynamic>{})
      .catchError((_) => const <String, dynamic>{});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final z = widget.sel.zone;
    final org = widget.sel.org;
    return FutureBuilder<Map<String, dynamic>>(
      future: _detail,
      builder: (context, snap) {
        final d = snap.data ?? const <String, dynamic>{};
        final stats = (d['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
        final sched = (d['schedule'] as Map?)?.cast<String, dynamic>() ?? const {};
        final days = ((sched['days'] as List?) ?? const []).map((e) => '$e').toList();
        final time = [sched['startTime'], sched['endTime']].whereType<String>().where((t) => t.isNotEmpty).join(' – ');
        final materials = ((d['materialTypes'] as List?) ?? const []).map((e) => '$e'.replaceAll('_', ' ')).toList();
        final kg = (stats['totalKgVerified'] as num?)?.toDouble() ?? 0;
        final runs = (stats['totalCollectionsLogged'] as num?)?.toInt() ?? 0;
        final inactive = d['isActive'] == false;
        final s = widget.sel;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.polyline_outlined, size: CanopyIconSize.s32, color: p.primaryInk),
            const SizedBox(width: CanopySpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusLabel(inactive ? 'Collection zone · paused' : 'Collection zone', color: inactive ? p.warning : p.success),
                Text(z.name, style: CanopyType.title.copyWith(color: p.ink)),
                if (org != null) Text('Run by ${org.name}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: CanopySpace.s12),
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.recycling_outlined,
              title: runs == 0 ? 'No collections logged yet' : '$runs collection${runs == 1 ? '' : 's'} logged',
              subtitle: kg > 0 ? '${kg.round()} kg verified' : 'Collections done here',
              chevron: false,
            ),
            if (days.isNotEmpty || time.isNotEmpty)
              CanopyListRow(
                icon: Icons.schedule_outlined,
                title: days.isEmpty ? time : days.join(' · '),
                subtitle: days.isEmpty ? 'Collection hours' : (time.isEmpty ? 'Collection days' : time),
                chevron: false,
              ),
            if (materials.isNotEmpty)
              CanopyListRow(icon: Icons.category_outlined, title: materials.join(' · '), subtitle: 'What they collect here', chevron: false),
          ]),
          const CanopySectionHeader(title: 'Inside this zone', padding: EdgeInsets.only(top: CanopySpace.section)),
          CanopyListGroup(children: [
            CanopyListRow(icon: Icons.park_outlined, title: '${s.trees} tree${s.trees == 1 ? '' : 's'} planted', chevron: false),
            CanopyListRow(
                icon: Icons.delete_outline,
                title: '${s.dumpsites} dumpsite${s.dumpsites == 1 ? '' : 's'} mapped',
                subtitle: s.reports > 0 ? '${s.reports} dumping report${s.reports == 1 ? '' : 's'}' : null,
                chevron: false),
            CanopyListRow(icon: Icons.inventory_2_outlined, title: '${s.sites} collection, sorting or recycling point${s.sites == 1 ? '' : 's'}', chevron: false),
          ]),
          if (org != null) ...[
            const SizedBox(height: CanopySpace.s12),
            CanopyButton.quiet(
              label: 'About ${org.name}',
              expand: true,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrgViewScreen(orgId: org.id, orgData: org.raw))),
            ),
          ],
        ]);
      },
    );
  }
}
