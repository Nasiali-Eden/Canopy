// lib/Shared/Activities/activity_registration_sheet.dart
//
// Registration sheet (rendered inside showCanopySheet). Summary of the
// activity, what the organiser receives, reminders consent, and one primary
// "Confirm registration". Capacity is re-checked inside the transaction.
//
// PRIVACY NOTE: userEmail is stored in activity_registrations/{id}.userEmail
// for organiser communications. Firestore rules should restrict reading it to
// the activity's organiser (and the member themselves).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/canopy_components.dart';
import 'activity_card.dart';

const _kActivities = 'activities';
const _kActivityRegistrations = 'activity_registrations';

class ActivityRegistrationSheet extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> activity;
  final String userId;
  final String userEmail;
  final String userName;
  final String? userAvatarUrl;

  const ActivityRegistrationSheet({
    super.key,
    required this.activityId,
    required this.activity,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.userAvatarUrl,
  });

  @override
  State<ActivityRegistrationSheet> createState() =>
      _ActivityRegistrationSheetState();
}

class _ActivityRegistrationSheetState extends State<ActivityRegistrationSheet> {
  bool _consent = true;
  bool _loading = false;
  bool _full = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final max = widget.activity['maxParticipants'] as int? ?? 0;
    final count = widget.activity['registeredCount'] as int? ?? 0;
    _full = max > 0 && count >= max;
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final db = FirebaseFirestore.instance;
      final regRef = db.collection(_kActivityRegistrations).doc();
      final actRef = db.collection(_kActivities).doc(widget.activityId);
      await db.runTransaction((txn) async {
        final snap = await txn.get(actRef);
        final data = snap.data()!;
        final count = data['registeredCount'] as int? ?? 0;
        final max = data['maxParticipants'] as int? ?? 0;
        // Re-check capacity inside the transaction (race guard).
        if (max != 0 && count >= max) throw const _Full();
        txn.set(regRef, {
          'activityId': widget.activityId,
          'userId': widget.userId,
          'userName': widget.userName,
          'userEmail': widget.userEmail,
          'userAvatarUrl': widget.userAvatarUrl,
          'registeredAt': FieldValue.serverTimestamp(),
          'status': 'registered',
          'notificationsConsent': _consent,
        });
        txn.update(actRef, {
          'registeredCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (!mounted) return;
      Navigator.pop(context);
      showCanopySnack(context, "You're registered for ${widget.activity['title']}.");
    } on _Full {
      if (mounted) setState(() => _full = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final a = widget.activity;
    final at = a['scheduledAt'] as Timestamp?;
    final place = activityLocationName(a);
    final org = (a['organizerName'] as String?)?.trim() ?? '';

    return CanopySheetBody(
      title: _full ? 'This activity is full' : 'Register',
      caption: (a['title'] as String?)?.trim(),
      children: [
        CanopyListGroup(children: [
          if (at != null)
            CanopyListRow(
                icon: Icons.calendar_today_outlined,
                title: formatActivityDate(at),
                subtitle: 'When'),
          if (place.isNotEmpty)
            CanopyListRow(
                icon: Icons.location_on_outlined, title: place, subtitle: 'Where'),
          if (org.isNotEmpty)
            CanopyListRow(
                icon: Icons.groups_outlined, title: org, subtitle: 'Organiser'),
          CanopyListRow(
            icon: Icons.group_outlined,
            title: activityGoingLabel(a),
            below: ActivityCapacityBar(
              registeredCount: a['registeredCount'] as int? ?? 0,
              maxParticipants: a['maxParticipants'] as int? ?? 0,
            ),
          ),
        ]),
        const SizedBox(height: CanopySpace.s16),
        if (_full)
          const CanopyCallout(
            kind: CalloutKind.warning,
            text: 'Someone took the last spot. Spots open up when people cancel — check back later.',
          )
        else ...[
          CanopyCheckRow(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v),
            label: 'Send me reminders and updates',
            caption: 'The organiser can message you about this activity.',
          ),
          const SizedBox(height: CanopySpace.s8),
          Text(
            widget.userEmail.isEmpty
                ? 'The organiser sees your name.'
                : 'The organiser sees your name and ${widget.userEmail}.',
            style: CanopyType.caption.copyWith(color: p.inkMuted),
          ),
          if (_failed) ...[
            const SizedBox(height: CanopySpace.s12),
            const CanopyCallout(
                kind: CalloutKind.danger,
                text: "Registration didn't go through. Check your connection and try again."),
          ],
        ],
      ],
      actions: [
        if (_full)
          CanopyButton.secondary(
              label: 'Close', expand: true, onPressed: () => Navigator.pop(context))
        else ...[
          CanopyButton(
            label: _failed ? 'Try again' : 'Confirm registration',
            expand: true,
            loading: _loading,
            onPressed: _register,
          ),
          CanopyButton.quiet(
              label: 'Not now', expand: true, onPressed: () => Navigator.pop(context)),
        ],
      ],
    );
  }
}

class _Full implements Exception {
  const _Full();
}
