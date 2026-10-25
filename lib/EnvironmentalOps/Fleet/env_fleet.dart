// lib/EnvironmentalOps/Fleet/env_fleet.dart
//
// Operations › Fleet (ENVOPS_HANDOFF §3.5). Signals (active now ·
// collections this week · kg this month) → collectors (CollectorRow: status
// label, 56dp call) + Add → sticky "Log a handoff" → HandoffLogger
// (collector chips, material chips, big kg number + keypad, sticky "Save
// handoff · N kg"). Empty: "Add your first collector to start logging
// handoffs". Reads the org-scoped legacy mirrors (index-free, single
// equality); writes go through EnvironmentOpsService, which keeps both.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Models/environmental/enums/fleet_collector_status.dart';
import '../../Models/environmental/enums/payment_method.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../theme/canopy_components.dart';
import '../envops_ui.dart';

enum CollectorStatus { active, offShift, uncontactable }

extension CollectorStatusX on CollectorStatus {
  String get key => switch (this) {
        CollectorStatus.active => 'active',
        CollectorStatus.offShift => 'off_shift',
        CollectorStatus.uncontactable => 'uncontactable',
      };

  String get label => switch (this) {
        CollectorStatus.active => 'Active',
        CollectorStatus.offShift => 'Off shift',
        CollectorStatus.uncontactable => 'Uncontactable',
      };

  FleetCollectorStatus get fleet => switch (this) {
        CollectorStatus.active => FleetCollectorStatus.active,
        CollectorStatus.offShift => FleetCollectorStatus.offShift,
        CollectorStatus.uncontactable => FleetCollectorStatus.uncontactable,
      };

  static CollectorStatus fromKey(String? key) => switch (key) {
        'off_shift' => CollectorStatus.offShift,
        'uncontactable' => CollectorStatus.uncontactable,
        _ => CollectorStatus.active,
      };
}

Color _statusColor(CollectorStatus s, CanopyPalette p) => switch (s) {
      CollectorStatus.active => p.success,
      CollectorStatus.offShift => p.inkMuted,
      CollectorStatus.uncontactable => p.warning,
    };

class EnvFleetScreen extends StatefulWidget {
  const EnvFleetScreen({super.key});

  @override
  State<EnvFleetScreen> createState() => _EnvFleetScreenState();
}

