// lib/Community/Map/map.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';
import 'map_style.dart' as map_style
    hide kPlaceholderOrgs, kPlaceholderAmenities;
import 'map_placeholders.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AMENITY TYPE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum AmenityType {
  waterPoint,
  recyclingDropOff,
  dumpsite,
  canopyHub,
  cleanupEvent,
  treeSite,
}

extension AmenityTypeX on AmenityType {
  String get label {
    switch (this) {
      case AmenityType.waterPoint:
        return 'Water Point';
      case AmenityType.recyclingDropOff:
        return 'Recycling Drop-Off';
      case AmenityType.dumpsite:
        return 'Active Dumpsite';
      case AmenityType.canopyHub:
        return 'Canopy Hub';
      case AmenityType.cleanupEvent:
        return 'Cleanup Event';
      case AmenityType.treeSite:
        return 'Tree Planting Site';
    }
  }

  IconData get icon {
    switch (this) {
      case AmenityType.waterPoint:
        return Icons.water_drop_outlined;
      case AmenityType.recyclingDropOff:
        return Icons.recycling;
      case AmenityType.dumpsite:
        return Icons.delete_outline;
      case AmenityType.canopyHub:
        return Icons.solar_power_outlined;
      case AmenityType.cleanupEvent:
        return Icons.cleaning_services_outlined;
      case AmenityType.treeSite:
        return Icons.park_outlined;
    }
  }

