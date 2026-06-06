import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../Models/organization.dart';
import '../../../Shared/theme/app_theme.dart';
import 'dash_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashAttentionStrip — live badges for pending actions; collapses to "All
// caught up" when there's nothing to act on.
// ─────────────────────────────────────────────────────────────────────────────

class DashAttentionStrip extends StatefulWidget {
  final String orgId;
  final Organization org;
  const DashAttentionStrip(
      {super.key, required this.orgId, required this.org});

  @override
  State<DashAttentionStrip> createState() => _DashAttentionStripState();
}

class _DashAttentionStripState extends State<DashAttentionStrip> {
  final _db = FirebaseFirestore.instance;

  int _pendingRsvps               = 0;
  int _eventsAwaitingVerification = 0;
  int _unreadEnquiries            = 0;
  int _pendingPartners            = 0;

  final List<dynamic> _subs = [];

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final orgId = widget.orgId;
    final caps  = widget.org.capabilities;

    if (caps.contains(OrgCapability.volunteers)) {
      _subs.add(_db
          .collection('volunteerRsvps')
          .where('orgId', isEqualTo: orgId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _pendingRsvps = s.docs.length);
      }));
    }

    if (caps.contains(OrgCapability.events)) {
      _subs.add(_db
          .collection('activities')
          .where('orgId', isEqualTo: orgId)
          .snapshots()
          .listen((s) {
        final count = s.docs
            .where(
                (d) => (d.data() as Map)['impactStatus'] == 'pending')
            .length;
        if (mounted) setState(() => _eventsAwaitingVerification = count);
      }));
    }

    if (caps.contains(OrgCapability.programmes)) {
      _subs.add(_db
          .collection('programme_enquiries')
          .where('orgId', isEqualTo: orgId)
          .where('status', isEqualTo: 'unread')
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _unreadEnquiries = s.docs.length);
      }));
    }

    if (caps.contains(OrgCapability.partners)) {
      _subs.add(_db
          .collection('orgPartners')
          .where('orgId', isEqualTo: orgId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _pendingPartners = s.docs.length);
      }));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  List<DashAttentionItem> _buildItems() {
    final caps  = widget.org.capabilities;
    final items = <DashAttentionItem>[];

    if (caps.contains(OrgCapability.volunteers) && _pendingRsvps > 0) {
      items.add(DashAttentionItem(
        type: DashAttentionType.action,
        icon: Icons.how_to_reg_outlined,
        message:
            '$_pendingRsvps volunteer RSVP${_pendingRsvps == 1 ? '' : 's'} pending review',
        actionLabel: 'Review',
        route: '/volunteerManagement',
      ));
    }
    if (caps.contains(OrgCapability.events) &&
        _eventsAwaitingVerification > 0) {
      items.add(DashAttentionItem(
        type: DashAttentionType.action,
        icon: Icons.task_alt,
        message:
            '$_eventsAwaitingVerification event${_eventsAwaitingVerification == 1 ? '' : 's'} awaiting verification',
        actionLabel: 'Verify',
        route: '/allActivities',
      ));
    }
    if (caps.contains(OrgCapability.programmes) && _unreadEnquiries > 0) {
      items.add(DashAttentionItem(
        type: DashAttentionType.action,
        icon: Icons.mark_email_unread_outlined,
        message:
            '$_unreadEnquiries unread programme enquir${_unreadEnquiries == 1 ? 'y' : 'ies'}',
        actionLabel: 'View',
        route: '/allActivities',
      ));
    }
    if (caps.contains(OrgCapability.partners) && _pendingPartners > 0) {
      items.add(DashAttentionItem(
        type: DashAttentionType.info,
        icon: Icons.handshake_outlined,
        message:
            '$_pendingPartners pending partner request${_pendingPartners == 1 ? '' : 's'}',
        actionLabel: 'Respond',
        route: '/partnerOrgs',
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    if (items.isEmpty) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(13),
          border:
              Border.all(color: AppTheme.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppTheme.primary, size: 18),
            const SizedBox(width: 10),
            Text('All caught up',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                  '· nothing needs your attention right now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.4))),
            ),
          ],
        ),
      );
    }

    final actionCount =
        items.where((i) => i.type == DashAttentionType.action).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Needs attention',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                    letterSpacing: 0.2)),
            const SizedBox(width: 7),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppTheme.tertiary,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$actionCount',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            itemBuilder: (context, i) => _AttentionCard(
              item: items[i],
              onTap: () =>
                  Navigator.of(context).pushNamed(items[i].route),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attention card tile
// ─────────────────────────────────────────────────────────────────────────────

class _AttentionCard extends StatelessWidget {
  final DashAttentionItem item;
  final VoidCallback onTap;
  const _AttentionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAction = item.type == DashAttentionType.action;
    final accent   = isAction ? AppTheme.tertiary : AppTheme.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
                color: accent.withOpacity(0.09),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(item.icon, size: 15, color: accent),
                ),
                const Spacer(),
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: isAction
                            ? accent
                            : accent.withOpacity(0.3),
                        shape: BoxShape.circle)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.message,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text('${item.actionLabel} →',
                      style: TextStyle(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
