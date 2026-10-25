// lib/Community/Communication/notification_center.dart
//
// Notifications (v2): All / Unread, grouped Today and Earlier. Tap marks
// read; swipe right marks read, swipe left deletes. "Mark all read" appears
// only when something is unread.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Models/app_notification.dart';
import '../../Services/Notifications/notification_service.dart';
import '../../theme/canopy_components.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  bool _unreadOnly = false;
  final _svc = NotificationService();

  IconData _icon(String type) => switch (type) {
        'event' || 'activity' || 'reminder' => Icons.event_outlined,
        'verification' || 'verified' => Icons.verified_outlined,
        'announcement' => Icons.campaign_outlined,
        'reply' || 'comment' => Icons.chat_bubble_outline,
        'badge' || 'points' => Icons.emoji_events_outlined,
        _ => Icons.notifications_none,
      };

  String _time(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return DateFormat('EEE').format(d);
    return DateFormat('d MMM').format(d);
  }

  Future<void> _markAll(String uid, List<AppNotification> list) async {
    try {
      for (final n in list.where((n) => !n.read)) {
        await _svc.markRead(userId: uid, notificationId: n.id);
      }
    } catch (_) {
      if (mounted) showCanopySnack(context, "Couldn't mark all as read.", error: true);
    }
  }

  Widget _row(String uid, AppNotification n) {
    final p = context.canopy;
    return Dismissible(
      key: ValueKey(n.id),
      background: Container(
        color: p.primarySoft,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: CanopySpace.gutter),
        child: Icon(Icons.mark_email_read_outlined, color: p.primaryInk),
      ),
      secondaryBackground: Container(
        color: p.dangerSoft,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: CanopySpace.gutter),
        child: Icon(Icons.delete_outline, color: p.danger),
      ),
      confirmDismiss: (dir) async {
        try {
          if (dir == DismissDirection.startToEnd) {
            await _svc.markRead(userId: uid, notificationId: n.id);
            return false;
          }
          await _svc.delete(userId: uid, notificationId: n.id);
          return true;
        } catch (_) {
          if (mounted) showCanopySnack(context, "Couldn't update that notification.", error: true);
          return false;
        }
      },
      child: CanopyListRow(
        leading: Icon(_icon(n.type), color: n.read ? p.inkMuted : p.primaryInk),
        title: n.title,
        subtitle: n.body.isEmpty ? null : n.body,
        titleColor: n.read ? p.inkMuted : p.ink,
        trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_time(n.createdAt), style: CanopyType.caption.copyWith(color: p.inkMuted)),
          if (!n.read) ...[
            const SizedBox(height: CanopySpace.s4),
            Semantics(label: 'Unread', child: Container(width: 8, height: 8, decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle))),
          ],
        ]),
        chevron: false,
        onTap: n.read ? null : () => _svc.markRead(userId: uid, notificationId: n.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return CanopyScaffold(appBar: canopyAppBar(context, title: 'Notifications'), body: const CanopySignedOutState());
    }
    return StreamBuilder<List<AppNotification>>(
      stream: _svc.watchNotifications(userId: uid, unreadOnly: _unreadOnly),
      builder: (context, snap) {
        final list = snap.data ?? const <AppNotification>[];
        final anyUnread = list.any((n) => !n.read);
        Widget body;
        if (snap.hasError) {
          body = CanopyErrorState(title: "Couldn't load notifications", onRetry: () => setState(() {}));
        } else if (!snap.hasData) {
          body = ListView(padding: const EdgeInsets.all(CanopySpace.gutter), children: [
            for (var i = 0; i < 4; i++) ...[
              const CanopySkeleton(height: 14, width: 180),
              const SizedBox(height: CanopySpace.s8),
              const CanopySkeleton(height: 11),
              const SizedBox(height: CanopySpace.s24),
            ],
          ]);
        } else if (list.isEmpty) {
          body = CanopyEmptyState(
            icon: Icons.notifications_none,
            title: _unreadOnly ? 'Nothing unread' : "You're all caught up",
            line: 'Reminders, verifications and replies show up here.',
          );
        } else {
          final now = DateTime.now();
          bool today(AppNotification n) =>
              n.createdAt != null && n.createdAt!.year == now.year && n.createdAt!.month == now.month && n.createdAt!.day == now.day;
          final t = list.where(today).toList(), e = list.where((n) => !today(n)).toList();
          body = ListView(padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, 0, CanopySpace.gutter, CanopySpace.s32), children: [
            if (t.isNotEmpty) ...[
              const CanopySectionHeader(title: 'Today', padding: EdgeInsets.only(top: CanopySpace.s16)),
              CanopyListGroup(children: [for (final n in t) _row(uid, n)]),
            ],
            if (e.isNotEmpty) ...[
              const CanopySectionHeader(title: 'Earlier', padding: EdgeInsets.only(top: CanopySpace.s16)),
              CanopyListGroup(children: [for (final n in e) _row(uid, n)]),
            ],
            const SizedBox(height: CanopySpace.s16),
            Text('Swipe right to mark read, left to delete.', textAlign: TextAlign.center, style: CanopyType.caption.copyWith(color: p.inkFaint)),
          ]);
        }
        return CanopyScaffold(
          appBar: canopyAppBar(context, title: 'Notifications', actions: [
            if (anyUnread) TextButton(onPressed: () => _markAll(uid, list), child: const Text('Mark all read')),
          ]),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8, CanopySpace.gutter, 0),
              child: CanopySegmented<bool>(
                options: const [(false, 'All'), (true, 'Unread')],
                value: _unreadOnly,
                onChanged: (v) => setState(() => _unreadOnly = v),
              ),
            ),
            Expanded(child: body),
          ]),
        );
      },
    );
  }
}
