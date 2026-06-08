// lib/Organization/Explorer/org_explorer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Shared/theme/app_theme.dart';
import 'org_view_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

const _sectors = [
  {'id': 'all', 'label': 'All'},
  {'id': 'sector_env', 'label': 'Environmental'},
  {'id': 'sector_social', 'label': 'Social'},
  {'id': 'sector_health', 'label': 'Health'},
  {'id': 'sector_education', 'label': 'Education'},
  {'id': 'sector_economic', 'label': 'Economic'},
  {'id': 'sector_community', 'label': 'Community'},
  {'id': 'sector_faith', 'label': 'Faith'},
];

Color _sectorColor(String sectorId) {
  const map = {
    'all': AppTheme.primary,
    'sector_env': Color(0xFF2E7D32),
    'sector_social': Color(0xFFC62828),
    'sector_health': Color(0xFF00695C),
    'sector_education': Color(0xFF1565C0),
    'sector_economic': Color(0xFFE65100),
    'sector_community': Color(0xFF5C6BC0),
    'sector_faith': Color(0xFF4E342E),
  };
  return map[sectorId] ?? AppTheme.primary;
}

String _sectorLabel(String sectorId) {
  const map = {
    'sector_env': 'Environmental',
    'sector_social': 'Social Services',
    'sector_health': 'Health & Medical',
    'sector_education': 'Education',
    'sector_economic': 'Economic',
    'sector_legal': 'Legal Aid',
    'sector_faith': 'Faith-Based',
    'sector_community': 'Community',
  };
  return map[sectorId] ?? sectorId;
}

IconData _sectorIcon(String sectorId) {
  const map = {
    'sector_env': Icons.eco_outlined,
    'sector_social': Icons.volunteer_activism_outlined,
    'sector_health': Icons.local_hospital_outlined,
    'sector_education': Icons.school_outlined,
    'sector_economic': Icons.trending_up_outlined,
    'sector_legal': Icons.gavel_outlined,
    'sector_faith': Icons.church_outlined,
    'sector_community': Icons.groups_outlined,
  };
  return map[sectorId] ?? Icons.business_outlined;
}

IconData _orgTypeIconData(String orgTypeId) {
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
  return map[orgTypeId] ?? Icons.business_outlined;
}

