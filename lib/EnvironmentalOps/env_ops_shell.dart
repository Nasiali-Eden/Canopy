// lib/EnvironmentalOps/env_ops_shell.dart
//
// Environmental Ops shell (ENVOPS_HANDOFF §3.1, §3.6). Tabs Overview ·
// Territory · Operations (Market · Trees · Fleet · Verified) · Profile.
//
// Overview: app bar (org logo, "Environmental Ops", Switch) → Live field map
// (tap → Territory) → Live signals → Quick actions → Field notes.
// Just enabled: "Your field workspace" + three numbered jobs.
// Drafts kept on the phone show as "Waiting to send" with Retry / Discard.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../Organization/Map/org_map_ops.dart';
import '../Services/Environmental/environment_ops_service.dart';
import '../Shared/widgets/canopy_bottom_bar.dart';
import '../Shared/widgets/role_context_switcher.dart';
import '../theme/canopy_components.dart';
import 'Fleet/env_fleet.dart';
import 'Market/create_listing_screen.dart';
import 'Market/env_market.dart';
import 'Profile/operational_footprint_map.dart';
import 'Shared/zone_drawing_controller.dart' show ZoneDrawingResult, ZoneType;
import 'Territory/env_territory.dart';
import 'Trees/env_trees.dart';
import 'Verified/env_verified.dart';
import 'envops_ui.dart';

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
  int _tab = 0;
  int _opsTab = 0;
  EnvironmentOpsContext? _ctx;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final c = await EnvironmentOpsService.instance.resolveContext();
      if (mounted) setState(() => _ctx = c);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  RoleContextSwitcher get _switcher {
    void go(WidgetBuilder? b) {
      if (b == null) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: b), (_) => false);
    }

    return RoleContextSwitcher(
      activeContext: 'envOps',
      hasMarketplace: widget.hasMarketplace,
      hasEnvOps: true,
      hasCultural: widget.hasCultural,
      onOrgTap: () => go(widget.orgContextBuilder),
      onMemberTap: () => go(widget.memberContextBuilder),
      onMarketplaceTap: widget.marketplaceContextBuilder == null ? null : () => go(widget.marketplaceContextBuilder),
      onEnvOpsTap: () {},
      onCulturalTap: widget.culturalContextBuilder == null ? null : () => go(widget.culturalContextBuilder),
    );
  }

  void _openOps(int sub) => setState(() {
        _opsTab = sub;
        _tab = 2;
      });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final ctx = _ctx;
    final logo = (ctx?.orgData['logoUrl'] ?? ctx?.orgData['profilePhoto']) as String?;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) setState(() => _tab = 0);
      },
      child: CanopyScaffold(
        appBar: canopyAppBar(
          context,
          showBack: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: CanopySpace.gutter),
            child: Center(child: CanopyAvatar(url: logo, name: ctx?.orgName ?? 'Org', size: 32, org: true)),
          ),
          title: const ['Environmental Ops', 'Territory', 'Operations', 'Profile'][_tab],
          actions: [
            TextButton.icon(
              onPressed: () => _switcher.openSheet(context),
              icon: Icon(Icons.swap_horiz, color: p.ink),
              label: Text('Switch', style: CanopyType.label.copyWith(color: p.ink)),
            ),
            const SizedBox(width: CanopySpace.s8),
          ],
        ),
        body: switch (_tab) {
          1 => const EnvTerritoryScreen(),
          2 => _OperationsTab(index: _opsTab, onChanged: (i) => setState(() => _opsTab = i)),
          3 => _ProfileTab(ctx: ctx, loading: _loading, switcher: _switcher, onOpenTab: (t) => setState(() => _tab = t)),
          _ => _OverviewTab(
              ctx: ctx,
              loading: _loading,
              onOpenTab: (t) => setState(() => _tab = t),
              onOpenOps: _openOps,
              onRetryContext: _resolve,
            ),
        },
        bottomNavigationBar: CanopyBottomBar(
          currentIndex: _tab,
          onTap: (i) => setState(() {
            if (i == 2 && _tab != 2) _opsTab = 0;
            _tab = i;
          }),
          destinations: const [
            CanopyNavDestination(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Overview'),
            CanopyNavDestination(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Territory'),
            CanopyNavDestination(icon: Icons.tune_outlined, activeIcon: Icons.tune, label: 'Operations'),
            CanopyNavDestination(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────

class _Signals {
  final int zones, pins, trees, handoffsThisMonth, collectors, listings;
  const _Signals(this.zones, this.pins, this.trees, this.handoffsThisMonth, this.collectors, this.listings);
  bool get empty => zones == 0 && pins == 0 && trees == 0 && handoffsThisMonth == 0;
}

class _Note {
  final int tab; // where tapping goes: 1 territory · 20 market · 21 trees · 22 fleet · -1 map pin
  final String what;
  final String where;
  final DateTime? at;
  final String? status;
  const _Note(this.tab, this.what, this.where, this.at, {this.status});
}

Future<_Signals> _loadSignals(EnvironmentOpsContext c) async {
  final db = FirebaseFirestore.instance;
  final org = db.collection('organizations').doc(c.orgId);
  Future<int> count(Query<Map<String, dynamic>> q) async {
    try {
      return (await q.count().get()).count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
  var zones = await count(org.collection('collectionZones'));
  if (zones == 0) zones = await count(db.collection('collection_zones').where('org_id', isEqualTo: c.orgId));
  final pins = await count(db.collection('map_pins').where('added_by_org_id', isEqualTo: c.orgId));
  final trees = await count(org.collection('trees'));
  var handoffs = 0;
  try {
    final h = await org.collection('collectionHandoffs').get();
    handoffs = h.docs.where((d) {
      final t = d.data()['loggedAt'];
      return t is Timestamp && !t.toDate().isBefore(monthStart);
    }).length;
  } catch (_) {}
  final collectors = await count(org.collection('fleetCollectors'));
  final listings = await count(org.collection('marketOrders'));
  return _Signals(zones, pins, trees, handoffs, collectors, listings);
}

Future<List<_Note>> _loadNotes(EnvironmentOpsContext c) async {
  final db = FirebaseFirestore.instance;
  final org = db.collection('organizations').doc(c.orgId);
  final out = <_Note>[];
  String place(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isNotEmpty && s != 'null' ? s : c.area;
  }

  try {
    for (final d in (await org.collection('collectionZones').limit(20).get()).docs) {
      final m = d.data();
      out.add(_Note(1, 'Zone saved · ${m['label'] ?? 'Territory'}', place(m['area']), (m['createdAt'] as Timestamp?)?.toDate(),
          status: (m['isActive'] as bool? ?? true) ? 'Active' : 'Draft'));
    }
  } catch (_) {}
  try {
    for (final d in (await db.collection('map_pins').where('added_by_org_id', isEqualTo: c.orgId).limit(20).get()).docs) {
      final m = d.data();
      final type = '${m['pin_type'] ?? 'site'}'.replaceAll('_', ' ');
      out.add(_Note(-1, '${type[0].toUpperCase()}${type.substring(1)} mapped · ${m['name'] ?? ''}', place(m['area']),
          (m['created_at'] as Timestamp?)?.toDate(),
          status: m['is_verified'] == true ? 'Verified' : 'Unverified'));
    }
  } catch (_) {}
  try {
    // One note per species planted on the same day, not one per tree.
    final byDay = <String, (int, String, DateTime?)>{};
    for (final d in (await org.collection('trees').limit(200).get()).docs) {
      final m = d.data();
      final at = (m['createdAt'] as Timestamp?)?.toDate();
      final name = '${m['commonName'] ?? m['species'] ?? 'Tree'}';
      final key = '${name}_${at == null ? '' : '${at.year}-${at.month}-${at.day}'}';
      byDay[key] = ((byDay[key]?.$1 ?? 0) + 1, name, byDay[key]?.$3 ?? at);
    }
    for (final v in byDay.values) {
      out.add(_Note(21, '${v.$1} ${v.$2} planted', c.area, v.$3, status: 'Pending verification'));
    }
  } catch (_) {}
  try {
    for (final d in (await org.collection('collectionHandoffs').limit(20).get()).docs) {
      final m = d.data();
      final mat = m['material'] is Map ? Map<String, dynamic>.from(m['material'] as Map) : const <String, dynamic>{};
      final loc = m['location'] is Map ? Map<String, dynamic>.from(m['location'] as Map) : const <String, dynamic>{};
      out.add(_Note(22, 'Handoff · ${(mat['weightKg'] as num?)?.toStringAsFixed(0) ?? '?'} kg ${mat['type'] ?? ''}'.trim(),
          place(loc['label']), (m['loggedAt'] as Timestamp?)?.toDate()));
    }
  } catch (_) {}
  out.sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
  return out.take(8).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  final EnvironmentOpsContext? ctx;
  final bool loading;
  final ValueChanged<int> onOpenTab;
  final ValueChanged<int> onOpenOps;
  final VoidCallback onRetryContext;
  const _OverviewTab({required this.ctx, required this.loading, required this.onOpenTab, required this.onOpenOps, required this.onRetryContext});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Future<_Signals>? _signals;
  Future<List<_Note>>? _notes;
  List<ZoneDraft> _drafts = const [];
  bool _sending = false;
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    _load();
    FieldDraftStore.instance.revision.addListener(_loadDrafts);
  }

  @override
  void didUpdateWidget(covariant _OverviewTab old) {
    super.didUpdateWidget(old);
    if (old.ctx?.orgId != widget.ctx?.orgId) _load();
  }

  @override
  void dispose() {
    FieldDraftStore.instance.revision.removeListener(_loadDrafts);
    super.dispose();
  }

  void _load() {
    final c = widget.ctx;
    if (c != null) {
      _signals = _loadSignals(c);
      _notes = _loadNotes(c);
      _rev++;
    }
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final d = await FieldDraftStore.instance.zones();
    if (mounted) setState(() => _drafts = d);
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([if (_signals != null) _signals!, if (_notes != null) _notes!]);
  }

  Future<void> _retry(ZoneDraft d) async {
    final c = widget.ctx;
    if (c == null) {
      showCanopySnack(context, 'Link an organisation before saving. The draft stays on this phone.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await EnvironmentOpsService.instance.createZone(
        orgId: c.orgId,
        uid: c.uid,
        name: d.name.isEmpty ? 'Zone ${fieldNoteTime(d.capturedAt)}' : d.name,
        vertices: d.points,
        areaKm2: ZoneDrawingResult(vertices: d.points, zoneType: ZoneType.collectionZone).areaKm2,
      );
      await FieldDraftStore.instance.removeZone(d.id);
      if (mounted) {
        showCanopySnack(context, 'Zone saved.');
        setState(_load);
      }
    } catch (_) {
      await FieldDraftStore.instance.putZone(d.copyWith(lastError: "Couldn't save — still on this phone."));
      if (mounted) showCanopySnack(context, "Still couldn't save. The draft is safe on this phone.", error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _discard(ZoneDraft d) async {
    final ok = await showCanopyConfirm(context,
        title: 'Discard this draft?', message: '${d.points.length} captured points will be deleted from this phone.', confirmLabel: 'Discard', danger: true);
    if (ok) await FieldDraftStore.instance.removeZone(d.id);
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Map<String, dynamic> get _orgData => {...widget.ctx!.orgData, 'orgId': widget.ctx!.orgId};

  void _mapDumpsite() => _push(OrgMapOpsScreen(orgData: _orgData, initialPinTypeId: 'dumpsite'));
  void _postRecovery() => _push(CreateListingScreen(orgId: widget.ctx!.orgId, orgData: _orgData));

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (widget.loading) {
      return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [
        CanopySkeleton(height: 220, radius: CanopyRadius.md),
        SizedBox(height: CanopySpace.section),
        CanopyListSkeleton(rows: 4),
      ]);
    }
    final c = widget.ctx;
    if (c == null) {
      return CanopyEmptyState(
        icon: Icons.link_off,
        title: 'Environmental profile is not linked',
        line: 'This account has no organisation. Field work needs an organisation to belong to.',
        actionLabel: 'Try again',
        onAction: widget.onRetryContext,
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_Signals>(
        future: _signals,
        builder: (context, sig) {
          final s = sig.data;
          final justEnabled = s != null && s.empty && _drafts.isEmpty;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
            children: [
              if (_drafts.isNotEmpty) ...[
                const CanopyCallout(
                  kind: CalloutKind.warning,
                  title: 'Some field work hasn\'t reached Canopy yet',
                  text: 'It is kept on this phone. Retry when you have signal.',
                ),
                const SizedBox(height: CanopySpace.s12),
                WaitingToSend(drafts: _drafts, busy: _sending, onRetry: _retry, onDiscard: _discard),
              ],
              if (justEnabled) ..._firstRun(p) else ...[
                FieldEyebrow('Live field map', padding: const EdgeInsets.only(top: CanopySpace.s8, bottom: CanopySpace.s12)),
                OperationalFootprintMap(
                  key: ValueKey('${c.orgId}:$_rev'),
                  orgId: c.orgId,
                  operatingArea: c.area,
                  height: 220,
                  onOpen: () => widget.onOpenTab(1),
                ),
                const FieldEyebrow('Live signals'),
                if (sig.hasError)
                  CanopyErrorState(inline: true, title: "Couldn't load signals.", onRetry: _refresh)
                else if (s == null)
                  const CanopyListSkeleton(rows: 2)
                else
                  SignalGrid(signals: [
                    SignalCard(value: '${s.zones}', caption: 'Zones', onTap: () => widget.onOpenTab(1)),
                    SignalCard(value: '${s.pins}', caption: 'Mapped sites', onTap: () => widget.onOpenTab(1)),
                    SignalCard(value: '${s.trees}', caption: 'Trees planted', onTap: () => widget.onOpenOps(1)),
                    SignalCard(value: '${s.handoffsThisMonth}', caption: 'Handoffs this month', onTap: () => widget.onOpenOps(2)),
                  ]),
                const FieldEyebrow('Quick actions'),
                _ActionGrid(actions: [
                  (Icons.polyline_outlined, 'Trace territory', () => widget.onOpenTab(1)),
                  (Icons.delete_outline, 'Map a dumpsite', _mapDumpsite),
                  (Icons.park_outlined, 'Record trees', () => widget.onOpenOps(1)),
                  (Icons.storefront_outlined, 'Post recovery', _postRecovery),
                ]),
                const FieldEyebrow('Field notes'),
                FutureBuilder<List<_Note>>(
                  future: _notes,
                  builder: (context, n) {
                    if (n.hasError) return CanopyErrorState(inline: true, title: "Couldn't load field notes.", onRetry: _refresh);
                    if (!n.hasData) return const CanopyListSkeleton(rows: 3);
                    if (n.data!.isEmpty) {
                      return Text('Nothing recorded yet. Field work shows here with the place it happened.',
                          style: CanopyType.body.copyWith(color: p.inkMuted));
                    }
                    return Column(children: [
                      for (final note in n.data!)
                        FieldNoteRow(
                          time: fieldNoteTime(note.at),
                          what: note.what,
                          where: note.where,
                          status: note.status == null
                              ? null
                              : StatusLabel(note.status!,
                                  color: switch (note.status) {
                                    'Active' || 'Verified' => p.success,
                                    'Draft' || 'Pending verification' || 'Unverified' => p.warning,
                                    _ => p.inkMuted,
                                  }),
                          onTap: () => switch (note.tab) {
                            1 => widget.onOpenTab(1),
                            21 => widget.onOpenOps(1),
                            22 => widget.onOpenOps(2),
                            _ => widget.onOpenTab(1),
                          },
                        ),
                    ]);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _firstRun(CanopyPalette p) {
    Widget job(int n, String title, String line, Widget action) => Padding(
          padding: const EdgeInsets.only(bottom: CanopySpace.s16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 36, child: Text('$n', style: CanopyField.signalValue.copyWith(color: p.ink))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: CanopyType.subhead.copyWith(color: p.ink)),
                Text(line, style: CanopyType.body.copyWith(color: p.inkMuted)),
                const SizedBox(height: CanopySpace.s8),
                action,
              ]),
            ),
          ]),
        );
    return [
      const SizedBox(height: CanopySpace.s16),
      Text('Your field workspace', style: CanopyType.display.copyWith(color: p.ink)),
      const SizedBox(height: CanopySpace.s4),
      Text('Three jobs get you started. Everything you record shows on your field map.', style: CanopyType.body.copyWith(color: p.inkMuted)),
      const FieldEyebrow('Start here'),
      job(1, 'Map where you work', 'Walk or tap the boundary of the area you cover.',
          FieldButton(label: 'Trace territory', onPressed: () => widget.onOpenTab(1))),
      job(2, 'Record what you plant', 'Count, species and place — survival is checked later.',
          FieldButton.secondary(label: 'Record trees', onPressed: () => widget.onOpenOps(1))),
      job(3, 'Log what collectors bring in', 'Add your collectors, then log each handoff in kg.',
          FieldButton.secondary(label: 'Open fleet', onPressed: () => widget.onOpenOps(2))),
    ];
  }
}

/// Four field-sized actions, 2×2, 1px outline, radius 10.
class _ActionGrid extends StatelessWidget {
  final List<(IconData, String, VoidCallback)> actions;
  const _ActionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    Widget tile((IconData, String, VoidCallback) a) => Semantics(
          button: true,
          label: a.$2,
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CanopyField.buttonRadius), side: BorderSide(color: p.outline)),
            child: InkWell(
              borderRadius: BorderRadius.circular(CanopyField.buttonRadius),
              onTap: a.$3,
              child: Padding(
                padding: const EdgeInsets.all(CanopySpace.s12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(a.$1, size: 24, color: p.ink),
                  const SizedBox(height: CanopySpace.s8),
                  Text(a.$2, style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                ]),
              ),
            ),
          ),
        );
    return Column(children: [
      for (var i = 0; i < actions.length; i += 2) ...[
        if (i > 0) const SizedBox(height: CanopySpace.s12),
        Row(children: [
          Expanded(child: tile(actions[i])),
          const SizedBox(width: CanopySpace.s12),
          Expanded(child: i + 1 < actions.length ? tile(actions[i + 1]) : const SizedBox.shrink()),
        ]),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPERATIONS
// ─────────────────────────────────────────────────────────────────────────────

class _OperationsTab extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _OperationsTab({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CanopyUnderlineTabs(tabs: const ['Market', 'Trees', 'Fleet', 'Verified'], index: index, onChanged: onChanged),
      Expanded(
        child: IndexedStack(index: index, children: const [
          EnvMarketScreen(),
          EnvTreesScreen(),
          EnvFleetScreen(),
          EnvVerifiedScreen(),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final EnvironmentOpsContext? ctx;
  final bool loading;
  final RoleContextSwitcher switcher;
  final ValueChanged<int> onOpenTab;
  const _ProfileTab({required this.ctx, required this.loading, required this.switcher, required this.onOpenTab});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Future<_Signals>? _signals;
  Future<List<_Note>>? _notes;

  @override
  void initState() {
    super.initState();
    final c = widget.ctx;
    if (c != null) {
      _signals = _loadSignals(c);
      _notes = _loadNotes(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (widget.loading) return const Center(child: CircularProgressIndicator());
    final c = widget.ctx;
    if (c == null) {
      return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: [
        const CanopyEmptyState(
          boxed: true,
          icon: Icons.link_off,
          title: 'Environmental profile is not linked',
          line: 'This account has no organisation to attach field work to.',
        ),
        const SizedBox(height: CanopySpace.section),
        widget.switcher,
      ]);
    }
    final d = c.orgData;
    final logo = (d['logoUrl'] ?? d['profilePhoto']) as String?;
    final rawMaterials = d['envOpsActivities'];
    final activities = rawMaterials is List ? rawMaterials.map((e) => '$e').toList() : const <String>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s16, CanopySpace.gutter, CanopySpace.s32),
      children: [
        Row(children: [
          CanopyAvatar(url: logo, name: c.orgName, size: 56, org: true),
          const SizedBox(width: CanopySpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.orgName, style: CanopyType.title.copyWith(color: p.ink)),
              Text('Operating in ${c.area}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ]),
          ),
        ]),
        const FieldEyebrow('Operational footprint'),
        OperationalFootprintMap(orgId: c.orgId, operatingArea: c.area),
        const FieldEyebrow('Readiness'),
        FutureBuilder<_Signals>(
          future: _signals,
          builder: (context, snap) {
            final s = snap.data;
            if (s == null) return const CanopyListSkeleton(rows: 4);
            ReadinessState st(bool done) => done ? ReadinessState.done : ReadinessState.todo;
            return ReadinessChecklist(items: [
              ReadinessItem('Territory mapped', st(s.zones > 0), line: '${s.zones} zone${s.zones == 1 ? '' : 's'}', onTap: () => widget.onOpenTab(1)),
              ReadinessItem('Sites on the map', st(s.pins > 0), line: '${s.pins} mapped'),
              ReadinessItem('Trees recorded', st(s.trees > 0), line: '${s.trees} trees'),
              ReadinessItem('Collectors added', st(s.collectors > 0), line: '${s.collectors} in your fleet'),
              ReadinessItem('Material listed on the market', st(s.listings > 0), line: '${s.listings} listing${s.listings == 1 ? '' : 's'}'),
              const ReadinessItem('Independent verification', ReadinessState.unavailable),
            ]);
          },
        ),
        if (activities.isNotEmpty) ...[
          const FieldEyebrow('What you run'),
          Text(activities.map((a) => a.replaceAll('_', ' ')).join(' · '), style: CanopyType.body.copyWith(color: p.ink)),
        ],
        const FieldEyebrow('Recent activity'),
        FutureBuilder<List<_Note>>(
          future: _notes,
          builder: (context, n) {
            if (!n.hasData) return const CanopyListSkeleton(rows: 3);
            if (n.data!.isEmpty) {
              return Text('Activity appears once you map, plant or log a handoff.', style: CanopyType.body.copyWith(color: p.inkMuted));
            }
            return Column(children: [
              for (final note in n.data!.take(5)) FieldNoteRow(time: fieldNoteTime(note.at), what: note.what, where: note.where),
            ]);
          },
        ),
        const FieldEyebrow('Workspace'),
        widget.switcher,
        const SizedBox(height: CanopySpace.s16),
        FieldButton.secondary(label: 'Switch back to organisation', onPressed: widget.switcher.onOrgTap),
      ],
    );
  }
}
