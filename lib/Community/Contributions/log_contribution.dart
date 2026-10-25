// lib/Community/Contributions/log_contribution.dart
//
// Log Contribution (DESIGN_HANDOFF.md §3). Sections top → bottom: location
// capture · what you did (title, description, work type, hours) · one-time vs
// transformation radio cards (transformation shows the month timeline) ·
// photos (PhotoPickerTile states) · link to an organisation activity · links ·
// estimated points (gold numerals, "once verified") · sticky "Submit".
//
// Data flow is unchanged: ContributionService.createContribution uploads the
// photos and writes the doc; points only count after verification.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Contributions/contribution_service.dart';
import '../../Shared/Inputs/pin_picker_screen.dart';
import '../../theme/canopy_components.dart';
import 'contribution_confirmation.dart';

/// Maximum number of photos a single entry can carry.
const int _kMaxPhotos = 4;

/// Project tracking modes shown as radio cards.
enum TrackingType {
  oneTime(
    'oneTime',
    'One-time',
    'A single activity — a one-off clean-up, donation drive or repair. Logged once.',
  ),
  transformation(
    'transformation',
    'Transformation',
    "An ongoing project you'll trace month by month so the change over time is visible.",
  );

  const TrackingType(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;
}

const _kSocialPlatforms = [
  ('linkedin', 'LinkedIn', 'linkedin.com/in/…'),
  ('facebook', 'Facebook', 'facebook.com/…'),
  ('instagram', 'Instagram', 'instagram.com/…'),
  ('tiktok', 'TikTok', 'tiktok.com/@…'),
];

const _kWorkTypes = [
  ('Cleanup', Icons.cleaning_services_outlined),
  ('Tree Planting', Icons.park_outlined),
  ('School Upgrading', Icons.school_outlined),
  ('Waste Management', Icons.recycling_outlined),
  ('Water & Sanitation', Icons.water_drop_outlined),
  ('Infrastructure', Icons.construction_outlined),
];

class LogContributionScreen extends StatefulWidget {
  const LogContributionScreen({super.key});

  @override
  State<LogContributionScreen> createState() => _LogContributionScreenState();
}

class _LogContributionScreenState extends State<LogContributionScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hoursController = TextEditingController();
  final Map<String, TextEditingController> _socialControllers = {
    for (final p in _kSocialPlatforms) p.$1: TextEditingController(),
  };

  late final _activities = FirebaseFirestore.instance
      .collection('activities')
      .limit(100)
      .snapshots();

  // Time estimates are awarded only after independent verification.
  static const String _type = 'Time';

  String _workType = _kWorkTypes.first.$1;
  TrackingType _trackingType = TrackingType.oneTime;
  String? _activityId;
  String? _activityTitle;

  final _picker = ImagePicker();
  final List<XFile> _photos = [];

  bool _saving = false;
  bool _submitFailed = false;
  bool _showErrors = false;

