// Data models and static taxonomy for organization registration
// Extracted from join_community.dart to be reused across registration screens

class OrgSector {
  final String id, label, icon, color, description;
  final List<OrgType> orgTypes;
  const OrgSector({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
    required this.orgTypes,
  });
}

class OrgType {
  final String id, label, icon, color, description;
  final List<OrgSubType> subTypes;
  final List<String> facilityIds;
  const OrgType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
    required this.subTypes,
    required this.facilityIds,
  });
}

class OrgSubType {
  final String id, label, icon;
  const OrgSubType({required this.id, required this.label, required this.icon});
}

class BeneficiaryGroup {
  final String id, label, icon, color;
  const BeneficiaryGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class LegalDesignation {
  final String id, acronym, fullForm, description;
  const LegalDesignation({
    required this.id,
    required this.acronym,
    required this.fullForm,
    required this.description,
  });
}

// Static taxonomy data (mirrors organization_taxonomy.json — keep in sync)

const List<OrgSector> kSectors = [
  OrgSector(
    id: 'sector_env',
    label: 'Environmental & Waste',
    icon: 'eco',
    color: '#2E7D32',
    description: 'Recycling, waste-to-art, cleanup, conservation, clean energy.',
    orgTypes: [
      OrgType(
        id: 'ot_recycler',
        label: 'Recycler',
        icon: 'recycling',
        color: '#388E3C',
        description: 'Collect, sort, and process recyclable materials.',
        facilityIds: ['facility_collection_point', 'facility_drop_off'],
        subTypes: [
          OrgSubType(id: 'st_plastic_recycler', label: 'Plastic Recycler', icon: 'water_drop'),
          OrgSubType(id: 'st_metal_recycler', label: 'Metal & Scrap Recycler', icon: 'hardware'),
          OrgSubType(id: 'st_paper_recycler', label: 'Paper & Cardboard Recycler', icon: 'description'),
          OrgSubType(id: 'st_glass_recycler', label: 'Glass Recycler', icon: 'wine_bar'),
          OrgSubType(id: 'st_ewaste_recycler', label: 'E-Waste Recycler', icon: 'devices'),
          OrgSubType(id: 'st_textile_recycler', label: 'Textile & Fabric Recycler', icon: 'checkroom'),
          OrgSubType(id: 'st_organic_recycler', label: 'Organic Waste / Composter', icon: 'compost'),
          OrgSubType(id: 'st_mixed_recycler', label: 'Mixed-Waste Recycler', icon: 'delete_sweep'),
        ],
      ),
      OrgType(
        id: 'ot_waste_art',
        label: 'Waste-to-Art Creator',
        icon: 'palette',
        color: '#00897B',
        description: 'Transform waste into art, ornaments, furniture, fashion & crafts.',
        facilityIds: ['facility_workshop', 'facility_gallery'],
        subTypes: [
          OrgSubType(id: 'st_plastic_art', label: 'Plastic Art & Sculpture', icon: 'format_shapes'),
          OrgSubType(id: 'st_ornament_maker', label: 'Ornament & Jewellery Maker', icon: 'diamond'),
          OrgSubType(id: 'st_furniture_maker', label: 'Upcycled Furniture Maker', icon: 'chair'),
          OrgSubType(id: 'st_fashion_upcycle', label: 'Upcycled Fashion Designer', icon: 'style'),
          OrgSubType(id: 'st_mural_art', label: 'Mural & Street Art (Eco)', icon: 'brush'),
          OrgSubType(id: 'st_mixed_craft', label: 'Mixed Waste Crafts', icon: 'auto_awesome'),
        ],
      ),
      OrgType(
        id: 'ot_cleanup_org',
        label: 'Cleanup Organization',
        icon: 'cleaning_services',
        color: '#43A047',
        description: 'Coordinate community, river, beach, or urban cleanup drives.',
        facilityIds: ['facility_base_camp', 'facility_meetup_point'],
        subTypes: [
          OrgSubType(id: 'st_community_cleanup', label: 'Community Cleanup', icon: 'people'),
          OrgSubType(id: 'st_river_cleanup', label: 'River & Waterway Cleanup', icon: 'waves'),
          OrgSubType(id: 'st_beach_cleanup', label: 'Beach & Ocean Cleanup', icon: 'beach_access'),
          OrgSubType(id: 'st_urban_cleanup', label: 'Urban & Street Cleanup', icon: 'location_city'),
          OrgSubType(id: 'st_forest_cleanup', label: 'Forest & Reserve Cleanup', icon: 'forest'),
        ],
      ),
      OrgType(
        id: 'ot_conservation',
        label: 'Conservation & Restoration',
        icon: 'park',
        color: '#2E7D32',
        description: 'Ecosystem restoration, tree planting, wildlife, biodiversity.',
        facilityIds: ['facility_nursery', 'facility_nature_center'],
        subTypes: [
          OrgSubType(id: 'st_reforestation', label: 'Reforestation & Tree Planting', icon: 'nature'),
          OrgSubType(id: 'st_wetland', label: 'Wetland & River Conservation', icon: 'water'),
          OrgSubType(id: 'st_wildlife', label: 'Wildlife & Habitat Protection', icon: 'pets'),
          OrgSubType(id: 'st_soil_conservation', label: 'Soil & Land Restoration', icon: 'landscape'),
        ],
      ),
      OrgType(
        id: 'ot_clean_energy',
        label: 'Clean Energy from Waste',
        icon: 'bolt',
        color: '#F9A825',
        description: 'Biogas, biomass, solar initiatives from waste conversion.',
        facilityIds: ['facility_processing_plant'],
        subTypes: [
          OrgSubType(id: 'st_biogas', label: 'Biogas Producer', icon: 'science'),
          OrgSubType(id: 'st_biomass', label: 'Biomass Energy', icon: 'local_fire_department'),
          OrgSubType(id: 'st_solar_waste', label: 'Solar & Renewables', icon: 'solar_power'),
        ],
      ),
    ],
  ),
  OrgSector(
    id: 'sector_social',
    label: 'Social Services & Welfare',
    icon: 'volunteer_activism',
    color: '#C62828',
    description: 'NGOs providing welfare, protection, and empowerment.',
    orgTypes: [
      OrgType(
        id: 'ot_women_org',
        label: "Women's Organization",
        icon: 'woman',
        color: '#E91E63',
        description: "Women's rights, empowerment, economic inclusion, safety.",
        facilityIds: ['facility_shelter', 'facility_training_center', 'facility_clinic'],
        subTypes: [
          OrgSubType(id: 'st_women_empowerment', label: 'Women Empowerment', icon: 'group'),
          OrgSubType(id: 'st_gbv', label: 'GBV / Domestic Violence Support', icon: 'shield'),
          OrgSubType(id: 'st_women_enterprise', label: 'Women Enterprise & Cooperatives', icon: 'storefront'),
          OrgSubType(id: 'st_maternal_health', label: 'Maternal & Reproductive Health', icon: 'pregnant_woman'),
          OrgSubType(id: 'st_women_legal', label: "Women's Legal Aid", icon: 'gavel'),
          OrgSubType(id: 'st_women_education', label: "Women's Education & Literacy", icon: 'school'),
        ],
      ),
      OrgType(
        id: 'ot_girls_org',
        label: "Girls' Organization",
        icon: 'girl',
        color: '#F06292',
        description: 'Mentorship, education, safety, and health for girls.',
        facilityIds: ['facility_drop_in_center', 'facility_safe_space', 'facility_school'],
        subTypes: [
          OrgSubType(id: 'st_girl_education', label: 'Girl Child Education', icon: 'school'),
          OrgSubType(id: 'st_girl_menstrual_health', label: 'Menstrual Health & Hygiene', icon: 'health_and_safety'),
          OrgSubType(id: 'st_girl_safety', label: 'Girl Safety & Anti-FGM', icon: 'shield'),
          OrgSubType(id: 'st_girl_mentorship', label: "Girls' Mentorship Programs", icon: 'star'),
          OrgSubType(id: 'st_teen_mothers', label: 'Teen Mother Support', icon: 'family_restroom'),
        ],
      ),
      OrgType(
        id: 'ot_children_org',
        label: "Children's Organization",
        icon: 'child_care',
        color: '#FF7043',
        description: 'Child welfare, protection, development, and education.',
        facilityIds: ['facility_children_home', 'facility_daycare', 'facility_school'],
        subTypes: [
          OrgSubType(id: 'st_orphan_care', label: 'Orphan & OVC Care', icon: 'family_restroom'),
          OrgSubType(id: 'st_child_protection', label: 'Child Protection', icon: 'shield'),
          OrgSubType(id: 'st_child_education', label: 'Early Childhood Education', icon: 'school'),
          OrgSubType(id: 'st_child_nutrition', label: 'Child Nutrition & Feeding', icon: 'restaurant'),
          OrgSubType(id: 'st_child_abuse', label: 'Child Abuse Prevention', icon: 'health_and_safety'),
          OrgSubType(id: 'st_street_children', label: 'Street Children Support', icon: 'home'),
        ],
      ),
      OrgType(
        id: 'ot_youth_org',
        label: 'Youth Organization',
        icon: 'group',
        color: '#7E57C2',
        description: 'Skills, leadership, employment, and wellness for 15–35 year olds.',
        facilityIds: ['facility_youth_center', 'facility_training_center'],
        subTypes: [
          OrgSubType(id: 'st_youth_skills', label: 'Youth Skills & Vocational Training', icon: 'build'),
          OrgSubType(id: 'st_youth_enterprise', label: 'Youth Entrepreneurship', icon: 'business_center'),
          OrgSubType(id: 'st_youth_mental_health', label: 'Youth Mental Health', icon: 'psychology'),
          OrgSubType(id: 'st_youth_sport', label: 'Sports & Physical Activity', icon: 'sports_soccer'),
          OrgSubType(id: 'st_youth_arts', label: 'Youth Arts & Culture', icon: 'music_note'),
          OrgSubType(id: 'st_youth_civic', label: 'Civic & Leadership Programs', icon: 'how_to_vote'),
        ],
      ),
      OrgType(
        id: 'ot_pwd_org',
        label: 'Persons with Disabilities (PWD)',
        icon: 'accessible',
        color: '#0288D1',
        description: 'Physical, sensory, intellectual, and psychosocial disability support.',
        facilityIds: ['facility_rehabilitation_center', 'facility_special_school', 'facility_clinic'],
        subTypes: [
          OrgSubType(id: 'st_physical_disability', label: 'Physical Disability Support', icon: 'wheelchair_pickup'),
          OrgSubType(id: 'st_visual_impairment', label: 'Visual Impairment Support', icon: 'visibility_off'),
          OrgSubType(id: 'st_hearing_impairment', label: 'Hearing Impairment / Deaf Support', icon: 'hearing_disabled'),
          OrgSubType(id: 'st_intellectual_disability', label: 'Intellectual & Developmental Disabilities', icon: 'psychology'),
          OrgSubType(id: 'st_mental_health_pwd', label: 'Psychosocial Disability', icon: 'self_improvement'),
          OrgSubType(id: 'st_autism', label: 'Autism Support', icon: 'diversity_2'),
          OrgSubType(id: 'st_assistive_tech', label: 'Assistive Technology & Devices', icon: 'devices'),
        ],
      ),
      OrgType(
        id: 'ot_elderly_org',
        label: 'Elderly Care',
        icon: 'elderly',
        color: '#5C6BC0',
        description: 'Care, companionship, and services for older persons.',
        facilityIds: ['facility_care_home', 'facility_day_center'],
        subTypes: [
          OrgSubType(id: 'st_elderly_home', label: 'Elder Care Homes', icon: 'home'),
          OrgSubType(id: 'st_home_based_care', label: 'Home-Based Care Services', icon: 'medical_services'),
          OrgSubType(id: 'st_elderly_livelihood', label: 'Elderly Livelihood & Pensions', icon: 'payments'),
        ],
      ),
      OrgType(
        id: 'ot_refugee_org',
        label: 'Refugees & Displaced Persons',
        icon: 'transfer_within_a_station',
        color: '#FF8F00',
        description: 'Refugees, asylum seekers, IDPs, and stateless persons.',
        facilityIds: ['facility_reception_center', 'facility_community_center'],
        subTypes: [
          OrgSubType(id: 'st_refugee_legal', label: 'Legal Aid & Documentation', icon: 'gavel'),
          OrgSubType(id: 'st_refugee_resettlement', label: 'Resettlement Support', icon: 'home'),
          OrgSubType(id: 'st_refugee_livelihoods', label: 'Livelihoods & Integration', icon: 'work'),
          OrgSubType(id: 'st_refugee_psychosocial', label: 'Psychosocial Support', icon: 'psychology'),
        ],
      ),
    ],
  ),
  OrgSector(
    id: 'sector_health',
    label: 'Health & Medical',
    icon: 'local_hospital',
    color: '#00695C',
    description: 'Health services, medical care, nutrition, WASH.',
    orgTypes: [
      OrgType(
        id: 'ot_clinic',
        label: 'Clinic / Health Facility',
        icon: 'local_hospital',
        color: '#E53935',
        description: 'Outpatient, inpatient, or specialized health care.',
        facilityIds: ['facility_clinic', 'facility_pharmacy', 'facility_laboratory'],
        subTypes: [
          OrgSubType(id: 'st_general_clinic', label: 'General Outpatient Clinic', icon: 'local_hospital'),
          OrgSubType(id: 'st_maternal_clinic', label: 'Maternal & Child Health Clinic', icon: 'pregnant_woman'),
          OrgSubType(id: 'st_dental', label: 'Dental Clinic', icon: 'medical_services'),
          OrgSubType(id: 'st_eye_clinic', label: 'Eye / Vision Clinic', icon: 'remove_red_eye'),
          OrgSubType(id: 'st_hiv_center', label: 'HIV/AIDS Care Center', icon: 'healing'),
          OrgSubType(id: 'st_mental_health_clinic', label: 'Mental Health Clinic', icon: 'psychology'),
          OrgSubType(id: 'st_physiotherapy', label: 'Physiotherapy & Rehabilitation', icon: 'accessibility_new'),
        ],
      ),
      OrgType(
        id: 'ot_wash',
        label: 'WASH Organization',
        icon: 'water_drop',
        color: '#1E88E5',
        description: 'Water, Sanitation, and Hygiene access and promotion.',
        facilityIds: ['facility_water_point', 'facility_borehole'],
        subTypes: [
          OrgSubType(id: 'st_water_access', label: 'Clean Water Access', icon: 'water'),
          OrgSubType(id: 'st_sanitation', label: 'Sanitation & Toilet Facilities', icon: 'wc'),
          OrgSubType(id: 'st_hygiene_promo', label: 'Hygiene Promotion', icon: 'soap'),
        ],
      ),
      OrgType(
        id: 'ot_nutrition_org',
        label: 'Nutrition & Food Security',
        icon: 'restaurant',
        color: '#EF6C00',
        description: 'Food insecurity, malnutrition, and food access.',
        facilityIds: ['facility_food_bank', 'facility_kitchen', 'facility_distribution_point'],
        subTypes: [
          OrgSubType(id: 'st_food_bank', label: 'Food Bank', icon: 'inventory'),
          OrgSubType(id: 'st_feeding_program', label: 'Feeding Program', icon: 'fastfood'),
          OrgSubType(id: 'st_school_feeding', label: 'School Feeding Program', icon: 'school'),
          OrgSubType(id: 'st_nutrition_therapy', label: 'Therapeutic Nutrition Center', icon: 'medical_services'),
        ],
      ),
    ],
  ),
  OrgSector(
    id: 'sector_education',
    label: 'Education & Skills',
    icon: 'school',
    color: '#1565C0',
    description: 'Formal education, vocational training, literacy, life skills.',
    orgTypes: [
      OrgType(
        id: 'ot_school',
        label: 'School',
        icon: 'school',
        color: '#1976D2',
        description: 'Formal educational institutions — primary, secondary, tertiary.',
        facilityIds: ['facility_school', 'facility_library', 'facility_computer_lab'],
        subTypes: [
          OrgSubType(id: 'st_early_childhood', label: 'Early Childhood / Nursery', icon: 'child_care'),
          OrgSubType(id: 'st_primary_school', label: 'Primary School', icon: 'school'),
          OrgSubType(id: 'st_secondary_school', label: 'Secondary School', icon: 'school'),
          OrgSubType(id: 'st_special_needs_school', label: 'Special Needs School', icon: 'accessible'),
          OrgSubType(id: 'st_adult_literacy', label: 'Adult Literacy Program', icon: 'menu_book'),
        ],
      ),
      OrgType(
        id: 'ot_vocational',
        label: 'Vocational & Skills Training',
        icon: 'build',
        color: '#0277BD',
        description: 'Technical and vocational education — tailoring, ICT, mechanics, etc.',
        facilityIds: ['facility_training_center', 'facility_workshop'],
        subTypes: [
          OrgSubType(id: 'st_tailoring', label: 'Tailoring & Fashion', icon: 'checkroom'),
          OrgSubType(id: 'st_carpentry', label: 'Carpentry & Woodwork', icon: 'carpenter'),
          OrgSubType(id: 'st_mechanics', label: 'Motor Vehicle Mechanics', icon: 'car_repair'),
          OrgSubType(id: 'st_ict_training', label: 'ICT & Digital Skills', icon: 'computer'),
          OrgSubType(id: 'st_culinary', label: 'Culinary Arts', icon: 'restaurant'),
          OrgSubType(id: 'st_construction', label: 'Construction & Plumbing', icon: 'construction'),
        ],
      ),
    ],
  ),
  OrgSector(
    id: 'sector_economic',
    label: 'Economic Empowerment',
    icon: 'trending_up',
    color: '#E65100',
    description: 'Financial inclusion, cooperatives, micro-enterprise, market access.',
    orgTypes: [
      OrgType(
        id: 'ot_sacco',
        label: 'SACCO / Microfinance / Chama',
        icon: 'account_balance',
        color: '#BF360C',
        description: 'Savings, credit, and self-help financial groups.',
        facilityIds: ['facility_office'],
        subTypes: [
          OrgSubType(id: 'st_sacco', label: 'SACCO', icon: 'savings'),
          OrgSubType(id: 'st_chama', label: 'Chama / Self-Help Group', icon: 'group'),
          OrgSubType(id: 'st_mfi', label: 'Microfinance Institution', icon: 'account_balance'),
          OrgSubType(id: 'st_cooperative', label: 'Cooperative Society', icon: 'diversity_3'),
        ],
      ),
      OrgType(
        id: 'ot_market_org',
        label: 'Market & Trade Organization',
        icon: 'storefront',
        color: '#E65100',
        description: 'Market access, trade, and local commerce for producers.',
        facilityIds: ['facility_market_stall', 'facility_warehouse'],
        subTypes: [
          OrgSubType(id: 'st_farmers_market', label: 'Farmers & Producers Market', icon: 'agriculture'),
          OrgSubType(id: 'st_craft_market', label: 'Craft & Artisan Market', icon: 'palette'),
          OrgSubType(id: 'st_digital_marketplace', label: 'Digital Marketplace / E-commerce', icon: 'shopping_cart'),
        ],
      ),
    ],
  ),
  OrgSector(
    id: 'sector_legal',
    label: 'Legal Aid & Advocacy',
    icon: 'gavel',
    color: '#4A148C',
    description: 'Legal aid, human rights, and civic engagement.',
    orgTypes: [
      OrgType(
        id: 'ot_legal_aid',
        label: 'Legal Aid Organization',
        icon: 'gavel',
        color: '#6A1B9A',
        description: 'Free or subsidized legal counsel and representation.',
        facilityIds: ['facility_legal_aid_office'],
        subTypes: [
          OrgSubType(id: 'st_gbv_legal', label: 'GBV / SGBV Legal Aid', icon: 'shield'),
          OrgSubType(id: 'st_land_rights', label: 'Land Rights Advocacy', icon: 'map'),
          OrgSubType(id: 'st_consumer_rights', label: 'Consumer Rights', icon: 'policy'),
          OrgSubType(id: 'st_child_legal', label: 'Child Rights Legal Aid', icon: 'child_care'),
        ],
      ),
    ],
  ),
  OrgSector(
    id: 'sector_faith',
    label: 'Faith-Based Organizations',
    icon: 'volunteer_activism',
    color: '#4E342E',
    description: 'Religious groups delivering community services.',
    orgTypes: [
      OrgType(
        id: 'ot_fbo',
        label: 'Faith-Based Organization',
        icon: 'church',
        color: '#5D4037',
        description: 'Churches, mosques, temples, and interfaith groups.',
        facilityIds: ['facility_worship_center', 'facility_community_hall', 'facility_shelter'],
        subTypes: [
          OrgSubType(id: 'st_church', label: 'Church / Christian Organization', icon: 'church'),
          OrgSubType(id: 'st_mosque', label: 'Mosque / Islamic Organization', icon: 'mosque'),
          OrgSubType(id: 'st_interfaith', label: 'Interfaith Organization', icon: 'diversity_1'),
        ],
      ),
    ],
  ),
];

const List<BeneficiaryGroup> kBeneficiaryGroups = [
  BeneficiaryGroup(id: 'bg_women', label: 'Women', icon: 'woman', color: '#E91E63'),
  BeneficiaryGroup(id: 'bg_girls', label: 'Girls (Under 18)', icon: 'girl', color: '#F06292'),
  BeneficiaryGroup(id: 'bg_men', label: 'Men', icon: 'man', color: '#1E88E5'),
  BeneficiaryGroup(id: 'bg_boys', label: 'Boys (Under 18)', icon: 'boy', color: '#42A5F5'),
  BeneficiaryGroup(id: 'bg_children', label: 'Children (All)', icon: 'child_care', color: '#FF7043'),
  BeneficiaryGroup(id: 'bg_youth', label: 'Youth (15–35)', icon: 'group', color: '#7E57C2'),
  BeneficiaryGroup(id: 'bg_elderly', label: 'Elderly (60+)', icon: 'elderly', color: '#5C6BC0'),
  BeneficiaryGroup(id: 'bg_pwd', label: 'Persons with Disabilities', icon: 'accessible', color: '#0288D1'),
  BeneficiaryGroup(id: 'bg_refugees', label: 'Refugees & IDPs', icon: 'transfer_within_a_station', color: '#FF8F00'),
  BeneficiaryGroup(id: 'bg_orphans', label: 'Orphans & OVCs', icon: 'family_restroom', color: '#EF6C00'),
  BeneficiaryGroup(id: 'bg_teen_mothers', label: 'Teen Mothers', icon: 'pregnant_woman', color: '#AD1457'),
  BeneficiaryGroup(id: 'bg_hiv_positive', label: 'PLHIV (HIV+)', icon: 'healing', color: '#00897B'),
  BeneficiaryGroup(id: 'bg_general', label: 'General Community', icon: 'people', color: '#43A047'),
];

const List<LegalDesignation> kLegalDesignations = [
  LegalDesignation(id: 'des_ngo', acronym: 'NGO', fullForm: 'Non-Governmental Organization', description: 'International or national charity operating independently of government.'),
  LegalDesignation(id: 'des_npo', acronym: 'NPO', fullForm: 'Non-Profit Organization', description: 'Organizations that reinvest all revenues into their mission.'),
  LegalDesignation(id: 'des_cbo', acronym: 'CBO', fullForm: 'Community-Based Organization', description: 'Locally formed grassroots organizations addressing local needs.'),
  LegalDesignation(id: 'des_pbo', acronym: 'PBO', fullForm: 'Public Benefit Organization', description: 'Officially registered groups serving the public good.'),
  LegalDesignation(id: 'des_trust', acronym: 'Trust', fullForm: 'Charitable Trust', description: 'Organizations managing funds or assets for community benefit.'),
  LegalDesignation(id: 'des_society', acronym: 'Society', fullForm: 'Registered Society', description: 'Associations for cultural, social, or religious activities.'),
  LegalDesignation(id: 'des_clg', acronym: 'CLG', fullForm: 'Company Limited by Guarantee', description: 'Non-profit companies running schools, clinics, or foundations.'),
  LegalDesignation(id: 'des_fbo', acronym: 'FBO', fullForm: 'Faith-Based Organization', description: 'Religious groups providing social services to communities.'),
  LegalDesignation(id: 'des_shg', acronym: 'SHG', fullForm: 'Self-Help Group', description: 'Small groups where members save money and support each other.'),
  LegalDesignation(id: 'des_sacco', acronym: 'SACCO', fullForm: 'Savings & Credit Cooperative', description: 'Member-owned financial cooperatives.'),
  LegalDesignation(id: 'des_social_enterprise', acronym: 'Social Enterprise', fullForm: 'Social Enterprise / Impact Business', description: 'Businesses with a primary social or environmental mission.'),
  LegalDesignation(id: 'des_network', acronym: 'Network', fullForm: 'Coalition or Network', description: 'An umbrella body coordinating multiple member organizations.'),
];
