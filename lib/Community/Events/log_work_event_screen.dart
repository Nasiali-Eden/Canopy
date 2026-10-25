// lib/Community/Events/log_work_event_screen.dart
//
// "Log Work" (DESIGN_HANDOFF.md §3 — Log Work landing + QR scanner).
//
// Landing: points hero (gradient), "Earn points now" (compact event rows with
// gold point numerals), how check-in works, a route to Log Contribution for
// solo work, and a sticky "Scan QR code".
//
// Scanner: camera chrome is always dark. States — scanning · processing ·
// success (one gold ring burst + count-up) · error (+ scan again) · camera
// denied (+ open settings). Points are awarded by the checkInToEvent Cloud
// Function, never by this screen.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../Services/Events/events_service.dart';
import '../../theme/canopy_components.dart';
import '../Contributions/log_contribution.dart';

class LogWorkEventScreen extends StatelessWidget {
  const LogWorkEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Log work'),
      body: uid == null
          ? const CanopySignedOutState(
              line: 'Sign in to check in at events and earn points.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(CanopySpace.gutter,
                  CanopySpace.s8, CanopySpace.gutter, CanopySpace.s32),
              children: [
                _PointsHero(uid: uid),
                const SizedBox(height: CanopySpace.section),
                const CanopySectionHeader(
                    title: 'Earn points now', padding: EdgeInsets.zero),
                const _LiveEventsList(),
                const SizedBox(height: CanopySpace.section),
                const CanopySectionHeader(
                    title: 'How it works', padding: EdgeInsets.zero),
                const _HowItWorks(),
                const SizedBox(height: CanopySpace.section),
                CanopyListGroup(children: [
                  CanopyListRow(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Working on your own?',
                    subtitle:
                        "Log a contribution with photos — points are added once it's verified.",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LogContributionScreen()),
                    ),
                  ),
                ]),
              ],
            ),
      sticky: uid == null
          ? null
          : StickyActionBar(children: [
              CanopyButton(
                label: 'Scan QR code',
                expand: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrScanScreen()),
                ),
              ),
            ]),
    );
  }
}

// ── Landing pieces ───────────────────────────────────────────────────────────