  bool _locating = false;
  String? _locationError;
  Position? _position;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    for (final c in _socialControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────

  double? get _hours => double.tryParse(_hoursController.text.trim());

  String? get _titleError =>
      _titleController.text.trim().isEmpty ? 'Give your contribution a title.' : null;

  String? get _hoursError {
    final h = _hours;
    if (h == null || !h.isFinite || h <= 0 || h > 24) {
      return 'Enter hours greater than 0 and up to 24.';
    }
    return null;
  }

  int get _estimate => ContributionService()
      .estimateImpactPoints(type: _type, hours: _hours, workType: _workType);

  // ── Location ────────────────────────────────────────────────────────────

  /// Pick the exact place on a map instead of reading this phone's GPS.
  Future<void> _chooseLocation() async {
    final start = _position == null ? null : LatLng(_position!.latitude, _position!.longitude);
    final at = await pickPin(context, initial: start, title: 'Where was the work?');
    if (at == null || !mounted) return;
    setState(() {
      _locationError = null;
      _position = Position(
        latitude: at.latitude,
        longitude: at.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    });
  }

  Future<void> _captureLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationDenied();
      }
      // Contributions happen wherever the member is — capture as-is.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _position = position);
    } on _LocationDenied {
      if (!mounted) return;
      setState(() => _locationError =
          'Location access is off. Turn it on in Settings to log where the work happened.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationError =
          "We couldn't get a location fix. Move somewhere with a clear sky and try again.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Photos ──────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (_photos.length >= _kMaxPhotos) return;
    final source = await showCanopySheet<ImageSource>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: 'Add a photo',
        children: [
          CanopyListGroup(children: [
            CanopyListRow(
              icon: Icons.photo_camera_outlined,
              title: 'Take a photo',
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            CanopyListRow(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        ],
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file != null && mounted) {
      setState(() {
        _photos.add(file);
        _submitFailed = false;
      });
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final user = Provider.of<F_User?>(context, listen: false);
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }
    setState(() => _showErrors = true);
    if (_titleError != null || _hoursError != null) {
      showCanopySnack(context, 'Fill in the highlighted fields.', error: true);
      return;
    }
    if (_position == null) {
      showCanopySnack(context, 'Capture your location first.', error: true);
      return;
    }
    if (_photos.isEmpty) {
      showCanopySnack(context, 'Add at least one photo.', error: true);
      return;
    }

    setState(() {
      _saving = true;
      _submitFailed = false;
    });
    try {
      final links = <String, String>{
        for (final p in _kSocialPlatforms)
          if (_socialControllers[p.$1]!.text.trim().isNotEmpty)
            p.$1: _socialControllers[p.$1]!.text.trim(),
      };
      final points = await ContributionService().createContribution(
        userId: user.uid,
        activityId: _activityId,
        title: _titleController.text.trim(),
        workType: _workType,
        type: _type,
        hours: _hours,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        photos: _photos,
        trackingType: _trackingType.id,
        socialLinks: links,
        location:
            '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ContributionConfirmationScreen(
            points: points,
            transformation: _trackingType == TrackingType.transformation,
            linkedActivity: _activityTitle,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return CanopyScaffold(
      appBar: canopyAppBar(context, title: 'Log contribution'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CanopySpace.gutter, CanopySpace.s8,
            CanopySpace.gutter, CanopySpace.s32),
        children: [
          Text('Record the work you did. Points count once an organisation verifies it.',
              style: CanopyType.body.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.section),

          // ── Where ─────────────────────────────────────────────────────
          _Heading('Where'),
          _LocationBlock(
            position: _position,
            locating: _locating,
            error: _locationError,
            showRequired: _showErrors && _position == null,
            onCapture: _captureLocation,
            onChoose: _chooseLocation,
          ),
          const SizedBox(height: CanopySpace.section),

          // ── What ──────────────────────────────────────────────────────
          _Heading('What you did'),
          CanopyTextField(
            label: 'Title',
            hint: 'Riverbank clean-up at Ngong Road',
            controller: _titleController,
            maxLength: 50,
            error: _showErrors ? _titleError : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Description',
            hint: 'Tell people what changed.',
            helper: 'Shown on the community feed.',
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyPickerField(
            label: 'Work type',
            value: _workType,
            onTap: _chooseWorkType,
          ),
          const SizedBox(height: CanopySpace.s16),
          CanopyTextField(
            label: 'Hours',
            hint: '3',
            controller: _hoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            helper: '10 estimated points per hour · up to 24 hours',
            error: _showErrors ? _hoursError : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CanopySpace.section),

          // ── Tracking ──────────────────────────────────────────────────
          _Heading('How should we follow it?'),
          for (final t in TrackingType.values) ...[
            CanopyOptionCard(
              selected: _trackingType == t,
              onTap: () => setState(() => _trackingType = t),
              title: t.label,
              caption: t.description,
              child: t == TrackingType.transformation &&
                      _trackingType == TrackingType.transformation
                  ? const _MonthTimeline()
                  : null,
            ),
            const SizedBox(height: CanopySpace.s12),
          ],
          const SizedBox(height: CanopySpace.section - CanopySpace.s12),

          // ── Photos ────────────────────────────────────────────────────
          _Heading('Photos', trailing: '${_photos.length} of $_kMaxPhotos'),
          if (_trackingType == TrackingType.transformation)
            Padding(
              padding: const EdgeInsets.only(bottom: CanopySpace.s12),
              child: Text('Your first photo becomes the "before" shot.',
                  style: CanopyType.caption.copyWith(color: p.inkMuted)),
            ),
          _PhotoGrid(
            photos: _photos,
            uploading: _saving,
            failed: _submitFailed,
            showRequired: _showErrors && _photos.isEmpty,
            onAdd: _pickPhoto,
            onRemove: (i) => setState(() => _photos.removeAt(i)),
            onRetry: _submit,
          ),
          const SizedBox(height: CanopySpace.section),

          // ── Activity link ─────────────────────────────────────────────
          _Heading('Organisation activity', trailing: 'Optional'),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _activities,
            builder: (context, snap) {
              final activities = snap.data?.docs
                      .where((d) =>
                          d.data()['orgId'] is String &&
                          (d.data()['orgId'] as String).isNotEmpty)
                      .toList() ??
                  const [];
              return CanopyPickerField(
                label: 'Linked activity',
                value: _activityTitle,
                placeholder: snap.hasData ? 'None' : 'Loading…',
                helper: snap.hasError
                    ? 'Activities are unavailable right now. You can still submit.'
                    : 'Linking an activity lets its organisation verify your work.',
                onTap: () => _chooseActivity(activities),
              );
            },
          ),
          const SizedBox(height: CanopySpace.section),

          // ── Links ─────────────────────────────────────────────────────
          _Heading('Links', trailing: 'Optional'),
          for (final s in _kSocialPlatforms) ...[
            CanopyTextField(
              label: s.$2,
              hint: s.$3,
              controller: _socialControllers[s.$1],
              keyboardType: TextInputType.url,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: CanopySpace.s12),
          ],
          const SizedBox(height: CanopySpace.s12),

          // ── Estimate ──────────────────────────────────────────────────
          CanopyCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESTIMATED POINTS',
                          style: CanopyType.eyebrow.copyWith(color: p.inkMuted)),
                      const SizedBox(height: CanopySpace.s4),
                      Text('Added to your total once verified.',
                          style: CanopyType.caption.copyWith(color: p.inkMuted)),
                    ],
                  ),
                ),
                PointsLabel(_estimate, fontSize: 22),
              ],
            ),
          ),
          if (_submitFailed) ...[
            const SizedBox(height: CanopySpace.s16),
            CanopyCallout(
              kind: CalloutKind.danger,
              title: "Your contribution didn't send",
              text: 'Nothing was lost — your photos and details are still here.',
              action: CanopyButton.quiet(label: 'Try again', onPressed: _submit),
            ),
          ],
        ],
      ),
      sticky: StickyActionBar(children: [
        CanopyButton(
          label: 'Submit contribution',
          expand: true,
          loading: _saving,
          onPressed: _submit,
        ),
      ]),
    );
  }

  Future<void> _chooseWorkType() async {
    final picked = await showCanopySheet<String>(
      context,
      builder: (ctx) => CanopySheetBody(
        title: 'Work type',
        children: [
          CanopyListGroup(children: [
            for (final w in _kWorkTypes)
              CanopyListRow(
                icon: w.$2,
                title: w.$1,
                chevron: false,
                trailing: w.$1 == _workType
                    ? Icon(Icons.check, color: ctx.canopy.ink)
                    : null,
                onTap: () => Navigator.pop(ctx, w.$1),
              ),
          ]),
        ],
      ),
    );
    if (picked != null) setState(() => _workType = picked);
  }

  Future<void> _chooseActivity(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> activities) async {
    final picked = await showCanopySheet<(String?, String?)>(
      context,
      tall: true,
      builder: (ctx) => CanopySheetBody(
        title: 'Link an activity',
        caption: 'Its organisation reviews and verifies your contribution.',
        children: [
          if (activities.isEmpty)
            const CanopyEmptyState(
              boxed: true,
              icon: Icons.event_note_outlined,
              title: 'No organisation activities yet',
            )
          else
            CanopyListGroup(children: [
              CanopyListRow(
                title: 'None',
                chevron: false,
                onTap: () => Navigator.pop(ctx, (null, null)),
              ),
              for (final d in activities)
                CanopyListRow(
                  title: (d.data()['title'] ?? d.data()['name'] ?? 'Community activity')
                      .toString(),
                  subtitle: (d.data()['organizerName'] ?? d.data()['orgName'] ?? '')
                      .toString(),
                  chevron: false,
                  trailing: d.id == _activityId
                      ? Icon(Icons.check, color: ctx.canopy.ink)
                      : null,
                  onTap: () => Navigator.pop(ctx, (
                    d.id,
                    (d.data()['title'] ?? d.data()['name'] ?? 'Community activity')
                        .toString()
                  )),
                ),
            ]),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _activityId = picked.$1;
        _activityTitle = picked.$2;
      });
    }
  }
}

