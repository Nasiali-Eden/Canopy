import 'package:flutter/material.dart';
import '../../../Shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum EventStage { draft, active, executing, verifying, onChain }

enum EventType { cleanup, treePlanting, training, awareness, waterway }

enum PartnerStatus { active, pending, invited }

enum AnnouncementReach { followers, nearby, both }

class OrgEvent {
  final String id;
  final String title;
  final EventType type;
  final EventStage stage;
  final DateTime dateTime;
  final String area;
  final int volunteersNeeded;
  final int volunteersConfirmed;
  final bool bountyAttached;
  final double? bountyAmount;
  final String? txHash;

  const OrgEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.stage,
    required this.dateTime,
    required this.area,
    required this.volunteersNeeded,
    required this.volunteersConfirmed,
    this.bountyAttached = false,
    this.bountyAmount,
    this.txHash,
  });
}

class OrgPartner {
  final String id;
  final String name;
  final String sector;
  final PartnerStatus status;
  final int sharedEvents;
  final String? logoInitials;

  const OrgPartner({
    required this.id,
    required this.name,
    required this.sector,
    required this.status,
    required this.sharedEvents,
    this.logoInitials,
  });
}

class OrgAnnouncement {
  final String id;
  final String title;
  final String preview;
  final DateTime sentAt;
  final AnnouncementReach reach;
  final int recipientCount;

  const OrgAnnouncement({
    required this.id,
    required this.title,
    required this.preview,
    required this.sentAt,
    required this.reach,
    required this.recipientCount,
  });
}

class VerifiedImpactRecord {
  final String id;
  final String title;
  final String type;
  final DateTime confirmedAt;
  final String area;
  final String txHash;
  final Map<String, String> metrics;