  Color get color {
    switch (this) {
      case AmenityType.waterPoint:
        return const Color(0xFF1E88E5);
      case AmenityType.recyclingDropOff:
        return const Color(0xFF43A047);
      case AmenityType.dumpsite:
        return const Color(0xFFE53935);
      case AmenityType.canopyHub:
        return AppTheme.tertiary;
      case AmenityType.cleanupEvent:
        return const Color(0xFF00897B);
      case AmenityType.treeSite:
        return const Color(0xFF2E7D32);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AMENITY MODEL
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

// ─────────────────────────────────────────────────────────────────────────────
// ORGANISATION MODEL
// ─────────────────────────────────────────────────────────────────────────────

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
  final String legalDesignation;
  final String country;
  final String city;
  final String area;
  final bool verified;
  final String? phone;
  final String? website;

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
    required this.legalDesignation,
    required this.country,
    required this.city,
    required this.area,
    this.verified = false,
    this.phone,
    this.website,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP CATEGORIES
// ─────────────────────────────────────────────────────────────────────────────

class _ChipCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _ChipCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_ChipCategory> _chipCategories = [
  _ChipCategory(
      id: 'all',
      label: 'All',
      icon: Icons.layers_outlined,
      color: AppTheme.primary),
  _ChipCategory(
      id: 'organisations',
      label: 'Organisations',
      icon: Icons.business_outlined,
      color: Color(0xFF2D7A4F)),
  _ChipCategory(
      id: 'who_they_serve',
      label: 'Who They Serve',
      icon: Icons.group_outlined,
      color: Color(0xFF7E57C2)),
  _ChipCategory(
      id: 'amenities',
      label: 'Amenities',
      icon: Icons.place_outlined,
      color: Color(0xFF1E88E5)),
  _ChipCategory(
      id: 'marketplace',
      label: 'Marketplace',
      icon: Icons.storefront_outlined,
      color: Color(0xFFC4A961)),
  _ChipCategory(
      id: 'events',
      label: 'Events',
      icon: Icons.event_outlined,
      color: Color(0xFF00897B)),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAP SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _iconsLoaded = false;

  // Active filter chip
  String _activeChipId = 'all';
  // Sub-filters selected inside the bottom sheet
  final Set<String> _activeSubFilters = {};

  MapOrganization? _selectedOrg;
  MapAmenity? _selectedAmenity;

  late AnimationController _sheetController;
  late AnimationController _subSheetController;
  bool _subSheetOpen = false;

  // Icon caches
  final Map<String, BitmapDescriptor> _orgIconsNormal = {};
  final Map<String, BitmapDescriptor> _orgIconsHero = {};
  final Map<AmenityType, BitmapDescriptor> _amenityIcons = {};

  // Merged org list: Firestore (production) + placeholders
  List<MapOrganization> get _allOrgs => kPlaceholderOrgs;
  List<MapAmenity> get _allAmenities => kPlaceholderAmenities;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-1.2921, 36.8219),
    zoom: 13,
  );

  // ── Sector / sub-filter data ─────────────────────────────────────────────

  static const _sectorSubFilters = <String, List<Map<String, dynamic>>>{
    'sector_env': [
      {'id': 'ot_recycler', 'label': 'Recycler', 'icon': Icons.recycling},
      {'id': 'ot_waste_art', 'label': 'Waste-to-Art', 'icon': Icons.palette},
      {
        'id': 'ot_cleanup_org',
        'label': 'Cleanup Org',
        'icon': Icons.cleaning_services
      },
      {'id': 'ot_conservation', 'label': 'Conservation', 'icon': Icons.park},
      {'id': 'ot_clean_energy', 'label': 'Clean Energy', 'icon': Icons.bolt},
    ],
    'sector_social': [
      {'id': 'ot_women_org', 'label': "Women's Org", 'icon': Icons.woman},
      {'id': 'ot_girls_org', 'label': "Girls' Org", 'icon': Icons.girl},
      {
        'id': 'ot_children_org',
        'label': "Children's Org",
        'icon': Icons.child_care
      },
      {'id': 'ot_youth_org', 'label': 'Youth Org', 'icon': Icons.group},
      {'id': 'ot_pwd_org', 'label': 'PWD Org', 'icon': Icons.accessible},
      {'id': 'ot_elderly_org', 'label': 'Elderly Care', 'icon': Icons.elderly},
      {
        'id': 'ot_refugee_org',
        'label': 'Refugee Support',
        'icon': Icons.transfer_within_a_station
      },
    ],
    'sector_health': [
      {'id': 'ot_clinic', 'label': 'Clinic', 'icon': Icons.local_hospital},
      {'id': 'ot_wash', 'label': 'WASH Org', 'icon': Icons.water_drop},
      {
        'id': 'ot_nutrition_org',
        'label': 'Nutrition',
        'icon': Icons.restaurant
      },
    ],
    'sector_education': [
      {'id': 'ot_school', 'label': 'School', 'icon': Icons.school},
      {'id': 'ot_vocational', 'label': 'Vocational', 'icon': Icons.build},
    ],
    'sector_economic': [
      {
        'id': 'ot_sacco',
        'label': 'SACCO / Microfinance',
        'icon': Icons.account_balance
      },
    ],
    'sector_legal': [
      {'id': 'ot_legal_aid', 'label': 'Legal Aid', 'icon': Icons.gavel},
    ],
    'sector_faith': [
      {'id': 'ot_fbo', 'label': 'Faith-Based Org', 'icon': Icons.church},
    ],
    'sector_community': [
      {
        'id': 'ot_football_club',
        'label': 'Football / Sports Club',
        'icon': Icons.sports_soccer
      },
      {
        'id': 'ot_drama_choir',
        'label': 'Drama, Music & Choir',
        'icon': Icons.theater_comedy
      },
      {
        'id': 'ot_neighbourhood_assoc',
        'label': 'Neighbourhood Association',
        'icon': Icons.home
      },
      {
        'id': 'ot_parent_group',
        'label': 'Parent & Family Group',
        'icon': Icons.family_restroom
      },
      {
        'id': 'ot_youth_club',
        'label': 'Youth Club (Informal)',
        'icon': Icons.groups
      },
      {
        'id': 'ot_cultural_group',
        'label': 'Cultural & Heritage Group',
        'icon': Icons.diversity_3
      },
    ],
  };

  static const _beneficiarySubFilters = <Map<String, dynamic>>[
    {'id': 'bg_women', 'label': 'Women', 'icon': Icons.woman},
    {'id': 'bg_girls', 'label': 'Girls (Under 18)', 'icon': Icons.girl},
    {'id': 'bg_men', 'label': 'Men', 'icon': Icons.man},
    {'id': 'bg_boys', 'label': 'Boys (Under 18)', 'icon': Icons.boy},
    {'id': 'bg_children', 'label': 'Children (All)', 'icon': Icons.child_care},
    {'id': 'bg_youth', 'label': 'Youth (15–35)', 'icon': Icons.group},
    {'id': 'bg_elderly', 'label': 'Elderly (60+)', 'icon': Icons.elderly},
    {
      'id': 'bg_pwd',
      'label': 'Persons with Disabilities',
      'icon': Icons.accessible
    },
    {
      'id': 'bg_refugees',
      'label': 'Refugees & IDPs',
      'icon': Icons.transfer_within_a_station
    },
    {
      'id': 'bg_orphans',
      'label': 'Orphans & OVCs',
      'icon': Icons.family_restroom
    },
    {
      'id': 'bg_teen_mothers',
      'label': 'Teen Mothers',
      'icon': Icons.pregnant_woman
    },
    {'id': 'bg_general', 'label': 'General Community', 'icon': Icons.people},
  ];

  static const _amenitySubFilters = <Map<String, dynamic>>[
    {
      'id': 'waterPoint',
      'label': 'Water Points',
      'icon': Icons.water_drop_outlined
    },
    {
      'id': 'recyclingDropOff',
      'label': 'Recycling Drop-Offs',
      'icon': Icons.recycling
    },
    {
      'id': 'dumpsite',
      'label': 'Active Dumpsites',
      'icon': Icons.delete_outline
    },
    {
      'id': 'canopyHub',
      'label': 'Canopy Hubs',
      'icon': Icons.solar_power_outlined
    },
    {
      'id': 'cleanupEvent',
      'label': 'Cleanup Events',
      'icon': Icons.cleaning_services_outlined
    },
    {
      'id': 'treeSite',
      'label': 'Tree Planting Sites',
      'icon': Icons.park_outlined
    },
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _subSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadIconsAndBuildMarkers();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _subSheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _sectorColor(String sectorId) {
    const map = {
      'sector_env': Color(0xFF2E7D32),
      'sector_social': Color(0xFFC62828),
      'sector_health': Color(0xFF00695C),
      'sector_education': Color(0xFF1565C0),
      'sector_economic': Color(0xFFE65100),
      'sector_legal': Color(0xFF4A148C),
      'sector_faith': Color(0xFF4E342E),
      'sector_community': Color(0xFF5C6BC0),
    };
    return map[sectorId] ?? AppTheme.primary;
  }

  IconData _orgTypeIcon(String orgTypeId) {
    const map = {
      'ot_recycler': Icons.recycling,
      'ot_waste_art': Icons.palette,
      'ot_cleanup_org': Icons.cleaning_services,
      'ot_conservation': Icons.park,
      'ot_clean_energy': Icons.bolt,
      'ot_women_org': Icons.woman,
      'ot_girls_org': Icons.girl,
      'ot_children_org': Icons.child_care,
      'ot_youth_org': Icons.group,
      'ot_pwd_org': Icons.accessible,
      'ot_elderly_org': Icons.elderly,
      'ot_refugee_org': Icons.transfer_within_a_station,
      'ot_clinic': Icons.local_hospital,
      'ot_wash': Icons.water_drop,
      'ot_nutrition_org': Icons.restaurant,
      'ot_school': Icons.school,
      'ot_vocational': Icons.build,
      'ot_sacco': Icons.account_balance,
      'ot_legal_aid': Icons.gavel,
      'ot_fbo': Icons.church,
      'ot_football_club': Icons.sports_soccer,
      'ot_drama_choir': Icons.theater_comedy,
      'ot_neighbourhood_assoc': Icons.home,
      'ot_parent_group': Icons.family_restroom,
      'ot_youth_club': Icons.groups,
      'ot_cultural_group': Icons.diversity_3,
    };
    return map[orgTypeId] ?? Icons.business;
  }

  String _facilityLabel(String id) {
    const map = {
      'facility_clinic': 'Clinic',
      'facility_school': 'School',
      'facility_training_center': 'Training Center',
      'facility_collection_point': 'Collection Point',
      'facility_drop_off': 'Drop-Off Point',
      'facility_workshop': 'Workshop / Studio',
      'facility_shelter': 'Shelter',
      'facility_community_center': 'Community Center',
      'facility_water_point': 'Water Point',
      'facility_youth_center': 'Youth Center',
      'facility_food_bank': 'Food Bank',
      'facility_rehabilitation_center': 'Rehab Center',
      'facility_legal_aid_office': 'Legal Aid Office',
      'facility_gallery': 'Gallery',
      'facility_office': 'Office',
      'facility_sports_ground': 'Sports Ground',
      'facility_drop_in_center': 'Drop-In Center',
    };
    return map[id] ?? id;
  }

  // ── Icon generation ──────────────────────────────────────────────────────

  Future<void> _loadIconsAndBuildMarkers() async {
    // Org icons
    final typeIds = _allOrgs.map((o) => o.orgTypeId).toSet();
    for (final typeId in typeIds) {
      final org = _allOrgs.firstWhere((o) => o.orgTypeId == typeId);
      final color = _sectorColor(org.sectorId);
      final icon = _orgTypeIcon(typeId);
      _orgIconsNormal[typeId] =
          await _makeOrgIcon(icon, color, 80.0, hero: false);
      _orgIconsHero[typeId] =
          await _makeOrgIcon(icon, color, 140.0, hero: true);
    }
    // Amenity icons
    for (final type in AmenityType.values) {
      _amenityIcons[type] = await _makeAmenityIcon(type);
    }
    if (mounted) {
      setState(() {
        _iconsLoaded = true;
        _rebuildMarkers();
      });
    }
  }

  Future<BitmapDescriptor> _makeOrgIcon(
      IconData iconData, Color color, double size,
      {required bool hero}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cx = size / 2, cy = size / 2;

    if (hero) {
      // Outer bloom halo
      canvas.drawCircle(
        Offset(cx, cy),
        size / 2 - 2,
        Paint()
          ..color = color.withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      // Sparkle ring
      final dotR = size / 2 - 11;
      for (int d = 0; d < 8; d++) {
        final angle = (d * math.pi * 2) / 8 - math.pi / 8;
        canvas.drawCircle(
          Offset(cx + dotR * math.cos(angle), cy + dotR * math.sin(angle)),
          d % 2 == 0 ? 3.8 : 2.4,
          Paint()
            ..color = d % 2 == 0
                ? Colors.white.withOpacity(0.95)
                : color.withOpacity(0.75),
        );
      }
    }

    // Shadow
    canvas.drawCircle(
      Offset(cx, cy + (hero ? 5 : 3)),
      size / 2 - (hero ? 18 : 8),
      Paint()
        ..color = Colors.black.withOpacity(hero ? 0.28 : 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, hero ? 10 : 5),
    );

    final circleR = size / 2 - (hero ? 16 : 8);
    final fillColor = hero
        ? Color.lerp(color, Colors.black, 0.15)!
        : Color.lerp(color, Colors.white, 0.62)!;

    canvas.drawCircle(Offset(cx, cy), circleR, Paint()..color = fillColor);

    if (hero) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: circleR - 3),
        -2.5,
        1.1,
        false,
        Paint()
          ..color = Colors.white.withOpacity(0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      circleR - 1,
      Paint()
        ..color = hero ? Colors.white : Colors.white.withOpacity(0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hero ? 3.0 : 1.8,
    );

    final iconFontSize = circleR * (hero ? 0.82 : 0.75);
    final iconColor = hero ? Colors.white : color.withOpacity(0.85);
    _paintIcon(canvas, iconData, iconFontSize, iconColor, Offset(cx, cy));

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _makeAmenityIcon(AmenityType type) async {
    const size = 72.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = type.color;
    final cx = size / 2, cy = size / 2;

    // Shadow
    canvas.drawCircle(
      Offset(cx, cy + 3),
      size / 2 - 10,
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Fill
    canvas.drawCircle(
      Offset(cx, cy),
      size / 2 - 9,
      Paint()..color = Color.lerp(color, Colors.white, 0.55)!,
    );
    // Border
    canvas.drawCircle(
      Offset(cx, cy),
      size / 2 - 10,
      Paint()
        ..color = Colors.white.withOpacity(0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // Icon
    _paintIcon(canvas, type.icon, (size / 2 - 9) * 0.72,
        color.withOpacity(0.90), Offset(cx, cy));

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Uses ui.ParagraphBuilder for reliable icon-font rendering on canvas.
  void _paintIcon(Canvas canvas, IconData icon, double fontSize, Color color,
      Offset center) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textDirection: ui.TextDirection.ltr),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: icon.fontFamily,
        fontFamilyFallback: const [],
      ))
      ..addText(String.fromCharCode(icon.codePoint));
    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: fontSize * 2));
    canvas.drawParagraph(
      para,
      Offset(center.dx - para.longestLine / 2,
          center.dy - para.height / 2),
    );
  }

  // ── Filtering ────────────────────────────────────────────────────────────

  List<MapOrganization> get _visibleOrgs {
    if (_activeChipId == 'all') return _allOrgs;
    if (_activeChipId == 'organisations') {
      if (_activeSubFilters.isEmpty) return _allOrgs;
      // sub-filters are sectorIds when chip = organisations
      return _allOrgs
          .where((o) => _activeSubFilters.contains(o.sectorId))
          .toList();
    }
    if (_activeChipId == 'who_they_serve') {
      if (_activeSubFilters.isEmpty) return _allOrgs;
      return _allOrgs
          .where((o) =>
              o.beneficiaryGroupIds.any((b) => _activeSubFilters.contains(b)))
          .toList();
    }
    if (_activeChipId == 'marketplace') return _allOrgs; // stub
    if (_activeChipId == 'events') return [];
    return _allOrgs;
  }

  List<MapAmenity> get _visibleAmenities {
    if (_activeChipId == 'all') return _allAmenities;
    if (_activeChipId == 'amenities') {
      if (_activeSubFilters.isEmpty) return _allAmenities;
      return _allAmenities
          .where((a) => _activeSubFilters.contains(a.amenityType.name))
          .toList();
    }
    if (_activeChipId == 'events') {
      return _allAmenities
          .where((a) =>
              a.amenityType == AmenityType.cleanupEvent ||
              a.amenityType == AmenityType.treeSite)
          .toList();
    }
    return [];
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};
    final isFiltered = _activeChipId != 'all';

    // Org markers
    for (final org in _visibleOrgs) {
      final icon = isFiltered
          ? (_orgIconsHero[org.orgTypeId] ?? BitmapDescriptor.defaultMarker)
          : (_orgIconsNormal[org.orgTypeId] ?? BitmapDescriptor.defaultMarker);
      markers.add(Marker(
        markerId: MarkerId(org.id),
        position: org.location,
        icon: icon,
        zIndex: isFiltered ? 2.0 : 1.0,
        infoWindow: InfoWindow.noText,
        onTap: () => _selectOrg(org),
      ));
    }

    // Amenity markers
    for (final amenity in _visibleAmenities) {
      if (!amenity.isActive) continue;
      final icon =
          _amenityIcons[amenity.amenityType] ?? BitmapDescriptor.defaultMarker;
      markers.add(Marker(
        markerId: MarkerId(amenity.id),
        position: amenity.location,
        icon: icon,
        zIndex: 1.5,
        infoWindow: InfoWindow.noText,
        onTap: () => _selectAmenity(amenity),
      ));
    }

    setState(() => _markers = markers);
  }

  // ── Selection ────────────────────────────────────────────────────────────

  void _selectOrg(MapOrganization org) {
    setState(() {
      _selectedOrg = org;
      _selectedAmenity = null;
    });
    _sheetController.forward(from: 0);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(org.location, 16));
  }

