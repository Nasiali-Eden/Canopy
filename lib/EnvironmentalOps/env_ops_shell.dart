import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Organization/Map/org_map_ops.dart';
import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/floating_nav_bar.dart';
import '../Shared/widgets/role_context_switcher.dart';
import 'Fleet/env_fleet.dart';
import 'Market/create_listing_screen.dart';
import 'Market/env_market.dart';
import 'Territory/env_territory.dart';
import 'Trees/env_trees.dart';
import 'Verified/env_verified.dart';

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
  static const _accentGreen = Color(0xFF2D7A4F);

  int _selectedIndex = 0;
  int _operationsInitialTab = 0;

  static const _tabs = [
    _TabInfo('Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _TabInfo('Territory', Icons.map_outlined, Icons.map_rounded),
    _TabInfo('Operations', Icons.tune_outlined, Icons.tune_rounded),
    _TabInfo('Profile', Icons.person_outline, Icons.person_rounded),
  ];

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
          onSelectTab: (index) => setState(() => _selectedIndex = index),
          onOpenOperations: _openOperations,
        );
    }
  }

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
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ENVIRONMENTAL OPS',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.3,
                ),
              ),
              Text(
                _tabs[_selectedIndex].label,
                style: TextStyle(
                  color: _accentGreen.withOpacity(0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        extendBody: true,
        body: _buildCurrentPage(),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() {
            if (index == 2) {
              _operationsInitialTab = 0;
            }
            _selectedIndex = index;
          }),
          destinations: _tabs
              .map(
                (tab) => FloatingNavDestination(
                  icon: tab.icon,
                  activeIcon: tab.selectedIcon,
                  label: tab.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _EnvOpsOverviewTab extends StatefulWidget {
  final void Function(int index)? onSelectTab;
  final void Function(int operationsSubTab)? onOpenOperations;

  const _EnvOpsOverviewTab({
    this.onSelectTab,
    this.onOpenOperations,
  });

  @override
  State<_EnvOpsOverviewTab> createState() => _EnvOpsOverviewTabState();
}

class _EnvOpsOverviewTabState extends State<_EnvOpsOverviewTab> {
  String? _orgId;
  String? _uid;
  Map<String, dynamic>? _orgData;
  bool _loading = true;
  Future<Map<String, int>>? _statsFuture;
  Future<List<_ActivityEntry>>? _activityFuture;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Map<String, dynamic>? get _orgDataWithId {
    if (_orgData == null) {
      return null;
    }
    return {..._orgData!, 'orgId': _orgId};
  }

  Future<void> _loadOrg() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _uid = uid;
      if (uid == null) {
        if (!mounted) {
          return;
        }
        setState(() => _loading = false);
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      final orgId = userDoc.data()?['orgId'] as String?;
      Map<String, dynamic>? orgData;
      if (orgId != null) {
        final orgDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .get();
        orgData = orgDoc.data();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _orgId = orgId;
        _orgData = orgData;
        _loading = false;
        _statsFuture = _loadStats();
        _activityFuture = _loadActivity();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadOrg();
    await Future.wait([
      if (_statsFuture != null) _statsFuture!,
      if (_activityFuture != null) _activityFuture!,
    ]);
  }

  Future<Map<String, int>> _loadStats() async {
    final orgId = _orgId;
    final uid = _uid;
    var zones = 0;
    var trees = 0;
    var pins = 0;

    try {
      if (orgId != null) {
        final orgRef =
            FirebaseFirestore.instance.collection('organizations').doc(orgId);

        final newZoneSnap = await orgRef.collection('collectionZones').count().get();
        final legacyZoneSnap = await FirebaseFirestore.instance
            .collection('collection_zones')
            .where('org_id', isEqualTo: orgId)
            .count()
            .get();
        zones = (newZoneSnap.count ?? 0) > 0
            ? (newZoneSnap.count ?? 0)
            : (legacyZoneSnap.count ?? 0);

        final pinSnap = await FirebaseFirestore.instance
            .collection('map_pins')
            .where('added_by_org_id', isEqualTo: orgId)
            .count()
            .get();
        pins = pinSnap.count ?? 0;

        final newTreeSnap = await orgRef.collection('trees').count().get();
        trees = newTreeSnap.count ?? 0;
      }

      if (trees == 0 && uid != null) {
        final legacyTreeSnap = await FirebaseFirestore.instance
            .collection('planting_posts')
            .where('created_by', isEqualTo: uid)
            .get();
        trees = legacyTreeSnap.docs.fold<int>(
          0,
          (sum, doc) => sum + ((doc.data()['quantity'] as num?)?.toInt() ?? 0),
        );
      }
    } catch (_) {
      // Keep partial counts when some queries succeed.
    }

    return {
      'zones': zones,
      'trees': trees,
      'pins': pins,
    };
  }

  Future<List<_ActivityEntry>> _loadActivity() async {
    final orgId = _orgId;
    final uid = _uid;
    final out = <_ActivityEntry>[];

    try {
      if (orgId != null) {
        final orgRef =
            FirebaseFirestore.instance.collection('organizations').doc(orgId);

        final newZoneSnap = await orgRef.collection('collectionZones').limit(20).get();
        if (newZoneSnap.docs.isNotEmpty) {
          for (final doc in newZoneSnap.docs) {
            final data = doc.data();
            final isActive = (data['isActive'] as bool?) ?? false;
            out.add(
              _ActivityEntry(
                kind: _ActivityKind.zone,
                icon: Icons.map_outlined,
                title: data['label'] as String? ?? 'Unnamed Zone',
                subtitle: isActive ? 'ACTIVE' : 'INACTIVE',
                color: isActive ? const Color(0xFF2D7A4F) : Colors.orange,
                timestamp: (data['createdAt'] as Timestamp?)?.toDate(),
              ),
            );
          }
        } else {
          final legacyZoneSnap = await FirebaseFirestore.instance
              .collection('collection_zones')
              .where('org_id', isEqualTo: orgId)
              .limit(20)
              .get();
          for (final doc in legacyZoneSnap.docs) {
            final data = doc.data();
            final status = (data['status'] as String? ?? 'draft').toUpperCase();
            out.add(
              _ActivityEntry(
                kind: _ActivityKind.zone,
                icon: Icons.map_outlined,
                title: data['name'] as String? ?? 'Unnamed Zone',
                subtitle: status,
                color: status == 'ACTIVE'
                    ? const Color(0xFF2D7A4F)
                    : Colors.orange,
                timestamp: (data['created_at'] as Timestamp?)?.toDate(),
              ),
            );
          }
        }

        final pinSnap = await FirebaseFirestore.instance
            .collection('map_pins')
            .where('added_by_org_id', isEqualTo: orgId)
            .limit(20)
            .get();
        for (final doc in pinSnap.docs) {
          final data = doc.data();
          out.add(
            _ActivityEntry(
              kind: _ActivityKind.pin,
              icon: Icons.place_outlined,
              title: data['name'] as String? ?? 'Map Pin',
              subtitle: 'MAP PIN',
              color: const Color(0xFF1565C0),
              timestamp: (data['created_at'] as Timestamp?)?.toDate(),
            ),
          );
        }

        final newTreeSnap = await orgRef.collection('trees').limit(20).get();
        if (newTreeSnap.docs.isNotEmpty) {
          for (final doc in newTreeSnap.docs) {
            final data = doc.data();
            final planting =
                (data['planting'] as Map<String, dynamic>?) ?? const {};
            final plantedAt = (planting['plantedAt'] as Timestamp?)?.toDate();
            out.add(
              _ActivityEntry(
                kind: _ActivityKind.planting,
                icon: Icons.park_outlined,
                title: data['commonName'] as String? ?? 'Tree Record',
                subtitle:
                    'TREE RECORDED - ${((data['status'] as String?) ?? 'unconfirmed').toUpperCase()}',
                color: const Color(0xFF388E3C),
                timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? plantedAt,
              ),
            );
          }
        } else if (uid != null) {
          final legacyTreeSnap = await FirebaseFirestore.instance
              .collection('planting_posts')
              .where('created_by', isEqualTo: uid)
              .limit(20)
              .get();
          for (final doc in legacyTreeSnap.docs) {
            final data = doc.data();
            final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
            final stage = (data['stage'] as String? ?? 'pending').toUpperCase();
            out.add(
              _ActivityEntry(
                kind: _ActivityKind.planting,
                icon: Icons.park_outlined,
                title: data['species'] as String? ?? 'Planting',
                subtitle: '$quantity TREES - $stage',
                color: const Color(0xFF388E3C),
                timestamp: (data['created_at'] as Timestamp?)?.toDate() ??
                    (data['planted_date'] as Timestamp?)?.toDate(),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Return whatever was already collected.
    }

    out.sort(
      (a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
    return out.take(6).toList();
  }

  void _openMapPins() {
    final orgData = _orgDataWithId;
    if (orgData == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrgMapOpsScreen(orgData: orgData),
      ),
    );
  }

  void _openListingComposer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateListingScreen(
          orgId: _orgId,
          orgData: _orgData,
        ),
      ),
    );
  }

  void _onActivityTap(_ActivityEntry entry) {
    switch (entry.kind) {
      case _ActivityKind.zone:
        widget.onSelectTab?.call(1);
        break;
      case _ActivityKind.planting:
        widget.onOpenOperations?.call(1);
        break;
      case _ActivityKind.pin:
        _openMapPins();
        break;
    }
  }

  static String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays <= 0) {
      return 'Today';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _EnvOpsShellState._accentGreen,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
        children: [
          _buildOrgHeader(),
          const SizedBox(height: 20),
          _SectionLabel(
            label: 'LIVE SNAPSHOT',
            note: 'A quick read of coverage, planting, and mapped field presence.',
          ),
          const SizedBox(height: 12),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _SectionLabel(
            label: 'QUICK ACTIONS',
            note: 'Shortcuts into the daily work that feeds verification later.',
          ),
          const SizedBox(height: 12),
          _buildActionGrid(),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: _SectionLabel(
                  label: 'RECENT ACTIVITY',
                  note: 'Latest zone, planting, and map activity tied to this org.',
                ),
              ),
              TextButton(
                onPressed: () => widget.onOpenOperations?.call(3),
                child: const Text('Open verified'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildOrgHeader() {
    if (_loading) {
      return Container(
        height: 196,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
      );
    }

    final name = (_orgData?['org_name'] ?? 'Your Organisation') as String;
    final city = (_orgData?['city'] ?? _orgData?['area'] ?? '') as String;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF173728),
            Color(0xFF2D7A4F),
            Color(0xFF87B68C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D7A4F).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 460;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          city.isNotEmpty ? city : 'Environmental operations hub',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.76),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Coordinate collection zones, tree work, dumpsite interventions, and evidence logging from one operational surface.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _HeroPill(icon: Icons.route_outlined, label: 'Territory ready'),
                  _HeroPill(icon: Icons.recycling_outlined, label: 'Collections tracked'),
                  _HeroPill(icon: Icons.verified_outlined, label: 'Evidence pipeline'),
                ],
              ),
              const SizedBox(height: 18),
              stacked
                  ? Column(
                      children: [
                        _HeaderActionButton(
                          label: 'Open Territory',
                          icon: Icons.map_outlined,
                          filled: true,
                          onTap: () => widget.onSelectTab?.call(1),
                        ),
                        const SizedBox(height: 10),
                        _HeaderActionButton(
                          label: 'Log Verification',
                          icon: Icons.verified_outlined,
                          onTap: () => widget.onOpenOperations?.call(3),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _HeaderActionButton(
                            label: 'Open Territory',
                            icon: Icons.map_outlined,
                            filled: true,
                            onTap: () => widget.onSelectTab?.call(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeaderActionButton(
                            label: 'Log Verification',
                            icon: Icons.verified_outlined,
                            onTap: () => widget.onOpenOperations?.call(3),
                          ),
                        ),
                      ],
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final loading =
            _loading || snapshot.connectionState == ConnectionState.waiting;
        final tiles = [
          _StatTile(
            icon: Icons.map_outlined,
            value: '${snapshot.data?['zones'] ?? 0}',
            label: 'Zones',
            color: const Color(0xFF2D7A4F),
            loading: loading,
            onTap: () => widget.onSelectTab?.call(1),
          ),
          _StatTile(
            icon: Icons.park_outlined,
            value: '${snapshot.data?['trees'] ?? 0}',
            label: 'Trees',
            color: const Color(0xFF388E3C),
            loading: loading,
            onTap: () => widget.onOpenOperations?.call(1),
          ),
          _StatTile(
            icon: Icons.place_outlined,
            value: '${snapshot.data?['pins'] ?? 0}',
            label: 'Map Pins',
            color: const Color(0xFF1565C0),
            loading: loading,
            onTap: _openMapPins,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 430 ? 3 : 1;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tiles
                  .map((tile) => SizedBox(width: width, child: tile))
                  .toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      _ActionItem(
        icon: Icons.edit_location_alt_outlined,
        label: 'Define Zone',
        description: 'Trace territory and register a collection boundary.',
        color: const Color(0xFF2D7A4F),
        onTap: () => widget.onSelectTab?.call(1),
      ),
      _ActionItem(
        icon: Icons.add_location_alt_outlined,
        label: 'Add Map Pin',
        description: 'Tag collection points, dumpsites, or partner sites.',
        color: const Color(0xFF1565C0),
        onTap: _openMapPins,
      ),
      _ActionItem(
        icon: Icons.park_outlined,
        label: 'Log Trees',
        description: 'Capture planting activity and follow-up records.',
        color: const Color(0xFF388E3C),
        onTap: () => widget.onOpenOperations?.call(1),
      ),
      _ActionItem(
        icon: Icons.storefront_outlined,
        label: 'Post Order',
        description: 'Create a buy or sell order for recyclable materials.',
        color: const Color(0xFFE65100),
        onTap: _openListingComposer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 940
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - (12 * (columns - 1))) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map((item) => SizedBox(width: width, child: _ActionCard(item: item)))
              .toList(),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    if (_loading) {
      return const _EmptyCard(
        icon: Icons.history_outlined,
        message: 'Loading recent activity...',
      );
    }

    if (_orgId == null) {
      return const _EmptyCard(
        icon: Icons.history_outlined,
        message: 'Activity will appear here once your organisation starts logging work.',
      );
    }

    return FutureBuilder<List<_ActivityEntry>>(
      future: _activityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _EmptyCard(
            icon: Icons.history_outlined,
            message: 'Loading recent activity...',
          );
        }

        final entries = snapshot.data ?? const <_ActivityEntry>[];
        if (entries.isEmpty) {
          return const _EmptyCard(
            icon: Icons.history_outlined,
            message: 'No activity yet. Define a zone, log trees, or add a map pin to begin.',
          );
        }

        return Column(
          children: entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityCard(
                    entry: entry,
                    timestamp: entry.timestamp != null ? _fmtDate(entry.timestamp!) : '',
                    onTap: () => _onActivityTap(entry),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

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

class _EnvOperationsTab extends StatefulWidget {
  final int initialTab;

  const _EnvOperationsTab({
    this.initialTab = 0,
  });

  @override
  State<_EnvOperationsTab> createState() => _EnvOperationsTabState();
}

class _EnvOperationsTabState extends State<_EnvOperationsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void didUpdateWidget(covariant _EnvOperationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.initialTab.clamp(0, 3);
    if (oldWidget.initialTab != widget.initialTab && _tabController.index != nextIndex) {
      _tabController.animateTo(nextIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: compact,
              labelColor: const Color(0xFF2D7A4F),
              unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.45),
              indicatorColor: const Color(0xFF2D7A4F),
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(icon: Icon(Icons.storefront_outlined, size: 16), text: 'Market'),
                Tab(icon: Icon(Icons.park_outlined, size: 16), text: 'Trees'),
                Tab(icon: Icon(Icons.local_shipping_outlined, size: 16), text: 'Fleet'),
                Tab(icon: Icon(Icons.verified_outlined, size: 16), text: 'Verified'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
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
    if (builder == null) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: builder),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF173728), Color(0xFF2D7A4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Environmental Ops',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Switch context, review the current workspace, or jump back to your organisation dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.56),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (orgContextBuilder != null || memberContextBuilder != null) ...[
          const _SectionLabel(
            label: 'SWITCH CONTEXT',
            note: 'Move between organisation, member, marketplace, and environmental surfaces.',
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
        ],
        if (orgContextBuilder != null) ...[
          const _SectionLabel(
            label: 'ORGANISATION',
            note: 'Return to the broader dashboard for people, programs, and settings.',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _switchTo(context, orgContextBuilder),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.lightGreen.withOpacity(0.32)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organisation Dashboard',
                          style: TextStyle(
                            color: AppTheme.darkGreen,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'People, operations, programmes, and organisational settings.',
                          style: TextStyle(
                            color: AppTheme.darkGreen.withOpacity(0.55),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.primary.withOpacity(0.62),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _TabInfo(this.label, this.icon, this.selectedIcon);
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return filled
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.darkGreen,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.45)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? note;

  const _SectionLabel({
    required this.label,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.45),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.58),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.darkGreen.withOpacity(0.24),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            loading
                ? Container(
                    width: 42,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.52),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
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

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;

  const _ActionCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 148),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 21),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppTheme.darkGreen.withOpacity(0.25),
                ),
              ],
            ),
            const Spacer(),
            Text(
              item.label,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.56),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _ActivityEntry entry;
  final String timestamp;
  final VoidCallback? onTap;

  const _ActivityCard({
    required this.entry,
    required this.timestamp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: entry.color.withOpacity(0.1)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 420;
            final content = [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: entry.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(entry.icon, color: entry.color, size: 20),
              ),
              const SizedBox(width: 12, height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: TextStyle(
                        color: entry.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ];

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: content),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: AppTheme.darkGreen.withOpacity(0.42),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppTheme.darkGreen.withOpacity(0.25),
                        ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                ...content,
                const SizedBox(width: 12),
                Text(
                  timestamp,
                  style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.42),
                    fontSize: 11,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.darkGreen.withOpacity(0.25),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.primary.withOpacity(0.35)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.55),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