class _LocationDenied implements Exception {
  const _LocationDenied();
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  final String text;
  final String? trailing;
  const _Heading(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    return Padding(
      padding: const EdgeInsets.only(bottom: CanopySpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: CanopyType.heading.copyWith(color: p.ink)),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: CanopyType.caption.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }
}

class _LocationBlock extends StatelessWidget {
  final Position? position;
  final bool locating;
  final String? error;
  final bool showRequired;
  final VoidCallback onCapture;
  final VoidCallback onChoose;

  const _LocationBlock({
    required this.position,
    required this.locating,
    required this.error,
    required this.showRequired,
    required this.onCapture,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    if (position != null) {
      return CanopyListGroup(children: [
        CanopyListRow(
          icon: Icons.my_location_outlined,
          title: position!.accuracy == 0 ? 'Place chosen on the map' : 'Location captured',
          subtitle:
              '${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}${position!.accuracy == 0 ? '' : ' · ±${position!.accuracy.round()} m'}',
          below: StatusLabel('Ready', color: p.success),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            CanopyButton.quiet(label: 'Map', size: CanopyButtonSize.compact, onPressed: onChoose),
            CanopyButton.quiet(label: 'GPS', size: CanopyButtonSize.compact, onPressed: onCapture),
          ]),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CanopyCard(
          borderColor: showRequired ? p.danger : null,
          borderWidth: showRequired ? 2 : 1,
          child: Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: CanopyIconSize.nav, color: p.inkMuted),
              const SizedBox(width: CanopySpace.s12),
              Expanded(
                child: Text(
                  'Required. We record where the work happened so it can be verified.',
                  style: CanopyType.body.copyWith(color: p.ink),
                ),
              ),
              const SizedBox(width: CanopySpace.s8),
              CanopyButton.secondary(
                label: 'Capture',
                size: CanopyButtonSize.compact,
                loading: locating,
                onPressed: onCapture,
              ),
            ],
          ),
        ),
        const SizedBox(height: CanopySpace.s8),
        CanopyButton.quiet(label: 'Choose the place on the map', expand: true, onPressed: onChoose),
        if (error != null) ...[
          const SizedBox(height: CanopySpace.s8),
          CanopyCallout(kind: CalloutKind.warning, text: error!),
        ],
      ],
    );
  }
}

