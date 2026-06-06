import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Shared/theme/app_theme.dart';
import '../Home/community_home.dart' show timeAgo;

const _kAnnouncements = 'announcements';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String? _selectedType;

  static const _types = [
    {'label': 'All', 'value': null},
    {'label': 'Alert', 'value': 'alert'},
    {'label': 'Event', 'value': 'event'},
    {'label': 'Update', 'value': 'update'},
    {'label': 'Opportunity', 'value': 'opportunity'},
    {'label': 'General', 'value': 'general'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3EE),
      appBar: AppBar(
        title: const Text('Announcements',
            style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.darkGreen,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: _types.map((t) {
                  final String? val = t['value'];
                  final selected = _selectedType == val;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = val),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.lightGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t['label'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.darkGreen.withOpacity(0.8))),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Firestore: announcements — ordered by createdAt desc
              stream: _selectedType == null
                  ? FirebaseFirestore.instance
                      .collection(_kAnnouncements)
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection(_kAnnouncements)
                      .where('type', isEqualTo: _selectedType)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade300, size: 40),
                        const SizedBox(height: 8),
                        const Text('Something went wrong'),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry')),
                      ],
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary));
                }
                final now = DateTime.now();
                final docs = (snap.data?.docs ?? []).where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final exp = data['expiresAt'] as Timestamp?;
                  return exp == null || exp.toDate().isAfter(now);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 64,
                            color: AppTheme.lightGreen.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _selectedType == null
                              ? 'No announcements'
                              : 'No $_selectedType announcements',
                          style: TextStyle(
                              color: AppTheme.darkGreen.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _AnnouncementCard(
                      data: data,
                      onTap: () => _openDetail(context, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AnnouncementDetailSheet(data: data),
    );
  }
}

// ── Announcement card ─────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _AnnouncementCard({required this.data, required this.onTap});

  Color _accentFor(String type) {
    switch (type) {
      case 'alert':
        return Colors.red.shade600;
      case 'event':
        return AppTheme.tertiary;
      case 'update':
        return AppTheme.primary;
      case 'opportunity':
        return AppTheme.accent;
      default:
        return AppTheme.lightGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'general';
    final isUrgent = data['isUrgent'] as bool? ?? false;
    final orgLogoUrl = data['orgLogoUrl'] as String?;
    final orgName = data['orgName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final accent = _accentFor(type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (orgLogoUrl != null)
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(orgLogoUrl),
                            onBackgroundImageError: (_, __) {},
                          )
                        else
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: accent.withOpacity(0.15),
                            child:
                                Icon(Icons.business, size: 14, color: accent),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(orgName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.darkGreen.withOpacity(0.65),
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('URGENT',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen,
                              fontSize: 14,
                            )),
                    const SizedBox(height: 6),
                    Text(body,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkGreen.withOpacity(0.7),
                            height: 1.5)),
                    if (createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(timeAgo(createdAt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Announcement detail sheet ─────────────────────────────────────────────────

class _AnnouncementDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnnouncementDetailSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final orgLogoUrl = data['orgLogoUrl'] as String?;
    final orgName = data['orgName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final attachedEventId = data['attachedEventId'] as String?;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                if (orgLogoUrl != null)
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(orgLogoUrl),
                    onBackgroundImageError: (_, __) {},
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child:
                        Icon(Icons.business, size: 18, color: AppTheme.primary),
                  ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orgName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGreen,
                            fontSize: 14)),
                    if (createdAt != null)
                      Text(timeAgo(createdAt),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkGreen.withOpacity(0.5))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                      fontSize: 18,
                    )),
            const SizedBox(height: 14),
            Text(body,
                style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.darkGreen.withOpacity(0.8),
                    height: 1.65)),
            if (attachedEventId != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.event_outlined),
                label: const Text('View Attached Event'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