/// Current impact-points balance (same rankingVersion gate as Profile/Home).
class _PointsHero extends StatelessWidget {
  final String uid;
  const _PointsHero({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('Users').doc(uid).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? const <String, dynamic>{};
        final points = d['rankingVersion'] == 1
            ? (d['impact_points'] as num?)?.toInt() ?? 0
            : 0;
        return CanopyHero(
          child: CanopyHeroTap(
            label: 'Your impact points: $points. Opens your impact.',
            onTap: () => Navigator.pushNamed(context, '/impact'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR IMPACT POINTS',
                    style: CanopyType.eyebrow
                        .copyWith(color: CanopyPalette.onHeroMuted)),
                const SizedBox(height: CanopySpace.s4),
                Text(snap.hasData ? '$points' : '—',
                    style: CanopyType.hero
                        .copyWith(color: CanopyPalette.onHeroPoints)),
                const SizedBox(height: CanopySpace.s8),
                Text('Check in at a community event to add to your total.',
                    style: CanopyType.body
                        .copyWith(color: CanopyPalette.onHeroMuted)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Live events and what each check-in is worth (compact rows — date block
/// left, no cover). Single equality filter, sorted client-side (index-free).
class _LiveEventsList extends StatefulWidget {
  const _LiveEventsList();

  @override
  State<_LiveEventsList> createState() => _LiveEventsListState();
}

class _LiveEventsListState extends State<_LiveEventsList> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() => _stream = FirebaseFirestore.instance
      .collection('Events')
      .where('active', isEqualTo: true)
      .limit(20)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return CanopyErrorState(
            inline: true,
            title: "Couldn't load live events.",
            onRetry: () => setState(_subscribe),
          );
        }
        if (!snap.hasData) return const CanopyListSkeleton(rows: 2, leadingSize: 56);

        final events = snap.data!.docs.map(CanopyEvent.fromDoc).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));

        if (events.isEmpty) {
          return const CanopyEmptyState(
            boxed: true,
            icon: Icons.event_available_outlined,
            title: 'No live events right now',
            line:
                "Most check-ins are worth +10 points — look for an organiser's QR at your next clean-up or planting day.",
          );
        }

        return CanopyListGroup(
          children: [
            for (final e in events.take(5))
              CanopyListRow(
                // Live = happening today.
                leading: CanopyDateBlock(date: DateTime.now()),
                title: e.title,
                subtitle: e.orgName,
                below: LabelRow(children: [
                  StatusLabel('Live', color: p.danger, live: true),
                  PointsLabel(e.pointsPerCheckin),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (Icons.place_outlined, 'Turn up',
        'Join a clean-up, planting day or other event run by an organisation.'),
    (Icons.qr_code_2_outlined, "Scan the organiser's QR",
        'Tap "Scan QR code" and point your camera at their code.'),
    (Icons.military_tech_outlined, 'Get your points',
        'Points land on your profile straight away and count toward badges and the leaderboard.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyCard(
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: CanopySpace.s16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}',
                    style: CanopyType.title.copyWith(color: p.ink)),
                const SizedBox(width: CanopySpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_steps[i].$2,
                          style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                      const SizedBox(height: CanopySpace.s2),
                      Text(_steps[i].$3,
                          style:
                              CanopyType.caption.copyWith(color: p.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: CanopySpace.s12),
                Icon(_steps[i].$1, size: CanopyIconSize.nav, color: p.inkMuted),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Scanner ──────────────────────────────────────────────────────────────────

enum _ScanState { scanning, processing, success, error }

/// QR check-in scanner. Camera chrome always renders on the dark palette.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _service = EventsService();
  final MobileScannerController _controller = MobileScannerController();
  _ScanState _state = _ScanState.scanning;
  String _message = '';
  int _points = 0;
  bool _already = false;
  String? _eventTitle;
  String? _orgName;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_state != _ScanState.scanning) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;

    final parsed = EventsService.parsePayload(raw);
    if (parsed == null) {
      setState(() {
        _state = _ScanState.error;
        _message = "That isn't a Canopy event code. Ask the organiser to show their check-in QR.";
      });
      return;
    }

    setState(() => _state = _ScanState.processing);
    try {
      // Event title/org for the result screen — best effort, never blocks.
      FirebaseFirestore.instance
          .collection('Events')
          .doc(parsed.eventId)
          .get()
          .then((s) {
        if (!mounted || !s.exists) return;
        final e = CanopyEvent.fromDoc(s);
        setState(() {
          _eventTitle = e.title;
          _orgName = e.orgName;
        });
      }).catchError((_) {});

      final result =
          await _service.checkIn(eventId: parsed.eventId, token: parsed.token);
      if (!mounted) return;
      setState(() {
        _state = _ScanState.success;
        _points = result.pointsAwarded;
        _already = result.alreadyCheckedIn;
      });
    } on CheckInException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _message = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _message = "We couldn't reach Canopy. Check your connection and scan again.";
      });
    }
  }

  void _scanAgain() => setState(() {
        _state = _ScanState.scanning;
        _message = '';
      });

  @override
  Widget build(BuildContext context) {
    // Camera chrome is always dark, whatever the app theme.
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        extensions: const [CanopyPalette.dark],
      ),
      child: Builder(builder: (context) {
        final p = context.canopy;
        return Scaffold(
          backgroundColor: p.canvas,
          appBar: canopyAppBar(
            context,
            title: 'Scan QR code',
            actions: [
              if (_state == _ScanState.scanning)
                CanopyIconButton(
                  icon: _torch ? Icons.flash_on_outlined : Icons.flash_off_outlined,
                  tooltip: _torch ? 'Turn torch off' : 'Turn torch on',
                  onPressed: () {
                    _controller.toggleTorch();
                    setState(() => _torch = !_torch);
                  },
                ),
            ],
          ),
          body: switch (_state) {
            _ScanState.success => _SuccessView(
                points: _points,
                already: _already,
                eventTitle: _eventTitle,
                orgName: _orgName,
              ),
            _ => Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) =>
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? const _CameraDenied()
                            : CanopyErrorState(
                                title: "The camera didn't start",
                                line: 'Close the scanner and try again.',
                                onRetry: () => _controller.start(),
                              ),
                  ),
                  if (_state == _ScanState.scanning) const _ScanFrame(),
                  Positioned(
                    left: CanopySpace.gutter,
                    right: CanopySpace.gutter,
                    bottom: CanopySpace.s32 + MediaQuery.paddingOf(context).bottom,
                    child: switch (_state) {
                      _ScanState.scanning => Text(
                          "Point your camera at the QR code the organiser is showing.",
                          textAlign: TextAlign.center,
                          style: CanopyType.body.copyWith(color: p.ink),
                        ),
                      _ScanState.processing => _Panel(children: [
                          const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5)),
                          const SizedBox(height: CanopySpace.s12),
                          Text('Checking you in…',
                              style: CanopyType.subhead.copyWith(color: p.ink)),
                        ]),
                      _ => _Panel(children: [
                          Icon(Icons.error_outline,
                              size: CanopyIconSize.s32, color: p.danger),
                          const SizedBox(height: CanopySpace.s8),
                          Text("Check-in didn't go through",
                              textAlign: TextAlign.center,
                              style: CanopyType.subhead.copyWith(color: p.ink)),
                          const SizedBox(height: CanopySpace.s4),
                          Text(_message,
                              textAlign: TextAlign.center,
                              style:
                                  CanopyType.body.copyWith(color: p.inkMuted)),
                          const SizedBox(height: CanopySpace.s16),
                          CanopyButton(
                              label: 'Scan again',
                              expand: true,
                              onPressed: _scanAgain),
                        ]),
                    },
                  ),
                ],
              ),
          },
        );
      }),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Container(
      padding: const EdgeInsets.all(CanopySpace.s20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(CanopyRadius.lg),
        boxShadow: CanopyElevation.e2(Brightness.dark),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: p.primarySoft, width: 3),
            borderRadius: BorderRadius.circular(CanopyRadius.xl),
          ),
        ),
      ),
    );
  }
}