/// Transformation month timeline: Today (before) → Month 1 → Month 2 → Month 3…
class _MonthTimeline extends StatelessWidget {
  const _MonthTimeline();

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final steps = [
      ('Today', 'Before photos'),
      ('Month 1', "We'll remind you"),
      ('Month 2', 'Progress photos'),
      ('Month 3+', 'Keep tracing'),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0 ? p.primary : p.surface,
                          border: Border.all(
                              color: i == 0 ? p.primary : p.outlineStrong,
                              width: 2),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(width: 2, color: p.outline),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: CanopySpace.s8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: CanopySpace.s12),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '${steps[i].$1}  ',
                          style: CanopyType.bodyStrong.copyWith(color: p.ink)),
                      TextSpan(
                          text: steps[i].$2,
                          style: CanopyType.caption.copyWith(color: p.inkMuted)),
                    ])),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// PhotoPickerTile grid: empty (dashed) · picked (thumb + remove) ·
/// uploading (ring) · failed (retry).
class _PhotoGrid extends StatelessWidget {
  final List<XFile> photos;
  final bool uploading;
  final bool failed;
  final bool showRequired;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onRetry;

  const _PhotoGrid({
    required this.photos,
    required this.uploading,
    required this.failed,
    required this.showRequired,
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final showAdd = photos.length < _kMaxPhotos && !uploading;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: CanopySpace.s12,
      mainAxisSpacing: CanopySpace.s12,
      children: [
        for (var i = 0; i < photos.length; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(CanopyRadius.sm),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(photos[i].path), fit: BoxFit.cover),
                if (uploading || failed)
                  ColoredBox(
                    color: p.scrim,
                    child: Center(
                      child: uploading
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: CanopyPalette.onHero))
                          : Semantics(
                              button: true,
                              label: 'Retry upload',
                              child: InkWell(
                                onTap: onRetry,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.refresh,
                                        color: CanopyPalette.onHero),
                                    Text('Retry',
                                        style: CanopyType.label.copyWith(
                                            color: CanopyPalette.onHero)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                if (i == 0)
                  Positioned(
                    left: CanopySpace.s8,
                    bottom: CanopySpace.s8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      color: p.scrim,
                      child: Text('COVER',
                          style: CanopyType.micro
                              .copyWith(color: CanopyPalette.onHero)),
                    ),
                  ),
                if (!uploading)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: CanopyIconButton(
                      icon: Icons.close,
                      tooltip: 'Remove photo',
                      onImage: true,
                      onPressed: () => onRemove(i),
                    ),
                  ),
              ],
            ),
          ),
        if (showAdd)
          DashedBorder(
            color: showRequired ? p.danger : p.outlineStrong,
            radius: CanopyRadius.sm,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(CanopyRadius.sm),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: CanopyIconSize.nav, color: p.ink),
                      const SizedBox(height: CanopySpace.s8),
                      Text('Add photo',
                          style: CanopyType.label.copyWith(color: p.ink)),
                      if (showRequired)
                        Text('At least one',
                            style: CanopyType.caption.copyWith(color: p.danger)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