  const VerifiedImpactRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.confirmedAt,
    required this.area,
    required this.txHash,
    required this.metrics,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER DATA
// ─────────────────────────────────────────────────────────────────────────────

final _kEvents = [
  OrgEvent(
    id: 'e1',
    title: 'Soweto West River Cleanup',
    type: EventType.cleanup,
    stage: EventStage.executing,
    dateTime: DateTime(2026, 5, 24, 7, 0),
    area: 'Soweto West',
    volunteersNeeded: 30,
    volunteersConfirmed: 24,
    bountyAttached: true,
    bountyAmount: 15000,
  ),
  OrgEvent(
    id: 'e2',
    title: 'Karura Reforestation Drive',
    type: EventType.treePlanting,
    stage: EventStage.active,
    dateTime: DateTime(2026, 6, 1, 8, 0),
    area: 'Gigiri',
    volunteersNeeded: 50,
    volunteersConfirmed: 31,
    bountyAttached: true,
    bountyAmount: 22000,
  ),
  OrgEvent(
    id: 'e3',
    title: 'Waste Sorting Training',
    type: EventType.training,
    stage: EventStage.draft,
    dateTime: DateTime(2026, 6, 7, 9, 0),
    area: 'Laini Saba',
    volunteersNeeded: 20,
    volunteersConfirmed: 0,
    bountyAttached: false,
  ),
  OrgEvent(
    id: 'e4',
    title: 'Makina Waterway Clearance',
    type: EventType.waterway,
    stage: EventStage.verifying,
    dateTime: DateTime(2026, 5, 15, 6, 30),
    area: 'Makina',
    volunteersNeeded: 40,
    volunteersConfirmed: 40,
    bountyAttached: true,
    bountyAmount: 18000,
  ),
  OrgEvent(
    id: 'e5',
    title: 'Gatwekera Dumpsite Cleanup',
    type: EventType.cleanup,
    stage: EventStage.onChain,
    dateTime: DateTime(2026, 4, 20, 7, 0),
    area: 'Gatwekera',
    volunteersNeeded: 35,
    volunteersConfirmed: 35,
    bountyAttached: true,
    bountyAmount: 12000,
    txHash: '0x7f3a...c91b',
  ),
];

const _kPartners = [
  OrgPartner(
    id: 'p1',
    name: 'Mtaa Safi Initiative',
    sector: 'Environmental',
    status: PartnerStatus.active,
    sharedEvents: 8,
    logoInitials: 'MS',
  ),
  OrgPartner(
    id: 'p2',
    name: 'Kibera Digital Village',
    sector: 'Technology',
    status: PartnerStatus.active,
    sharedEvents: 3,
    logoInitials: 'KD',
  ),
  OrgPartner(
    id: 'p3',
    name: 'Green Youth Collective',
    sector: 'Youth',
    status: PartnerStatus.pending,
    sharedEvents: 0,
    logoInitials: 'GY',
  ),
  OrgPartner(
    id: 'p4',
    name: 'Nairobi Urban Farms',
    sector: 'Agriculture',
    status: PartnerStatus.invited,
    sharedEvents: 0,
    logoInitials: 'NF',
  ),
];

final _kAnnouncements = [
  OrgAnnouncement(
    id: 'a1',
    title: 'Cleanup this Saturday — Join Us!',
    preview:
    'We are heading to Soweto West river on Saturday at 7am. Bring gloves...',
    sentAt: DateTime(2026, 5, 20, 10, 30),
    reach: AnnouncementReach.both,
    recipientCount: 312,
  ),
  OrgAnnouncement(
    id: 'a2',
    title: 'New tree planting slots open',
    preview:
    'Karura reforestation drive has new volunteer slots available for June 1st...',
    sentAt: DateTime(2026, 5, 18, 14, 0),
    reach: AnnouncementReach.followers,
    recipientCount: 148,
  ),
  OrgAnnouncement(
    id: 'a3',
    title: 'Makina waterway — verified complete',
    preview:
    'The Makina waterway clearance has passed verification. Thank you to all...',
    sentAt: DateTime(2026, 5, 16, 9, 0),
    reach: AnnouncementReach.both,
    recipientCount: 290,
  ),
];

final _kImpactRecords = [
  VerifiedImpactRecord(
    id: 'ir1',
    title: 'Gatwekera Dumpsite Transformation',
    type: 'Dumpsite Clearance',
    confirmedAt: DateTime(2026, 5, 19),
    area: 'Gatwekera',
    txHash: '0x7f3a...c91b',
    metrics: {
      'Plastic Diverted': '4.2 tonnes',
      'Site Area': '1,200 m²',
      'Verifiers': '6',
      'Days Monitored': '30',
    },
  ),
  VerifiedImpactRecord(
    id: 'ir2',
    title: 'Laini Saba Tree Planting',
    type: 'Urban Greening',
    confirmedAt: DateTime(2026, 4, 10),
    area: 'Laini Saba',
    txHash: '0x2c8d...f04e',
    metrics: {
      'Trees Planted': '120',
      'Survival Rate': '94%',
      'Volunteers': '38',
      'Days Monitored': '90',
    },
  ),
];

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Operations',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_kEvents.where((e) => e.stage != EventStage.onChain).length} active · '
                              '${_kPartners.where((p) => p.status == PartnerStatus.active).length} partners · '
                              '${_kImpactRecords.length} on-chain records',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGreen.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _GradientIconButton(
                    icon: Icons.add_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tabs ─────────────────────────────────────────────────
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
                  unselectedLabelColor:
                  AppTheme.darkGreen.withOpacity(0.55),
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
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _EventsTab(),
                  _PartnersTab(),
                  _BroadcastTab(),
                  _ImpactTab(),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: _ContextFab(tabIndex: _tabController.index),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  const _EventsTab();

  @override
  Widget build(BuildContext context) {
    // Group by stage
    final draft =
    _kEvents.where((e) => e.stage == EventStage.draft).toList();
    final active =
    _kEvents.where((e) => e.stage == EventStage.active).toList();
    final executing =
    _kEvents.where((e) => e.stage == EventStage.executing).toList();
    final verifying =
    _kEvents.where((e) => e.stage == EventStage.verifying).toList();
    final onChain =
    _kEvents.where((e) => e.stage == EventStage.onChain).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Pipeline overview
        _EventPipelineStrip(events: _kEvents),
        const SizedBox(height: 16),

        if (executing.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.play_circle_outline,
              label: 'Executing Now',
              color: AppTheme.accent),
          ...executing.map((e) => _EventCard(event: e)),
          const SizedBox(height: 4),
        ],
        if (verifying.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.fact_check_outlined,
              label: 'In Verification',
              color: AppTheme.tertiary),
          ...verifying.map((e) => _EventCard(event: e)),
          const SizedBox(height: 4),
        ],
        if (active.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.event_available_outlined,
              label: 'Upcoming',
              color: AppTheme.primary),
          ...active.map((e) => _EventCard(event: e)),
          const SizedBox(height: 4),
        ],
        if (draft.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.edit_outlined,
              label: 'Drafts',
              color: AppTheme.lightGreen),
          ...draft.map((e) => _EventCard(event: e)),
          const SizedBox(height: 4),
        ],
        if (onChain.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.verified_outlined,
              label: 'On-Chain',
              color: Colors.teal.shade600,
              subtitle: 'Permanently recorded'),
          ...onChain.map((e) => _EventCard(event: e)),
        ],
      ],
    );
  }
}

class _EventPipelineStrip extends StatelessWidget {
  final List<OrgEvent> events;
  const _EventPipelineStrip({required this.events});

  @override
  Widget build(BuildContext context) {
    final stages = [
      EventStage.draft,
      EventStage.active,
      EventStage.executing,
      EventStage.verifying,
      EventStage.onChain,
    ];
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
              final count =
                  events.where((e) => e.stage == stages[i]).length;
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
                        color: AppTheme.lightGreen.withOpacity(0.3),
                      ),
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
  final OrgEvent event;
  const _EventCard({required this.event});

