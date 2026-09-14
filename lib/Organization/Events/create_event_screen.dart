// lib/Organization/Events/create_event_screen.dart
//
// Org side of "Log Work" QR check-in: create an event, show its QR (scanned
// by members in LogWorkEventScreen), then end it when it's over. Reachable
// from the org dashboard's Quick Actions ("Host Event").

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../Services/Events/events_service.dart';
import '../../Shared/theme/app_theme.dart';

class CreateEventScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const CreateEventScreen({super.key, required this.orgId, required this.orgName});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _service = EventsService();
  final _titleController = TextEditingController();
  int _points = 10;
  bool _creating = false;
  CanopyEvent? _event;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _creating = true);
    try {
      final event = await _service.createEvent(
        orgId: widget.orgId,
        orgName: widget.orgName,
        title: _titleController.text.trim(),
        pointsPerCheckin: _points,
      );
      if (mounted) setState(() => _event = event);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _end() async {
    final event = _event;
    if (event == null) return;
    await _service.endEvent(event.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.darkGreen,
        title: const Text('Host an Event',
            style: TextStyle(
                color: AppTheme.darkGreen, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _event == null ? _buildForm() : _buildQr(_event!),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EVENT TITLE',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
                letterSpacing: 0.3)),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Saturday Riverbank Cleanup',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.lightGreen.withOpacity(0.5)),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text('POINTS PER CHECK-IN',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
                letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _points = (_points - 5).clamp(5, 500)),
              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primary),
            ),
            Text('$_points',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
            IconButton(
              onPressed: () => setState(() => _points = (_points + 5).clamp(5, 500)),
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _creating ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _creating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Create Event & Show QR',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildQr(CanopyEvent event) {
    return Column(
      children: [
        Text(event.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
        const SizedBox(height: 6),
        Text('${event.pointsPerCheckin} points per check-in',
            style: TextStyle(fontSize: 13, color: AppTheme.darkGreen.withOpacity(0.6))),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.lightGreen.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: QrImageView(
            data: event.qrPayload,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.tertiary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Members scan this from Home → Log Work. It stops working the '
            'moment you end the event below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF7A6329), height: 1.4),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _end,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('End Event',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
