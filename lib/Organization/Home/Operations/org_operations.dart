import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../Shared/theme/app_theme.dart';
import '../../../Shared/Activities/create_activity.dart';
import 'send_partnership_request.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class OrgOperations extends StatefulWidget {
  const OrgOperations({super.key});

  @override
  State<OrgOperations> createState() => _OrgOperationsState();
}

class _OrgOperationsState extends State<OrgOperations>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _orgId;
  bool _orgLoaded = false;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadOrgId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrgId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _orgLoaded = true);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final orgId = doc.exists
          ? (doc.data() as Map<String, dynamic>)['orgId'] as String?
          : null;
      setState(() {
        _orgId = orgId;
        _orgLoaded = true;
      });
    } catch (e) {
      debugPrint('OrgOperations._loadOrgId error: $e');
      if (mounted) setState(() => _orgLoaded = true);
    }
  }

  void _refresh() => setState(() => _refreshKey++);

  void _onAdd() {
    switch (_tabController.index) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
        );
        break;
      case 1:
        if (_orgId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SendPartnershipRequestScreen(orgId: _orgId!),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Operations',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkGreen,
                        height: 1.1,
                      ),
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: _refresh,
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.add_rounded,
                    gradient: true,
                    onTap: _onAdd,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tab bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.darkGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.55),
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Events'),
                    Tab(text: 'Partners'),
                    Tab(text: 'Broadcast'),
                    Tab(text: 'Impact'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // ── Tab views ────────────────────────────────────────────
            Expanded(
              child: !_orgLoaded
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2))
                  : _orgId == null
                      ? Center(
                          child: Text(
                            'No organisation linked to this account',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkGreen.withOpacity(0.45)),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _EventsTab(
                                orgId: _orgId!,
                                key: ValueKey('ev-$_refreshKey')),
                            _PartnersTab(
                                orgId: _orgId!,
                                key: ValueKey('pa-$_refreshKey')),
                            _BroadcastTab(
                                orgId: _orgId!,
                                key: ValueKey('bc-$_refreshKey')),
                            _ImpactTab(
                                orgId: _orgId!,
                                key: ValueKey('im-$_refreshKey')),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  final String orgId;
  const _EventsTab({super.key, required this.orgId});

  static String _stage(Map<String, dynamic> d) {
    final status = d['status'] as String? ?? '';
    final impact = d['impactStatus'] as String? ?? '';
    if (impact == 'confirmed') return 'onChain';
    if (status == 'completed' && impact == 'pending') return 'verifying';
    if (status == 'ongoing') return 'executing';
    if (status == 'upcoming') return 'active';
    return 'draft';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('orgId', isEqualTo: orgId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No events yet',
            subtitle: 'Create your first event to mobilise volunteers',
            actionLabel: 'Create Event',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
            ),
          );
        }

        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final s = _stage(data);
          grouped.putIfAbsent(s, () => []).add(data);
        }

        final counts = {
          'draft': grouped['draft']?.length ?? 0,
          'active': grouped['active']?.length ?? 0,
          'executing': grouped['executing']?.length ?? 0,
          'verifying': grouped['verifying']?.length ?? 0,
          'onChain': grouped['onChain']?.length ?? 0,
        };

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _EventPipelineStrip(counts: counts),
            const SizedBox(height: 16),
            if ((grouped['executing'] ?? []).isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.play_circle_outline,
                  label: 'Executing Now',
                  color: AppTheme.accent),
              ...grouped['executing']!
                  .map((d) => _EventCard(data: d, stage: 'executing')),
              const SizedBox(height: 4),
            ],
            if ((grouped['verifying'] ?? []).isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.fact_check_outlined,
                  label: 'In Verification',
                  color: AppTheme.tertiary),
              ...grouped['verifying']!
                  .map((d) => _EventCard(data: d, stage: 'verifying')),
              const SizedBox(height: 4),
            ],
            if ((grouped['active'] ?? []).isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.event_available_outlined,
                  label: 'Upcoming',
                  color: AppTheme.primary),
              ...grouped['active']!
                  .map((d) => _EventCard(data: d, stage: 'active')),
              const SizedBox(height: 4),
            ],
            if ((grouped['draft'] ?? []).isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.edit_outlined,
                  label: 'Drafts',
                  color: AppTheme.lightGreen),
              ...grouped['draft']!
                  .map((d) => _EventCard(data: d, stage: 'draft')),
              const SizedBox(height: 4),
            ],
            if ((grouped['onChain'] ?? []).isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.verified_outlined,
                  label: 'On-Chain',
                  color: Colors.teal.shade600,
                  subtitle: 'Permanently recorded'),
              ...grouped['onChain']!
                  .map((d) => _EventCard(data: d, stage: 'onChain')),
            ],
          ],
        );
      },
    );
  }
}

