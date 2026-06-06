import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../Models/programme.dart';
import '../../../Models/programme_enquiry.dart';
import '../../../Shared/theme/app_theme.dart';
import 'programme_editor.dart';
import 'programme_logic.dart';

const _kBg = Color(0xFFF7F5F0);
// Nav-bar visual height above the system safe area — matches org_home's
// floating pill bar (SafeArea min-bottom 16 + padding 20 + content ≈41).
const _kNavBarAboveSafeArea = 80.0;

// ─────────────────────────────────────────────────────────────────────────────
// OrgProgrammes — management view (editorial redesign)
// ─────────────────────────────────────────────────────────────────────────────

class OrgProgrammes extends StatefulWidget {
  const OrgProgrammes({super.key});

  @override
  State<OrgProgrammes> createState() => _OrgProgrammesState();
}

class _OrgProgrammesState extends State<OrgProgrammes>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  String? _orgId;
  bool _loadingOrg = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    _fetchOrgId();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchOrgId() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();
      final id = (doc.data() ?? {})['orgId'] as String?;
      if (mounted) setState(() { _orgId = id; _loadingOrg = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingOrg = false);
    }
  }

  void _openEditor({Programme? programme}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgrammeEditor(orgId: _orgId!, existing: programme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final navBottom = systemBottom + _kNavBarAboveSafeArea;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Programmes',
              style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
            Text(
              'Manage your offerings',
              style: TextStyle(
                color: AppTheme.darkGreen.withOpacity(0.38),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          if (_orgId != null && _tab.index == 0)
            GestureDetector(
              onTap: _openEditor,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'New',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: _buildTabBar(),
        ),
      ),
      body: _loadingOrg
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _orgId == null
              ? _buildNoOrg()
              : _buildTabView(navBottom),
    );
  }

  // ── Custom tab bar ─────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    if (_orgId == null) return const SizedBox.shrink();
    return StreamBuilder<List<ProgrammeEnquiry>>(
      stream: ProgrammeLogic.streamEnquiries(_orgId!),
      builder: (context, snap) {
        final unread = (snap.data ?? [])
            .where((e) => e.status == EnquiryStatus.unread)
            .length;
        return Container(
          color: _kBg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.darkGreen.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _TabPill(
                  label: 'Offerings',
                  icon: Icons.layers_outlined,
                  index: 0,
                  controller: _tab,
                ),
                _TabPill(
                  label: 'Track Record',
                  icon: Icons.workspace_premium_outlined,
                  index: 1,
                  controller: _tab,
                ),
                _TabPill(
                  label: 'Enquiries',
                  icon: Icons.forum_outlined,
                  index: 2,
                  controller: _tab,
                  badge: unread,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab view ───────────────────────────────────────────────────────────────

  Widget _buildTabView(double navBottom) {
    return StreamBuilder<List<Programme>>(
      stream: ProgrammeLogic.streamProgrammes(_orgId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final all = snap.data ?? [];
        final offerings = all
            .where((p) =>
                p.status != ProgrammeStatus.completed &&
                p.status != ProgrammeStatus.archived)
            .toList();
        final trackRecord =
            all.where((p) => p.status == ProgrammeStatus.completed).toList();

        return TabBarView(
          controller: _tab,
          children: [
            _OfferingsTab(
              programmes: offerings,
              navBottom: navBottom,
              onEdit: (p) => _openEditor(programme: p),
              onCreate: _openEditor,
            ),
            _TrackRecordTab(
              programmes: trackRecord,
              navBottom: navBottom,
            ),
            _EnquiriesTab(
              orgId: _orgId!,
              navBottom: navBottom,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoOrg() {
    return Center(
      child: Text('No organisation linked to this account.',
          style: TextStyle(color: AppTheme.darkGreen.withOpacity(0.5))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented tab control
// ─────────────────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index;
  final TabController controller;
  final int badge;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.index,
    required this.controller,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = controller.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.animateTo(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.darkGreen.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? AppTheme.darkGreen
                    : AppTheme.darkGreen.withOpacity(0.38),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppTheme.darkGreen
                      : AppTheme.darkGreen.withOpacity(0.38),
                  letterSpacing: isActive ? 0.1 : 0,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  constraints: const BoxConstraints(minWidth: 14),
                  height: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offerings tab
// ─────────────────────────────────────────────────────────────────────────────

class _OfferingsTab extends StatelessWidget {
  final List<Programme> programmes;
  final double navBottom;
  final void Function(Programme) onEdit;
  final VoidCallback onCreate;

  const _OfferingsTab({
    required this.programmes,
    required this.navBottom,
    required this.onEdit,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    if (programmes.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, navBottom + 32),
        children: [
          _AddOfferingCard(onTap: onCreate),
        ],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 20, 16, navBottom + 88),
      itemCount: programmes.length,
      itemBuilder: (context, i) => _FadeSlideIn(
        key: ValueKey('off-${programmes[i].id}'),
        delay: Duration(milliseconds: i * 55),
        child: _OfferingCard(
          programme: programmes[i],
          onTap: () => onEdit(programmes[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Record tab
// ─────────────────────────────────────────────────────────────────────────────

class _TrackRecordTab extends StatelessWidget {
  final List<Programme> programmes;
  final double navBottom;

  const _TrackRecordTab({required this.programmes, required this.navBottom});

  @override
  Widget build(BuildContext context) {
    if (programmes.isEmpty) {
      return _EmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'Track record builds here',
        body: 'Completed programmes appear with their verified impact.',
        navBottom: navBottom,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 20, 16, navBottom + 32),
      itemCount: programmes.length,
      itemBuilder: (context, i) => _FadeSlideIn(
        key: ValueKey('tr-${programmes[i].id}'),
        delay: Duration(milliseconds: i * 55),
        child: _TrackRecordCard(programme: programmes[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enquiries tab
// ─────────────────────────────────────────────────────────────────────────────

class _EnquiriesTab extends StatelessWidget {
  final String orgId;
  final double navBottom;

  const _EnquiriesTab({required this.orgId, required this.navBottom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProgrammeEnquiry>>(
      stream: ProgrammeLogic.streamEnquiries(orgId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final enquiries = snap.data ?? [];
        if (enquiries.isEmpty) {
          return _EmptyState(
            icon: Icons.mark_email_unread_outlined,
            title: 'Inbox is quiet',
            body:
                'When community members reach out, their messages appear here.',
            navBottom: navBottom,
          );
        }

        // Group by status: unread → read → responded → closed
        final groups = <EnquiryStatus, List<ProgrammeEnquiry>>{};
        for (final e in enquiries) {
          groups.putIfAbsent(e.status, () => []).add(e);
        }
        const order = [
          EnquiryStatus.unread,
          EnquiryStatus.read,
          EnquiryStatus.responded,
          EnquiryStatus.closed,
        ];

        final children = <Widget>[];
        var animIdx = 0;
        for (final status in order) {
          final list = groups[status];
          if (list == null || list.isEmpty) continue;
          children.add(
            _EnquirySectionHeader(status: status, count: list.length),
          );
          for (final e in list) {
            children.add(_FadeSlideIn(
              key: ValueKey('enq-${e.id}'),
              delay: Duration(milliseconds: animIdx * 45),
              child: _EnquiryTile(enquiry: e),
            ));
            animIdx++;
          }
          children.add(const SizedBox(height: 20));
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, navBottom + 32),
          children: children,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add offering card — tappable ghost card shown when list is empty
// ─────────────────────────────────────────────────────────────────────────────

class _AddOfferingCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddOfferingCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.25),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGreen.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Ghost image area with dashed-style look
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: Container(
                height: 160,
                width: double.infinity,
                color: AppTheme.primary.withOpacity(0.04),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to add a new offering',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary.withOpacity(0.8),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Ghost content area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 180,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
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
// Offering card — image-led, full-width banner
// ─────────────────────────────────────────────────────────────────────────────

class _OfferingCard extends StatelessWidget {
  final Programme programme;
  final VoidCallback onTap;

  const _OfferingCard({required this.programme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = programme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGreen.withOpacity(0.09),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover banner ────────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  _CoverThumb(url: p.coverImageUrl, height: 170, fullWidth: true),
                  // Status badge — top right, dark frosted
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _StatusBadge(status: p.status),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta: type · price (inline, quiet)
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500),
                      children: [
                        TextSpan(
                          text: p.type.label,
                          style: TextStyle(
                              color: AppTheme.darkGreen.withOpacity(0.45)),
                        ),
                        TextSpan(
                          text: '  ·  ',
                          style: TextStyle(
                              color: AppTheme.darkGreen.withOpacity(0.25)),
                        ),
                        TextSpan(
                          text: p.displayPrice,
                          style: TextStyle(
                            color: p.isPaid
                                ? AppTheme.tertiary
                                : AppTheme.darkGreen.withOpacity(0.45),
                            fontWeight: p.isPaid
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Title + chevron
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppTheme.darkGreen.withOpacity(0.28),
                        ),
                      ),
                    ],
                  ),

                  if (p.summary.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      p.summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.48),
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
// Track Record card — editorial hero with verified impact
// ─────────────────────────────────────────────────────────────────────────────

class _TrackRecordCard extends StatelessWidget {
  final Programme programme;

  const _TrackRecordCard({required this.programme});

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final hasImpact = p.impactRefs.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGreen.withOpacity(0.09),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero image — title overlaid on deep scrim ────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                _CoverThumb(url: p.coverImageUrl, height: 210, fullWidth: true),

                // Deep bottom-up gradient scrim
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.30, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.76),
                        ],
                      ),
                    ),
                  ),
                ),

                // Type chip — frosted, top left
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25), width: 0.5),
                    ),
                    child: Text(
                      p.type.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                // Gold "Verified" badge — top right
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 10, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Title — bottom left, display weight
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 56, 16),
                    child: Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.4,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Completion date — bottom right
                if (p.publishedAt != null)
                  Positioned(
                    bottom: 16,
                    right: 14,
                    child: Text(
                      DateFormat('MMM yyyy').format(p.publishedAt!),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Impact strip ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: hasImpact
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.impactRefs.length}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen,
                          height: 1,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VERIFIED IMPACT RECORDS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: AppTheme.tertiary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Linked to this programme\'s outcomes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.darkGreen.withOpacity(0.42),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 15, color: AppTheme.tertiary),
                      const SizedBox(width: 8),
                      Text(
                        'Verified completion',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· no impact figures yet',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.33),
                        ),
                      ),
                    ],
                  ),
          ),

          if (p.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                p.summary,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.48),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enquiry section header
// ─────────────────────────────────────────────────────────────────────────────

class _EnquirySectionHeader extends StatelessWidget {
  final EnquiryStatus status;
  final int count;

  const _EnquirySectionHeader(
      {required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final isUnread = status == EnquiryStatus.unread;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        children: [
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color:
                  isUnread ? AppTheme.tertiary : AppTheme.darkGreen.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGreen.withOpacity(0.32),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enquiry tile — refined inbox row
// ─────────────────────────────────────────────────────────────────────────────

class _EnquiryTile extends StatelessWidget {
  final ProgrammeEnquiry enquiry;

  const _EnquiryTile({required this.enquiry});

  @override
  Widget build(BuildContext context) {
    final isUnread = enquiry.status == EnquiryStatus.unread;
    return GestureDetector(
      onTap: () {
        if (isUnread) ProgrammeLogic.markRead(enquiry.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gold leading bar — unread only
              Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: isUnread ? AppTheme.tertiary : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: avatar + name/programme + date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.primary, AppTheme.secondary],
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              enquiry.fromUserName.isNotEmpty
                                  ? enquiry.fromUserName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  enquiry.fromUserName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isUnread
                                        ? AppTheme.darkGreen
                                        : AppTheme.darkGreen.withOpacity(0.75),
                                  ),
                                ),
                                Text(
                                  enquiry.programmeTitle,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.darkGreen.withOpacity(0.42),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (enquiry.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('d MMM').format(enquiry.createdAt!),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.darkGreen.withOpacity(0.32),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 9),

                      // Message preview
                      Text(
                        enquiry.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen
                              .withOpacity(isUnread ? 0.78 : 0.58),
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Contact info — de-emphasised
                      if (enquiry.contactPhone != null ||
                          enquiry.contactEmail != null) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 12,
                          children: [
                            if (enquiry.contactPhone != null)
                              _ContactLine(
                                icon: Icons.phone_outlined,
                                text: enquiry.contactPhone!,
                              ),
                            if (enquiry.contactEmail != null)
                              _ContactLine(
                                icon: Icons.mail_outline_rounded,
                                text: enquiry.contactEmail!,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: AppTheme.accent.withOpacity(0.6)),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.accent.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge — overlaid on image, dark frosted
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ProgrammeStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cover thumb — Image.network with graceful error fallback (unchanged contract)
// ─────────────────────────────────────────────────────────────────────────────

class _CoverThumb extends StatelessWidget {
  final String? url;
  final double height;
  final bool fullWidth;

  const _CoverThumb({
    this.url,
    required this.height,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = fullWidth ? double.infinity : height;
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        width: w,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(w),
      );
    }
    return _placeholder(w);
  }

  Widget _placeholder(double w) {
    return Container(
      width: w,
      height: height,
      color: AppTheme.lightGreen.withOpacity(0.12),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 36,
          color: AppTheme.lightGreen.withOpacity(0.38),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — on-brand, editorial
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final double navBottom;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.navBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(48, 0, 48, navBottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppTheme.lightGreen.withOpacity(0.45)),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkGreen,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.darkGreen.withOpacity(0.45),
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered fade+slide entrance animation
// ─────────────────────────────────────────────────────────────────────────────

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
        child: widget.child,
      ),
    );
  }
}
