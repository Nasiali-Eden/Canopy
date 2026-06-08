// lib/EnvironmentalOps/env_ops_shell.dart
//
// 4-tab Environmental Ops shell — similar pattern to CultureHomeScreen.
// Tabs: Overview · Territory · Operations · Profile

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/role_context_switcher.dart';
import 'Market/env_market.dart';
import 'Market/create_listing_screen.dart';
import 'Territory/env_territory.dart';
import 'Trees/env_trees.dart';
import 'Fleet/env_fleet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHELL
// ─────────────────────────────────────────────────────────────────────────────

class EnvOpsShell extends StatefulWidget {
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? marketplaceContextBuilder;
  final WidgetBuilder? culturalContextBuilder;
  final bool hasMarketplace;
  final bool hasCultural;

  const EnvOpsShell({
    super.key,
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.marketplaceContextBuilder,
    this.culturalContextBuilder,
    this.hasMarketplace = false,
    this.hasCultural = false,
  });

  @override
  State<EnvOpsShell> createState() => _EnvOpsShellState();
}

class _EnvOpsShellState extends State<EnvOpsShell> {
  // 0=Overview  1=Territory  2=Operations  3=Profile
  int _selectedIndex = 0;

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 1:
        return const EnvTerritoryScreen();
      case 2:
        return const _EnvOperationsTab();
      case 3:
        return _EnvOpsProfileTab(
          orgContextBuilder: widget.orgContextBuilder,
          memberContextBuilder: widget.memberContextBuilder,
          marketplaceContextBuilder: widget.marketplaceContextBuilder,
          culturalContextBuilder: widget.culturalContextBuilder,
          hasMarketplace: widget.hasMarketplace,
          hasCultural: widget.hasCultural,
        );
      default:
        return const _EnvOpsOverviewTab();
    }
  }

  static const _tabs = [
    _TabInfo('Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _TabInfo('Territory', Icons.map_outlined, Icons.map_rounded),
    _TabInfo('Operations', Icons.settings_outlined, Icons.settings_rounded),
    _TabInfo('Profile', Icons.person_outline, Icons.person_rounded),
  ];

  static const _accentGreen = Color(0xFF2D7A4F);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F6F2),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ENVIRONMENTAL OPS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  fontSize: 13,
                  color: AppTheme.darkGreen,
                ),
              ),
              Text(
                _tabs[_selectedIndex].label,
                style: TextStyle(
                  fontSize: 10,
                  color: _accentGreen.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: _buildCurrentPage(),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 68,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final isActive = _selectedIndex == i;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _accentGreen
                                  : _accentGreen.withOpacity(0.08),
                              shape: BoxShape.circle,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: _accentGreen.withOpacity(0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              isActive ? tab.selectedIcon : tab.icon,
                              size: 18,
                              color: isActive
                                  ? Colors.white
                                  : AppTheme.darkGreen.withOpacity(0.55),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? _accentGreen
                                  : AppTheme.darkGreen.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 0 — OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _EnvOpsOverviewTab extends StatefulWidget {
  const _EnvOpsOverviewTab();

  @override
  State<_EnvOpsOverviewTab> createState() => _EnvOpsOverviewTabState();
}

class _EnvOpsOverviewTabState extends State<_EnvOpsOverviewTab> {
  String? _orgId;
  Map<String, dynamic>? _orgData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final orgId = userDoc.data()?['orgId'] as String?;
      if (orgId == null) return;
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      if (mounted) {
        setState(() {
          _orgId = orgId;
          _orgData = orgDoc.data();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrgHeader(),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildSectionLabel('QUICK ACTIONS'),
          const SizedBox(height: 12),
          _buildActionGrid(),
          const SizedBox(height: 24),
          _buildSectionLabel('RECENT ACTIVITY'),
          const SizedBox(height: 12),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildOrgHeader() {
    if (_loading) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }
    final name = (_orgData?['org_name'] ?? 'Your Organisation') as String;
    final city = (_orgData?['city'] ?? '') as String;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4332), Color(0xFF2D7A4F)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D7A4F).withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (city.isNotEmpty)
                  Text(
                    city,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Env Ops',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _loadStats(),
      builder: (context, snap) {
        final zones = snap.data?['zones'] ?? 0;
        final trees = snap.data?['trees'] ?? 0;
        final pins = snap.data?['pins'] ?? 0;
        return Row(
          children: [
            _StatTile(
                icon: Icons.map_outlined,
                value: '$zones',
                label: 'Zones',
                color: const Color(0xFF2D7A4F)),
            const SizedBox(width: 10),
            _StatTile(
                icon: Icons.park_outlined,
                value: '$trees',
                label: 'Trees',
                color: const Color(0xFF388E3C)),
            const SizedBox(width: 10),
            _StatTile(
                icon: Icons.place_outlined,
                value: '$pins',
                label: 'Map Pins',
                color: const Color(0xFF1565C0)),
          ],
        );
      },
    );
  }

  Future<Map<String, int>> _loadStats() async {
    if (_orgId == null) return {};
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('collection_zones')
            .where('org_id', isEqualTo: _orgId)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('map_pins')
            .where('added_by_org_id', isEqualTo: _orgId)
            .count()
            .get(),
      ]);
      return {
        'zones': results[0].count ?? 0,
        'pins': results[1].count ?? 0,
        'trees': 0, // tree records require separate query
      };
    } catch (_) {
      return {};
    }
  }

  Widget _buildActionGrid() {
    final actions = [
      _ActionItem(
        icon: Icons.edit_location_alt_outlined,
        label: 'Define Zone',
        description: 'Draw a collection zone on the map',
        color: const Color(0xFF2D7A4F),
        onTap: () {
          // Switch to Territory tab (parent will handle)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Open Territory tab to define zones'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      _ActionItem(
        icon: Icons.add_location_alt_outlined,
        label: 'Add Map Pin',
        description: 'Mark a community location on the map',
        color: const Color(0xFF1565C0),
        onTap: () {},
      ),
      _ActionItem(
        icon: Icons.park_outlined,
        label: 'Log Trees',
        description: 'Record trees planted or monitored',
        color: const Color(0xFF388E3C),
        onTap: () {},
      ),
      _ActionItem(
        icon: Icons.storefront_outlined,
        label: 'Post Order',
        description: 'Buy or sell recyclable materials',
        color: const Color(0xFFE65100),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateListingScreen(
              orgId: _orgId,
              orgData: _orgData,
            ),
          ),
        ),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: actions.map((a) => _ActionCard(item: a)).toList(),
    );
  }

  Widget _buildRecentActivity() {
    if (_orgId == null) {
      return _EmptyCard(
        icon: Icons.history_outlined,
        message: 'Activity will appear here once you start operations',
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('collection_zones')
          .where('org_id', isEqualTo: _orgId)
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyCard(
            icon: Icons.history_outlined,
            message: 'No zones defined yet — go to Territory to start',
          );
        }
        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? 'Unnamed Zone';
            final status = data['status'] as String? ?? 'draft';
            final ts = data['created_at'] as dynamic;
            return _ActivityRow(
              icon: Icons.map_outlined,
              title: name,
              subtitle: status.toUpperCase(),
              color: status == 'active'
                  ? const Color(0xFF2D7A4F)
                  : Colors.orange,
              timestamp: ts is Timestamp
                  ? _fmtDate(ts.toDate())
                  : '',
            );
          }).toList(),
        );
      },
    );
  }

  static String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppTheme.darkGreen.withOpacity(0.45),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — OPERATIONS (Market · Trees · Fleet)
