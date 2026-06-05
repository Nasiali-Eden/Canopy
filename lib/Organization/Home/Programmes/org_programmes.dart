import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../Models/programme.dart';
import '../../../Models/programme_enquiry.dart';
import '../../../Shared/theme/app_theme.dart';
import 'programme_editor.dart';
import 'programme_logic.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kBg = Color(0xFFF7F5F0);
// Nav-bar visual height above the system safe area — matches org_home's
// floating pill bar (SafeArea min-bottom 16 + padding 20 + content ≈41).
const _kNavBarAboveSafeArea = 80.0;

// ─────────────────────────────────────────────────────────────────────────────
// OrgProgrammes — management view (replaces placeholder)
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
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: const Text(
          'Programmes',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(),
        ),
      ),
      body: _loadingOrg
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _orgId == null
              ? _buildNoOrg()
              : Stack(
                  children: [
                    _buildTabView(navBottom),
                    // FAB — Positioned above the floating nav bar (Offerings tab only)
                    if (_tab.index == 0)
                      Positioned(
                        right: 20,
                        bottom: navBottom + 8,
                        child: FloatingActionButton(
                          heroTag: 'programmes_fab',
                          onPressed: () => _openEditor(),
                          backgroundColor: AppTheme.tertiary,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          child: const Icon(Icons.add, size: 26),
                        ),
                      ),
                  ],
                ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: _orgId == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<ProgrammeEnquiry>>(
              stream: ProgrammeLogic.streamEnquiries(_orgId!),
              builder: (context, snap) {
                final unread = (snap.data ?? [])
                    .where((e) => e.status == EnquiryStatus.unread)
                    .length;
                return TabBar(
                  controller: _tab,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.darkGreen.withOpacity(0.45),
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    const Tab(text: 'Offerings'),
                    const Tab(text: 'Track Record'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Enquiries'),
                          if (unread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.tertiary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
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
// Offerings tab
// ─────────────────────────────────────────────────────────────────────────────

class _OfferingsTab extends StatelessWidget {
  final List<Programme> programmes;
  final double navBottom;
  final void Function(Programme) onEdit;

  const _OfferingsTab({
    required this.programmes,
    required this.navBottom,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (programmes.isEmpty) {
      return _EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No offerings yet',
        subtitle: 'Tap + to publish your first programme.',
        navBottom: navBottom,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, navBottom + 80),
      itemCount: programmes.length,
      itemBuilder: (context, i) => _ProgrammeCard(
        programme: programmes[i],
        onTap: () => onEdit(programmes[i]),
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
        icon: Icons.verified_outlined,
        title: 'Track record builds here',
        subtitle: 'Completed programmes appear with their verified impact.',
        navBottom: navBottom,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, navBottom + 24),
      itemCount: programmes.length,
      itemBuilder: (context, i) => _TrackRecordCard(programme: programmes[i]),
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
            icon: Icons.inbox_outlined,
            title: 'No enquiries yet',
            subtitle:
                'When community members reach out, their messages appear here.',
            navBottom: navBottom,
          );
        }

        // Group by status: unread → read → responded → closed
        final groups = <EnquiryStatus, List<ProgrammeEnquiry>>{};
        for (final e in enquiries) {
          groups.putIfAbsent(e.status, () => []).add(e);
        }
        final order = [
          EnquiryStatus.unread,
          EnquiryStatus.read,
          EnquiryStatus.responded,
          EnquiryStatus.closed,
        ];

        final sections = <Widget>[];
        for (final status in order) {
          final list = groups[status];
          if (list == null || list.isEmpty) continue;
          sections.add(_EnquirySection(status: status, enquiries: list));
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, navBottom + 24),
          children: sections,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Programme card (Offerings)
// ─────────────────────────────────────────────────────────────────────────────

class _ProgrammeCard extends StatelessWidget {
  final Programme programme;
  final VoidCallback onTap;

  const _ProgrammeCard({required this.programme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final Color statusColor;
    switch (p.status) {
      case ProgrammeStatus.active:   statusColor = AppTheme.primary;  break;
      case ProgrammeStatus.upcoming: statusColor = AppTheme.accent;   break;
      case ProgrammeStatus.draft:    statusColor = Colors.grey;       break;
      default:                       statusColor = AppTheme.secondary; break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18)),
              child: _CoverThumb(url: p.coverImageUrl, size: 90),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeChip(type: p.type),
                        const SizedBox(width: 6),
                        _PriceChip(programme: p),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.darkGreen,
                          height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        p.summary,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p.status.label,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.edit_outlined,
                  size: 16, color: AppTheme.lightGreen),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Record card
// ─────────────────────────────────────────────────────────────────────────────

class _TrackRecordCard extends StatelessWidget {
  final Programme programme;

  const _TrackRecordCard({required this.programme});

  @override
  Widget build(BuildContext context) {
    final p = programme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover + overlay
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                _CoverThumb(url: p.coverImageUrl, size: 140, fullWidth: true),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 24, 14, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55)
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        _TypeChip(type: p.type, dark: true),
                        const Spacer(),
                        if (p.publishedAt != null)
                          Text(
                            DateFormat('MMM yyyy').format(p.publishedAt!),
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.darkGreen),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.summary,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGreen.withOpacity(0.5)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Verified impact strip (read-only — derived from impactRefs)
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        p.impactRefs.isNotEmpty
                            ? '${p.impactRefs.length} verified impact records'
                            : 'Verified completion · no impact figures yet',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enquiry section + tile
// ─────────────────────────────────────────────────────────────────────────────

class _EnquirySection extends StatelessWidget {
  final EnquiryStatus status;
  final List<ProgrammeEnquiry> enquiries;

  const _EnquirySection({required this.status, required this.enquiries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            status.label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppTheme.darkGreen.withOpacity(0.45)),
          ),
        ),
        ...enquiries.map((e) => _EnquiryTile(enquiry: e)),
        const SizedBox(height: 16),
      ],
    );
  }
}

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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? AppTheme.primary.withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? AppTheme.primary.withOpacity(0.2)
                : Colors.grey.shade100,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
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
                    color: AppTheme.lightGreen.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    enquiry.fromUserName.isNotEmpty
                        ? enquiry.fromUserName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 14),
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
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      Text(
                        enquiry.programmeTitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppTheme.primary, shape: BoxShape.circle),
                  ),
                if (enquiry.createdAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('d MMM').format(enquiry.createdAt!),
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.darkGreen.withOpacity(0.4)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              enquiry.message,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkGreen.withOpacity(0.75),
                  height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (enquiry.contactPhone != null ||
                enquiry.contactEmail != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (enquiry.contactPhone != null) ...[
                    Icon(Icons.phone_outlined,
                        size: 11, color: AppTheme.accent),
                    const SizedBox(width: 3),
                    Text(enquiry.contactPhone!,
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.accent)),
                    const SizedBox(width: 12),
                  ],
                  if (enquiry.contactEmail != null) ...[
                    Icon(Icons.email_outlined,
                        size: 11, color: AppTheme.accent),
                    const SizedBox(width: 3),
                    Text(enquiry.contactEmail!,
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.accent)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CoverThumb extends StatelessWidget {
  final String? url;
  final double size;
  final bool fullWidth;

  const _CoverThumb({this.url, required this.size, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    final w = fullWidth ? double.infinity : size;
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        width: w,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(w),
      );
    }
    return _placeholder(w);
  }

  Widget _placeholder(double w) {
    return Container(
      width: w,
      height: size,
      color: AppTheme.lightGreen.withOpacity(0.12),
      child: Icon(Icons.image_outlined,
          color: AppTheme.lightGreen.withOpacity(0.5), size: 28),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final ProgrammeType type;
  final bool dark;

  const _TypeChip({required this.type, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(0.18)
            : AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : AppTheme.accent),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final Programme programme;

  const _PriceChip({required this.programme});

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (programme.isPaid) {
      color = AppTheme.tertiary;
    } else if (programme.isVolunteer) {
      color = AppTheme.accent;
    } else {
      color = AppTheme.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        programme.displayPrice,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double navBottom;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.navBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: navBottom, left: 40, right: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon,
                  size: 32, color: AppTheme.lightGreen.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.45)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
