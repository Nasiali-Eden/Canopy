// lib/Community/Communication/announcements_list.dart
//
// Announcements (v2). Organisation broadcasts, urgent first, expired hidden;
// type chips narrow the list. Rows match Home's announcement rows.

import 'package:flutter/material.dart';

import '../../Models/announcement.dart';
import '../../Services/Announcements/announcement_service.dart';
import '../../theme/canopy_components.dart';

String announcementAge(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}

class AnnouncementsListScreen extends StatefulWidget {
  const AnnouncementsListScreen({super.key});

  @override
  State<AnnouncementsListScreen> createState() => _AnnouncementsListScreenState();
}

class _AnnouncementsListScreenState extends State<AnnouncementsListScreen> {
  static const _types = [('alert', 'Alerts'), ('event', 'Events'), ('update', 'Updates'), ('opportunity', 'Opportunities')];
  String? _type;
  late Stream<List<Announcement>> _stream = AnnouncementService().watchAnnouncements();

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Announcements'),
      body: StreamBuilder<List<Announcement>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return CanopyErrorState(
                title: "Couldn't load announcements", onRetry: () => setState(() => _stream = AnnouncementService().watchAnnouncements()));
          }
          if (!snap.hasData) {
            return ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: const [CanopyListSkeleton(rows: 5, leadingSize: 40)]);
          }
          final all = snap.data!;
          final shown = _type == null ? all : all.where((a) => a.type == _type).toList();
          final types = _types.where((t) => all.any((a) => a.type == t.$1)).toList();
          return Column(children: [
            if (types.isNotEmpty)
              CanopyChipRail(chips: [
                CanopyFilterChip(label: 'All', selected: _type == null, onTap: () => setState(() => _type = null)),
                for (final t in types)
                  CanopyFilterChip(label: t.$2, selected: _type == t.$1, onTap: () => setState(() => _type = _type == t.$1 ? null : t.$1)),
              ]),
            Expanded(
              child: shown.isEmpty
                  ? const CanopyEmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No announcements',
                      line: 'When an organisation near you posts an update, it appears here.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s12, CanopySpace.gutter, CanopySpace.s32),
                      children: [
                        CanopyListGroup(children: [
                          for (final a in shown)
                            CanopyListRow(
                              leading: CanopyAvatar(url: a.orgLogoUrl, name: a.orgName.isEmpty ? 'Canopy' : a.orgName, size: 40, org: true),
                              title: a.title.isEmpty ? a.body : a.title,
                              subtitle: [if (a.orgName.isNotEmpty) a.orgName, announcementAge(a.createdAt)].where((s) => s.isNotEmpty).join(' · '),
                              below: a.pinned
                                  ? Padding(padding: const EdgeInsets.only(top: CanopySpace.s2), child: StatusLabel('Urgent', color: p.danger))
                                  : null,
                              onTap: () => Navigator.pushNamed(context, '/announcements/${a.id}'),
                            ),
                        ]),
                      ],
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