  void _selectAmenity(MapAmenity amenity) {
    setState(() {
      _selectedAmenity = amenity;
      _selectedOrg = null;
    });
    _sheetController.forward(from: 0);
    _mapController
        ?.animateCamera(CameraUpdate.newLatLngZoom(amenity.location, 16));
  }

  void _clearSelection() {
    _sheetController.reverse().then((_) {
      if (mounted)
        setState(() {
          _selectedOrg = null;
          _selectedAmenity = null;
        });
    });
  }

  // ── Chip / sub-sheet ─────────────────────────────────────────────────────

  void _onChipTap(String chipId) {
    if (_activeChipId == chipId && chipId != 'all') {
      // Re-tapping opens sub-sheet
      _openSubSheet(chipId);
      return;
    }
    setState(() {
      _activeChipId = chipId;
      _activeSubFilters.clear();
      _subSheetOpen = false;
    });
    _subSheetController.reverse();
    _rebuildMarkers();
  }

  void _openSubSheet(String chipId) {
    if (chipId == 'all') return;
    setState(() => _subSheetOpen = true);
    _subSheetController.forward(from: 0);
  }

  void _closeSubSheet() {
    _subSheetController.reverse().then((_) {
      if (mounted) setState(() => _subSheetOpen = false);
    });
  }

