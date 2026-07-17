import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Shared/theme/app_theme.dart';
import '../../Services/Environmental/environment_ops_service.dart';
import '../../Models/environmental/enums/fleet_collector_status.dart';
import '../../Models/environmental/enums/payment_method.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FLEET — collectors & collection handoffs, backed by Firestore.
//
// Collections:
//   collectors            { org_id, name, zone, phone, status, created_by,
//                           created_at }
//   collection_handoffs   { org_id, collector_id, collector_name, kg, material,
//                           delivered_at, created_by, created_at }
//
// All reads are org-scoped with a single equality filter (index-free); stats
// and per-collector aggregates are computed client-side.
// ─────────────────────────────────────────────────────────────────────────────

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

  Color get color => switch (this) {
        CollectorStatus.active => AppTheme.primary,
        CollectorStatus.offShift => Colors.grey,
        CollectorStatus.uncontactable => Colors.amber,
      };

  static CollectorStatus fromKey(String? key) => switch (key) {
        'off_shift' => CollectorStatus.offShift,
        'uncontactable' => CollectorStatus.uncontactable,
        _ => CollectorStatus.active,
      };
}

class EnvFleetScreen extends StatefulWidget {
  const EnvFleetScreen({super.key});

  @override
  State<EnvFleetScreen> createState() => _EnvFleetScreenState();
}

