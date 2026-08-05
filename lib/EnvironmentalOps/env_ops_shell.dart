import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../Shared/theme/app_theme.dart';
import '../Shared/widgets/canopy_bottom_bar.dart';
import '../Shared/widgets/role_context_switcher.dart';
import '../Services/Environmental/environment_ops_service.dart';
import 'Fleet/env_fleet.dart';
import 'Mapping/env_mapping_hub.dart';
import 'Mapping/mapped_site_catalog.dart';
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
  int _selectedIndex = 0;
  int _operationsInitialTab = 0;

  static const _tabs = [
    _TabInfo('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
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
        backgroundColor: const Color(0xFFF6F3EC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F3EC),
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
                  letterSpacing: 2.4,
                ),
              ),
              Text(
                _tabs[_selectedIndex].label,
                style: TextStyle(
                  color: AppTheme.primary.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        body: _buildCurrentPage(),
        bottomNavigationBar: CanopyBottomBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() {
            if (index == 2) {
              _operationsInitialTab = 0;
            }
            _selectedIndex = index;
          }),
          destinations: _tabs
              .map(
                (tab) => CanopyNavDestination(
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
  final _service = EnvironmentOpsService.instance;

  EnvironmentOpsContext? _contextData;
  bool _loading = true;
  Future<Map<String, int>>? _statsFuture;
  Future<List<_ActivityEntry>>? _activityFuture;

  Map<String, dynamic>? get _orgDataWithId {
    final contextData = _contextData;
    if (contextData == null) {
      return null;
    }
    return {
      ...contextData.orgData,
      'orgId': contextData.orgId,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final contextData = await _service.resolveContext();
      if (!mounted) {
        return;
      }
      setState(() {
        _contextData = contextData;
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
    await _loadContext();
    await Future.wait([
      if (_statsFuture != null) _statsFuture!,
      if (_activityFuture != null) _activityFuture!,
    ]);
  }

  Future<Map<String, int>> _loadStats() async {
    final contextData = _contextData;
    if (contextData == null) {
      return {
        'zones': 0,
        'trees': 0,
        'pins': 0,
        'handoffs': 0,
      };
    }

    final orgId = contextData.orgId;
    final orgRef = FirebaseFirestore.instance.collection('organizations').doc(orgId);

    var zones = 0;
    var trees = 0;
    var pins = 0;
    var handoffs = 0;

    try {
      final newZoneSnap = await orgRef.collection('collectionZones').count().get();
      final legacyZoneSnap = await FirebaseFirestore.instance
          .collection('collection_zones')
          .where('org_id', isEqualTo: orgId)
          .count()
          .get();
      zones = (newZoneSnap.count ?? 0) > 0
          ? (newZoneSnap.count ?? 0)
          : (legacyZoneSnap.count ?? 0);

      final treeSnap = await orgRef.collection('trees').count().get();
      trees = treeSnap.count ?? 0;
      if (trees == 0) {
        final legacyTreeSnap = await FirebaseFirestore.instance
            .collection('planting_posts')
            .where('created_by', isEqualTo: contextData.uid)
            .get();
        trees = legacyTreeSnap.docs.fold<int>(
          0,
          (sum, doc) => sum + ((doc.data()['quantity'] as num?)?.toInt() ?? 0),
        );
      }

      final pinSnap = await FirebaseFirestore.instance
          .collection('map_pins')
          .where('added_by_org_id', isEqualTo: orgId)
          .count()
          .get();
      pins = pinSnap.count ?? 0;

      final handoffSnap = await orgRef.collection('collectionHandoffs').count().get();
      if ((handoffSnap.count ?? 0) > 0) {
        handoffs = handoffSnap.count ?? 0;
      } else {
        final legacyHandoffSnap = await FirebaseFirestore.instance
            .collection('collection_handoffs')
            .where('org_id', isEqualTo: orgId)
            .count()
            .get();
        handoffs = legacyHandoffSnap.count ?? 0;
      }
    } catch (_) {
      // Keep partial stats if one query fails.
    }

    return {
      'zones': zones,
      'trees': trees,
      'pins': pins,
      'handoffs': handoffs,
    };
  }

  Future<List<_ActivityEntry>> _loadActivity() async {
    final contextData = _contextData;
    if (contextData == null) {
      return const <_ActivityEntry>[];
    }

    final orgId = contextData.orgId;
    final out = <_ActivityEntry>[];
    final orgRef = FirebaseFirestore.instance.collection('organizations').doc(orgId);

    try {
      final zoneSnap = await orgRef.collection('collectionZones').limit(20).get();
      for (final doc in zoneSnap.docs) {
        final data = doc.data();
        final isActive = (data['isActive'] as bool?) ?? false;
        out.add(
          _ActivityEntry(
            kind: _ActivityKind.zone,
            title: data['label'] as String? ?? 'Collection zone',
            subtitle: isActive ? 'Boundary active' : 'Boundary draft',
            timestamp: (data['createdAt'] as Timestamp?)?.toDate(),
            color: isActive ? AppTheme.primary : Colors.orange,
            icon: Icons.polyline_outlined,
          ),
        );
      }

      if (out.where((entry) => entry.kind == _ActivityKind.zone).isEmpty) {
        final legacyZoneSnap = await FirebaseFirestore.instance
            .collection('collection_zones')
            .where('org_id', isEqualTo: orgId)
            .limit(10)
            .get();
        for (final doc in legacyZoneSnap.docs) {
          final data = doc.data();
          out.add(
            _ActivityEntry(
              kind: _ActivityKind.zone,
              title: data['name'] as String? ?? 'Collection zone',
              subtitle: '${(data['status'] as String? ?? 'draft').toUpperCase()} boundary',
              timestamp: (data['created_at'] as Timestamp?)?.toDate(),
              color: AppTheme.primary,
              icon: Icons.polyline_outlined,
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
        final pinType = (data['pin_type'] as String? ?? 'site').replaceAll('_', ' ');
        out.add(
          _ActivityEntry(
            kind: _ActivityKind.mapping,
            title: data['name'] as String? ?? 'Mapped site',
            subtitle: pinType.toUpperCase(),
            timestamp: (data['created_at'] as Timestamp?)?.toDate(),
            color: AppTheme.accent,
            icon: Icons.place_outlined,
          ),
        );
      }

      final treeSnap = await orgRef.collection('trees').limit(20).get();
      for (final doc in treeSnap.docs) {
        final data = doc.data();
        out.add(
          _ActivityEntry(
            kind: _ActivityKind.tree,
            title: data['commonName'] as String? ?? 'Tree record',
            subtitle: '${(data['status'] as String? ?? 'unconfirmed').toUpperCase()} planting',
            timestamp: (data['createdAt'] as Timestamp?)?.toDate(),
            color: const Color(0xFF3A7D44),
            icon: Icons.park_outlined,
          ),
        );
      }
    } catch (_) {
      // Return partial activity if some queries fail.
    }

    out.sort(
      (a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
    return out.take(6).toList();
  }

  void _openListingComposer() {
    final orgData = _orgDataWithId;
    if (orgData == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateListingScreen(
          orgId: _contextData!.orgId,
          orgData: orgData,
        ),
      ),
    );
  }

  void _openMappingHub() {
    final orgData = _orgDataWithId;
    if (orgData == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EnvMappingHubScreen(
          orgData: orgData,
          onOpenCollectionZones: () => widget.onSelectTab?.call(1),
        ),
      ),
    );
  }

  void _onActivityTap(_ActivityEntry entry) {
    switch (entry.kind) {
      case _ActivityKind.zone:
        widget.onSelectTab?.call(1);
        break;
      case _ActivityKind.tree:
        widget.onOpenOperations?.call(1);
        break;
      case _ActivityKind.mapping:
        _openMappingHub();
        break;
    }
  }

  static String _formatDate(DateTime date) {
    final today = DateTime.now();
    final onlyDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    final diff = todayDate.difference(onlyDate);
    if (diff.inDays <= 0) {
      return 'Today';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          _buildHero(),
          const SizedBox(height: 18),
          _buildEditorialBanner(),
          const SizedBox(height: 22),
          _LabeledSection(
            label: 'FIELD SIGNALS',
            note: 'A quick reading of where the operation is active right now.',
          ),
          const SizedBox(height: 12),
          _buildSignalsGrid(),
          const SizedBox(height: 22),
          _LabeledSection(
            label: 'COMMANDS',
            note: 'Launch straight into the workflows that move territory, cleanup, and recovery forward.',
          ),
          const SizedBox(height: 12),
          _buildActionDeck(),
          const SizedBox(height: 22),
          _LabeledSection(
            label: 'MAPPING SURFACES',
            note: 'A cleaner view of what this organisation can place on the map beyond collection boundaries.',
          ),
          const SizedBox(height: 12),
          _buildMappingPreview(),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: _LabeledSection(
                  label: 'ACTIVITY PULSE',
                  note: 'Recent movements across mapping, trees, and territory.',
                ),
              ),
              TextButton(
                onPressed: () => widget.onOpenOperations?.call(3),
                child: const Text('Open verified'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivityFeed(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    if (_loading) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(28),
        ),
      );
    }

    final contextData = _contextData;
    final orgName = contextData?.orgName ?? 'Environmental Operations';
    final area = contextData?.area ?? 'Field network';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF143225),
            Color(0xFF2D7A4F),
            Color(0xFFD6C299),
          ],
          stops: [0.0, 0.62, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D7A4F).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -10,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 6,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orgName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          area,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'An elegant field console for zones, sites, handoffs, greening records, and proof of environmental impact.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _HeroTag(label: 'Territory'),
                  _HeroTag(label: 'Cleanup'),
                  _HeroTag(label: 'Recovery'),
                  _HeroTag(label: 'Verification'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFD9C6A2).withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_outlined, color: AppTheme.darkGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Inspired by current Pinterest-style eco dashboards: softer earth tones, editorial spacing, stronger section hierarchy, and mapping-first quick actions.',
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.68),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalsGrid() {
    return FutureBuilder<Map<String, int>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ??
            const {
              'zones': 0,
              'trees': 0,
              'pins': 0,
              'handoffs': 0,
            };
        final cards = [
          _SignalCardData(
            label: 'Zones',
            value: '${stats['zones'] ?? 0}',
            icon: Icons.polyline_outlined,
            color: AppTheme.primary,
            caption: 'Boundary coverage',
          ),
          _SignalCardData(
            label: 'Mapped Sites',
            value: '${stats['pins'] ?? 0}',
            icon: Icons.place_outlined,
            color: AppTheme.accent,
            caption: 'Pins across operations',
          ),
          _SignalCardData(
            label: 'Trees',
            value: '${stats['trees'] ?? 0}',
            icon: Icons.park_outlined,
            color: const Color(0xFF3A7D44),
            caption: 'Planted or tracked',
          ),
          _SignalCardData(
            label: 'Handoffs',
            value: '${stats['handoffs'] ?? 0}',
            icon: Icons.inventory_2_outlined,
            color: AppTheme.tertiary,
            caption: 'Verified collection flow',
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 480
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map((card) => SizedBox(
                        width: width,
                        child: _SignalCard(data: card),
                      ))
                  .toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildActionDeck() {
    final actions = [
      _ActionCardData(
        title: 'Open Territory',
        caption: 'Trace collection zones and manage polygon coverage.',
        icon: Icons.map_outlined,
        color: AppTheme.primary,
        onTap: () => widget.onSelectTab?.call(1),
      ),
      _ActionCardData(
        title: 'Open Mapping Hub',
        caption: 'Launch dumpsites, collection sites, scrap yards, and more.',
        icon: Icons.travel_explore_outlined,
        color: AppTheme.accent,
        onTap: _openMappingHub,
      ),
      _ActionCardData(
        title: 'Log Trees',
        caption: 'Move into planting, follow-up, and verification trails.',
        icon: Icons.park_outlined,
        color: const Color(0xFF3A7D44),
        onTap: () => widget.onOpenOperations?.call(1),
      ),
      _ActionCardData(
        title: 'Post Recovery Order',
        caption: 'Create a market listing for recyclable material flow.',
        icon: Icons.storefront_outlined,
        color: AppTheme.tertiary,
        onTap: _openListingComposer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
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
              .map((action) => SizedBox(
                    width: width,
                    child: _EditorialActionCard(data: action),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildMappingPreview() {
    final preview = envMappedSiteDefinitions.take(4).toList();
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 920
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: preview
                  .map(
                    (definition) => SizedBox(
                      width: width,
                      child: _MappingPreviewCard(
                        definition: definition,
                        onTap: _openMappingHub,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openMappingHub,
            icon: const Icon(Icons.layers_outlined),
            label: const Text('Explore all mapping types'),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityFeed() {
    if (_loading) {
      return const _EmptyPanel(
        icon: Icons.history_outlined,
        message: 'Loading environmental activity...',
      );
    }

    if (_contextData == null) {
      return const _EmptyPanel(
        icon: Icons.forest_outlined,
        message: 'Connect an organisation to activate the environmental dashboard.',
      );
    }

    return FutureBuilder<List<_ActivityEntry>>(
      future: _activityFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <_ActivityEntry>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _EmptyPanel(
            icon: Icons.history_outlined,
            message: 'Loading environmental activity...',
          );
        }
        if (entries.isEmpty) {
          return const _EmptyPanel(
            icon: Icons.timeline_outlined,
            message: 'No environmental activity yet. Start with territory, trees, or mapping.',
          );
        }

        return Column(
          children: entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityCard(
                    entry: entry,
                    timestamp: entry.timestamp != null
                        ? _formatDate(entry.timestamp!)
                        : '',
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

enum _ActivityKind { zone, mapping, tree }

class _ActivityEntry {
  final _ActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime? timestamp;
  final Color color;
  final IconData icon;

  const _ActivityEntry({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.color,
    required this.icon,
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
    if (oldWidget.initialTab != widget.initialTab &&
        _tabController.index != nextIndex) {
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
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: compact,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.45),
              indicatorColor: AppTheme.primary,
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
                color: Colors.black.withOpacity(0.04),
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
                'Switch context, review your operational surface, or move back to the broader organisation dashboard.',
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
          const _LabeledSection(
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
          const _LabeledSection(
            label: 'ORGANISATION',
            note: 'Return to people, programmes, settings, and the wider dashboard.',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _switchTo(context, orgContextBuilder),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.lightGreen.withOpacity(0.28)),
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
                    child: const Icon(Icons.business_outlined, color: AppTheme.primary),
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
                          'People, operations, programmes, and settings.',
                          style: TextStyle(
                            color: AppTheme.darkGreen.withOpacity(0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.primary.withOpacity(0.62)),
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

class _HeroTag extends StatelessWidget {
  final String label;

  const _HeroTag({
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
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LabeledSection extends StatelessWidget {
  final String label;
  final String? note;

  const _LabeledSection({
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
            color: AppTheme.darkGreen.withOpacity(0.46),
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
              color: AppTheme.darkGreen.withOpacity(0.62),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _SignalCardData {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const _SignalCardData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });
}

class _SignalCard extends StatelessWidget {
  final _SignalCardData data;

  const _SignalCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.caption,
            style: TextStyle(
              color: AppTheme.darkGreen.withOpacity(0.56),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCardData {
  final String title;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCardData({
    required this.title,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _EditorialActionCard extends StatelessWidget {
  final _ActionCardData data;

  const _EditorialActionCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 162),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: data.color.withOpacity(0.08),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(data.icon, color: data.color),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, color: data.color),
              ],
            ),
            const Spacer(),
            Text(
              data.title,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.caption,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.58),
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

class _MappingPreviewCard extends StatelessWidget {
  final EnvMappedSiteDefinition definition;
  final VoidCallback onTap;

  const _MappingPreviewCard({
    required this.definition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: definition.color.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: definition.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(definition.icon, color: definition.color),
            ),
            const SizedBox(height: 12),
            Text(
              definition.title,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              definition.subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.58),
                fontSize: 11,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: entry.color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 420;
            final leading = Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: entry.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(entry.icon, color: entry.color, size: 20),
                ),
                const SizedBox(width: 12),
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
              ],
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
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
                          color: AppTheme.darkGreen.withOpacity(0.25),
                        ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: leading),
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

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyPanel({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary.withOpacity(0.36)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.58),
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