class _CameraDenied extends StatelessWidget {
  const _CameraDenied();

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return ColoredBox(
      color: p.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(CanopySpace.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined,
                  size: CanopyIconSize.empty, color: p.inkFaint),
              const SizedBox(height: CanopySpace.s12),
              Text('Camera access is off',
                  style: CanopyType.heading.copyWith(color: p.ink)),
              const SizedBox(height: CanopySpace.s4),
              Text(
                "Canopy needs your camera to read the organiser's QR code. Turn it on in Settings, then come back.",
                textAlign: TextAlign.center,
                style: CanopyType.body.copyWith(color: p.inkMuted),
              ),
              const SizedBox(height: CanopySpace.s16),
              CanopyButton(label: 'Open settings', onPressed: openAppSettings),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final int points;
  final bool already;
  final String? eventTitle;
  final String? orgName;
  const _SuccessView({
    required this.points,
    required this.already,
    this.eventTitle,
    this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final headline = CanopyType.hero.copyWith(color: p.goldInk);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CanopySpace.gutter),
        child: Column(
          children: [
            const Spacer(),
            if (already)
              Icon(Icons.check_circle_outline,
                  size: CanopyIconSize.empty, color: p.success)
            else
              CanopyCheckInBurst(
                size: 120,
                child: CanopyCountUp(value: points, style: headline, prefix: '+'),
              ),
            const SizedBox(height: CanopySpace.s12),
            Text(already ? "You're already checked in" : 'Checked in',
                style: CanopyType.display.copyWith(color: p.ink)),
            const SizedBox(height: CanopySpace.s4),
            Text(
              [
                if (eventTitle != null) eventTitle!,
                if (orgName != null && orgName!.isNotEmpty) orgName!,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: CanopyType.body.copyWith(color: p.inkMuted),
            ),
            if (!already) ...[
              const SizedBox(height: CanopySpace.s4),
              Text('$points points added to your total.',
                  style: CanopyType.body.copyWith(color: p.inkMuted)),
            ],
            const Spacer(),
            CanopyButton(
                label: 'Done',
                expand: true,
                onPressed: () => Navigator.pop(context)),
            CanopyButton.quiet(
              label: 'See your impact',
              expand: true,
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/impact'),
            ),
          ],
        ),
      ),
    );
  }
}
