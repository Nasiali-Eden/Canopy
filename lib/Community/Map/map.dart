import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filter model — mirrors organization_taxonomy.json structure
// ─────────────────────────────────────────────────────────────────────────────

class MapFilter {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  bool selected;

  MapFilter({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.selected = false,
  });
}

class MapFilterLevel {
  final String id;
  final String label;
  final List<MapFilter> options;
  MapFilterLevel({required this.id, required this.label, required this.options});
}

// ─────────────────────────────────────────────────────────────────────────────
// Organization model
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
  final String? logoUrl; // URL to org's transparent PNG from Firebase Storage
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
// MapScreen
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
  bool _showFilterPanel = false;
  MapOrganization? _selectedOrg;

  // Active filters — multi-select across all 5 levels
  final Set<String> _activeSectorFilters = {};
  final Set<String> _activeOrgTypeFilters = {};
  final Set<String> _activeBeneficiaryFilters = {};
  final Set<String> _activeFacilityFilters = {};
  final Set<String> _activeSubFacilityFilters = {};

  // Icon cache: keyed by orgTypeId
  final Map<String, BitmapDescriptor> _typeIcons = {};

  late AnimationController _filterPanelController;
  late AnimationController _bottomSheetController;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-1.2921, 36.8219),
    zoom: 13,
  );

  // ── Sample data (replace with Firestore stream in production) ───────────────
  final List<MapOrganization> _allOrgs = const [
    MapOrganization(
      id: 'org_001',
      name: 'Kibera Plastics Collective',
      description: 'Collecting and processing plastic waste from Kibera into pellets and recycled products for resale.',
      location: LatLng(-1.3120, 36.7810),
      sectorId: 'sector_env',
      orgTypeId: 'ot_recycler',
      subTypeIds: ['st_plastic_recycler', 'st_mixed_recycler'],
      beneficiaryGroupIds: ['bg_youth', 'bg_women', 'bg_general'],
      facilityTypeIds: ['facility_collection_point', 'facility_drop_off'],
      subFacilityIds: ['sf_plastic_drop', 'sf_general_drop'],
      legalDesignation: 'CBO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Kibera',
      verified: true,
    ),
    MapOrganization(
      id: 'org_002',
      name: 'Sanaa ya Taka (Waste Art Co-op)',
      description: 'Transforming plastic waste and scrap metal into sculptures, ornaments, and handmade jewellery sold globally.',
      location: LatLng(-1.3000, 36.7670),
      sectorId: 'sector_env',
      orgTypeId: 'ot_waste_art',
      subTypeIds: ['st_plastic_art', 'st_ornament_maker'],
      beneficiaryGroupIds: ['bg_women', 'bg_youth'],
      facilityTypeIds: ['facility_workshop', 'facility_gallery'],
      subFacilityIds: ['sf_art_studio', 'sf_sewing_studio'],
      legalDesignation: 'Social Enterprise',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Kawangware',
      verified: true,
    ),
    MapOrganization(
      id: 'org_003',
      name: 'Amka Girls Initiative',
      description: 'Empowering girls through mentorship, menstrual health education, and anti-FGM advocacy in Mathare.',
      location: LatLng(-1.2597, 36.8581),
      sectorId: 'sector_social',
      orgTypeId: 'ot_girls_org',
      subTypeIds: ['st_girl_mentorship', 'st_girl_menstrual_health', 'st_girl_safety'],
      beneficiaryGroupIds: ['bg_girls', 'bg_teen_mothers'],
      facilityTypeIds: ['facility_community_center', 'facility_drop_in_center'],
      subFacilityIds: ['sf_counseling_room', 'sf_resource_center'],
      legalDesignation: 'NGO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Mathare',
      verified: true,
    ),
    MapOrganization(
      id: 'org_004',
      name: 'Tupendane PWD Center',
      description: 'Rehabilitation, assistive devices, and vocational training for persons with physical and intellectual disabilities.',
      location: LatLng(-1.3158, 36.8269),
      sectorId: 'sector_social',
      orgTypeId: 'ot_pwd_org',
      subTypeIds: ['st_physical_disability', 'st_intellectual_disability', 'st_assistive_tech'],
      beneficiaryGroupIds: ['bg_pwd', 'bg_children', 'bg_youth'],
      facilityTypeIds: ['facility_rehabilitation_center', 'facility_training_center'],
      subFacilityIds: ['sf_tailoring_unit', 'sf_ict_lab'],
      legalDesignation: 'NPO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'South B',
      verified: false,
    ),
    MapOrganization(
      id: 'org_005',
      name: 'Mama na Mtoto Health Clinic',
      description: 'Maternal and child health clinic providing ANC, immunization, and HIV testing services to Kibera residents.',
      location: LatLng(-1.3125, 36.7825),
      sectorId: 'sector_health',
      orgTypeId: 'ot_clinic',
      subTypeIds: ['st_maternal_clinic', 'st_hiv_center'],
      beneficiaryGroupIds: ['bg_women', 'bg_children', 'bg_girls'],
      facilityTypeIds: ['facility_clinic'],
      subFacilityIds: ['sf_antenatal', 'sf_hiv_testing', 'sf_pharmacy'],
      legalDesignation: 'NGO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Olympic Estate, Kibera',
      verified: true,
      phone: '+254700000001',
    ),
    MapOrganization(
      id: 'org_006',
      name: 'Tabasamu Women Enterprise',
      description: 'Women savings cooperative supporting 200+ members with microcredit, business training, and market linkages.',
      location: LatLng(-1.2833, 36.8167),
      sectorId: 'sector_social',
      orgTypeId: 'ot_women_org',
      subTypeIds: ['st_women_enterprise', 'st_women_empowerment'],
      beneficiaryGroupIds: ['bg_women'],
      facilityTypeIds: ['facility_office', 'facility_training_center'],
      subFacilityIds: ['sf_arts_studio'],
      legalDesignation: 'SACCO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Ngara',
      verified: true,
    ),
    MapOrganization(
      id: 'org_007',
      name: 'Nairobi River Guardians',
      description: 'Monthly cleanup drives along the Nairobi River, with waste quantification reports and school education programs.',
      location: LatLng(-1.3175, 36.7875),
      sectorId: 'sector_env',
      orgTypeId: 'ot_cleanup_org',
      subTypeIds: ['st_river_cleanup', 'st_community_cleanup'],
      beneficiaryGroupIds: ['bg_youth', 'bg_general'],
      facilityTypeIds: ['facility_collection_point'],
      subFacilityIds: ['sf_general_drop'],
      legalDesignation: 'CBO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Westlands — Nairobi River',
      verified: true,
    ),
    MapOrganization(
      id: 'org_008',
      name: 'Upendo Children\'s Home',
      description: 'Caring for 150 orphaned and abandoned children with housing, full-time schooling, and psychosocial support.',
      location: LatLng(-1.2400, 36.8700),
      sectorId: 'sector_social',
      orgTypeId: 'ot_children_org',
      subTypeIds: ['st_orphan_care', 'st_child_education'],
      beneficiaryGroupIds: ['bg_children', 'bg_orphans'],
      facilityTypeIds: ['facility_shelter', 'facility_school'],
      subFacilityIds: ['sf_emergency_shelter', 'sf_primary', 'sf_library'],
      legalDesignation: 'Trust',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Roysambu',
      verified: true,
    ),
    MapOrganization(
      id: 'org_009',
      name: 'Kibera WASH Point',
      description: 'Clean water access, communal latrines, and hygiene promotion across 5 villages in Kibera.',
      location: LatLng(-1.3140, 36.7840),
      sectorId: 'sector_health',
      orgTypeId: 'ot_wash',
      subTypeIds: ['st_water_access', 'st_sanitation'],
      beneficiaryGroupIds: ['bg_general', 'bg_children'],
      facilityTypeIds: ['facility_water_point'],
      subFacilityIds: ['sf_public_tap', 'sf_latrine_block', 'sf_handwashing'],
      legalDesignation: 'CBO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Kibera, Olympic Estate',
      verified: true,
    ),
    MapOrganization(
      id: 'org_010',
      name: 'FutureMakers Youth Hub',
      description: 'ICT training, graphic design, and entrepreneurship programs for youth aged 18–30 in Ngara.',
      location: LatLng(-1.2667, 36.8333),
      sectorId: 'sector_social',
      orgTypeId: 'ot_youth_org',
      subTypeIds: ['st_youth_skills', 'st_youth_enterprise', 'st_youth_arts'],
      beneficiaryGroupIds: ['bg_youth', 'bg_boys', 'bg_girls'],
      facilityTypeIds: ['facility_youth_center', 'facility_training_center'],
      subFacilityIds: ['sf_ict_lab', 'sf_entrepreneurship_hub', 'sf_recording_studio'],
      legalDesignation: 'NPO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Ngara',
      verified: false,
    ),
    MapOrganization(
      id: 'org_011',
      name: 'Taka Treasure Upcyclers',
      description: 'Handcrafted upcycled furniture and home goods from reclaimed wood, tyres, and metal scrap.',
      location: LatLng(-1.2921, 36.7856),
      sectorId: 'sector_env',
      orgTypeId: 'ot_waste_art',
      subTypeIds: ['st_furniture_maker', 'st_mixed_craft'],
      beneficiaryGroupIds: ['bg_youth', 'bg_men'],
      facilityTypeIds: ['facility_workshop'],
      subFacilityIds: ['sf_fabrication_shop'],
      legalDesignation: 'Social Enterprise',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'Kilimani',
      verified: false,
    ),
    MapOrganization(
      id: 'org_012',
      name: 'Haki Legal Aid Centre',
      description: 'Free legal aid for survivors of GBV, land disputes, and child rights violations across Nairobi.',
      location: LatLng(-1.2864, 36.8172),
      sectorId: 'sector_legal',
      orgTypeId: 'ot_legal_aid',
      subTypeIds: ['st_gbv_legal', 'st_land_rights', 'st_child_legal'],
      beneficiaryGroupIds: ['bg_women', 'bg_children', 'bg_pwd'],
      facilityTypeIds: ['facility_legal_aid_office'],
      subFacilityIds: [],
      legalDesignation: 'NGO',
      country: 'Kenya',
      city: 'Nairobi',
      area: 'CBD',
      verified: true,
      phone: '+254722000002',
      website: 'https://hakilegal.example.org',
    ),
  ];

  // ── Filter level definitions ─────────────────────────────────────────────────

  late final List<MapFilterLevel> _filterLevels = [
    MapFilterLevel(
      id: 'sector',
      label: 'Sector',
      options: [
        MapFilter(id: 'sector_env', label: 'Environmental & Waste', icon: Icons.eco, color: const Color(0xFF2E7D32)),
        MapFilter(id: 'sector_social', label: 'Social Services', icon: Icons.volunteer_activism, color: const Color(0xFFC62828)),
        MapFilter(id: 'sector_health', label: 'Health & Medical', icon: Icons.local_hospital, color: const Color(0xFF00695C)),
        MapFilter(id: 'sector_education', label: 'Education & Skills', icon: Icons.school, color: const Color(0xFF1565C0)),
        MapFilter(id: 'sector_economic', label: 'Economic Empowerment', icon: Icons.trending_up, color: const Color(0xFFE65100)),
        MapFilter(id: 'sector_legal', label: 'Legal Aid & Advocacy', icon: Icons.gavel, color: const Color(0xFF4A148C)),
        MapFilter(id: 'sector_faith', label: 'Faith-Based', icon: Icons.church, color: const Color(0xFF4E342E)),
      ],
    ),
    MapFilterLevel(
      id: 'orgType',
      label: 'Org Type',
      options: [
        MapFilter(id: 'ot_recycler', label: 'Recycler', icon: Icons.recycling, color: const Color(0xFF388E3C)),
        MapFilter(id: 'ot_waste_art', label: 'Waste-to-Art Creator', icon: Icons.palette, color: const Color(0xFF00897B)),
        MapFilter(id: 'ot_cleanup_org', label: 'Cleanup Org', icon: Icons.cleaning_services, color: const Color(0xFF43A047)),
        MapFilter(id: 'ot_conservation', label: 'Conservation', icon: Icons.park, color: const Color(0xFF2E7D32)),
        MapFilter(id: 'ot_clean_energy', label: 'Clean Energy', icon: Icons.bolt, color: const Color(0xFFF9A825)),
        MapFilter(id: 'ot_women_org', label: "Women's Org", icon: Icons.woman, color: const Color(0xFFE91E63)),
        MapFilter(id: 'ot_girls_org', label: "Girls' Org", icon: Icons.girl, color: const Color(0xFFF06292)),
        MapFilter(id: 'ot_children_org', label: "Children's Org", icon: Icons.child_care, color: const Color(0xFFFF7043)),
        MapFilter(id: 'ot_youth_org', label: 'Youth Org', icon: Icons.group, color: const Color(0xFF7E57C2)),
        MapFilter(id: 'ot_pwd_org', label: 'PWD Org', icon: Icons.accessible, color: const Color(0xFF0288D1)),
        MapFilter(id: 'ot_elderly_org', label: 'Elderly Care', icon: Icons.elderly, color: const Color(0xFF5C6BC0)),
        MapFilter(id: 'ot_refugee_org', label: 'Refugee Support', icon: Icons.transfer_within_a_station, color: const Color(0xFFFF8F00)),
        MapFilter(id: 'ot_clinic', label: 'Clinic', icon: Icons.local_hospital, color: const Color(0xFFE53935)),
        MapFilter(id: 'ot_wash', label: 'WASH Org', icon: Icons.water_drop, color: const Color(0xFF1E88E5)),
        MapFilter(id: 'ot_nutrition_org', label: 'Nutrition & Food', icon: Icons.restaurant, color: const Color(0xFFEF6C00)),
        MapFilter(id: 'ot_school', label: 'School', icon: Icons.school, color: const Color(0xFF1976D2)),
        MapFilter(id: 'ot_vocational', label: 'Vocational Training', icon: Icons.build, color: const Color(0xFF0277BD)),
        MapFilter(id: 'ot_sacco', label: 'SACCO / Microfinance', icon: Icons.account_balance, color: const Color(0xFFBF360C)),
        MapFilter(id: 'ot_legal_aid', label: 'Legal Aid', icon: Icons.gavel, color: const Color(0xFF6A1B9A)),
        MapFilter(id: 'ot_fbo', label: 'Faith-Based Org', icon: Icons.church, color: const Color(0xFF5D4037)),
      ],
    ),
    MapFilterLevel(
      id: 'beneficiary',
      label: 'Who They Serve',
      options: [
        MapFilter(id: 'bg_women', label: 'Women', icon: Icons.woman, color: const Color(0xFFE91E63)),
        MapFilter(id: 'bg_girls', label: 'Girls (Under 18)', icon: Icons.girl, color: const Color(0xFFF06292)),
        MapFilter(id: 'bg_men', label: 'Men', icon: Icons.man, color: const Color(0xFF1E88E5)),
        MapFilter(id: 'bg_boys', label: 'Boys (Under 18)', icon: Icons.boy, color: const Color(0xFF42A5F5)),
        MapFilter(id: 'bg_children', label: 'Children (All)', icon: Icons.child_care, color: const Color(0xFFFF7043)),
        MapFilter(id: 'bg_youth', label: 'Youth (15–35)', icon: Icons.group, color: const Color(0xFF7E57C2)),
        MapFilter(id: 'bg_elderly', label: 'Elderly (60+)', icon: Icons.elderly, color: const Color(0xFF5C6BC0)),
        MapFilter(id: 'bg_pwd', label: 'Persons with Disabilities', icon: Icons.accessible, color: const Color(0xFF0288D1)),
        MapFilter(id: 'bg_refugees', label: 'Refugees & IDPs', icon: Icons.transfer_within_a_station, color: const Color(0xFFFF8F00)),
        MapFilter(id: 'bg_orphans', label: 'Orphans & OVCs', icon: Icons.family_restroom, color: const Color(0xFFEF6C00)),
        MapFilter(id: 'bg_teen_mothers', label: 'Teen Mothers', icon: Icons.pregnant_woman, color: const Color(0xFFAD1457)),
        MapFilter(id: 'bg_hiv_positive', label: 'PLHIV (HIV+)', icon: Icons.healing, color: const Color(0xFF00897B)),
        MapFilter(id: 'bg_general', label: 'General Community', icon: Icons.people, color: const Color(0xFF43A047)),
      ],
    ),
    MapFilterLevel(
      id: 'facility',
      label: 'Facility Type',
      options: [
        MapFilter(id: 'facility_clinic', label: 'Clinic / Health Facility', icon: Icons.local_hospital, color: const Color(0xFFE53935)),
        MapFilter(id: 'facility_school', label: 'School / Learning Center', icon: Icons.school, color: const Color(0xFF1976D2)),
        MapFilter(id: 'facility_training_center', label: 'Training / Vocational Center', icon: Icons.build, color: const Color(0xFF0277BD)),
        MapFilter(id: 'facility_collection_point', label: 'Waste Collection Point', icon: Icons.recycling, color: const Color(0xFF388E3C)),
        MapFilter(id: 'facility_drop_off', label: 'Drop-Off Point', icon: Icons.archive, color: const Color(0xFF43A047)),
        MapFilter(id: 'facility_workshop', label: 'Workshop / Studio', icon: Icons.palette, color: const Color(0xFF00897B)),
        MapFilter(id: 'facility_shelter', label: 'Shelter / Safe House', icon: Icons.home, color: const Color(0xFFAD1457)),
        MapFilter(id: 'facility_community_center', label: 'Community Center', icon: Icons.groups, color: const Color(0xFF00897B)),
        MapFilter(id: 'facility_water_point', label: 'Water Point / WASH', icon: Icons.water_drop, color: const Color(0xFF1E88E5)),
        MapFilter(id: 'facility_youth_center', label: 'Youth Center', icon: Icons.group, color: const Color(0xFF7E57C2)),
        MapFilter(id: 'facility_food_bank', label: 'Food Bank / Feeding Program', icon: Icons.restaurant, color: const Color(0xFFEF6C00)),
        MapFilter(id: 'facility_rehabilitation_center', label: 'Rehabilitation Center', icon: Icons.accessibility_new, color: const Color(0xFF0288D1)),
        MapFilter(id: 'facility_legal_aid_office', label: 'Legal Aid Office', icon: Icons.gavel, color: const Color(0xFF6A1B9A)),
        MapFilter(id: 'facility_gallery', label: 'Gallery / Exhibition Space', icon: Icons.photo_library, color: const Color(0xFFF57C00)),
      ],
    ),
    MapFilterLevel(
      id: 'subFacility',
      label: 'Services',
      options: [
        MapFilter(id: 'sf_antenatal', label: 'Antenatal Care', icon: Icons.pregnant_woman, color: const Color(0xFFE53935)),
        MapFilter(id: 'sf_hiv_testing', label: 'HIV Testing & Counseling', icon: Icons.healing, color: const Color(0xFF00897B)),
        MapFilter(id: 'sf_pharmacy', label: 'Pharmacy', icon: Icons.medication, color: const Color(0xFFE53935)),
        MapFilter(id: 'sf_mental_health_services', label: 'Mental Health Services', icon: Icons.psychology, color: const Color(0xFF7E57C2)),
        MapFilter(id: 'sf_dental_unit', label: 'Dental Unit', icon: Icons.medical_services, color: const Color(0xFF1976D2)),
        MapFilter(id: 'sf_eye_unit', label: 'Eye / Vision Unit', icon: Icons.remove_red_eye, color: const Color(0xFF0277BD)),
        MapFilter(id: 'sf_plastic_drop', label: 'Plastic Drop-Off', icon: Icons.water_drop, color: const Color(0xFF388E3C)),
        MapFilter(id: 'sf_ewaste_drop', label: 'E-Waste Drop-Off', icon: Icons.devices, color: const Color(0xFF43A047)),
        MapFilter(id: 'sf_public_tap', label: 'Public Tap / Standpipe', icon: Icons.water_drop, color: const Color(0xFF1E88E5)),
        MapFilter(id: 'sf_latrine_block', label: 'Latrine Block', icon: Icons.wc, color: const Color(0xFF546E7A)),
        MapFilter(id: 'sf_handwashing', label: 'Handwashing Station', icon: Icons.soap, color: const Color(0xFF1E88E5)),
        MapFilter(id: 'sf_ict_lab', label: 'ICT / Computer Lab', icon: Icons.laptop, color: const Color(0xFF0277BD)),
        MapFilter(id: 'sf_tailoring_unit', label: 'Tailoring Unit', icon: Icons.checkroom, color: const Color(0xFF0277BD)),
        MapFilter(id: 'sf_recording_studio', label: 'Recording Studio', icon: Icons.mic, color: const Color(0xFF7E57C2)),
        MapFilter(id: 'sf_gbv_safe_house', label: 'GBV Safe House', icon: Icons.shield, color: const Color(0xFFAD1457)),
        MapFilter(id: 'sf_counseling_room', label: 'Counseling Room', icon: Icons.psychology, color: const Color(0xFF7E57C2)),
        MapFilter(id: 'sf_library', label: 'Library', icon: Icons.local_library, color: const Color(0xFF1976D2)),
        MapFilter(id: 'sf_art_studio', label: 'Art Studio', icon: Icons.brush, color: const Color(0xFF00897B)),
        MapFilter(id: 'sf_fabrication_shop', label: 'Fabrication / Metal Shop', icon: Icons.hardware, color: const Color(0xFF00897B)),
        MapFilter(id: 'sf_entrepreneurship_hub', label: 'Entrepreneurship Hub', icon: Icons.business_center, color: const Color(0xFF7E57C2)),
        MapFilter(id: 'sf_resource_center', label: 'Resource & Info Center', icon: Icons.info, color: const Color(0xFF00897B)),
      ],
    ),
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _filterPanelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _loadIconsAndBuildMarkers();
  }

  @override
  void dispose() {
    _filterPanelController.dispose();
    _bottomSheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color _sectorColor(String sectorId) {
    const map = {
      'sector_env': Color(0xFF2E7D32),
      'sector_social': Color(0xFFC62828),
      'sector_health': Color(0xFF00695C),
      'sector_education': Color(0xFF1565C0),
      'sector_economic': Color(0xFFE65100),
      'sector_legal': Color(0xFF4A148C),
      'sector_faith': Color(0xFF4E342E),
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
    };
    return map[id] ?? id;
  }

  // ── Icon generation ─────────────────────────────────────────────────────────

  Future<void> _loadIconsAndBuildMarkers() async {
    final typeIds = _allOrgs.map((o) => o.orgTypeId).toSet();
    for (final typeId in typeIds) {
      final org = _allOrgs.firstWhere((o) => o.orgTypeId == typeId);
      _typeIcons[typeId] = await _makeMarkerIcon(
        _orgTypeIcon(typeId),
        _sectorColor(org.sectorId),
        90.0,
      );
    }
    if (mounted) {
      setState(() {
        _iconsLoaded = true;
        _rebuildMarkers();
      });
    }
  }

  Future<BitmapDescriptor> _makeMarkerIcon(
      IconData iconData, Color color, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Outer glow
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 4,
      Paint()
        ..color = color.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main filled circle
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 9,
      Paint()..color = color,
    );

    // White ring
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 11,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Icon
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: size * 0.36,
          fontFamily: iconData.fontFamily,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ── Filtering ────────────────────────────────────────────────────────────────

  List<MapOrganization> get _filteredOrgs {
    return _allOrgs.where((org) {
      if (_activeSectorFilters.isNotEmpty &&
          !_activeSectorFilters.contains(org.sectorId)) return false;
      if (_activeOrgTypeFilters.isNotEmpty &&
          !_activeOrgTypeFilters.contains(org.orgTypeId)) return false;
      if (_activeBeneficiaryFilters.isNotEmpty &&
          org.beneficiaryGroupIds.toSet().intersection(_activeBeneficiaryFilters).isEmpty) return false;
      if (_activeFacilityFilters.isNotEmpty &&
          org.facilityTypeIds.toSet().intersection(_activeFacilityFilters).isEmpty) return false;
      if (_activeSubFacilityFilters.isNotEmpty &&
          org.subFacilityIds.toSet().intersection(_activeSubFacilityFilters).isEmpty) return false;
      return true;
    }).toList();
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};
    for (final org in _filteredOrgs) {
      final icon = _typeIcons[org.orgTypeId] ?? BitmapDescriptor.defaultMarker;
      markers.add(Marker(
        markerId: MarkerId(org.id),
        position: org.location,
        icon: icon,
        infoWindow: InfoWindow.noText,
        onTap: () => _selectOrg(org),
      ));
    }
    setState(() => _markers = markers);
  }

  void _selectOrg(MapOrganization org) {
    setState(() => _selectedOrg = org);
    _bottomSheetController.forward(from: 0);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(org.location, 16),
    );
  }

  void _clearOrgSelection() {
    _bottomSheetController.reverse().then((_) {
      if (mounted) setState(() => _selectedOrg = null);
    });
  }

  bool get _hasActiveFilters =>
      _activeSectorFilters.isNotEmpty ||
      _activeOrgTypeFilters.isNotEmpty ||
      _activeBeneficiaryFilters.isNotEmpty ||
      _activeFacilityFilters.isNotEmpty ||
      _activeSubFacilityFilters.isNotEmpty;

  int get _totalActiveCount =>
      _activeSectorFilters.length +
      _activeOrgTypeFilters.length +
      _activeBeneficiaryFilters.length +
      _activeFacilityFilters.length +
      _activeSubFacilityFilters.length;

  void _clearAllFilters() {
    setState(() {
      _activeSectorFilters.clear();
      _activeOrgTypeFilters.clear();
      _activeBeneficiaryFilters.clear();
      _activeFacilityFilters.clear();
      _activeSubFacilityFilters.clear();
    });
    _rebuildMarkers();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (c) => _mapController = c,
            onTap: (_) => _clearOrgSelection(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Scrim when filter panel open ──────────────────────────────────
          if (_showFilterPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFilterPanel,
                child: Container(color: Colors.black.withOpacity(0.38)),
              ),
            ),

          // ── Top search / filter bar ───────────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openFilterPanel,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune,
                            size: 20,
                            color: _hasActiveFilters ? AppTheme.primary : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _hasActiveFilters
                                  ? '$_totalActiveCount filter${_totalActiveCount == 1 ? '' : 's'} active'
                                  : 'Filter organizations…',
                              style: TextStyle(
                                fontSize: 14,
                                color: _hasActiveFilters ? AppTheme.primary : Colors.grey.shade500,
                                fontWeight: _hasActiveFilters ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_hasActiveFilters)
                            GestureDetector(
                              onTap: () {
                                _clearAllFilters();
                                setState(() {});
                              },
                              child: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _MapIconButton(
                  icon: Icons.my_location_outlined,
                  onTap: () => _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_initialPosition.target, 13),
                  ),
                ),
              ],
            ),
          ),

          // ── Active filter chips row ───────────────────────────────────────
          if (_hasActiveFilters)
            Positioned(
              top: topPad + 74,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ..._activeSectorFilters.map((id) => _buildActiveChip(id, 0)),
                    ..._activeOrgTypeFilters.map((id) => _buildActiveChip(id, 1)),
                    ..._activeBeneficiaryFilters.map((id) => _buildActiveChip(id, 2)),
                    ..._activeFacilityFilters.map((id) => _buildActiveChip(id, 3)),
                    ..._activeSubFacilityFilters.map((id) => _buildActiveChip(id, 4)),
                  ],
                ),
              ),
            ),

          // ── Results badge ─────────────────────────────────────────────────
          Positioned(
            top: topPad + (_hasActiveFilters ? 120 : 74),
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
              ),
              child: Text(
                '${_filteredOrgs.length} org${_filteredOrgs.length == 1 ? '' : 's'} shown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
            ),
          ),

          // ── Filter panel (slides from right) ─────────────────────────────
          if (_showFilterPanel)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: MediaQuery.of(context).size.width * 0.88,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _filterPanelController,
                  curve: Curves.easeOutCubic,
                )),
                child: _FilterPanel(
                  filterLevels: _filterLevels,
                  activeSectorFilters: _activeSectorFilters,
                  activeOrgTypeFilters: _activeOrgTypeFilters,
                  activeBeneficiaryFilters: _activeBeneficiaryFilters,
                  activeFacilityFilters: _activeFacilityFilters,
                  activeSubFacilityFilters: _activeSubFacilityFilters,
                  onChanged: () {
                    setState(() {});
                    _rebuildMarkers();
                  },
                  onClose: _closeFilterPanel,
                  onClearAll: _clearAllFilters,
                ),
              ),
            ),

          // ── Org detail bottom sheet ────────────────────────────────────────
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
                  parent: _bottomSheetController,
                  curve: Curves.easeOutCubic,
                )),
                child: _OrgDetailSheet(
                  org: _selectedOrg!,
                  sectorColor: _sectorColor(_selectedOrg!.sectorId),
                  orgTypeIcon: _orgTypeIcon(_selectedOrg!.orgTypeId),
                  facilityLabel: _facilityLabel,
                  onClose: _clearOrgSelection,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFilterPanel() {
    setState(() => _showFilterPanel = true);
    _filterPanelController.forward(from: 0);
  }

  void _closeFilterPanel() {
    _filterPanelController.reverse().then((_) {
      if (mounted) setState(() => _showFilterPanel = false);
    });
  }

  Widget _buildActiveChip(String id, int levelIndex) {
    final options = _filterLevels[levelIndex].options;
    final filter = options.firstWhere(
      (f) => f.id == id,
      orElse: () => MapFilter(id: id, label: id, icon: Icons.label, color: AppTheme.primary),
    );
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filter.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(filter.icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(filter.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () {
              setState(() {
                _activeSetFor(levelIndex).remove(id);
              });
              _rebuildMarkers();
            },
            child: const Icon(Icons.close, color: Colors.white, size: 13),
          ),
        ],
      ),
    );
  }

  Set<String> _activeSetFor(int levelIndex) {
    switch (levelIndex) {
      case 0: return _activeSectorFilters;
      case 1: return _activeOrgTypeFilters;
      case 2: return _activeBeneficiaryFilters;
      case 3: return _activeFacilityFilters;
      case 4: return _activeSubFacilityFilters;
      default: return {};
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Panel
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatefulWidget {
  final List<MapFilterLevel> filterLevels;
  final Set<String> activeSectorFilters;
  final Set<String> activeOrgTypeFilters;
  final Set<String> activeBeneficiaryFilters;
  final Set<String> activeFacilityFilters;
  final Set<String> activeSubFacilityFilters;
  final VoidCallback onChanged;
  final VoidCallback onClose;
  final VoidCallback onClearAll;

  const _FilterPanel({
    required this.filterLevels,
    required this.activeSectorFilters,
    required this.activeOrgTypeFilters,
    required this.activeBeneficiaryFilters,
    required this.activeFacilityFilters,
    required this.activeSubFacilityFilters,
    required this.onChanged,
    required this.onClose,
    required this.onClearAll,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  int _selectedLevelIndex = 0;

  Set<String> _activeSetFor(int i) {
    switch (i) {
      case 0: return widget.activeSectorFilters;
      case 1: return widget.activeOrgTypeFilters;
      case 2: return widget.activeBeneficiaryFilters;
      case 3: return widget.activeFacilityFilters;
      case 4: return widget.activeSubFacilityFilters;
      default: return {};
    }
  }

  void _toggle(int levelIndex, String id) {
    final s = _activeSetFor(levelIndex);
    setState(() => s.contains(id) ? s.remove(id) : s.add(id));
    widget.onChanged();
  }

  int _countFor(int i) => _activeSetFor(i).length;

  @override
  Widget build(BuildContext context) {
    final level = widget.filterLevels[_selectedLevelIndex];
    final activeSet = _activeSetFor(_selectedLevelIndex);

    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(-4, 0)),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.tune, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Deep Filter', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const Spacer(),
                    TextButton(
                      onPressed: () { widget.onClearAll(); setState(() {}); },
                      child: Text('Clear all', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(Icons.close, color: Colors.grey.shade500, size: 22),
                    ),
                  ],
                ),
              ),

              // Level tabs
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.filterLevels.length,
                  itemBuilder: (_, i) {
                    final isSelected = _selectedLevelIndex == i;
                    final count = _countFor(i);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedLevelIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : (count > 0 ? AppTheme.primary.withOpacity(0.08) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.filterLevels[i].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : (count > 0 ? AppTheme.primary : Colors.black54),
                              ),
                            ),
                            if (count > 0 && !isSelected) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade200),

              // Filter options list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  itemCount: level.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 5),
                  itemBuilder: (_, i) {
                    final opt = level.options[i];
                    final selected = activeSet.contains(opt.id);
                    return InkWell(
                      onTap: () => _toggle(_selectedLevelIndex, opt.id),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? opt.color.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? opt.color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: selected ? opt.color : opt.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(opt.icon, size: 17, color: selected ? Colors.white : opt.color),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                                  color: selected ? opt.color : Colors.black87,
                                ),
                              ),
                            ),
                            if (selected) Icon(Icons.check_circle, color: opt.color, size: 19),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Apply button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: FilledButton(
                  onPressed: widget.onClose,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Org Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OrgDetailSheet extends StatelessWidget {
  final MapOrganization org;
  final Color sectorColor;
  final IconData orgTypeIcon;
  final String Function(String) facilityLabel;
  final VoidCallback onClose;

  const _OrgDetailSheet({
    required this.org,
    required this.sectorColor,
    required this.orgTypeIcon,
    required this.facilityLabel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: logo + name + location + verified badge
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo or icon
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: sectorColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: org.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            org.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Icon(orgTypeIcon, color: Colors.white, size: 28),
                          ),
                        )
                      : Icon(orgTypeIcon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              org.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (org.verified)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 11, color: Colors.green.shade700),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${org.area}, ${org.city}, ${org.country}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _miniTag(org.legalDesignation, sectorColor),
                          const SizedBox(width: 6),
                          if (org.phone != null) _miniTag(org.phone!, Colors.teal),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, size: 20, color: Colors.grey.shade400),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Text(
              org.description,
              style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Facilities chips
          if (org.facilityTypeIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: org.facilityTypeIds.map((id) {
                  return Container(
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sectorColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sectorColor.withOpacity(0.25)),
                    ),
                    child: Text(
                      facilityLabel(id),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sectorColor),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // CTA buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(context).padding.bottom + 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline, size: 17),
                    label: const Text('View Profile'),
                    style: FilledButton.styleFrom(
                      backgroundColor: sectorColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 46),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SheetIconButton(
                  icon: Icons.directions_outlined,
                  color: sectorColor,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _SheetIconButton(
                  icon: Icons.share_outlined,
                  color: sectorColor,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: AppTheme.darkGreen, size: 22),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SheetIconButton({required this.icon, required this.color, required this.onTap});

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