import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../Models/user.dart';
import '../../Services/Community/community_service.dart';
import '../theme/app_theme.dart';
import 'activity_card.dart'
    show
        ActivityCapacityBar,
        ActivityTypeChip,
        ActivityStatusChip,
        formatActivityFullDate,
        kTypeGradients,
        kTypeIcons;
import 'activity_registration_sheet.dart';

class ActivityDetailScreen extends StatelessWidget {
  final String activityId;
  final Map<String, dynamic> activity;

  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final type = activity['type'] as String? ?? 'other';
    final status = activity['status'] as String? ?? 'open';
    final title = activity['title'] as String? ?? '';
    final description = activity['description'] as String? ?? '';
    final coverImageUrl = activity['coverImageUrl'] as String?;
    final scheduledAt = activity['scheduledAt'] as Timestamp?;
    final durationMinutes = activity['durationMinutes'] as int? ?? 0;
    final locationName = activity['locationName'] as String? ??
        _flatLocation(activity['location']);
    final registeredCount = activity['registeredCount'] as int? ?? 0;
    final maxParticipants = activity['maxParticipants'] as int? ?? 0;
    final organizerName = activity['organizerName'] as String? ?? '';
    final organizerEmail = activity['organizerEmail'] as String? ?? '';
    final tags = (activity['tags'] as List<dynamic>?)?.cast<String>() ?? [];

    final gradients = kTypeGradients[type] ?? kTypeGradients['other']!;
    final icon = kTypeIcons[type] ?? Icons.event_outlined;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3EE),
      body: CustomScrollView(
        slivers: [
          // ── Cover / AppBar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: gradients.first,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: coverImageUrl != null
                  ? Image.network(
                      coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _GradientCover(gradients: gradients, icon: icon),
                      loadingBuilder: (_, child, prog) =>
                          prog == null
                              ? child
                              : _GradientCover(
                                  gradients: gradients, icon: icon),
                    )
                  : _GradientCover(gradients: gradients, icon: icon),
              collapseMode: CollapseMode.parallax,
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title card ───────────────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ActivityTypeChip(type: type),
                          const SizedBox(width: 8),
                          ActivityStatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Organiser ────────────────────────────────────────────
                _Card(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primary.withOpacity(0.15),
                        child: Text(
                          organizerName.isNotEmpty
                              ? organizerName[0].toUpperCase()
                              : 'O',
                          style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              organizerName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGreen),
                            ),
                            if (organizerEmail.isNotEmpty)
                              Text(
                                organizerEmail,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.darkGreen.withOpacity(0.55)),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.person_outline,
                          color: AppTheme.accent.withOpacity(0.5), size: 18),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Details ──────────────────────────────────────────────
                _Card(
                  child: Column(
                    children: [
                      if (scheduledAt != null)
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date & Time',
                          value: formatActivityFullDate(scheduledAt),
                        ),
                      if (durationMinutes > 0) ...[
                        const _Divider(),
                        _DetailRow(
                          icon: Icons.timer_outlined,
                          label: 'Duration',
                          value: '$durationMinutes minutes',
                        ),
                      ],
                      if (locationName.isNotEmpty) ...[
                        const _Divider(),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: locationName,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Capacity ─────────────────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group_outlined,
                              size: 16, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          const Text(
                            'Participants',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ActivityCapacityBar(
                        registeredCount: registeredCount,
                        maxParticipants: maxParticipants,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Description ──────────────────────────────────────────
                if (description.isNotEmpty)
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About this activity',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.darkGreen.withOpacity(0.8),
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Tags ─────────────────────────────────────────────────
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _Card(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppTheme.lightGreen.withOpacity(0.3)),
                                ),
                                child: Text(tag,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.darkGreen,
                                        fontWeight: FontWeight.w500)),
                              ))
                          .toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Register button ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: _DetailRegisterButton(
                    activityId: activityId,
                    activityData: activity,
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
// DETAIL REGISTER BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRegisterButton extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> activityData;

  const _DetailRegisterButton({
    required this.activityId,
    required this.activityData,
  });

  @override
  State<_DetailRegisterButton> createState() => _DetailRegisterButtonState();
}

class _DetailRegisterButtonState extends State<_DetailRegisterButton> {
  bool _cancelling = false;

  Future<void> _onRegister(String userId) async {
    // Lazy-fetch user profile at tap time — F_User only provides uid
    final profile =
        await CommunityService().getUserProfile(userId: userId);
    if (!mounted) return;
    final userEmail = profile?['email'] as String? ?? '';
    final userName = profile?['displayName'] as String? ?? '';
    final userAvatarUrl = profile?['avatarUrl'] as String?;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivityRegistrationSheet(
        activityId: widget.activityId,
        activity: widget.activityData,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
      ),
    );
  }

  Future<void> _cancelRegistration(
      String userId, String registrationId) async {
    setState(() => _cancelling = true);
    try {
      final db = FirebaseFirestore.instance;
      // Firestore: transaction — cancel registration + decrement registeredCount
      await db.runTransaction((txn) async {
        final actRef =
            db.collection('activities').doc(widget.activityId);
        final regRef =
            db.collection('activity_registrations').doc(registrationId);
        txn.update(regRef, {'status': 'cancelled'});
        txn.update(actRef, {
          'registeredCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration cancelled.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _confirmCancel(
      BuildContext context, String userId, String registrationId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Registration?'),
        content: Text(
            'You will be removed from ${widget.activityData['title']}. The organiser may have noted your interest.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRegistration(userId, registrationId);
            },
            child: const Text('Cancel Registration',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<F_User?>(context);
    if (user == null) return const SizedBox.shrink();

    final activityStatus =
        widget.activityData['status'] as String? ?? 'open';

    return StreamBuilder<QuerySnapshot>(
      // Firestore: activity_registrations — real-time registration status
      stream: CommunityService().getUserRegistrationStream(
        activityId: widget.activityId,
        userId: user.uid,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 50,
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2)));
        }

        final docs = snap.data?.docs ?? [];
        final isRegistered = docs.isNotEmpty &&
            (docs.first.data() as Map)['status'] == 'registered';
        final registrationId =
            docs.isNotEmpty ? docs.first.id : null;

        if (isRegistered) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "You're registered for this activity!",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_cancelling)
                const SizedBox(
                    height: 44,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2)))
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      if (registrationId != null) {
                        _confirmCancel(
                            context, user.uid, registrationId);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                    child: const Text('Cancel Registration',
                        style: TextStyle(color: AppTheme.primary)),
                  ),
                ),
            ],
          );
        }

        if (activityStatus == 'full') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'This activity is full.',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: () => _onRegister(user.uid),
            icon: const Icon(Icons.how_to_reg_outlined,
                color: Colors.white, size: 18),
            label: const Text('Register for this Activity',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _GradientCover extends StatelessWidget {
  final List<Color> gradients;
  final IconData icon;

  const _GradientCover({required this.gradients, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradients,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 60, color: Colors.white.withOpacity(0.55)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.darkGreen)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 20,
        color: AppTheme.lightGreen.withOpacity(0.2));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _flatLocation(dynamic location) {
  if (location is Map) {
    final area = location['area'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    return area.isNotEmpty ? area : city;
  }
  return '';
}