  void _toggleSubFilter(String id) {
    setState(() {
      _activeSubFilters.contains(id)
          ? _activeSubFilters.remove(id)
          : _activeSubFilters.add(id);
    });
    _rebuildMarkers();
  }

  void _clearSubFilters() {
    setState(() => _activeSubFilters.clear());
    _rebuildMarkers();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // Nav bar height (transparent but still reserves space for items)
    const navBarH = 70.0;

    final activeChip = _chipCategories.firstWhere((c) => c.id == _activeChipId);

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (c) {
              _mapController = c;
              c.setMapStyle(map_style.kCanopyMapStyle);
            },
            onTap: (_) {
              _clearSelection();
              _closeSubSheet();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Search bar ─────────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: _SearchBar(
              onTap: () {
                // TODO: open MapSearchOverlay
              },
            ),
          ),

          // ── Filter chip row ────────────────────────────────────────────
          Positioned(
            top: topPad + 12 + 50, // below search bar
            left: 0,
            right: 0,
            child: _FilterChipRow(
              categories: _chipCategories,
              activeId: _activeChipId,
              activeSubCount: _activeSubFilters.length,
              onTap: _onChipTap,
            ),
          ),

          // ── Org count pill ─────────────────────────────────────────────
          Positioned(
            top: topPad + 12 + 50 + 48,
            right: 16,
            child: _CountPill(
              orgCount: _visibleOrgs.length,
              amenityCount: _visibleAmenities.length,
            ),
          ),

          // ── My location button ─────────────────────────────────────────
          Positioned(
            bottom: bottomPad + navBarH + 16,
            right: 16,
            child: _MapIconButton(
              icon: Icons.my_location_outlined,
              onTap: () => _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(_initialPosition.target, 13),
              ),
            ),
          ),

