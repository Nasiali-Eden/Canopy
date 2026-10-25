// lib/Organization/Explorer/org_explorer_screen.dart
//
// Organisation explorer (ORG_HANDOFF §3.8, F). Search, sector chips, org rows
// (logo, verified, what + distance, next event). Distance shows only when
// location permission is already granted — the explorer never prompts.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../theme/canopy_components.dart';
import 'org_view_screen.dart';

const _sectors = [
  ('sector_env', 'Environmental'),
  ('sector_social', 'Social'),
  ('sector_health', 'Health'),
  ('sector_education', 'Education'),
  ('sector_economic', 'Economic'),
  ('sector_community', 'Community'),
  ('sector_faith', 'Faith'),
];

String _sectorLabel(String id) => const {
      'sector_env': 'Environmental',
      'sector_social': 'Social services',
      'sector_health': 'Health',
      'sector_education': 'Education',
      'sector_economic': 'Economic',
      'sector_legal': 'Legal aid',
      'sector_faith': 'Faith-based',
      'sector_community': 'Community',
    }[id] ??
    '';

class OrgExplorerScreen extends StatefulWidget {
  const OrgExplorerScreen({super.key});

  @override
  State<OrgExplorerScreen> createState() => _OrgExplorerScreenState();
}

class _OrgExplorerScreenState extends State<OrgExplorerScreen> {
  String? _sector;
  String _query = '';
  Position? _here;
  Map<String, (String, DateTime)> _nextEvent = const {};
  late Stream<QuerySnapshot<Map<String, dynamic>>> _orgs =
      FirebaseFirestore.instance.collection('organizations').snapshots();

  @override
  void initState() {
    super.initState();
    _locate();
    _loadNextEvents();
  }

  Future<void> _locate() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
      final pos = await Geolocator.getLastKnownPosition();
      if (mounted && pos != null) setState(() => _here = pos);
    } catch (_) {}
  }

  /// One index-free range query: every upcoming activity, earliest per org.
  Future<void> _loadNextEvents() async {
    try {
      final s = await FirebaseFirestore.instance
          .collection('activities')
          .where('dateTime', isGreaterThan: Timestamp.now())
          .get();
      final next = <String, (String, DateTime)>{};
      for (final d in s.docs) {
        final m = d.data();
        final org = m['orgId'] as String?;
        final at = (m['dateTime'] as Timestamp?)?.toDate();
        final status = m['status'] as String? ?? '';
        if (org == null || org.isEmpty || at == null || status == 'draft' || status == 'cancelled') continue;
        if (next[org] == null || at.isBefore(next[org]!.$2)) {
          next[org] = (((m['title'] ?? m['name'] ?? 'Event') as String), at);
        }
      }
      if (mounted) setState(() => _nextEvent = next);
    } catch (_) {}
  }

  double? _km(Map<String, dynamic> d) {
    final here = _here;
    if (here == null) return null;
    final gp = d['location'];
    final lat = gp is GeoPoint ? gp.latitude : (d['lat'] as num?)?.toDouble();
    final lng = gp is GeoPoint ? gp.longitude : (d['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(here.latitude, here.longitude, lat, lng) / 1000;
  }

  @override
  Widget build(BuildContext context) {
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Organisations'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s4, CanopySpace.gutter, CanopySpace.s8),
          child: CanopyTextField.search(
            hint: 'Search by name, place or what they do',
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        CanopyChipRail(chips: [
          CanopyFilterChip(label: 'All', selected: _sector == null, onTap: () => setState(() => _sector = null)),
          for (final s in _sectors)
            CanopyFilterChip(
              label: s.$2,
              selected: _sector == s.$1,
              onTap: () => setState(() => _sector = _sector == s.$1 ? null : s.$1),
            ),
        ]),
        const SizedBox(height: CanopySpace.s8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _orgs,
            builder: (context, snap) {
              if (snap.hasError) {
                return CanopyErrorState(
                  title: "Couldn't load organisations",
                  onRetry: () => setState(() => _orgs = FirebaseFirestore.instance.collection('organizations').snapshots()),
                );
              }
              if (!snap.hasData) {
                return ListView(
                    padding: const EdgeInsets.all(CanopySpace.gutter),
                    children: const [CanopyListSkeleton(rows: 6, leadingSize: 48)]);
              }
              var docs = snap.data!.docs.where((d) {
                final m = d.data();
                if (_sector != null && m['sectorId'] != _sector) return false;
                if (_query.isEmpty) return true;
                final hay = [m['org_name'], m['name'], m['city'], m['area'], m['orgDesignation'], m['background'], m['description']]
                    .whereType<String>()
                    .join(' ')
                    .toLowerCase();
                return hay.contains(_query);
              }).toList();
              // Nearest first when we know where you are; otherwise A–Z.
              docs.sort((a, b) {
                final ka = _km(a.data()), kb = _km(b.data());
                if (ka != null && kb != null) return ka.compareTo(kb);
                if (ka != null) return -1;
                if (kb != null) return 1;
                String n(Map<String, dynamic> m) => ((m['org_name'] ?? m['name'] ?? '') as String).toLowerCase();
                return n(a.data()).compareTo(n(b.data()));
              });
              if (docs.isEmpty) {
                return CanopyEmptyState(
                  icon: Icons.apartment_outlined,
                  title: _query.isEmpty && _sector == null ? 'No organisations yet' : 'No organisations match',
                  actionLabel: _query.isEmpty && _sector == null ? null : 'Clear filters',
                  onAction: () => setState(() => _sector = null),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32),
                children: [
                  CanopyListGroup(children: [for (final d in docs) _row(d.id, d.data())]),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _row(String id, Map<String, dynamic> m) {
    final p = context.canopy;
    final name = ((m['org_name'] ?? m['name'] ?? 'Organisation') as String).trim();
    final what = [
      ((m['orgDesignation'] ?? m['designation'] ?? '') as String).trim(),
      _sectorLabel(m['sectorId'] as String? ?? ''),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final km = _km(m);
    final where = km != null
        ? (km < 1 ? '${(km * 1000).round()} m away' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away')
        : [m['area'], m['city']].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    final next = _nextEvent[id];
    return CanopyListRow(
      leading: CanopyAvatar(url: (m['logoUrl'] ?? m['profilePhoto']) as String?, name: name, size: 48, org: true),
      title: name,
      subtitle: [what, where].where((s) => s.isNotEmpty).join(' · '),
      trailing: m['verified'] == true ? Icon(Icons.verified, size: 18, color: p.primary) : null,
      below: next == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: CanopySpace.s4),
              child: Row(children: [
                Icon(Icons.event_outlined, size: 14, color: p.inkMuted),
                const SizedBox(width: CanopySpace.s4),
                Expanded(
                  child: Text('Next: ${next.$1} · ${DateFormat('EEE d MMM').format(next.$2)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: CanopyType.caption.copyWith(color: p.inkMuted)),
                ),
              ]),
            ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrgViewScreen(orgId: id, orgData: m))),
    );
  }
}
