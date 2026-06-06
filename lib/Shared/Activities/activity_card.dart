import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Models/user.dart';
import '../../Services/Community/community_service.dart';
import '../theme/app_theme.dart';
import 'activity_registration_sheet.dart';
import 'activity_detail_screen.dart';

const _kActivities = 'activities';
const _kActivityRegistrations = 'activity_registrations';

// ─────────────────────────────────────────────────────────────────────────────
// TYPE + STATUS MAPS  (used by card, detail screen, and filter sheet)
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<Color>> kTypeGradients = {
  'cleanup': [AppTheme.primary, AppTheme.lightGreen],
  'tree_planting': [AppTheme.darkGreen, AppTheme.accent],
  'awareness': [AppTheme.accent, AppTheme.lightGreen],
  'training': [AppTheme.tertiary, Color(0xFFE8D5A3)],
  'monitoring': [AppTheme.secondary, AppTheme.lightGreen],
  'other': [AppTheme.lightGreen, Color(0xFFE8F5E9)],
};

const Map<String, IconData> kTypeIcons = {
  'cleanup': Icons.delete_sweep_outlined,
  'tree_planting': Icons.park_outlined,
  'awareness': Icons.campaign_outlined,
  'training': Icons.school_outlined,
  'monitoring': Icons.monitor_heart_outlined,
  'other': Icons.event_outlined,
};

const Map<String, String> kTypeLabels = {
  'cleanup': 'Cleanup',
  'tree_planting': 'Tree Planting',
  'awareness': 'Awareness',
  'training': 'Training',
  'monitoring': 'Monitoring',
  'other': 'Other',
};

List<Color> _gradientForType(String type) =>
    kTypeGradients[type] ?? kTypeGradients['other']!;

IconData _iconForType(String type) =>
    kTypeIcons[type] ?? Icons.event_outlined;

String _labelForType(String type) =>
    kTypeLabels[type] ?? type;

// ─────────────────────────────────────────────────────────────────────────────
// DATE HELPERS (public for reuse in detail screen)
// ─────────────────────────────────────────────────────────────────────────────

String formatActivityDate(Timestamp t) {
  final d = t.toDate();
  final now = DateTime.now();
  final diff = d.difference(now);
  if (diff.inDays == 0) return 'Today · ${DateFormat('HH:mm').format(d)}';
  if (diff.inDays == 1) return 'Tomorrow · ${DateFormat('HH:mm').format(d)}';
  if (diff.inDays < 7) return DateFormat('EEEE · HH:mm').format(d);
  return DateFormat('d MMM · HH:mm').format(d);
}