class _EnvFleetScreenState extends State<EnvFleetScreen> {
  String? _orgId;
  String? _uid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _uid = uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        _orgId = userDoc.data()?['orgId'] as String?;
      }
    } catch (_) {
      // Fall through to no-org state.
    }
    if (mounted) setState(() => _loading = false);
  }

  CollectionReference<Map<String, dynamic>> get _collectorsRef =>
      FirebaseFirestore.instance.collection('collectors');

  CollectionReference<Map<String, dynamic>> get _handoffsRef =>
      FirebaseFirestore.instance.collection('collection_handoffs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      floatingActionButton: (_orgId == null)
          ? null
          // Lifted clear of the shell's floating nav pill (body is extendBody).
          : Padding(
              padding: const EdgeInsets.only(bottom: 78),
              child: FloatingActionButton.extended(
                onPressed: _openLogHandoff,
                backgroundColor: AppTheme.primary,
                icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                label: const Text('Log Handoff',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppTheme.primary)))
            : _orgId == null
                ? _buildNoOrg()
                : _buildContent(),
      ),
    );
  }

  Widget _buildNoOrg() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Sign in with an organisation to manage your collection fleet.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: AppTheme.darkGreen.withOpacity(0.6)),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Outer stream: handoffs (drive stats + per-collector aggregates).
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          _handoffsRef.where('org_id', isEqualTo: _orgId).snapshots(),
      builder: (context, handoffSnap) {
        final handoffs = handoffSnap.data?.docs ?? const [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              _collectorsRef.where('org_id', isEqualTo: _orgId).snapshots(),
          builder: (context, collectorSnap) {
            final collectors = (collectorSnap.data?.docs ?? const [])
                .toList()
              ..sort((a, b) => (a.data()['name'] as String? ?? '')
                  .toLowerCase()
                  .compareTo(
                      (b.data()['name'] as String? ?? '').toLowerCase()));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _buildStatStrip(collectors, handoffs),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _sectionLabel('COLLECTORS'),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openAddCollector,
                      child: Row(
                        children: [
                          const Icon(Icons.add,
                              size: 16, color: AppTheme.accent),
                          const SizedBox(width: 2),
                          Text('Add collector',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accent)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (collectors.isEmpty)
                  _buildEmptyCollectors()
                else
                  ...collectors.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CollectorCard(
                          name: c.data()['name'] as String? ?? 'Collector',
                          zone: c.data()['zone'] as String? ?? '',
                          status: CollectorStatusX.fromKey(
                              c.data()['status'] as String?),
                          kgThisMonth: _kgThisMonth(handoffs, c.id),
                          transactions: _txnCount(handoffs, c.id),
                          lastDelivery: _lastDelivery(handoffs, c.id),
                        ),
                      )),
              ],
            );
          },
        );
      },
    );
  }

  // ── Aggregations ───────────────────────────────────────────────────────────

  DateTime get _startOfWeek {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
  }

  DateTime get _startOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  int _activeCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> cs) =>
      cs.where((c) =>
          (c.data()['status'] as String? ?? 'active') == 'active').length;

  int _weekCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> hs) =>
      hs.where((h) {
        final d = (h.data()['delivered_at'] as Timestamp?)?.toDate();
        return d != null && !d.isBefore(_startOfWeek);
      }).length;

  int _kgThisMonthTotal(
          List<QueryDocumentSnapshot<Map<String, dynamic>>> hs) =>
      hs.fold<int>(0, (acc, h) {
        final d = (h.data()['delivered_at'] as Timestamp?)?.toDate();
        if (d == null || d.isBefore(_startOfMonth)) return acc;
        return acc + ((h.data()['kg'] as num?)?.toInt() ?? 0);
      });

  int _kgThisMonth(
          List<QueryDocumentSnapshot<Map<String, dynamic>>> hs, String cid) =>
      hs.fold<int>(0, (acc, h) {
        if (h.data()['collector_id'] != cid) return acc;
        final d = (h.data()['delivered_at'] as Timestamp?)?.toDate();
        if (d == null || d.isBefore(_startOfMonth)) return acc;
        return acc + ((h.data()['kg'] as num?)?.toInt() ?? 0);
      });

  int _txnCount(
          List<QueryDocumentSnapshot<Map<String, dynamic>>> hs, String cid) =>
      hs.where((h) => h.data()['collector_id'] == cid).length;

  String _lastDelivery(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> hs, String cid) {
    DateTime? latest;
    for (final h in hs) {
      if (h.data()['collector_id'] != cid) continue;
      final d = (h.data()['delivered_at'] as Timestamp?)?.toDate();
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    if (latest == null) return '—';
    return _fmtRelative(latest);
  }

  static String _fmtRelative(DateTime dt) {
    final today = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = DateTime(today.year, today.month, today.day).difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('d MMM').format(dt);
  }

  // ── UI pieces ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppTheme.darkGreen.withOpacity(0.45),
        ),
      );

  Widget _buildStatStrip(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> collectors,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> handoffs,
  ) {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
                label: 'Collectors Active',
                value: '${_activeCount(collectors)}')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                label: 'Collections This Week',
                value: '${_weekCount(handoffs)}')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                label: 'Kg This Month',
                value: '${_kgThisMonthTotal(handoffs)}')),
      ],
    );
  }

  Widget _buildEmptyCollectors() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined,
              size: 40, color: AppTheme.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('No collectors yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen.withOpacity(0.65))),
          const SizedBox(height: 6),
          Text('Add your first collector to start logging handoffs',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.4))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openAddCollector,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('Add collector',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _openAddCollector() async {
    if (_orgId == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCollectorSheet(),
    );
    if (result == null) return;
    try {
      await EnvironmentOpsService.instance.addCollector(
        orgId: _orgId!,
        uid: _uid ?? 'anon',
        name: result['name'] as String,
        zone: result['zone'] as String?,
        phone: result['phone'] as String?,
        status: _toFleetStatus(result['status'] as CollectorStatus),
      );
    } catch (e) {
      _toast('Could not add collector: $e');
    }
  }

  Future<void> _openLogHandoff() async {
    if (_orgId == null) return;
    final collectorsSnap =
        await _collectorsRef.where('org_id', isEqualTo: _orgId).get();
    final collectors = collectorsSnap.docs
        .map((d) => (id: d.id, name: d.data()['name'] as String? ?? 'Collector'))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;
    if (collectors.isEmpty) {
      _toast('Add a collector first');
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogHandoffSheet(collectors: collectors),
    );
    if (result == null) return;
    try {
      await EnvironmentOpsService.instance.logCollectionHandoff(
        orgId: _orgId!,
        uid: _uid ?? 'anon',
        collectorId: result['collector_id'] as String,
        collectorName: result['collector_name'] as String,
        weightKg: (result['kg'] as num).toDouble(),
        materialType: (result['material'] as String?)?.trim().isNotEmpty == true
            ? (result['material'] as String).trim()
            : 'Mixed Plastics',
        deliveredAt: result['delivered_at'] as DateTime,
        paymentMethod: PaymentMethod.mpesa,
      );
      _toast('Handoff logged');
    } catch (e) {
      _toast('Could not log handoff: $e');
    }
  }

  FleetCollectorStatus _toFleetStatus(CollectorStatus status) {
    switch (status) {
      case CollectorStatus.active:
        return FleetCollectorStatus.active;
      case CollectorStatus.offShift:
        return FleetCollectorStatus.offShift;
      case CollectorStatus.uncontactable:
        return FleetCollectorStatus.uncontactable;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLECTOR CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CollectorCard extends StatelessWidget {
  final String name;
  final String zone;
  final CollectorStatus status;
  final int kgThisMonth;
  final int transactions;
  final String lastDelivery;

  const _CollectorCard({
    required this.name,
    required this.zone,
    required this.status,
    required this.kgThisMonth,
    required this.transactions,
    required this.lastDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline,
                    color: AppTheme.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.darkGreen)),
              ),
              if (zone.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(zone,
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: status.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(status.label,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.7))),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.lightGreen.withOpacity(0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniStat('$kgThisMonth kg', 'This month')),
              Expanded(child: _miniStat('$transactions', 'Handoffs')),
              Expanded(child: _miniStat(lastDelivery, 'Last delivery')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.darkGreen)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: AppTheme.darkGreen.withOpacity(0.5))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppTheme.darkGreen)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: AppTheme.darkGreen.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD COLLECTOR SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _AddCollectorSheet extends StatefulWidget {
  const _AddCollectorSheet();

  @override
  State<_AddCollectorSheet> createState() => _AddCollectorSheetState();
}

class _AddCollectorSheetState extends State<_AddCollectorSheet> {
  final _nameCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  CollectorStatus _status = CollectorStatus.active;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _zoneCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _nameCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Collector',
      children: [
        const _SheetLabel('Name *'),
        _SheetField(
          controller: _nameCtrl,
          hint: 'e.g. Jane Achieng',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const _SheetLabel('Zone'),
        _SheetField(controller: _zoneCtrl, hint: 'e.g. Kibera Zone A'),
        const SizedBox(height: 16),
        const _SheetLabel('Phone'),
        _SheetField(
            controller: _phoneCtrl,
            hint: 'Optional',
            keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        const _SheetLabel('Status'),
        Wrap(
          spacing: 8,
          children: CollectorStatus.values.map((s) {
            final active = s == _status;
            return ChoiceChip(
              label: Text(s.label),
              selected: active,
              onSelected: (_) => setState(() => _status = s),
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : AppTheme.darkGreen),
              backgroundColor: Colors.grey.withOpacity(0.1),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _SheetSubmit(
          label: 'Add Collector',
          enabled: _valid,
          onSubmit: () => Navigator.pop(context, {
            'name': _nameCtrl.text.trim(),
            'zone': _zoneCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'status': _status,
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOG HANDOFF SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _LogHandoffSheet extends StatefulWidget {
  final List<({String id, String name})> collectors;
  const _LogHandoffSheet({required this.collectors});

  @override
  State<_LogHandoffSheet> createState() => _LogHandoffSheetState();
}

class _LogHandoffSheetState extends State<_LogHandoffSheet> {
  String? _collectorId;
  final _kgCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  DateTime _deliveredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _collectorId = widget.collectors.first.id;
  }

  @override
  void dispose() {
    _kgCtrl.dispose();
    _materialCtrl.dispose();
    super.dispose();
  }

  bool get _valid {
    final kg = double.tryParse(_kgCtrl.text.trim());
    return _collectorId != null && kg != null && kg > 0;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Log Collection Handoff',
      children: [
        const _SheetLabel('Collector *'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _collectorId,
              isExpanded: true,
              items: widget.collectors
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name,
                            style: const TextStyle(
                                fontSize: 14, color: AppTheme.darkGreen)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _collectorId = v),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SheetLabel('Weight (kg) *'),
        _SheetField(
          controller: _kgCtrl,
          hint: 'e.g. 24',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const _SheetLabel('Material'),
        _SheetField(controller: _materialCtrl, hint: 'Optional, e.g. PET plastic'),
        const SizedBox(height: 16),
        const _SheetLabel('Delivery date'),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _deliveredAt,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _deliveredAt = picked);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppTheme.accent),
                const SizedBox(width: 10),
                Text(DateFormat('d MMM yyyy').format(_deliveredAt),
                    style: const TextStyle(
                        color: AppTheme.darkGreen, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SheetSubmit(
          label: 'Log Handoff',
          enabled: _valid,
          onSubmit: () {
            final name = widget.collectors
                .firstWhere((c) => c.id == _collectorId)
                .name;
            Navigator.pop(context, {
              'collector_id': _collectorId,
              'collector_name': name,
              'kg': double.parse(_kgCtrl.text.trim()),
              'material': _materialCtrl.text.trim().isEmpty
                  ? null
                  : _materialCtrl.text.trim(),
              'delivered_at': _deliveredAt,
            });
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SHEET WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F5F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen)),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen)),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  const _SheetField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
        ),
      ),
    );
  }
}

class _SheetSubmit extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onSubmit;
  const _SheetSubmit(
      {required this.label, required this.enabled, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          disabledBackgroundColor: Colors.grey.withOpacity(0.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      ),
    );
  }
}
