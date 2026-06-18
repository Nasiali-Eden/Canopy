// lib/EnvironmentalOps/env_ops_shell.dart
//
// 4-tab Environmental Ops shell — similar pattern to CultureHomeScreen.
// Tabs: Overview · Territory · Operations · Profile

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/role_context_switcher.dart';
import '../Shared/widgets/floating_nav_bar.dart';
import 'Market/env_market.dart';
import 'Market/create_listing_screen.dart';
import 'Territory/env_territory.dart';
import 'Trees/env_trees.dart';
import 'Fleet/env_fleet.dart';
import 'Verified/env_verified.dart';
import '../Organization/Map/org_map_ops.dart';

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
  // Sub-tab to open when entering Operations (0=Market 1=Trees 2=Fleet).
  int _operationsInitialTab = 0;

  void _openOperations(int subTab) {
    setState(() {
      _operationsInitialTab = subTab;
      _selectedIndex = 2;
    });
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 1:
        return const EnvTerritoryScreen();
      case 2:
        return _EnvOperationsTab(initialTab: _operationsInitialTab);
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
        return _EnvOpsOverviewTab(
          onSelectTab: (i) => setState(() => _selectedIndex = i),
          onOpenOperations: _openOperations,
        );
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
        extendBody: true,
        body: _buildCurrentPage(),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() {
            // Manual taps on Operations land on the default (Market) sub-tab;
            // deep-links via _openOperations set the target explicitly.
            if (i == 2) _operationsInitialTab = 0;
            _selectedIndex = i;
          }),
          destinations: _tabs
              .map((t) => FloatingNavDestination(
                    icon: t.icon,
                    activeIcon: t.selectedIcon,
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 0 — OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _EnvOpsOverviewTab extends StatefulWidget {
  /// Switches the bottom-nav tab (1 = Territory, 3 = Profile, …).
  final void Function(int index)? onSelectTab;

  /// Opens the Operations tab on a specific sub-tab (0 = Market, 1 = Trees,
  /// 2 = Fleet).
  final void Function(int operationsSubTab)? onOpenOperations;

  const _EnvOpsOverviewTab({this.onSelectTab, this.onOpenOperations});

  @override
  State<_EnvOpsOverviewTab> createState() => _EnvOpsOverviewTabState();
}

class _EnvOpsOverviewTabState extends State<_EnvOpsOverviewTab> {
  String? _orgId;
  String? _uid;
  Map<String, dynamic>? _orgData;
  bool _loading = true;

  // Cached so they are not rebuilt on every setState/scroll.
  Future<Map<String, int>>? _statsFuture;
  Future<List<_ActivityEntry>>? _activityFuture;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _uid = uid;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final orgId = userDoc.data()?['orgId'] as String?;
      Map<String, dynamic>? orgData;
      if (orgId != null) {
        final orgDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .get();
        orgData = orgDoc.data();
      }
      if (!mounted) return;
      setState(() {
        _orgId = orgId;
        _orgData = orgData;
        _loading = false;
        _statsFuture = _loadStats();
        _activityFuture = _loadActivity();
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadOrg();
    await Future.wait([
      if (_statsFuture != null) _statsFuture!,
      if (_activityFuture != null) _activityFuture!,
    ]);
  }

  /// orgData enriched with the org id, so screens that read `orgData['orgId']`
  /// (e.g. OrgMapOpsScreen, which tags new pins with `added_by_org_id`) save
  /// against the correct organisation.
  Map<String, dynamic>? get _orgDataWithId {
    if (_orgData == null) return null;
    return {..._orgData!, 'orgId': _orgId};
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _EnvOpsShellState._accentGreen,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
            Row(
              children: [
                _buildSectionLabel('RECENT ACTIVITY'),
                const Spacer(),
                GestureDetector(
                  onTap: () => widget.onSelectTab?.call(1),
                  child: Text(
                    'View territory',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _EnvOpsShellState._accentGreen.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgHeader() {
    if (_loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
      );
    }
    final name = (_orgData?['org_name'] ?? 'Your Organisation') as String;
    final city = (_orgData?['city'] ?? '') as String;
    return GestureDetector(
      onTap: () => widget.onSelectTab?.call(3), // → Profile / context
      child: Container(
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
              child:
                  const Icon(Icons.eco_outlined, color: Colors.white, size: 26),
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
                  Text(
                    city.isNotEmpty ? city : 'Environmental Operations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.7), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _statsFuture,
      builder: (context, snap) {
        final loading =
            _loading || snap.connectionState == ConnectionState.waiting;
        final zones = snap.data?['zones'] ?? 0;
        final trees = snap.data?['trees'] ?? 0;
        final pins = snap.data?['pins'] ?? 0;
        return Row(
          children: [
            _StatTile(
              icon: Icons.map_outlined,
              value: '$zones',
              label: 'Zones',
              color: const Color(0xFF2D7A4F),
              loading: loading,
              onTap: () => widget.onSelectTab?.call(1), // → Territory
            ),
            const SizedBox(width: 10),
            _StatTile(
              icon: Icons.park_outlined,
              value: '$trees',
              label: 'Trees',
              color: const Color(0xFF388E3C),
              loading: loading,
              onTap: () => widget.onOpenOperations?.call(1), // → Trees
            ),
            const SizedBox(width: 10),
            _StatTile(
              icon: Icons.place_outlined,
              value: '$pins',
              label: 'Map Pins',
              color: const Color(0xFF1565C0),
              loading: loading,
              onTap: _openMapPins,
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, int>> _loadStats() async {
    final orgId = _orgId;
    final uid = _uid;
    int zones = 0;
    int trees = 0;
    int pins = 0;
    try {
      if (orgId != null) {
        final zoneSnap = await FirebaseFirestore.instance
            .collection('collection_zones')
            .where('org_id', isEqualTo: orgId)
            .count()
            .get();
        zones = zoneSnap.count ?? 0;
        final pinSnap = await FirebaseFirestore.instance
            .collection('map_pins')
            .where('added_by_org_id', isEqualTo: orgId)
            .count()
            .get();
        pins = pinSnap.count ?? 0;
      }
      if (uid != null) {
        // Sum tree quantities across this user's planting posts. Index-free
        // (single equality filter, no orderBy).
        final treeSnap = await FirebaseFirestore.instance
            .collection('planting_posts')
            .where('created_by', isEqualTo: uid)
            .get();
        trees = treeSnap.docs.fold<int>(
          0,
          (acc, d) => acc + ((d.data()['quantity'] as num?)?.toInt() ?? 0),
        );
      }
    } catch (_) {
      // Leave whatever counts succeeded.
    }
    return {'zones': zones, 'trees': trees, 'pins': pins};
  }

  void _openMapPins() {
    final data = _orgDataWithId;
    if (data == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrgMapOpsScreen(orgData: data)),
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      _ActionItem(
        icon: Icons.edit_location_alt_outlined,
        label: 'Define Zone',
        description: 'Walk & trace a collection zone',
        color: const Color(0xFF2D7A4F),
        onTap: () => widget.onSelectTab?.call(1), // → Territory tab
      ),
      _ActionItem(
        icon: Icons.add_location_alt_outlined,
        label: 'Add Map Pin',
        description: 'Mark a community location on the map',
        color: const Color(0xFF1565C0),
        onTap: _openMapPins,
      ),
      _ActionItem(
        icon: Icons.park_outlined,
        label: 'Log Trees',
        description: 'Record trees planted or monitored',
        color: const Color(0xFF388E3C),
        // → Operations · Trees (its screen has no AppBar, so it must live
        // inside the shell rather than be pushed as a dead-end route).
        onTap: () => widget.onOpenOperations?.call(1),
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
    if (_loading) {
      return _EmptyCard(
        icon: Icons.history_outlined,
        message: 'Loading recent activity…',
      );
    }
    if (_orgId == null) {
      return _EmptyCard(
        icon: Icons.history_outlined,
        message: 'Activity will appear here once you start operations',
      );
    }
    return FutureBuilder<List<_ActivityEntry>>(
      future: _activityFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _EmptyCard(
            icon: Icons.history_outlined,
            message: 'Loading recent activity…',
          );
        }
        final entries = snap.data ?? const <_ActivityEntry>[];
        if (entries.isEmpty) {
          return _EmptyCard(
            icon: Icons.history_outlined,
            message: 'No activity yet — define a zone, log trees, '
                'or add a map pin to get started',
          );
        }
        return Column(
          children: entries
              .map((e) => _ActivityRow(
                    icon: e.icon,
                    title: e.title,
                    subtitle: e.subtitle,
                    color: e.color,
                    timestamp:
                        e.timestamp != null ? _fmtDate(e.timestamp!) : '',
                    onTap: () => _onActivityTap(e),
                  ))
              .toList(),
        );
      },
    );
  }

  void _onActivityTap(_ActivityEntry e) {
    switch (e.kind) {
      case _ActivityKind.zone:
        widget.onSelectTab?.call(1); // → Territory
        break;
      case _ActivityKind.planting:
        widget.onOpenOperations?.call(1); // → Operations · Trees
        break;
      case _ActivityKind.pin:
        _openMapPins();
        break;
    }
  }

  /// Builds a unified, index-free recent-activity feed from zones, plantings
  /// and map pins, sorted client-side by timestamp.
  Future<List<_ActivityEntry>> _loadActivity() async {
    final orgId = _orgId;
    final uid = _uid;
    final out = <_ActivityEntry>[];
    try {
      if (orgId != null) {
        final zoneSnap = await FirebaseFirestore.instance
            .collection('collection_zones')
            .where('org_id', isEqualTo: orgId)
            .limit(20)
            .get();
        for (final d in zoneSnap.docs) {
          final m = d.data();
          final status = (m['status'] as String? ?? 'draft');
          out.add(_ActivityEntry(
            kind: _ActivityKind.zone,
            icon: Icons.map_outlined,
            title: m['name'] as String? ?? 'Unnamed Zone',
            subtitle: status.toUpperCase(),
            color: status == 'active'
                ? const Color(0xFF2D7A4F)
                : Colors.orange,
            timestamp: (m['created_at'] as Timestamp?)?.toDate(),
          ));
        }

        final pinSnap = await FirebaseFirestore.instance
            .collection('map_pins')
            .where('added_by_org_id', isEqualTo: orgId)
            .limit(20)
            .get();
        for (final d in pinSnap.docs) {
          final m = d.data();
          out.add(_ActivityEntry(
            kind: _ActivityKind.pin,
            icon: Icons.place_outlined,
            title: m['name'] as String? ?? 'Map Pin',
            subtitle: 'MAP PIN',
            color: const Color(0xFF1565C0),
            timestamp: (m['created_at'] as Timestamp?)?.toDate(),
          ));
        }
      }

      if (uid != null) {
        final treeSnap = await FirebaseFirestore.instance
            .collection('planting_posts')
            .where('created_by', isEqualTo: uid)
            .limit(20)
            .get();
        for (final d in treeSnap.docs) {
          final m = d.data();
          final qty = (m['quantity'] as num?)?.toInt() ?? 0;
          final stage = (m['stage'] as String? ?? 'pending');
          out.add(_ActivityEntry(
            kind: _ActivityKind.planting,
            icon: Icons.park_outlined,
            title: m['species'] as String? ?? 'Planting',
            subtitle: '$qty TREES · ${stage.toUpperCase()}',
            color: const Color(0xFF388E3C),
            timestamp: (m['created_at'] as Timestamp?)?.toDate() ??
                (m['planted_date'] as Timestamp?)?.toDate(),
          ));
        }
      }
    } catch (_) {
      // Return whatever loaded.
    }
    out.sort((a, b) => (b.timestamp ?? DateTime(0))
        .compareTo(a.timestamp ?? DateTime(0)));
    return out.take(6).toList();
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

// ─── Recent-activity entry ────────────────────────────────────────────────────
enum _ActivityKind { zone, planting, pin }

class _ActivityEntry {
  final _ActivityKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final DateTime? timestamp;

  const _ActivityEntry({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.timestamp,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — OPERATIONS (Market · Trees · Fleet)
// ─────────────────────────────────────────────────────────────────────────────

class _EnvOperationsTab extends StatefulWidget {
  final int initialTab;
  const _EnvOperationsTab({this.initialTab = 0});

  @override
  State<_EnvOperationsTab> createState() => _EnvOperationsTabState();
}

class _EnvOperationsTabState extends State<_EnvOperationsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
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
              Tab(
                icon: Icon(Icons.verified_outlined, size: 16),
                text: 'Verified',
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
              EnvVerifiedScreen(),
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
  final bool loading;
  final VoidCallback? onTap;
  const _StatTile(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color,
      this.loading = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right,
                        size: 16, color: AppTheme.darkGreen.withOpacity(0.25)),
                ],
              ),
              const SizedBox(height: 8),
              loading
                  ? Container(
                      width: 28,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : Text(
                      value,
                      style: const TextStyle(
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
  final VoidCallback? onTap;
  const _ActivityRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.timestamp,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 8),
            Text(timestamp,
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.darkGreen.withOpacity(0.40))),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 16, color: AppTheme.darkGreen.withOpacity(0.25)),
            ],
          ],
        ),
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