class _EnvFleetScreenState extends State<EnvFleetScreen> {
  EnvironmentOpsContext? _ctx;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    EnvironmentOpsService.instance.resolveContext().then((c) {
      if (mounted) {
        setState(() {
          _ctx = c;
          _loading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> _addCollector() async {
    final c = _ctx;
    if (c == null) return;
    final r = await showCanopySheet<(String, String?, String?, CollectorStatus)>(context, builder: (_) => const _AddCollectorSheet());
    if (r == null) return;
    try {
      await EnvironmentOpsService.instance.addCollector(orgId: c.orgId, uid: c.uid, name: r.$1, zone: r.$2, phone: r.$3, status: r.$4.fleet);
      if (mounted) showCanopySnack(context, '${r.$1} added.');
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't add the collector. Try again.", error: true);
    }
  }

  Future<void> _setStatus(String id, String name, CollectorStatus current) async {
    final c = _ctx;
    if (c == null) return;
    final next = await showCanopySheet<CollectorStatus>(context, builder: (ctx) {
      return CanopySheetBody(title: name, caption: 'Status', children: [
        CanopyListGroup(children: [
          for (final s in CollectorStatus.values)
            CanopyListRow(
              leading: CanopyRadio(selected: s == current),
              title: s.label,
              chevron: false,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ]),
      ]);
    });
    if (next == null || next == current) return;
    try {
      final batch = _db.batch();
      batch.update(_db.collection('collectors').doc(id), {'status': next.key});
      batch.set(
        _db.collection('organizations').doc(c.orgId).collection('fleetCollectors').doc(id),
        {'status': next.fleet.firestoreKey, 'statusUpdatedAt': FieldValue.serverTimestamp(), 'statusUpdatedBy': c.uid},
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't update. Try again.", error: true);
    }
  }

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) showCanopySnack(context, "Couldn't start the call.", error: true);
  }

  Future<void> _logHandoff(List<(String, String, String?)> collectors) async {
    final c = _ctx;
    if (c == null) return;
    if (collectors.isEmpty) {
      showCanopySnack(context, 'Add a collector first.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HandoffLoggerScreen(ctx: c, collectors: collectors)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final c = _ctx;
    if (c == null) {
      return const CanopyEmptyState(
          icon: Icons.link_off, title: 'Not linked to an organisation', line: 'A fleet belongs to an organisation.');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('collection_handoffs').where('org_id', isEqualTo: c.orgId).snapshots(),
      builder: (context, hs) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('collectors').where('org_id', isEqualTo: c.orgId).snapshots(),
        builder: (context, cs) {
          final handoffs = hs.data?.docs ?? const [];
          final collectors = [...(cs.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])]
            ..sort((a, b) => '${a.data()['name']}'.toLowerCase().compareTo('${b.data()['name']}'.toLowerCase()));
          final now = DateTime.now();
          final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          final monthStart = DateTime(now.year, now.month);
          DateTime? at(QueryDocumentSnapshot<Map<String, dynamic>> h) => (h.data()['delivered_at'] as Timestamp?)?.toDate();
          final week = handoffs.where((h) => !(at(h)?.isBefore(weekStart) ?? true)).length;
          final kgMonth = handoffs.where((h) => !(at(h)?.isBefore(monthStart) ?? true)).fold<double>(0, (s, h) => s + ((h.data()['kg'] as num?)?.toDouble() ?? 0));
          final active = collectors.where((x) => CollectorStatusX.fromKey(x.data()['status'] as String?) == CollectorStatus.active).length;
          final picker = [for (final x in collectors) (x.id, '${x.data()['name'] ?? 'Collector'}', x.data()['zone'] as String?)];

          return CanopyScaffold(
            body: ListView(
              padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
              children: [
                if (cs.hasError || hs.hasError)
                  const CanopyErrorState(inline: true, title: "Couldn't load the fleet.")
                else if (!cs.hasData)
                  const CanopyListSkeleton(rows: 3)
                else ...[
                  SignalGrid(signals: [
                    SignalCard(value: '$active', caption: 'Active now'),
                    SignalCard(value: '$week', caption: 'Collections this week'),
                    SignalCard(value: '${kgMonth.round()}', caption: 'Kg this month'),
                  ]),
                  FieldEyebrow('Collectors · ${collectors.length}', actionLabel: collectors.isEmpty ? null : 'Add', onAction: _addCollector),
                  if (collectors.isEmpty)
                    CanopyEmptyState(
                      boxed: true,
                      icon: Icons.groups_outlined,
                      title: 'Add your first collector to start logging handoffs',
                      actionLabel: 'Add collector',
                      onAction: _addCollector,
                    )
                  else
                    CanopyCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < collectors.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.outline),
                          Builder(builder: (_) {
                            final d = collectors[i].data();
                            final st = CollectorStatusX.fromKey(d['status'] as String?);
                            final phone = (d['phone'] as String?)?.trim() ?? '';
                            final kg = handoffs
                                .where((h) => h.data()['collector_id'] == collectors[i].id && !(at(h)?.isBefore(monthStart) ?? true))
                                .fold<double>(0, (s, h) => s + ((h.data()['kg'] as num?)?.toDouble() ?? 0));
                            return CollectorRow(
                              name: '${d['name'] ?? 'Collector'}',
                              zone: (d['zone'] as String?)?.trim(),
                              phone: phone.isEmpty ? null : phone,
                              status: LabelRow(children: [
                                StatusLabel(st.label, color: _statusColor(st, p)),
                                if (kg > 0) StatusLabel('${kg.round()} kg this month', color: p.inkMuted),
                              ]),
                              onCall: phone.isEmpty ? null : () => _call(phone),
                              onTap: () => _setStatus(collectors[i].id, '${d['name'] ?? 'Collector'}', st),
                            );
                          }),
                        ],
                      ]),
                    ),
                ],
              ],
            ),
            sticky: collectors.isEmpty
                ? null
                : StickyActionBar(children: [FieldButton(label: 'Log a handoff', icon: Icons.scale_outlined, onPressed: () => _logHandoff(picker))]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD COLLECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _AddCollectorSheet extends StatefulWidget {
  const _AddCollectorSheet();

  @override
  State<_AddCollectorSheet> createState() => _AddCollectorSheetState();
}

class _AddCollectorSheetState extends State<_AddCollectorSheet> {
  final _name = TextEditingController();
  final _zone = TextEditingController();
  final _phone = TextEditingController();
  CollectorStatus _status = CollectorStatus.active;
  bool _showErrors = false;

  @override
  void dispose() {
    _name.dispose();
    _zone.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return CanopySheetBody(
      title: 'Add a collector',
      children: [
        CanopyTextField(
          label: 'Name',
          controller: _name,
          autofocus: true,
          error: _showErrors && _name.text.trim().isEmpty ? 'Enter their name.' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField.phone(label: 'Phone (optional)', controller: _phone),
        const SizedBox(height: CanopySpace.s16),
        CanopyTextField(label: 'Zone (optional)', hint: 'Where they usually collect', controller: _zone),
        const SizedBox(height: CanopySpace.s16),
        CanopySegmented<CollectorStatus>(
          options: [for (final s in CollectorStatus.values) (s, s.label)],
          value: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
      ],
      actions: [
        FieldButton(
          label: 'Add collector',
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.pop(context, (_name.text.trim(), _opt(_zone), _opt(_phone), _status));
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HANDOFF LOGGER
// ─────────────────────────────────────────────────────────────────────────────

class HandoffLoggerScreen extends StatefulWidget {
  final EnvironmentOpsContext ctx;
  final List<(String, String, String?)> collectors; // id, name, zone
  const HandoffLoggerScreen({super.key, required this.ctx, required this.collectors});

  @override
  State<HandoffLoggerScreen> createState() => _HandoffLoggerScreenState();
}

class _HandoffLoggerScreenState extends State<HandoffLoggerScreen> {
  static const _materials = ['PET bottles', 'HDPE', 'Mixed plastics', 'Soft plastic / film', 'Metal', 'Paper & card', 'Glass', 'E-waste'];

  late String _collector = widget.collectors.first.$1;
  String _material = _materials.first;
  String _kg = '';
  bool _saving = false;

  double get _kgN => double.tryParse(_kg) ?? 0;

  Future<void> _save() async {
    if (_kgN <= 0) {
      showCanopySnack(context, 'Enter the weight in kg.', error: true);
      return;
    }
    setState(() => _saving = true);
    final who = widget.collectors.firstWhere((c) => c.$1 == _collector);
    try {
      await EnvironmentOpsService.instance.logCollectionHandoff(
        orgId: widget.ctx.orgId,
        uid: widget.ctx.uid,
        collectorId: who.$1,
        collectorName: who.$2,
        weightKg: _kgN,
        materialType: _material,
        locationLabel: who.$3,
        deliveredAt: DateTime.now(),
        paymentMethod: PaymentMethod.mpesa,
      );
      if (!mounted) return;
      showCanopySnack(context, 'Handoff saved · $_kg kg from ${who.$2}.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't save. Your entry is still here — try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Log a handoff'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
        children: [
          const FieldEyebrow('Collector', padding: EdgeInsets.only(bottom: CanopySpace.s12)),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final c in widget.collectors)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: CanopyFilterChip(label: c.$2, selected: _collector == c.$1, onTap: () => setState(() => _collector = c.$1)),
              ),
          ]),
          const FieldEyebrow('Material'),
          Wrap(spacing: CanopySpace.s8, runSpacing: CanopySpace.s8, children: [
            for (final m in _materials) CanopyFilterChip(label: m, selected: _material == m, onTap: () => setState(() => _material = m)),
          ]),
          const FieldEyebrow('Weight'),
          BigNumberInput(value: _kg, unit: 'kg'),
          const SizedBox(height: CanopySpace.s12),
          FieldKeypad(value: _kg, onChanged: (v) => setState(() => _kg = v)),
        ],
      ),
      sticky: StickyActionBar(children: [
        FieldButton(label: _kgN > 0 ? 'Save handoff · $_kg kg' : 'Save handoff', loading: _saving, onPressed: _kgN > 0 ? _save : null),
      ]),
    );
  }
}