String _facilityLabelText(String id) {
  const map = {
    'facility_clinic': 'Clinic',
    'facility_school': 'School',
    'facility_training_center': 'Training Center',
    'facility_collection_point': 'Collection Point',
    'facility_drop_off': 'Drop-Off Point',
    'facility_workshop': 'Workshop',
    'facility_shelter': 'Shelter',
    'facility_community_center': 'Community Center',
    'facility_water_point': 'Water Point',
    'facility_youth_center': 'Youth Center',
    'facility_food_bank': 'Food Bank',
    'facility_rehabilitation_center': 'Rehab Center',
    'facility_legal_aid_office': 'Legal Aid',
    'facility_gallery': 'Gallery',
    'facility_office': 'Office',
    'facility_sports_ground': 'Sports Ground',
    'facility_drop_in_center': 'Drop-In Center',
  };
  return map[id] ?? id;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class OrgExplorerScreen extends StatefulWidget {
  const OrgExplorerScreen({super.key});

  @override
  State<OrgExplorerScreen> createState() => _OrgExplorerScreenState();
}

class _OrgExplorerScreenState extends State<OrgExplorerScreen> {
  final _searchController = TextEditingController();
  String _activeSectorId = 'all';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          _buildSearchBar(),
          _buildFilterRow(),
          _buildOrgList(),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 96,
      collapsedHeight: 60,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppTheme.darkGreen),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 14),
        title: const Text(
          'Organisations',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  // ── Search ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style:
                const TextStyle(fontSize: 14, color: AppTheme.darkGreen),
            decoration: InputDecoration(
              hintText: 'Search by name, city, or type…',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppTheme.darkGreen.withOpacity(0.40),
              ),
              prefixIcon: Icon(Icons.search,
                  size: 19, color: AppTheme.primary.withOpacity(0.70)),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(Icons.close,
                          size: 16,
                          color: AppTheme.darkGreen.withOpacity(0.5)),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sector Filter ─────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
        child: SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sectors.length,
            itemBuilder: (_, i) {
              final s = _sectors[i];
              final id = s['id'] as String;
              final isActive = id == _activeSectorId;
              final color = _sectorColor(id);
              return GestureDetector(
                onTap: () => setState(() => _activeSectorId = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: isActive ? color : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (id != 'all') ...[
                        Icon(_sectorIcon(id),
                            size: 12,
                            color:
                                isActive ? Colors.white : color),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        s['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildOrgList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text('Failed to load organisations',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          );
        }

        var docs = snap.data?.docs ?? [];

        if (_activeSectorId != 'all') {
          docs = docs
              .where((d) =>
                  (d.data() as Map<String, dynamic>)['sectorId'] ==
                  _activeSectorId)
              .toList();
        }

        if (_query.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name =
                ((data['org_name'] ?? data['name'] ?? '') as String)
                    .toLowerCase();
            final city = (data['city'] as String? ?? '').toLowerCase();
            final area = (data['area'] as String? ?? '').toLowerCase();
            final desc =
                (data['background'] ?? data['description'] ?? data['bio'] ?? '')
                    .toString()
                    .toLowerCase();
            return name.contains(_query) ||
                city.contains(_query) ||
                area.contains(_query) ||
                desc.contains(_query);
          }).toList();
        }

        if (docs.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_outlined,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'No organisations found',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OrgCard(id: doc.id, data: data),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORG CARD — horizontal layout
// ─────────────────────────────────────────────────────────────────────────────

class _OrgCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _OrgCard({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final orgName =
        (data['org_name'] ?? data['name'] ?? 'Organisation') as String;
    // Field reality (see CommunityAuthService.registerAsOrganization):
    //   description → 'background', logo → 'profilePhoto',
    //   designation → 'orgDesignation'.
    final logoUrl = (data['logoUrl'] ?? data['profilePhoto']) as String?;
    final coverUrl = (data['coverImageUrl'] ?? data['profilePhoto']) as String?;
    final sectorId = data['sectorId'] as String? ?? '';
    final orgTypeId = data['orgTypeId'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final area = data['area'] as String? ?? '';
    final verified = data['verified'] as bool? ?? false;
    final description =
        (data['background'] ?? data['description'] ?? data['bio'] ?? '') as String;
    final facilityTypeIds =
        List<String>.from(data['facilityTypeIds'] ?? []);
    final designation =
        (data['orgDesignation'] ?? data['designation'] ?? '') as String;

    if (kDebugMode) {
      debugPrint('[OrgCard] id=$id name=$orgName '
          'background.len=${description.length} logoUrl=$logoUrl '
          'designation=$designation keys=${data.keys.toList()}');
    }

    final sectorCol = _sectorColor(sectorId);
    final locationStr =
        [area, city].where((s) => s.isNotEmpty).join(', ');
    final initials = _initials(orgName);
    final typeIcon = orgTypeId.isNotEmpty
        ? _orgTypeIconData(orgTypeId)
        : _sectorIcon(sectorId);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrgViewScreen(orgId: id, orgData: data),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: cover image (110px) ──────────────────────────────
              SizedBox(
                width: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover background
                    coverUrl != null && coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _CoverPlaceholder(color: sectorCol),
                          )
                        : _CoverPlaceholder(color: sectorCol),

                    // Bottom-to-top gradient on image
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.45),
                            ],
                            stops: const [0.45, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Logo circle bottom-right
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _InitialsCircle(
                                    initials: initials, color: sectorCol),
                              )
                            : _InitialsCircle(
                                initials: initials, color: sectorCol),
                      ),
                    ),

                    // Verified badge top-left
                    if (verified)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1B5E20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified,
                              size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Right: content ─────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + designation
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              orgName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkGreen,
                                height: 1.25,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (designation.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: sectorCol.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                designation,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: sectorCol,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Sector chip with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: sectorCol.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon,
                                    size: 11, color: sectorCol),
                                const SizedBox(width: 4),
                                Text(
                                  _sectorLabel(sectorId),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: sectorCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Location
                      if (locationStr.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 11,
                                color:
                                    AppTheme.darkGreen.withOpacity(0.40)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                locationStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      AppTheme.darkGreen.withOpacity(0.55),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Description (long — aim ~100 words visible)
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 7,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.darkGreen.withOpacity(0.58),
                            height: 1.45,
                          ),
                        ),
                      ],

                      // Facility chips (up to 3)
                      if (facilityTypeIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: facilityTypeIds
                              .take(3)
                              .map((fId) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: sectorCol.withOpacity(0.07),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color: sectorCol
                                              .withOpacity(0.22)),
                                    ),
                                    child: Text(
                                      _facilityLabelText(fId),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: sectorCol,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'O';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _InitialsCircle extends StatelessWidget {
  final String initials;
  final Color color;
  const _InitialsCircle({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withOpacity(0.12),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final Color color;
  const _CoverPlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.28),
            color.withOpacity(0.10),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.business_outlined,
            size: 30, color: color.withOpacity(0.28)),
      ),
    );
  }
}