// ─────────────────────────────────────────────────────────────────────────────

class _EnvOperationsTab extends StatefulWidget {
  const _EnvOperationsTab();

  @override
  State<_EnvOperationsTab> createState() => _EnvOperationsTabState();
}

class _EnvOperationsTabState extends State<_EnvOperationsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: const Color(0xFF2D7A4F),
            unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.45),
            indicatorColor: const Color(0xFF2D7A4F),
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                icon: Icon(Icons.storefront_outlined, size: 16),
                text: 'Market',
              ),
              Tab(
                icon: Icon(Icons.park_outlined, size: 16),
                text: 'Trees',
              ),
              Tab(
                icon: Icon(Icons.local_shipping_outlined, size: 16),
                text: 'Fleet',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              EnvMarketScreen(),
              EnvTreesScreen(),
              EnvFleetScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────��───────────────────────────────────────────────────
// TAB 3 — PROFILE
// ─────────────────────────────────────────────────────────────────────────────

class _EnvOpsProfileTab extends StatelessWidget {
  final WidgetBuilder? orgContextBuilder;
  final WidgetBuilder? memberContextBuilder;
  final WidgetBuilder? marketplaceContextBuilder;
  final WidgetBuilder? culturalContextBuilder;
  final bool hasMarketplace;
  final bool hasCultural;

  const _EnvOpsProfileTab({
    this.orgContextBuilder,
    this.memberContextBuilder,
    this.marketplaceContextBuilder,
    this.culturalContextBuilder,
    this.hasMarketplace = false,
    this.hasCultural = false,
  });

  void _switchTo(BuildContext context, WidgetBuilder? builder) {
    if (builder == null) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: builder),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B4332), Color(0xFF2D7A4F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D7A4F).withOpacity(0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.eco_outlined,
                      size: 34, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Environmental Ops',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Active context',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkGreen.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (orgContextBuilder != null || memberContextBuilder != null) ...[
            _sectionLabel('SWITCH CONTEXT'),
            const SizedBox(height: 10),
            RoleContextSwitcher(
              activeContext: 'envOps',
              hasMarketplace: hasMarketplace,
              hasEnvOps: true,
              hasCultural: hasCultural,
              onOrgTap: () => _switchTo(context, orgContextBuilder),
              onMemberTap: () => _switchTo(context, memberContextBuilder),
              onMarketplaceTap: marketplaceContextBuilder != null
                  ? () => _switchTo(context, marketplaceContextBuilder)
                  : null,
              onEnvOpsTap: () {},
              onCulturalTap: culturalContextBuilder != null
                  ? () => _switchTo(context, culturalContextBuilder)
                  : null,
            ),
            const SizedBox(height: 28),
          ],

          if (orgContextBuilder != null) ...[
            _sectionLabel('ORGANISATION'),
            const SizedBox(height: 10),
            _buildReturnToOrgCard(context),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppTheme.darkGreen.withOpacity(0.45),
      ),
    );
  }

  Widget _buildReturnToOrgCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _switchTo(context, orgContextBuilder),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.lightGreen.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.business_outlined,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organisation Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'People, operations, programmes & settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppTheme.primary.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TabInfo {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _TabInfo(this.label, this.icon, this.selectedIcon);
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatTile(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkGreen,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, color: AppTheme.darkGreen.withOpacity(0.50)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(
      {required this.icon,
      required this.label,
      required this.description,
      required this.color,
      required this.onTap});
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 20, color: item.color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.darkGreen.withOpacity(0.50),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String timestamp;
  const _ActivityRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
          Text(timestamp,
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.darkGreen.withOpacity(0.40))),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.primary.withOpacity(0.35)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkGreen.withOpacity(0.55),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