String formatActivityFullDate(Timestamp t) {
  return DateFormat('EEEE, d MMMM yyyy · HH:mm').format(t.toDate());
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE CHIP + STATUS CHIP  (reusable, public)
// ─────────────────────────────────────────────────────────────────────────────

class ActivityTypeChip extends StatelessWidget {
  final String type;
  const ActivityTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(type);
    final gradient = _gradientForType(type);
    final label = _labelForType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: gradient.map((c) => c.withOpacity(0.2)).toList()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradient.first.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: gradient.first),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: gradient.first,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class ActivityStatusChip extends StatelessWidget {
  final String status;
  const ActivityStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'open' => (Colors.green.shade600, 'Open'),
      'full' => (Colors.orange.shade600, 'Full'),
      'cancelled' => (Colors.red.shade600, 'Cancelled'),
      'completed' => (AppTheme.accent, 'Completed'),
      _ => (AppTheme.lightGreen, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAPACITY BAR  (public for reuse in detail screen + registration sheet)
// ─────────────────────────────────────────────────────────────────────────────

class ActivityCapacityBar extends StatelessWidget {
  final int registeredCount;
  final int maxParticipants;

  const ActivityCapacityBar({
    super.key,
    required this.registeredCount,
    required this.maxParticipants,
  });

  @override
  Widget build(BuildContext context) {
    // Always route through getCapacityStatus — never inline capacity logic.
    final status = CommunityService().getCapacityStatus(
      registeredCount: registeredCount,
      maxParticipants: maxParticipants,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!status.isUnlimited) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.fillRatio,
              minHeight: 5,
              backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                status.isFull
                    ? Colors.orange.shade600
                    : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          status.displayLabel,
          style: TextStyle(
            fontSize: 11,
            color: status.isFull
                ? Colors.orange.shade700
                : AppTheme.darkGreen.withOpacity(0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String activityId;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.activityId,
  });

  @override
  Widget build(BuildContext context) {
    final type = activity['type'] as String? ?? 'other';
    final status = activity['status'] as String? ?? 'open';
    final title = activity['title'] as String? ?? '';
    final description = activity['description'] as String? ?? '';
    final coverImageUrl = activity['coverImageUrl'] as String?;
    final scheduledAt = activity['scheduledAt'] as Timestamp?;
    final locationName = activity['locationName'] as String? ??
        _flatLocation(activity['location']);
    final registeredCount = activity['registeredCount'] as int? ?? 0;
    final maxParticipants = activity['maxParticipants'] as int? ?? 0;
    final organizerName = activity['organizerName'] as String? ?? '';

    final gradientColors = _gradientForType(type);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(
            activityId: activityId,
            activity: activity,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.lightGreen.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: coverImageUrl != null
                    ? Image.network(
                        coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _TypeCover(gradientColors: gradientColors, type: type),
                        loadingBuilder: (_, child, prog) =>
                            prog == null
                                ? child
                                : _TypeCover(
                                    gradientColors: gradientColors, type: type),
                      )
                    : _TypeCover(
                        gradientColors: gradientColors, type: type),
              ),
            ),

            // ── Type chip + status chip ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  ActivityTypeChip(type: type),
                  const Spacer(),
                  ActivityStatusChip(status: status),
                ],
              ),
            ),

            // ── Title ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                      fontSize: 14,
                      height: 1.3,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Description preview ───────────────────────────────────
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Text(
                  description,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkGreen.withOpacity(0.6),
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Meta row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    scheduledAt != null
                        ? formatActivityDate(scheduledAt)
                        : 'Date TBD',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.location_on_outlined,
                      size: 13, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationName,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Capacity bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: ActivityCapacityBar(
                registeredCount: registeredCount,
                maxParticipants: maxParticipants,
              ),
            ),

            // ── Organiser row + register button ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.primary.withOpacity(0.15),
                    child: Text(
                      organizerName.isNotEmpty
                          ? organizerName[0].toUpperCase()
                          : 'O',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'by $organizerName',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGreen.withOpacity(0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _RegisterButton(
                    activityId: activityId,
                    activityData: activity,
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
// TYPE COVER  (gradient background when no image)
// ─────────────────────────────────────────────────────────────────────────────

class _TypeCover extends StatelessWidget {
  final List<Color> gradientColors;
  final String type;

  const _TypeCover(
      {required this.gradientColors, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _iconForType(type),
          size: 40,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterButton extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> activityData;

  const _RegisterButton({
    required this.activityId,
    required this.activityData,
  });

  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton> {
  bool _cancelling = false;

  Future<void> _onTapRegister(String userId) async {
    // Fetch user profile lazily at tap time — F_User only has uid
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

  Future<void> _onTapCancelConfirm(
      String userId, String registrationId) async {
    setState(() => _cancelling = true);
    try {
      final db = _db;
      // Firestore: transaction — cancel registration + decrement registeredCount
      await db.runTransaction((txn) async {
        final actRef =
            db.collection(_kActivities).doc(widget.activityId);
        final regRef = db
            .collection(_kActivityRegistrations)
            .doc(registrationId);

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

  void _showCancelDialog(
      BuildContext context, String userId, String registrationId) {
    final title =
        widget.activityData['title'] as String? ?? 'this activity';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Registration?'),
        content: Text(
            'You will be removed from $title. The organiser may have already noted your interest.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Registration'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onTapCancelConfirm(userId, registrationId);
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
              width: 80,
              height: 32,
              child: Center(
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)));
        }

        final docs = snap.data?.docs ?? [];
        final isRegistered = docs.isNotEmpty &&
            (docs.first.data() as Map)['status'] == 'registered';
        final wasCancelled = docs.isNotEmpty &&
            (docs.first.data() as Map)['status'] == 'cancelled';
        final registrationId =
            docs.isNotEmpty ? docs.first.id : null;

        if (isRegistered) {
          return _cancelling
              ? const SizedBox(
                  width: 80,
                  height: 32,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary)))
              : OutlinedButton.icon(
                  onPressed: () {
                    if (registrationId != null) {
                      _showCancelDialog(
                          context, user.uid, registrationId);
                    }
                  },
                  icon: const Icon(Icons.check_circle,
                      size: 14, color: AppTheme.primary),
                  label: const Text('Registered',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.primary)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 0),
                    side: const BorderSide(color: AppTheme.primary),
                  ),
                );
        }

        if (activityStatus == 'full' && !wasCancelled) {
          return OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 0),
              side: BorderSide(
                  color: AppTheme.lightGreen.withOpacity(0.5)),
            ),
            child: Text('Full',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGreen.withOpacity(0.5))),
          );
        }

        return FilledButton(
          onPressed: () => _onTapRegister(user.uid),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(0, 32),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Register'),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER LOADING CARD
// ─────────────────────────────────────────────────────────────────────────────

class ActivityShimmerCard extends StatefulWidget {
  const ActivityShimmerCard({super.key});

  @override
  State<ActivityShimmerCard> createState() => _ActivityShimmerCardState();
}

class _ActivityShimmerCardState extends State<ActivityShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmerColor =
            AppTheme.lightGreen.withOpacity(0.1 + _anim.value * 0.12);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.lightGreen.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  )),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14,
                        width: 80,
                        color: shimmerColor,
                        margin:
                            const EdgeInsets.only(bottom: 10)),
                    Container(
                        height: 16, color: shimmerColor),
                    const SizedBox(height: 6),
                    Container(
                        height: 12,
                        width: 200,
                        color: shimmerColor),
                    const SizedBox(height: 12),
                    Container(
                        height: 5,
                        color: shimmerColor),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a flat locationName string from the legacy location map.
String _flatLocation(dynamic location) {
  if (location is Map) {
    final area = location['area'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    return area.isNotEmpty ? area : city;
  }
  return '';
}

final _db = FirebaseFirestore.instance;
