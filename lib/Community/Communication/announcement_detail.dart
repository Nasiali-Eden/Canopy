// lib/Community/Communication/announcement_detail.dart
//
// One announcement (v2): organisation (→ its public page), urgent label,
// time, the message in full, and when it expires.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Models/announcement.dart';
import '../../Organization/Explorer/org_view_screen.dart';
import '../../Services/Announcements/announcement_service.dart';
import '../../theme/canopy_components.dart';
import 'announcements_list.dart' show announcementAge;

class AnnouncementDetailScreen extends StatefulWidget {
  final String announcementId;
  const AnnouncementDetailScreen({super.key, required this.announcementId});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  late Future<Announcement?> _future = AnnouncementService().getAnnouncement(widget.announcementId);

  Future<void> _openOrg(String orgId) async {
    try {
      final d = (await FirebaseFirestore.instance.collection('organizations').doc(orgId).get()).data();
      if (d == null || !mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrgViewScreen(orgId: orgId, orgData: d)));
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't open the organisation.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Announcement'),
      body: FutureBuilder<Announcement?>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(
                title: "Couldn't load this announcement",
                onRetry: () => setState(() => _future = AnnouncementService().getAnnouncement(widget.announcementId)));
          }
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final a = snap.data;
          if (a == null) return const CanopyEmptyState(icon: Icons.campaign_outlined, title: 'This announcement was removed');
          return ListView(
            padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
            children: [
              if (a.orgName.isNotEmpty)
                CanopyListGroup(children: [
                  CanopyListRow(
                    leading: CanopyAvatar(url: a.orgLogoUrl, name: a.orgName, size: 40, org: true),
                    title: a.orgName,
                    subtitle: announcementAge(a.createdAt),
                    onTap: a.orgId.isEmpty ? null : () => _openOrg(a.orgId),
                  ),
                ]),
              const SizedBox(height: CanopySpace.s16),
              if (a.pinned) ...[StatusLabel('Urgent', color: p.danger), const SizedBox(height: CanopySpace.s4)],
              if (a.title.isNotEmpty) Text(a.title, style: CanopyType.title.copyWith(color: p.ink)),
              const SizedBox(height: CanopySpace.s12),
              SelectableText(a.body, style: CanopyType.body.copyWith(fontSize: 16, height: 1.55, color: p.ink)),
              if (a.expiresAt != null) ...[
                const SizedBox(height: CanopySpace.s16),
                Text('Until ${DateFormat('EEE d MMM').format(a.expiresAt!)}', style: CanopyType.caption.copyWith(color: p.inkMuted)),
              ],
            ],
          );
        },
      ),
    );
  }
}