          // ── Sub-filter sheet ───────────────────────────────────────────
          if (_subSheetOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSubSheet,
                child: Container(color: Colors.transparent),
              ),
            ),
          if (_subSheetOpen)
            Positioned(
              bottom: bottomPad + navBarH,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _subSheetController,
                  curve: Curves.easeOutCubic,
                )),
                child: _SubFilterSheet(
                  chip: activeChip,
                  activeSubFilters: _activeSubFilters,
                  onToggle: _toggleSubFilter,
                  onClear: _clearSubFilters,
                  onClose: _closeSubSheet,
                  sectorSubFilters: _sectorSubFilters,
                  beneficiarySubFilters: _beneficiarySubFilters,
                  amenitySubFilters: _amenitySubFilters,
                ),
              ),
            ),

          // ── Org detail bottom sheet ────────────────────────────────────
          if (_selectedOrg != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _sheetController,
                  curve: Curves.easeOutCubic,
                )),
                child: _OrgDetailSheet(
                  org: _selectedOrg!,
                  sectorColor: _sectorColor(_selectedOrg!.sectorId),
                  orgTypeIcon: _orgTypeIcon(_selectedOrg!.orgTypeId),
                  facilityLabel: _facilityLabel,
                  bottomPad: bottomPad + navBarH,
                  onClose: _clearSelection,
                ),
              ),
            ),

          // ── Amenity card ───────────────────────────────────────────────
          if (_selectedAmenity != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _sheetController,
                  curve: Curves.easeOutCubic,
                )),
                child: _AmenityCard(
                  amenity: _selectedAmenity!,
                  bottomPad: bottomPad + navBarH,
                  onClose: _clearSelection,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Search organisations, places, or facilities...',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.darkGreen.withOpacity(0.50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP ROW
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  final List<_ChipCategory> categories;
  final String activeId;
  final int activeSubCount;
  final void Function(String) onTap;

  const _FilterChipRow({
    required this.categories,
    required this.activeId,
    required this.activeSubCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isActive = cat.id == activeId;
          final hasSubFilter = isActive && activeSubCount > 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onTap(cat.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                decoration: BoxDecoration(
                  color: isActive ? cat.color : Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? cat.color : Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? cat.color.withOpacity(0.30)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: isActive ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 14,
                      color: isActive ? Colors.white : cat.color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : AppTheme.darkGreen.withOpacity(0.75),
                      ),
                    ),
                    if (hasSubFilter) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$activeSubCount',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: cat.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNT PILL
// ─────────────────────────────────────────────────────────────────────────────

class _CountPill extends StatelessWidget {
  final int orgCount;
  final int amenityCount;
  const _CountPill({required this.orgCount, required this.amenityCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 11, color: AppTheme.primary),
          const SizedBox(width: 3),
          Text('$orgCount',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen)),
          const SizedBox(width: 6),
          Container(
              width: 1,
              height: 10,
              color: AppTheme.lightGreen.withOpacity(0.5)),
          const SizedBox(width: 6),
          Icon(Icons.place_outlined, size: 11, color: AppTheme.accent),
          const SizedBox(width: 3),
          Text('$amenityCount',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _SubFilterSheet extends StatelessWidget {
  final _ChipCategory chip;
  final Set<String> activeSubFilters;
  final void Function(String) onToggle;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final Map<String, List<Map<String, dynamic>>> sectorSubFilters;
  final List<Map<String, dynamic>> beneficiarySubFilters;
  final List<Map<String, dynamic>> amenitySubFilters;

  const _SubFilterSheet({
    required this.chip,
    required this.activeSubFilters,
    required this.onToggle,
    required this.onClear,
    required this.onClose,
    required this.sectorSubFilters,
    required this.beneficiarySubFilters,
    required this.amenitySubFilters,
  });

  List<Map<String, dynamic>> get _options {
    switch (chip.id) {
      case 'organisations':
        // Show sectors as sub-filters
        return [
          {
            'id': 'sector_env',
            'label': 'Environmental & Waste',
            'icon': Icons.eco
          },
          {
            'id': 'sector_social',
            'label': 'Social Services',
            'icon': Icons.volunteer_activism
          },
          {
            'id': 'sector_health',
            'label': 'Health & Medical',
            'icon': Icons.local_hospital
          },
          {
            'id': 'sector_education',
            'label': 'Education & Skills',
            'icon': Icons.school
          },
          {
            'id': 'sector_economic',
            'label': 'Economic Empowerment',
            'icon': Icons.trending_up
          },
          {
            'id': 'sector_legal',
            'label': 'Legal Aid & Advocacy',
            'icon': Icons.gavel
          },
          {'id': 'sector_faith', 'label': 'Faith-Based', 'icon': Icons.church},
          {
            'id': 'sector_community',
            'label': 'Community & Sports',
            'icon': Icons.groups
          },
        ];
      case 'who_they_serve':
        return beneficiarySubFilters;
      case 'amenities':
        return amenitySubFilters;
      case 'marketplace':
        return [
          {
            'id': 'collector',
            'label': 'Collector Listings',
            'icon': Icons.recycling
          },
          {'id': 'processor', 'label': 'Processor Hubs', 'icon': Icons.factory},
          {
            'id': 'maker',
            'label': 'Artisan / Maker Shops',
            'icon': Icons.palette
          },
        ];
      case 'events':
        return [
          {
            'id': 'cleanupEvent',
            'label': 'Cleanup Events',
            'icon': Icons.cleaning_services_outlined
          },
          {
            'id': 'treeSite',
            'label': 'Tree Planting Sites',
            'icon': Icons.park_outlined
          },
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final options = _options;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.45),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: chip.color.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: chip.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(chip.icon, color: chip.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chip.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                        Text(
                          activeSubFilters.isEmpty
                              ? 'Showing all'
                              : '${activeSubFilters.length} selected',
                          style: TextStyle(
                            fontSize: 11,
                            color: chip.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeSubFilters.isNotEmpty)
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        foregroundColor: chip.color,
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Clear'),
                    ),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade400),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            // Options wrap
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((opt) {
                    final id = opt['id'] as String;
                    final label = opt['label'] as String;
                    final icon = opt['icon'] as IconData;
                    final selected = activeSubFilters.contains(id);
                    return GestureDetector(
                      onTap: () => onToggle(id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? chip.color
                              : chip.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? chip.color
                                : chip.color.withOpacity(0.25),
                            width: selected ? 0 : 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 13,
                                color: selected ? Colors.white : chip.color),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.darkGreen.withOpacity(0.75),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 5),
                              Icon(Icons.check, size: 12, color: Colors.white),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORG DETAIL BOTTOM SHEET — redesigned with full-width logo/gradient header
// ─────────────────────────────────────────────────────────────────────────────

class _OrgDetailSheet extends StatelessWidget {
  final MapOrganization org;
  final Color sectorColor;
  final IconData orgTypeIcon;
  final String Function(String) facilityLabel;
  final double bottomPad;
  final VoidCallback onClose;

  const _OrgDetailSheet({
    required this.org,
    required this.sectorColor,
    required this.orgTypeIcon,
    required this.facilityLabel,
    required this.bottomPad,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 30, offset: Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 0),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Full-width header strip ──────────────────────────────────
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background: logo image or gradient
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: org.logoUrl != null
                      ? Image.network(
                          org.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _HeaderGradient(
                              color: sectorColor, icon: orgTypeIcon),
                        )
                      : _HeaderGradient(color: sectorColor, icon: orgTypeIcon),
                ),
                // Bottom gradient overlay for text
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 90,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Org name + badges bottom-left
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (org.verified)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified,
                                      size: 10, color: Colors.white),
                                  const SizedBox(width: 3),
                                  const Text('Verified',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.40)),
                            ),
                            child: Text(
                              org.legalDesignation,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        org.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.2,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4)
                          ],
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                // Close button top-right
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Location line ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: sectorColor),
                const SizedBox(width: 4),
                Text(
                  '${org.area}, ${org.city}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
                if (org.phone != null) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.phone_outlined,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(org.phone!,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),

          // ── Description ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              org.description,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen.withOpacity(0.70),
                  height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Facility chips ─────────────────────────────────────────────
          if (org.facilityTypeIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: org.facilityTypeIds
                    .map((id) => Container(
                          margin: const EdgeInsets.only(right: 7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sectorColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: sectorColor.withOpacity(0.30)),
                          ),
                          child: Text(facilityLabel(id),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sectorColor)),
                        ))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── CTA buttons ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 14),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Organisation profiles coming soon')),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('View Profile'),
                    style: FilledButton.styleFrom(
                      backgroundColor: sectorColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 46),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SheetIconButton(
                    icon: Icons.directions_outlined,
                    color: sectorColor,
                    onTap: () {}),
                const SizedBox(width: 8),
                _SheetIconButton(
                    icon: Icons.share_outlined,
                    color: sectorColor,
                    onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderGradient extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _HeaderGradient({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(color, Colors.black, 0.25)!,
            color,
            Color.lerp(color, Colors.white, 0.15)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 52, color: Colors.white.withOpacity(0.30)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AMENITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AmenityCard extends StatelessWidget {
  final MapAmenity amenity;
  final double bottomPad;
  final VoidCallback onClose;

  const _AmenityCard({
    required this.amenity,
    required this.bottomPad,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = amenity.amenityType.color;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 24, offset: Offset(0, -3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(amenity.amenityType.icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(amenity.amenityType.label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      Text(amenity.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGreen,
                              height: 1.2)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon:
                      Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              amenity.description,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen.withOpacity(0.65),
                  height: 1.5),
            ),
          ),
          if (amenity.operatingHours != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.access_time_outlined, size: 13, color: color),
                  const SizedBox(width: 5),
                  Text(amenity.operatingHours!,
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (amenity.acceptedMaterials.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: amenity.acceptedMaterials
                    .map((m) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Text(m,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ))
                    .toList(),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad + 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.flag_outlined, size: 15),
                    label: const Text('Report an Issue'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SheetIconButton(
                    icon: Icons.share_outlined, color: color, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLES
// ─────────────────────────────────────────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: AppTheme.darkGreen, size: 20),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SheetIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
