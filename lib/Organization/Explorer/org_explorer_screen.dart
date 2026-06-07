// lib/Organization/Explorer/org_explorer_screen.dart
//
// Displays all registered organisations as browsable cards.
// Launched from the community Map screen.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTOR FILTER DATA
// ─────────────────────────────────────────────────────────────────────────────

const _sectors = [
  {'id': 'all', 'label': 'All', 'color': AppTheme.primary},
  {'id': 'sector_env', 'label': 'Environmental', 'color': Color(0xFF2E7D32)},
  {'id': 'sector_social', 'label': 'Social', 'color': Color(0xFFC62828)},
  {'id': 'sector_health', 'label': 'Health', 'color': Color(0xFF00695C)},
  {'id': 'sector_education', 'label': 'Education', 'color': Color(0xFF1565C0)},
  {'id': 'sector_economic', 'label': 'Economic', 'color': Color(0xFFE65100)},
  {'id': 'sector_community', 'label': 'Community', 'color': Color(0xFF5C6BC0)},
  {'id': 'sector_faith', 'label': 'Faith', 'color': Color(0xFF4E342E)},
];

Color _sectorColor(String sectorId) {
  for (final s in _sectors) {
    if (s['id'] == sectorId) return s['color'] as Color;
  }
  return AppTheme.primary;
}

String _sectorLabel(String sectorId) {
  for (final s in _sectors) {
    if (s['id'] == sectorId) return s['label'] as String;
  }
  return sectorId;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class OrgExplorerScreen extends StatefulWidget {
  const OrgExplorerScreen({Key? key}) : super(key: key);

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
          _buildOrgGrid(),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: AppTheme.darkGreen,
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Organisations',
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }

  // ── Search ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: const TextStyle(fontSize: 14, color: AppTheme.darkGreen),
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
                          size: 16, color: AppTheme.darkGreen.withOpacity(0.5)),
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
              final color = s['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _activeSectorId = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isActive ? color : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : color,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────────────

  Widget _buildOrgGrid() {
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

        // Apply sector filter
        if (_activeSectorId != 'all') {
          docs = docs
              .where((d) =>
                  (d.data() as Map<String, dynamic>)['sectorId'] ==
                  _activeSectorId)
              .toList();
        }

        // Apply search
        if (_query.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name =
                ((data['org_name'] ?? data['name'] ?? '') as String)
                    .toLowerCase();
            final city = (data['city'] as String? ?? '').toLowerCase();
            final area = (data['area'] as String? ?? '').toLowerCase();
            return name.contains(_query) ||
                city.contains(_query) ||
                area.contains(_query);
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                return _OrgCard(id: doc.id, data: data);
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
// ORG CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OrgCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _OrgCard({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final orgName =
        (data['org_name'] ?? data['name'] ?? 'Organisation') as String;
    final logoUrl = data['logoUrl'] as String?;
    final coverUrl = data['coverImageUrl'] as String?;
    final sectorId = data['sectorId'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final area = data['area'] as String? ?? '';
    final verified = data['verified'] as bool? ?? false;

    final sectorCol = _sectorColor(sectorId);
    final locationStr = [area, city].where((s) => s.isNotEmpty).join(', ');

    final initials = _initials(orgName);

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to full org detail page when available
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orgName),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image section (top 55%)
            Expanded(
              flex: 55,
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

                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Verified badge
                  if (verified)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_rounded,
                                size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Logo floating in centre of the cover
                  Center(
                    child: _LogoCircle(
                        logoUrl: logoUrl,
                        initials: initials,
                        color: sectorCol),
                  ),
                ],
              ),
            ),

            // Info section
            Expanded(
              flex: 45,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      orgName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkGreen,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sectorId.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: sectorCol.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _sectorLabel(sectorId),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: sectorCol,
                              ),
                            ),
                          ),
                        if (locationStr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 11,
                                  color: AppTheme.darkGreen.withOpacity(0.45)),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  locationStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        AppTheme.darkGreen.withOpacity(0.55),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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

class _LogoCircle extends StatelessWidget {
  final String? logoUrl;
  final String initials;
  final Color color;

  const _LogoCircle(
      {required this.logoUrl, required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _InitialsCircle(
                  initials: initials, color: color),
            )
          : _InitialsCircle(initials: initials, color: color),
    );
  }
}

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
          fontSize: 16,
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
            color.withOpacity(0.25),
            color.withOpacity(0.10),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.business_outlined,
            size: 32, color: color.withOpacity(0.30)),
      ),
    );
  }
}