  Color get _stageColor {
    switch (event.stage) {
      case EventStage.draft:
        return AppTheme.lightGreen;
      case EventStage.active:
        return AppTheme.primary;
      case EventStage.executing:
        return AppTheme.accent;
      case EventStage.verifying:
        return AppTheme.tertiary;
      case EventStage.onChain:
        return Colors.teal.shade600;
    }
  }

  String get _stageLabel {
    switch (event.stage) {
      case EventStage.draft:
        return 'Draft';
      case EventStage.active:
        return 'Upcoming';
      case EventStage.executing:
        return 'Running';
      case EventStage.verifying:
        return 'Verifying';
      case EventStage.onChain:
        return 'On-Chain';
    }
  }

  IconData get _typeIcon {
    switch (event.type) {
      case EventType.cleanup:
        return Icons.cleaning_services_outlined;
      case EventType.treePlanting:
        return Icons.park_outlined;
      case EventType.training:
        return Icons.school_outlined;
      case EventType.awareness:
        return Icons.campaign_outlined;
      case EventType.waterway:
        return Icons.water_outlined;
    }
  }

  String _formatDate(DateTime dt) {
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
    final pct = event.volunteersNeeded > 0
        ? (event.volunteersConfirmed / event.volunteersNeeded)
        .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: event.stage == EventStage.onChain
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
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _stageColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon, size: 16, color: _stageColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
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
                        Icon(Icons.location_on_outlined,
                            size: 11,
                            color: AppTheme.darkGreen.withOpacity(0.4)),
                        const SizedBox(width: 3),
                        Text(
                          event.area,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_outlined,
                            size: 11,
                            color: AppTheme.darkGreen.withOpacity(0.4)),
                        const SizedBox(width: 3),
                        Text(
                          _formatDate(event.dateTime),
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
              // Stage badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _stageColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                  Border.all(color: _stageColor.withOpacity(0.3)),
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

          // Volunteer progress
          Row(
            children: [
              Text(
                '${event.volunteersConfirmed}/${event.volunteersNeeded} volunteers',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _stageColor,
                ),
              ),
              const Spacer(),
              if (event.bountyAttached && event.bountyAmount != null)
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 11, color: AppTheme.tertiary),
                    const SizedBox(width: 3),
                    Text(
                      'KES ${event.bountyAmount!.toStringAsFixed(0)}',
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

          // On-chain tx hash
          if (event.txHash != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link_rounded,
                    size: 11, color: Colors.teal.shade600),
                const SizedBox(width: 4),
                Text(
                  'TX: ${event.txHash}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade600,
                    fontFamily: 'monospace',
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
  const _PartnersTab();

  @override
  Widget build(BuildContext context) {
    final active =
    _kPartners.where((p) => p.status == PartnerStatus.active).toList();
    final pending = _kPartners
        .where((p) => p.status == PartnerStatus.pending)
        .toList();
    final invited = _kPartners
        .where((p) => p.status == PartnerStatus.invited)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Stats
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
          _MiniStat(
              label: 'Shared Events',
              value:
              '${_kPartners.fold(0, (s, p) => s + p.sharedEvents)}',
              color: AppTheme.accent),
        ]),
        const SizedBox(height: 8),

        if (active.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.handshake_outlined,
              label: 'Active Partners',
              color: AppTheme.primary),
          ...active.map((p) => _PartnerCard(partner: p)),
          const SizedBox(height: 4),
        ],
        if (pending.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.hourglass_top_outlined,
              label: 'Pending Approval',
              color: AppTheme.tertiary),
          ...pending.map((p) => _PartnerCard(partner: p)),
          const SizedBox(height: 4),
        ],
        if (invited.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.mail_outline_rounded,
              label: 'Invited',
              color: AppTheme.lightGreen),
          ...invited.map((p) => _PartnerCard(partner: p)),
        ],
      ],
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final OrgPartner partner;
  const _PartnerCard({required this.partner});

  Color get _statusColor {
    switch (partner.status) {
      case PartnerStatus.active:
        return AppTheme.primary;
      case PartnerStatus.pending:
        return AppTheme.tertiary;
      case PartnerStatus.invited:
        return AppTheme.lightGreen;
    }
  }

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
      child: Row(
        children: [
          // Logo initials circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _statusColor.withOpacity(0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                partner.logoInitials ?? '??',
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
                  partner.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      partner.sector,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkGreen.withOpacity(0.5),
                      ),
                    ),
                    if (partner.sharedEvents > 0) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.event_outlined,
                          size: 11,
                          color: AppTheme.darkGreen.withOpacity(0.4)),
                      const SizedBox(width: 3),
                      Text(
                        '${partner.sharedEvents} shared events',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Action button
          if (partner.status == PartnerStatus.active)
            _SmallActionButton(
                label: 'View',
                color: AppTheme.primary,
                onTap: () {})
          else if (partner.status == PartnerStatus.pending)
            _SmallActionButton(
                label: 'Approve',
                color: AppTheme.tertiary,
                onTap: () {})
          else
            _SmallActionButton(
                label: 'Resend',
                color: AppTheme.lightGreen,
                onTap: () {}),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BROADCAST TAB
// ─────────────────────────────────────────────────────────────────────────────

class _BroadcastTab extends StatelessWidget {
  const _BroadcastTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Compose card
        _ComposeCard(),
        const SizedBox(height: 16),
        _SectionHeader(
            icon: Icons.history_outlined,
            label: 'Sent Announcements',
            color: AppTheme.primary),
        ..._kAnnouncements
            .map((a) => _AnnouncementCard(announcement: a)),
      ],
    );
  }
}