class _EventPipelineStrip extends StatelessWidget {
  final Map<String, int> counts;
  const _EventPipelineStrip({required this.counts});

  @override
  Widget build(BuildContext context) {
    final stages = ['draft', 'active', 'executing', 'verifying', 'onChain'];
    final labels = ['Draft', 'Active', 'Running', 'Verify', 'Done'];
    final colors = [
      AppTheme.lightGreen,
      AppTheme.primary,
      AppTheme.accent,
      AppTheme.tertiary,
      Colors.teal.shade600,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Pipeline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(stages.length, (i) {
              final count = counts[stages[i]] ?? 0;
              final isLast = i == stages.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? colors[i].withOpacity(0.12)
                                  : Colors.grey.withOpacity(0.06),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: count > 0
                                    ? colors[i].withOpacity(0.4)
                                    : Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: count > 0
                                      ? colors[i]
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: count > 0
                                  ? colors[i]
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Container(
                          width: 16,
                          height: 1,
                          color: AppTheme.lightGreen.withOpacity(0.3)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String stage;
  const _EventCard({required this.data, required this.stage});

  Color get _stageColor {
    switch (stage) {
      case 'draft':
        return AppTheme.lightGreen;
      case 'active':
        return AppTheme.primary;
      case 'executing':
        return AppTheme.accent;
      case 'verifying':
        return AppTheme.tertiary;
      default:
        return Colors.teal.shade600;
    }
  }

  String get _stageLabel {
    switch (stage) {
      case 'draft':
        return 'Draft';
      case 'active':
        return 'Upcoming';
      case 'executing':
        return 'Running';
      case 'verifying':
        return 'Verifying';
      default:
        return 'On-Chain';
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (dt == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Untitled';
    final location = data['location'] as String? ?? '';
    final participants = data['participants'] as int? ?? 0;
    final maxParticipants = data['maxParticipants'] as int? ?? 0;
    final bountyAmount = (data['bountyAmount'] as num?)?.toDouble();
    final txHash = data['txHash'] as String?;
    final pct = maxParticipants > 0
        ? (participants / maxParticipants).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stage == 'onChain'
              ? Colors.teal.withOpacity(0.2)
              : AppTheme.lightGreen.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: _stageColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _stageColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.eco_outlined, size: 16, color: _stageColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (location.isNotEmpty) ...[
                          Icon(Icons.location_on_outlined,
                              size: 11,
                              color: AppTheme.darkGreen.withOpacity(0.4)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.darkGreen.withOpacity(0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.calendar_today_outlined,
                            size: 11,
                            color: AppTheme.darkGreen.withOpacity(0.4)),
                        const SizedBox(width: 3),
                        Text(
                          _formatDate(data['date']),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _stageColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _stageColor.withOpacity(0.3)),
                ),
                child: Text(
                  _stageLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _stageColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$participants/$maxParticipants volunteers',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _stageColor,
                ),
              ),
              const Spacer(),
              if (bountyAmount != null && bountyAmount > 0)
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 11, color: AppTheme.tertiary),
                    const SizedBox(width: 3),
                    Text(
                      'KES ${bountyAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.tertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: _stageColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_stageColor),
            ),
          ),
          if (txHash != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link_rounded,
                    size: 11, color: Colors.teal.shade600),
                const SizedBox(width: 4),
                Text(
                  'TX: $txHash',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade600,
                  ),
                ),
                const Spacer(),
                Text(
                  'View on chain →',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTNERS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _PartnersTab extends StatelessWidget {
  final String orgId;
  const _PartnersTab({super.key, required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orgPartners')
          .where('orgId', isEqualTo: orgId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.handshake_outlined,
            title: 'No partners yet',
            subtitle:
                'Invite another organisation to collaborate on events and programmes',
            actionLabel: 'Send Partnership Request',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SendPartnershipRequestScreen(orgId: orgId),
              ),
            ),
          );
        }

        final active = docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['status'] == 'active')
            .toList();
        final pending = docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['status'] == 'pending')
            .toList();
        final invited = docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['status'] == 'invited')
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            // Stats row
            _MiniStatsRow(items: [
              _MiniStat(
                  label: 'Active',
                  value: '${active.length}',
                  color: AppTheme.primary),
              _MiniStat(
                  label: 'Pending',
                  value: '${pending.length}',
                  color: AppTheme.tertiary),
              _MiniStat(
                  label: 'Invited',
                  value: '${invited.length}',
                  color: AppTheme.lightGreen),
            ]),
            const SizedBox(height: 8),

            if (pending.isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.hourglass_top_outlined,
                  label: 'Awaiting Your Response',
                  color: AppTheme.tertiary),
              ...pending.map((d) => _PartnerCard(
                    docId: d.id,
                    data: d.data() as Map<String, dynamic>,
                  )),
              const SizedBox(height: 4),
            ],
            if (active.isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.handshake_outlined,
                  label: 'Active Partners',
                  color: AppTheme.primary),
              ...active.map((d) => _PartnerCard(
                    docId: d.id,
                    data: d.data() as Map<String, dynamic>,
                  )),
              const SizedBox(height: 4),
            ],
            if (invited.isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.mail_outline_rounded,
                  label: 'Invitations Sent',
                  color: AppTheme.lightGreen),
              ...invited.map((d) => _PartnerCard(
                    docId: d.id,
                    data: d.data() as Map<String, dynamic>,
                  )),
            ],
            const SizedBox(height: 16),
            _OutlineButton(
              label: 'Send Partnership Request',
              icon: Icons.add_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SendPartnershipRequestScreen(orgId: orgId),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _PartnerCard({required this.docId, required this.data});

  String get _status => data['status'] as String? ?? 'invited';
  String get _name => data['partnerName'] as String? ?? 'Unknown';
  String get _sector => data['partnerSector'] as String? ?? '';
  int get _shared => data['sharedEvents'] as int? ?? 0;

  String get _initials {
    final parts = _name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _name.isNotEmpty ? _name[0].toUpperCase() : '?';
  }

  Color get _statusColor {
    switch (_status) {
      case 'active':
        return AppTheme.primary;
      case 'pending':
        return AppTheme.tertiary;
      default:
        return AppTheme.lightGreen;
    }
  }

  Future<void> _updateStatus(String newStatus) =>
      FirebaseFirestore.instance
          .collection('orgPartners')
          .doc(docId)
          .update({'status': newStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Initials circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: _statusColor.withOpacity(0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (_sector.isNotEmpty)
                          Text(
                            _sector,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.darkGreen.withOpacity(0.5)),
                          ),
                        if (_shared > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.event_outlined,
                              size: 11,
                              color: AppTheme.darkGreen.withOpacity(0.4)),
                          const SizedBox(width: 3),
                          Text(
                            '$_shared shared events',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.darkGreen.withOpacity(0.5)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action buttons per status
          if (_status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SmallActionButton(
                    label: 'Accept',
                    color: AppTheme.primary,
                    onTap: () => _updateStatus('active'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallActionButton(
                    label: 'Review',
                    color: AppTheme.tertiary,
                    onTap: () => _showMessageDialog(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallActionButton(
                    label: 'Decline',
                    color: Colors.redAccent,
                    onTap: () => _confirmDecline(context),
                  ),
                ),
              ],
            ),
          ] else if (_status == 'active') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SmallActionButton(
                    label: 'Contact',
                    color: AppTheme.primary,
                    onTap: () => _showMessageDialog(context),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SmallActionButton(
                    label: 'Cancel Invite',
                    color: AppTheme.darkGreen.withOpacity(0.5),
                    onTap: () => _confirmDecline(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showMessageDialog(BuildContext context) {
    final msg = data['message'] as String? ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_name,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen)),
        content: msg.isNotEmpty
            ? Text(msg,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.7)))
            : Text('No message provided.',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.4))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDecline(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen)),
        content: Text(
            _status == 'pending'
                ? 'Decline partnership request from $_name?'
                : 'Cancel invitation to $_name?',
            style: TextStyle(
                fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseFirestore.instance
                  .collection('orgPartners')
                  .doc(docId)
                  .delete();
            },
            child: const Text('Confirm',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BROADCAST TAB
// ─────────────────────────────────────────────────────────────────────────────

class _BroadcastTab extends StatefulWidget {
  final String orgId;
  const _BroadcastTab({super.key, required this.orgId});

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final _bodyController = TextEditingController();
  String _reach = 'followers';
  bool _sending = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _bodyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'orgId': widget.orgId,
        'body': text,
        'reach': _reach,
        'sentAt': FieldValue.serverTimestamp(),
        'recipientCount': 0,
      });
      _bodyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Announcement sent'),
              backgroundColor: AppTheme.primary),
        );
      }
    } catch (e) {
      debugPrint('Broadcast error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Compose card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.darkGreen, AppTheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkGreen.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign_outlined,
                      color: Colors.white.withOpacity(0.9), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'New Announcement',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write your announcement...',
                  hintStyle:
                      TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.12),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ReachChip(
                    label: 'Followers',
                    active: _reach == 'followers',
                    onTap: () => setState(() => _reach = 'followers'),
                  ),
                  const SizedBox(width: 6),
                  _ReachChip(
                    label: 'Nearby',
                    active: _reach == 'nearby',
                    onTap: () => setState(() => _reach = 'nearby'),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.darkGreen),
                            )
                          : const Text(
                              'Send',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkGreen,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // History
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .where('orgId', isEqualTo: widget.orgId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              // sort client-side — avoid composite index
              final sorted = List.of(docs)
                ..sort((a, b) {
                  final at = (a.data() as Map)['sentAt'];
                  final bt = (b.data() as Map)['sentAt'];
                  if (at is Timestamp && bt is Timestamp) {
                    return bt.compareTo(at);
                  }
                  return 0;
                });

              if (sorted.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _EmptyState(
                    icon: Icons.history_outlined,
                    title: 'No announcements yet',
                    subtitle: 'Your sent announcements will appear here',
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                      icon: Icons.history_outlined,
                      label: 'Sent Announcements',
                      color: AppTheme.primary),
                  ...sorted.map((d) => _AnnouncementCard(
                      data: d.data() as Map<String, dynamic>)),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ReachChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ReachChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnnouncementCard({required this.data});

  String _timeAgo(dynamic raw) {
    if (raw == null) return '';
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final body = data['body'] as String? ?? '';
    final reach = data['reach'] as String? ?? 'followers';
    final recipients = data['recipientCount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeAgo(data['sentAt']),
                style: TextStyle(
                    fontSize: 10, color: AppTheme.darkGreen.withOpacity(0.4)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_outline,
                  size: 12, color: AppTheme.darkGreen.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text(
                '$recipients reached',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  reach[0].toUpperCase() + reach.substring(1),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPACT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactTab extends StatelessWidget {
  final String orgId;
  const _ImpactTab({super.key, required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('orgId', isEqualTo: orgId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2));
        }

        final all = snapshot.data?.docs ?? [];
        final verified = all
            .where((d) =>
                (d.data() as Map<String, dynamic>)['impactStatus'] ==
                'confirmed')
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            // On-chain summary
            _OnChainSummaryCard(totalRecords: verified.length),
            const SizedBox(height: 16),

            if (verified.isEmpty)
              _EmptyState(
                icon: Icons.verified_outlined,
                title: 'No verified records yet',
                subtitle:
                    'Impact records appear here once an event passes verification',
              )
            else ...[
              _SectionHeader(
                icon: Icons.verified_outlined,
                label: 'Verified Records',
                color: Colors.teal.shade600,
                subtitle: 'Permanently anchored',
              ),
              ...verified.map((d) => _ImpactRecordCard(
                  data: d.data() as Map<String, dynamic>)),
            ],
          ],
        );
      },
    );
  }
}

class _OnChainSummaryCard extends StatelessWidget {
  final int totalRecords;
  const _OnChainSummaryCard({required this.totalRecords});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade700,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded,
                  color: Colors.white.withOpacity(0.85), size: 18),
              const SizedBox(width: 8),
              const Text(
                'On-Chain Summary',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cardano',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _OnChainStat(value: '$totalRecords', label: 'Records'),
              _VertDivider(),
              const _OnChainStat(value: '—', label: 'Plastic'),
              _VertDivider(),
              const _OnChainStat(value: '—', label: 'Trees'),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnChainStat extends StatelessWidget {
  final String value;
  final String label;
  const _OnChainStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15));
  }
}

class _ImpactRecordCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ImpactRecordCard({required this.data});

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (dt == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Untitled';
    final type = data['type'] as String? ?? '';
    final location = data['location'] as String? ?? '';
    final txHash = data['txHash'] as String? ?? '';
    final metrics = (data['metrics'] as Map?)?.cast<String, dynamic>() ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.teal.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.verified_outlined,
                    size: 15, color: Colors.teal.shade600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (type.isNotEmpty)
                          Text(type,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade600,
                                  fontWeight: FontWeight.w600)),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('· $location',
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      AppTheme.darkGreen.withOpacity(0.45))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(_formatDate(data['date']),
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.darkGreen.withOpacity(0.4))),
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: metrics.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.lightGreen.withOpacity(0.2)),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${e.value} ',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen),
                        ),
                        TextSpan(
                          text: e.key,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.darkGreen.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (txHash.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.link_rounded,
                    size: 12, color: Colors.teal.shade600),
                const SizedBox(width: 5),
                Text(txHash,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade600)),
                const Spacer(),
                Text('View on Cardano →',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lightGreen.withOpacity(0.18),
                    AppTheme.accent.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon,
                  size: 34, color: AppTheme.lightGreen.withOpacity(0.7)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.darkGreen.withOpacity(0.45),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.darkGreen, AppTheme.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.darkGreen.withOpacity(0.4),
                        fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: color.withOpacity(0.12)),
          ),
        ],
      ),
    );
  }
}

class _MiniStatsRow extends StatelessWidget {
  final List<_MiniStat> items;
  const _MiniStatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: Column(
              children: [
                Text(item.value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: item.color)),
                const SizedBox(height: 2),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.darkGreen.withOpacity(0.45))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MiniStat {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallActionButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool gradient;
  const _IconBtn({required this.icon, required this.onTap, this.gradient = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: gradient
              ? const LinearGradient(
                  colors: [AppTheme.darkGreen, AppTheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: gradient ? null : AppTheme.lightGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          boxShadow: gradient
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(icon,
            size: 18,
            color: gradient
                ? Colors.white
                : AppTheme.darkGreen.withOpacity(0.7)),
      ),
    );
  }
}
