// PRIVACY NOTE:
// User email is stored in activity_registrations/{id}.userEmail at registration time.
// This field is intended for organiser use (event communications, reminders, updates).
// Firestore Security Rules should enforce:
//   - Read access to userEmail restricted to the activity's organizerId
//   - Users can read their own registrations
//   - Users cannot read other users' registration email fields
// Rules implementation is outside the scope of this file — coordinate with backend.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Services/Community/community_service.dart';
import '../theme/app_theme.dart';
import 'activity_card.dart' show ActivityCapacityBar, formatActivityDate;

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

class _ActivityRegistrationSheetState
    extends State<ActivityRegistrationSheet> {
  bool _notificationsConsent = true;
  bool _isLoading = false;
  bool _isFull = false;

  @override
  void initState() {
    super.initState();
    // Reflect current capacity state from the activity data
    final maxP = widget.activity['maxParticipants'] as int? ?? 0;
    final regC = widget.activity['registeredCount'] as int? ?? 0;
    _isFull = maxP > 0 && regC >= maxP;
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final regRef = db.collection(_kActivityRegistrations).doc(); // Firestore: activity_registrations/{newId}
      final activityRef = db.collection(_kActivities).doc(widget.activityId); // Firestore: activities/{activityId}

      await db.runTransaction((transaction) async {
        final activitySnap = await transaction.get(activityRef);
        final data = activitySnap.data()!;
        final currentCount = data['registeredCount'] as int? ?? 0;
        final maxParticipants = data['maxParticipants'] as int? ?? 0;

        // Re-check capacity inside transaction (race condition guard)
        if (maxParticipants != 0 && currentCount >= maxParticipants) {
          throw Exception('event_full');
        }

        transaction.set(regRef, {
          'activityId': widget.activityId,
          'userId': widget.userId,
          'userName': widget.userName,
          'userEmail': widget.userEmail,
          'userAvatarUrl': widget.userAvatarUrl,
          'registeredAt': FieldValue.serverTimestamp(),
          'status': 'registered',
          'notificationsConsent': _notificationsConsent,
        });

        transaction.update(activityRef, {
          'registeredCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're registered for ${widget.activity['title']}",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.darkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.toString().contains('event_full')) {
        setState(() => _isFull = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Registration failed. Please try again.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.activity['type'] as String? ?? 'other';
    final title = widget.activity['title'] as String? ?? '';
    final organizerName =
        widget.activity['organizerName'] as String? ?? '';
    final scheduledAt =
        widget.activity['scheduledAt'] as Timestamp?;
    final durationMinutes =
        widget.activity['durationMinutes'] as int? ?? 0;
    final locationName = widget.activity['locationName'] as String? ??
        _flatLoc(widget.activity['location']);
    final registeredCount =
        widget.activity['registeredCount'] as int? ?? 0;
    final maxParticipants =
        widget.activity['maxParticipants'] as int? ?? 0;

    final capacityStatus = CommunityService().getCapacityStatus(
      registeredCount: registeredCount,
      maxParticipants: maxParticipants,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Activity summary header ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.8),
                          AppTheme.lightGreen.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForType(type),
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGreen,
                                  fontSize: 15,
                                )),
                        Text('by $organizerName',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkGreen
                                    .withOpacity(0.55))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(
                height: 24,
                color: AppTheme.lightGreen.withOpacity(0.2),
                indent: 16,
                endIndent: 16),

            // ── Details grid ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (scheduledAt != null)
                    _DetailRow(
                        Icons.calendar_today_outlined,
                        formatActivityDate(scheduledAt)),
                  if (durationMinutes > 0) ...[
                    const SizedBox(height: 10),
                    _DetailRow(Icons.timer_outlined,
                        '$durationMinutes min estimated'),
                  ],
                  if (locationName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                        Icons.location_on_outlined, locationName),
                  ],
                  const SizedBox(height: 10),
                  _DetailRow(Icons.group_outlined,
                      capacityStatus.displayLabel),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Capacity bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ActivityCapacityBar(
                registeredCount: registeredCount,
                maxParticipants: maxParticipants,
              ),
            ),

            const SizedBox(height: 20),

            // ── Email info ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.lightGreen.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined,
                        size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contact email for organiser',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.darkGreen
                                    .withOpacity(0.55))),
                        Text(widget.userEmail,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkGreen)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Notifications consent ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CheckboxListTile(
                title: const Text(
                  'Receive updates from organiser about this event',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'The organiser may email you with event details, reminders, or changes.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.55)),
                ),
                value: _notificationsConsent,
                onChanged: (v) =>
                    setState(() => _notificationsConsent = v ?? true),
                activeColor: AppTheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),

            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isFull || capacityStatus.isFull
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade600,
                              size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This event is full. You can no longer register.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _register,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          Icons.how_to_reg_outlined,
                                          color: Colors.white,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Confirm Registration',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  color: AppTheme.darkGreen
                                      .withOpacity(0.6)),
                            ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGreen.withOpacity(0.8))),
        ),
      ],
    );
  }
}

IconData _iconForType(String type) {
  const icons = {
    'cleanup': Icons.delete_sweep_outlined,
    'tree_planting': Icons.park_outlined,
    'awareness': Icons.campaign_outlined,
    'training': Icons.school_outlined,
    'monitoring': Icons.monitor_heart_outlined,
  };
  return icons[type] ?? Icons.event_outlined;
}

String _flatLoc(dynamic location) {
  if (location is Map) {
    final area = location['area'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    return area.isNotEmpty ? area : city;
  }
  return '';
}
