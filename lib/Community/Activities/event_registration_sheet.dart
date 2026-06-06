import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../Shared/theme/app_theme.dart';

const _kActivities = 'activities';
const _kActivityRegistrations = 'activity_registrations';

class EventRegistrationSheet extends StatefulWidget {
  final String activityId;
  final String userId;

  const EventRegistrationSheet({
    super.key,
    required this.activityId,
    required this.userId,
  });

  @override
  State<EventRegistrationSheet> createState() =>
      _EventRegistrationSheetState();
}

class _EventRegistrationSheetState extends State<EventRegistrationSheet> {
  String? _registrationDocId;
  String? _registrationStatus;
  bool _checking = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    try {
      // Firestore: activity_registrations — check for existing registration
      final snap = await FirebaseFirestore.instance
          .collection(_kActivityRegistrations)
          .where('activityId', isEqualTo: widget.activityId)
          .where('userId', isEqualTo: widget.userId)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        setState(() {
          _registrationDocId = doc.id;
          _registrationStatus = (doc.data())['status'] as String?;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _register(String title) async {
    setState(() => _submitting = true);
    try {
      final uuid = const Uuid().v4();
      // Firestore: transaction — create registration + increment registeredCount
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final actRef = FirebaseFirestore.instance
            .collection(_kActivities)
            .doc(widget.activityId);
        final actSnap = await txn.get(actRef);
        final count = (actSnap.data()?['registeredCount'] as int?) ?? 0;

        final regRef = FirebaseFirestore.instance
            .collection(_kActivityRegistrations)
            .doc(uuid);
        txn.set(regRef, {
          'activityId': widget.activityId,
          'userId': widget.userId,
          'registeredAt': FieldValue.serverTimestamp(),
          'status': 'registered',
        });
        txn.update(actRef, {'registeredCount': count + 1});
      });
      if (!mounted) return;
      setState(() {
        _registrationDocId = uuid;
        _registrationStatus = 'registered';
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You're registered for $title"),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration failed. Try again.')),
        );
      }
    }
  }

  Future<void> _cancelRegistration() async {
    if (_registrationDocId == null) return;
    setState(() => _submitting = true);
    try {
      // Firestore: transaction — cancel registration + decrement registeredCount
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final actRef = FirebaseFirestore.instance
            .collection(_kActivities)
            .doc(widget.activityId);
        final actSnap = await txn.get(actRef);
        final count = (actSnap.data()?['registeredCount'] as int?) ?? 0;

        final regRef = FirebaseFirestore.instance
            .collection(_kActivityRegistrations)
            .doc(_registrationDocId);
        txn.update(regRef, {'status': 'cancelled'});
        txn.update(actRef,
            {'registeredCount': (count - 1).clamp(0, 999999)});
      });
      if (!mounted) return;
      setState(() {
        _registrationStatus = 'cancelled';
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration cancelled.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: StreamBuilder<DocumentSnapshot>(
        // Firestore: activities/{activityId}
        stream: FirebaseFirestore.instance
            .collection(_kActivities)
            .doc(widget.activityId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return _sheetError();
          if (!snap.hasData ||
              snap.connectionState == ConnectionState.waiting ||
              _checking) {
            return _sheetLoading();
          }
          final data = snap.data!.data() as Map<String, dynamic>?;
          if (data == null) return _sheetError();
          return _sheetContent(data);
        },
      ),
    );
  }

  Widget _sheetLoading() => const SizedBox(
        height: 300,
        child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      );

  Widget _sheetError() => SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade300, size: 36),
              const SizedBox(height: 8),
              const Text('Something went wrong'),
            ],
          ),
        ),
      );

  Widget _sheetContent(Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Event';
    final type = data['type'] as String? ?? '';
    final status = data['status'] as String? ?? 'open';
    final registeredCount = data['registeredCount'] as int? ?? 0;
    final maxParticipants = data['maxParticipants'] as int? ?? 0;
    final location = data['location'] as String? ?? '';
    final organizerName = data['organizerName'] as String? ?? '';
    final scheduledAt = data['scheduledAt'] as Timestamp?;

    final isFull =
        maxParticipants > 0 && registeredCount >= maxParticipants;
    final isCancelled = status == 'cancelled';
    final isCompleted = status == 'completed';
    final isRegistered = _registrationStatus == 'registered';
    final wasCancelled = _registrationStatus == 'cancelled';
    final fillRatio = maxParticipants > 0
        ? (registeredCount / maxParticipants).clamp(0.0, 1.0)
        : 0.0;

    final dateStr = scheduledAt != null
        ? DateFormat('EEE, d MMM yyyy · h:mm a').format(scheduledAt.toDate())
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
          if (type.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(type,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen)),
          const SizedBox(height: 16),
          _InfoRow(Icons.calendar_today_outlined, dateStr),
          const SizedBox(height: 8),
          if (location.isNotEmpty) ...[
            _InfoRow(Icons.location_on_outlined, location),
            const SizedBox(height: 8),
          ],
          _InfoRow(Icons.person_outline, 'By $organizerName'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.people_outline,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                '$registeredCount / ${maxParticipants == 0 ? '∞' : maxParticipants} registered',
                style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ],
          ),
          if (maxParticipants > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fillRatio,
                backgroundColor: AppTheme.lightGreen.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                    isFull ? Colors.red.shade400 : AppTheme.primary),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (isCancelled || isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCancelled
                    ? 'This event has been cancelled'
                    : 'Event completed',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else if (isRegistered)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    label: const Text("You're Registered",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _submitting ? null : _cancelRegistration,
                  child: _submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cancel Registration',
                          style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          else if (isFull)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.grey.shade400,
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Event is Full'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : () => _register(title),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48)),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Register for Event'),
              ),
            ),
          if (wasCancelled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : () => _register(title),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Register Again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 14, color: AppTheme.darkGreen.withOpacity(0.8))),
        ),
      ],
    );
  }
}
