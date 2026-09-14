import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../Shared/theme/app_theme.dart';
import '../Shared/theme/canopy_ui.dart';
import '../Shared/widgets/canopy_bottom_bar.dart';
import '../Shared/widgets/profile/canopy_profile_widgets.dart';
import '../Shared/widgets/role_context_switcher.dart';
import '../Services/Environmental/environment_ops_service.dart';
import 'Fleet/env_fleet.dart';
import 'Mapping/env_mapping_hub.dart';
import 'Market/create_listing_screen.dart';
import 'Market/env_market.dart';
import 'Profile/operational_footprint_map.dart';
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
  int _footprintRevision = 0;

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
        _footprintRevision++;
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
    final orgRef =
        FirebaseFirestore.instance.collection('organizations').doc(orgId);

    var zones = 0;
    var trees = 0;
    var pins = 0;
    var handoffs = 0;

    try {
      final newZoneSnap =
          await orgRef.collection('collectionZones').count().get();
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
          (total, doc) =>
              total + ((doc.data()['quantity'] as num?)?.toInt() ?? 0),
        );
      }

      final pinSnap = await FirebaseFirestore.instance
          .collection('map_pins')
          .where('added_by_org_id', isEqualTo: orgId)
          .count()
          .get();
      pins = pinSnap.count ?? 0;

      final handoffSnap =
          await orgRef.collection('collectionHandoffs').count().get();
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
    final orgRef =
        FirebaseFirestore.instance.collection('organizations').doc(orgId);

    try {
      final zoneSnap =
          await orgRef.collection('collectionZones').limit(20).get();
      for (final doc in zoneSnap.docs) {
        final data = doc.data();
        final isActive = (data['isActive'] as bool?) ?? false;
        final area = _placeName(data['area'], contextData.area);
        out.add(
          _ActivityEntry(
            kind: _ActivityKind.zone,
            title: data['label'] as String? ?? 'Collection zone',
            subtitle: '$area - ${isActive ? 'ACTIVE' : 'DRAFT'} boundary',
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
          final area = _placeName(data['area'], contextData.area);
          out.add(
            _ActivityEntry(
              kind: _ActivityKind.zone,
              title: data['name'] as String? ?? 'Collection zone',
              subtitle:
                  '$area - ${(data['status'] as String? ?? 'draft').toUpperCase()} boundary',
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
        final pinType =
            (data['pin_type'] as String? ?? 'site').replaceAll('_', ' ');
        final area = _placeName(data['area'], contextData.area);
        out.add(
          _ActivityEntry(
            kind: _ActivityKind.mapping,
            title: data['name'] as String? ?? 'Mapped site',
            subtitle: '$area - ${pinType.toUpperCase()}',
            timestamp: (data['created_at'] as Timestamp?)?.toDate(),
            color: AppTheme.accent,
            icon: Icons.place_outlined,
          ),
        );
      }

      final treeSnap = await orgRef.collection('trees').limit(20).get();
      for (final doc in treeSnap.docs) {
        final data = doc.data();
        final planting = data['planting'] is Map
            ? Map<String, dynamic>.from(data['planting'] as Map)
            : const <String, dynamic>{};
        final location = planting['location'] is Map
            ? Map<String, dynamic>.from(planting['location'] as Map)
            : const <String, dynamic>{};
        final area = _placeName(location['area'], contextData.area);
        final commonName = '${data['commonName'] ?? ''}'.trim();
        final species = '${data['species'] ?? ''}'.trim();
        out.add(
          _ActivityEntry(
            kind: _ActivityKind.tree,
            title: commonName.isNotEmpty
                ? commonName
                : (species.isNotEmpty ? species : 'Tree record'),
            subtitle:
                '$area - ${(data['status'] as String? ?? 'unconfirmed').toUpperCase()} planting',
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
      (a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
    return out.take(6).toList();
  }

  String _placeName(dynamic storedArea, String fallbackArea) {
    final stored = '${storedArea ?? ''}'.trim();
    if (stored.isNotEmpty) return stored;
    final fallback = fallbackArea.trim();
    return fallback.isEmpty ? 'Operating area not added' : fallback;
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
          if (_contextData != null) ...[
            const _LabeledSection(
              label: 'LIVE FIELD MAP',
              note: 'Territory, dumpsites, and planting evidence in one view.',
            ),
            const SizedBox(height: 12),
            OperationalFootprintMap(
              key: ValueKey(
                '${_contextData!.orgId}:$_footprintRevision',
              ),
              orgId: _contextData!.orgId,
              operatingArea: _contextData!.area,
            ),
            const SizedBox(height: 22),
          ],
          const _LabeledSection(
            label: 'LIVE SIGNALS',
            note: 'Tap a signal to open the field work behind it.',
          ),
          const SizedBox(height: 12),
          _buildSignalsGrid(),
          const SizedBox(height: 22),
          const _LabeledSection(
            label: 'QUICK ACTIONS',
            note: 'Add fresh evidence from the field.',
          ),
          const SizedBox(height: 12),
          _buildActionDeck(),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: _LabeledSection(
                  label: 'FIELD NOTES',
                  note: 'Recent work, with the place it happened.',
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
    final area = contextData?.area.trim().isNotEmpty == true
        ? contextData!.area.trim()
        : 'Area not added';

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
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Your field activity, mapped as it happens.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Operating in $area',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroTag(
                    label: 'Trace territory',
                    icon: Icons.polyline_outlined,
                    onTap: () => widget.onSelectTab?.call(1),
                  ),
                  _HeroTag(
                    label: 'Record trees',
                    icon: Icons.park_outlined,
                    onTap: () => widget.onOpenOperations?.call(1),
                  ),
                  _HeroTag(
                    label: 'Map a site',
                    icon: Icons.add_location_alt_outlined,
                    onTap: _openMappingHub,
                  ),
                ],
              ),
            ],
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
            label: 'Territory',
            value: '${stats['zones'] ?? 0}',
            icon: Icons.polyline_outlined,
            color: AppTheme.primary,
            caption: 'Saved zones',
            onTap: () => widget.onSelectTab?.call(1),
          ),
          _SignalCardData(
            label: 'Mapped Sites',
            value: '${stats['pins'] ?? 0}',
            icon: Icons.place_outlined,
            color: AppTheme.accent,
            caption: 'Recorded pins',
            onTap: _openMappingHub,
          ),
          _SignalCardData(
            label: 'Trees',
            value: '${stats['trees'] ?? 0}',
            icon: Icons.park_outlined,
            color: const Color(0xFF3A7D44),
            caption: 'Trees tracked',
            onTap: () => widget.onOpenOperations?.call(1),
          ),
          _SignalCardData(
            label: 'Handoffs',
            value: '${stats['handoffs'] ?? 0}',
            icon: Icons.inventory_2_outlined,
            color: AppTheme.tertiary,
            caption: 'Collection flow',
            onTap: () => widget.onOpenOperations?.call(2),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
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
        title: 'Trace territory',
        caption: 'Walk and save a collection boundary.',
        icon: Icons.map_outlined,
        color: AppTheme.primary,
        onTap: () => widget.onSelectTab?.call(1),
      ),
      _ActionCardData(
        title: 'Map a dumpsite',
        caption: 'Place a field site on the shared map.',
        icon: Icons.travel_explore_outlined,
        color: AppTheme.accent,
        onTap: _openMappingHub,
      ),
      _ActionCardData(
        title: 'Record trees',
        caption: 'Add planting evidence and follow-ups.',
        icon: Icons.park_outlined,
        color: const Color(0xFF3A7D44),
        onTap: () => widget.onOpenOperations?.call(1),
      ),
      _ActionCardData(
        title: 'Post recovery',
        caption: 'List recyclable material for collection.',
        icon: Icons.storefront_outlined,
        color: AppTheme.tertiary,
        onTap: _openListingComposer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920 ? 4 : 2;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;
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
        message:
            'Connect an organisation to activate the environmental dashboard.',
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
            message:
                'No environmental activity yet. Start with territory, trees, or mapping.',
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
                Tab(
                    icon: Icon(Icons.storefront_outlined, size: 16),
                    text: 'Market'),
                Tab(icon: Icon(Icons.park_outlined, size: 16), text: 'Trees'),
                Tab(
                    icon: Icon(Icons.local_shipping_outlined, size: 16),
                    text: 'Fleet'),
                Tab(
                    icon: Icon(Icons.verified_outlined, size: 16),
                    text: 'Verified'),
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
        FutureBuilder<EnvironmentOpsContext?>(
          future: EnvironmentOpsService.instance.resolveContext(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final ops = snapshot.data;
            if (ops == null) {
              return const CanopyProfileEmptyState(
                icon: Icons.link_off_outlined,
                title: 'Environmental profile is not linked',
                message:
                    'Link an organisation to add service area, material capability, verification, and operational records.',
              );
            }
            final data = ops.orgData;
            final rawMaterials = data['specialisations'] ??
                data['materials'] ??
                data['material_types'];
            final materials = rawMaterials is List
                ? rawMaterials.map((item) => '$item').toList()
                : const <String>[];
            final verification =
                '${data['verification_status'] ?? data['verificationStatus'] ?? 'Not submitted'}';
            final capacity = data['processing_capacity_kg'] ??
                data['capacity_kg'] ??
                data['monthly_capacity_kg'];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CanopyProfileSection(
                  title: 'Operational identity',
                  description:
                      'The organisation and service area attached to this environmental workspace.',
                  child: CanopyIdentityLedger(
                    name: ops.orgName,
                    role:
                        '${data['org_type'] ?? data['organization_type'] ?? 'Environmental operator'}',
                    location: ops.area,
                    initials: ops.orgName
                        .trim()
                        .split(RegExp(r'\s+'))
                        .take(2)
                        .map((word) => word.isEmpty ? '' : word[0])
                        .join(),
                    status: verification,
                    accent: CanopyUi.teal,
                  ),
                ),
                const SizedBox(height: 24),
                CanopyProfileSection(
                  title: 'Readiness',
                  description:
                      'Coverage and capability details used to assess collection and processing fit.',
                  child: CanopyProfileMetricGrid(
                    metrics: [
                      CanopyProfileMetric(
                        label: 'Service area',
                        value: ops.area,
                        icon: Icons.map_outlined,
                      ),
                      CanopyProfileMetric(
                        label: 'Materials',
                        value: '${materials.length}',
                        icon: Icons.recycling_outlined,
                        color: CanopyUi.teal,
                      ),
                      CanopyProfileMetric(
                        label: 'Capacity',
                        value: capacity == null ? 'Not added' : '$capacity kg',
                        icon: Icons.scale_outlined,
                        color: CanopyUi.gold,
                      ),
                      CanopyProfileMetric(
                        label: 'Verification',
                        value: verification,
                        icon: Icons.verified_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                CanopyProfileSection(
                  title: 'Operational footprint',
                  description:
                      'Territory boundaries, organisation dumpsites, and planting evidence recorded across this operating area.',
                  child: OperationalFootprintMap(
                    orgId: ops.orgId,
                    operatingArea: ops.area,
                  ),
                ),
                const SizedBox(height: 24),
                CanopyProfileSection(
                  title: 'Capabilities',
                  description:
                      'Materials handled, collection coverage, processing capacity, and traceability evidence belong here.',
                  child: materials.isEmpty
                      ? const CanopyProfileEmptyState(
                          icon: Icons.recycling_outlined,
                          title: 'Material capabilities not added',
                          message:
                              'Add accepted materials and capacity so collectors and marketplace partners can assess fit.',
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: materials
                              .map((material) => Chip(label: Text(material)))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 24),
                const CanopyProfileSection(
                  title: 'Recent activity',
                  description:
                      'Verified events are drawn from territory, fleet, tree, market, and handoff records.',
                  child: CanopyProfileEmptyState(
                    icon: Icons.history_outlined,
                    title: 'Activity appears after operations begin',
                    message:
                        'Create a zone, map a site, publish a listing, or verify a handoff to build this operational history.',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        if (orgContextBuilder != null || memberContextBuilder != null) ...[
          const _LabeledSection(
            label: 'SWITCH CONTEXT',
            note:
                'Move between organisation, member, marketplace, and environmental surfaces.',
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
            note:
                'Return to people, programmes, settings, and the wider dashboard.',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _switchTo(context, orgContextBuilder),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppTheme.lightGreen.withOpacity(0.28)),
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
                    child: const Icon(Icons.business_outlined,
                        color: AppTheme.primary),
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
                  Icon(Icons.chevron_right,
                      color: AppTheme.primary.withOpacity(0.62)),
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
  final IconData icon;
  final VoidCallback onTap;

  const _HeroTag({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
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
          ),
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
  final VoidCallback onTap;

  const _SignalCardData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _SignalCard extends StatelessWidget {
  final _SignalCardData data;

  const _SignalCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${data.label}, ${data.value}. ${data.caption}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 142),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: data.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(data.icon, color: data.color, size: 20),
                    ),
                    const Spacer(),
                    Icon(Icons.north_east_rounded,
                        color: data.color.withOpacity(0.7), size: 16),
                  ],
                ),
                const Spacer(),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.label,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.darkGreen.withOpacity(0.56),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
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
