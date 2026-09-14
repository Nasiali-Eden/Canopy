// lib/Community/Events/log_work_event_screen.dart
//
// "Log Work" — real screen behind the Home quick-action tile that used to
// be a locked "coming soon" stub (see home_feed.dart). Scans an organiser's
// QR code and checks the signed-in member into that event; points are
// awarded by the checkInToEvent Cloud Function, not by this screen.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../Services/Events/events_service.dart';
import '../../Shared/theme/app_theme.dart';

class LogWorkEventScreen extends StatefulWidget {
  const LogWorkEventScreen({super.key});

  @override
  State<LogWorkEventScreen> createState() => _LogWorkEventScreenState();
}

class _LogWorkEventScreenState extends State<LogWorkEventScreen> {
  final _service = EventsService();
  final MobileScannerController _controller = MobileScannerController();
  bool _busy = false;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _resultMessage != null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final parsed = EventsService.parsePayload(raw);
    if (parsed == null) {
      setState(() {
        _resultMessage = "That doesn't look like a Canopy event code.";
        _resultIsError = true;
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _service.checkIn(eventId: parsed.eventId, token: parsed.token);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resultIsError = false;
        _resultMessage = result.alreadyCheckedIn
            ? "You're already checked in to this event."
            : '+${result.pointsAwarded} points — checked in!';
      });
    } on CheckInException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resultIsError = true;
        _resultMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resultIsError = true;
        _resultMessage = 'Something went wrong — please try again.';
      });
    }
  }

  void _scanAgain() {
    setState(() {
      _resultMessage = null;
      _resultIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Log Work',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _ScanFrameOverlay(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: _resultMessage == null
                ? const Text(
                    'Scan the QR code the event organiser is showing to check '
                    'in and get your points.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  )
                : _ResultCard(
                    message: _resultMessage!,
                    isError: _resultIsError,
                    onScanAgain: _resultIsError ? _scanAgain : null,
                    onDone: _resultIsError ? null : () => Navigator.pop(context),
                  ),
          ),
          if (_busy)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ScanFrameOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFF8E53), width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onScanAgain;
  final VoidCallback? onDone;

  const _ResultCard({
    required this.message,
    required this.isError,
    this.onScanAgain,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle,
            color: isError ? Colors.red.shade600 : AppTheme.primary,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: onScanAgain ?? onDone,
              style: FilledButton.styleFrom(
                backgroundColor: isError ? AppTheme.darkGreen : AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isError ? 'Scan Again' : 'Done',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