class _ComposeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.darkGreen,
            AppTheme.primary,
          ],
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
          Container(
            height: 44,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              'Write your announcement...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ReachChip(label: 'Followers', active: true),
              const SizedBox(width: 6),
              _ReachChip(label: 'Nearby', active: false),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
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
    );
  }
}

class _ReachChip extends StatelessWidget {
  final String label;
  final bool active;
  const _ReachChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          color: active
              ? Colors.white
              : Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final OrgAnnouncement announcement;
  const _AnnouncementCard({required this.announcement});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String get _reachLabel {
    switch (announcement.reach) {
      case AnnouncementReach.followers:
        return 'Followers';
      case AnnouncementReach.nearby:
        return 'Nearby';
      case AnnouncementReach.both:
        return 'All';
    }
  }

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
                  announcement.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
              Text(
                _timeAgo(announcement.sentAt),
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.darkGreen.withOpacity(0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            announcement.preview,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkGreen.withOpacity(0.55),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_outline,
                  size: 12,
                  color: AppTheme.darkGreen.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text(
                '${announcement.recipientCount} reached',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _reachLabel,
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
// IMPACT RECORDS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactTab extends StatelessWidget {
  const _ImpactTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // On-chain summary
        _OnChainSummaryCard(),
        const SizedBox(height: 16),
        _SectionHeader(
          icon: Icons.verified_outlined,
          label: 'Verified Records',
          color: Colors.teal.shade600,
          subtitle: 'Permanently anchored on Cardano',
        ),
        ..._kImpactRecords.map((r) => _ImpactRecordCard(record: r)),
      ],
    );
  }
}

class _OnChainSummaryCard extends StatelessWidget {
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cardano',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _OnChainStat(
                  value: '${_kImpactRecords.length}',
                  label: 'Records'),
              _VerticalDivider(),
              const _OnChainStat(value: '4.2t', label: 'Plastic'),
              _VerticalDivider(),
              const _OnChainStat(value: '120', label: 'Trees'),
              _VerticalDivider(),
              const _OnChainStat(value: '2', label: 'Sites'),
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withOpacity(0.15),
    );
  }
}

class _ImpactRecordCard extends StatelessWidget {
  final VerifiedImpactRecord record;
  const _ImpactRecordCard({required this.record});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
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
          // Title row
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
                    Text(
                      record.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          record.type,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.teal.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${record.area}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(record.confirmedAt),
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.darkGreen.withOpacity(0.4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Metrics grid
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: record.metrics.entries.map((e) {
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
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      TextSpan(
                        text: e.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // TX hash row
          Row(
            children: [
              Icon(Icons.link_rounded,
                  size: 12, color: Colors.teal.shade600),
              const SizedBox(width: 5),
              Text(
                record.txHash,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade600,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                'View on Cardano →',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade600,
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
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.darkGreen.withOpacity(0.4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
        border:
        Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
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
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkGreen.withOpacity(0.45),
                  ),
                ),
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
  const _MiniStat(
      {required this.label, required this.value, required this.color});
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
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _GradientIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GradientIconButton(
      {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _ContextFab extends StatelessWidget {
  final int tabIndex;
  const _ContextFab({required this.tabIndex});

  String get _label {
    switch (tabIndex) {
      case 0:
        return 'New Event';
      case 1:
        return 'Link Partner';
      case 2:
        return 'New Announcement';
      case 3:
        return 'Export Report';
      default:
        return 'Create';
    }
  }

  IconData get _icon {
    switch (tabIndex) {
      case 0:
        return Icons.add_circle_outline;
      case 1:
        return Icons.handshake_outlined;
      case 2:
        return Icons.campaign_outlined;
      case 3:
        return Icons.download_outlined;
      default:
        return Icons.add;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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