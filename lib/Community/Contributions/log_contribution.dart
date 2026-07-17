import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../Models/user.dart';
import '../../Services/Contributions/contribution_service.dart';
import '../../Shared/theme/app_theme.dart';

/// Maximum number of photos a single entry can carry.
const int _kMaxPhotos = 4;

/// Project tracking modes shown as selectable cards.
enum TrackingType {
  oneTime(
    'oneTime',
    'One-time event',
    Icons.bolt_outlined,
    'A single activity — a one-off cleanup, donation drive or repair. '
        'Logged once, with no monthly follow-ups.',
  ),
  transformation(
    'transformation',
    'Transformation activity',
    Icons.timeline_outlined,
    'An ongoing project you\'ll trace month by month. We\'ll remind you about '
        'a month from now to add Month 1 photos, then each month after, so the '
        'change over time is visible.',
  );

  const TrackingType(this.id, this.label, this.icon, this.description);

  final String id;
  final String label;
  final IconData icon;
  final String description;
}

/// A single optional social link the user can attach to an entry.
class _SocialPlatform {
  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;

  const _SocialPlatform({
    required this.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });
}

const List<_SocialPlatform> _kSocialPlatforms = [
  _SocialPlatform(
    key: 'linkedin',
    label: 'LinkedIn',
    hint: 'linkedin.com/in/...',
    icon: Icons.business_center_outlined,
    color: Color(0xFF0A66C2),
  ),
  _SocialPlatform(
    key: 'facebook',
    label: 'Facebook',
    hint: 'facebook.com/...',
    icon: Icons.facebook,
    color: Color(0xFF1877F2),
  ),
  _SocialPlatform(
    key: 'instagram',
    label: 'Instagram',
    hint: 'instagram.com/...',
    icon: Icons.camera_alt_outlined,
    color: Color(0xFFE4405F),
  ),
  _SocialPlatform(
    key: 'tiktok',
    label: 'TikTok',
    hint: 'tiktok.com/@...',
    icon: Icons.music_note,
    color: Color(0xFF010101),
  ),
];

class LogContributionScreen extends StatefulWidget {
  const LogContributionScreen({super.key});

  @override
  State<LogContributionScreen> createState() => _LogContributionScreenState();
}

class _LogContributionScreenState extends State<LogContributionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _workType = 'Cleanup';
  TrackingType _trackingType = TrackingType.oneTime;

  // Social link controllers, keyed by platform.
  final Map<String, TextEditingController> _socialControllers = {
    for (final p in _kSocialPlatforms) p.key: TextEditingController(),
  };

  // Points are estimated from the work type bonus (time-based contribution).
  static const String _type = 'Time';

  final _picker = ImagePicker();
  final List<XFile> _photos = [];

  bool _saving = false;
  bool _verifyingLocation = false;
  bool _locationVerified = false;
  Position? _currentPosition;
  final _locationController = TextEditingController();


  // Work type configurations.
  static const List<Map<String, dynamic>> _workTypes = [
    {
      'name': 'Cleanup',
      'icon': Icons.cleaning_services,
      'description': 'Community cleanup initiatives',
    },
    {
      'name': 'Tree Planting',
      'icon': Icons.park,
      'description': 'Planting and nurturing trees',
    },
    {
      'name': 'School Upgrading',
      'icon': Icons.school,
      'description': 'Improving school facilities',
    },
    {
      'name': 'Waste Management',
      'icon': Icons.recycling,
      'description': 'Organizing waste and recycling',
    },
    {
      'name': 'Water & Sanitation',
      'icon': Icons.water_drop,
      'description': 'Improving water and sanitation',
    },
    {
      'name': 'Infrastructure',
      'icon': Icons.construction,
      'description': 'Community infrastructure projects',
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    for (final c in _socialControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> get _workTypeConfig => _workTypes.firstWhere(
        (w) => w['name'] == _workType,
        orElse: () => _workTypes[0],
      );

  int _estimate() {
    return ContributionService().estimateImpactPoints(
      type: _type,
      workType: _workType,
    );
  }

  void _showSnack(String message, Color color, {IconData? icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Location verification ────────────────────────────────────────────────────

  Future<void> _verifyLocation() async {
    setState(() => _verifyingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Contributions happen wherever the member is, so capture the reading
      // as-is. This used to reject anything beyond 500m of a hardcoded point
      // in central Nairobi, which made logging impossible everywhere else.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locationVerified = true;
        _locationController.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
      _showSnack('Location captured', Colors.green.shade600,
          icon: Icons.check_circle);
    } catch (e) {
      _showSnack('Could not capture location: $e', Colors.red.shade600,
          icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _verifyingLocation = false);
    }
  }

  // ── Photos ───────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (_photos.length >= _kMaxPhotos) {
      _showSnack('You can add up to $_kMaxPhotos photos.',
          Colors.orange.shade700,
          icon: Icons.info_outline);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const _IconPill(
                  icon: Icons.photo_camera_outlined, color: AppTheme.primary),
              title: const Text('Take a photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const _IconPill(
                  icon: Icons.photo_library_outlined, color: AppTheme.tertiary),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (file != null && mounted) {
      setState(() => _photos.add(file));
    }
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  // ── Submit ───────────────────────────────────────────────────────────────────

  Map<String, String> _collectSocialLinks() {
    final links = <String, String>{};
    for (final p in _kSocialPlatforms) {
      final v = _socialControllers[p.key]!.text.trim();
      if (v.isNotEmpty) links[p.key] = v;
    }
    return links;
  }

  Future<void> _submit() async {
    final user = Provider.of<F_User?>(context, listen: false);
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_locationVerified) {
      _showSnack('Please capture your location first.', Colors.orange.shade700,
          icon: Icons.location_off_outlined);
      return;
    }

    if (_photos.isEmpty) {
      _showSnack('Add at least one photo.', Colors.orange.shade700,
          icon: Icons.photo_outlined);
      return;
    }

    setState(() => _saving = true);

    try {
      final points = await ContributionService().createContribution(
        userId: user.uid,
        title: _titleController.text.trim(),
        workType: _workType,
        type: _type,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        photos: _photos,
        trackingType: _trackingType.id,
        socialLinks: _collectSocialLinks(),
        location: _locationController.text.trim(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/contributions/confirm',
        arguments: {'points': points},
      );
    } catch (e) {
      _showSnack('Error: $e', Colors.red.shade600, icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final points = _estimate();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.tertiary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 15, color: AppTheme.darkGreen),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Log Contribution',
              style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
          Text('Record the work you did',
              style: TextStyle(
                  color: AppTheme.darkGreen.withOpacity(0.5), fontSize: 11)),
        ]),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Location verification
                      _LocationCard(
                        verified: _locationVerified,
                        verifying: _verifyingLocation,
                        onVerify: _verifyLocation,
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const _SectionLabel('Title', AppTheme.primary),
                      const SizedBox(height: 10),
                      _LabeledField(
                        controller: _titleController,
                        label: 'Contribution title',
                        icon: Icons.title,
                        accent: AppTheme.primary,
                        maxLength: 50,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 22),

                      // Description
                      const _SectionLabel('Description', AppTheme.accent),
                      const SizedBox(height: 6),
                      Text(
                        'Shown on the community feed. Tell people what changed.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 10),
                      _LabeledField(
                        controller: _descriptionController,
                        label: 'Describe the activity...',
                        icon: Icons.notes_outlined,
                        accent: AppTheme.accent,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 22),

                      // Work type
                      const _SectionLabel('Work Type', AppTheme.lightGreen),
                      const SizedBox(height: 10),
                      _buildWorkTypeDropdown(),
                      const SizedBox(height: 22),

                      // Tracking type
                      const _SectionLabel('Activity Type', AppTheme.tertiary),
                      const SizedBox(height: 6),
                      Text(
                        'How should we follow this project over time?',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 12),
                      ...TrackingType.values.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TrackingCard(
                              type: t,
                              selected: _trackingType == t,
                              onTap: () =>
                                  setState(() => _trackingType = t),
                            ),
                          )),
                      const SizedBox(height: 12),

                      // Photos
                      _SectionLabel(
                        'Photos',
                        AppTheme.primary,
                        trailing: '${_photos.length}/$_kMaxPhotos',
                      ),
                      const SizedBox(height: 12),
                      _PhotoGrid(
                        photos: _photos,
                        maxPhotos: _kMaxPhotos,
                        onAdd: _pickPhoto,
                        onRemove: _removePhoto,
                      ),
                      const SizedBox(height: 22),

                      // Social links
                      const _SectionLabel('Links', AppTheme.darkGreen,
                          trailing: 'Optional'),
                      const SizedBox(height: 6),
                      Text(
                        'Attach social links so people can follow the project.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGreen.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 12),
                      ..._kSocialPlatforms.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LabeledField(
                              controller: _socialControllers[p.key]!,
                              label: '${p.label} (optional)',
                              hint: p.hint,
                              icon: p.icon,
                              accent: p.color,
                              keyboardType: TextInputType.url,
                            ),
                          )),
                      const SizedBox(height: 10),

                      // Impact estimate
                      _ImpactCard(points: points),
                    ],
                  ),
                ),
              ),

              // Submit
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: _GradientButton(
                    label: 'Submit Contribution',
                    icon: Icons.check_circle_outline,
                    isLoading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.lightGreen.withOpacity(0.4), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _IconPill(
              icon: _workTypeConfig['icon'] as IconData,
              color: AppTheme.lightGreen),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _workType,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.lightGreen.withOpacity(0.8)),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
                items: _workTypes.map((w) {
                  return DropdownMenuItem(
                    value: w['name'] as String,
                    child: Text(w['name'] as String),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _workType = v ?? 'Cleanup'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable widgets (registration-style)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  final String? trailing;

  const _SectionLabel(this.text, this.color, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(trailing!,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ],
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconPill({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accent;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accent,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
  });

  OutlineInputBorder _border(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width));

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(
          color: AppTheme.darkGreen, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: hint == null ? label : null,
        hintText: hint,
        labelStyle: TextStyle(color: accent.withOpacity(0.75), fontSize: 13),
        hintStyle: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.35), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        counterText: maxLength == null ? null : '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: _IconPill(icon: icon, color: accent),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 52, minHeight: 52),
        border: _border(accent.withOpacity(0.2)),
        enabledBorder: _border(accent.withOpacity(0.22)),
        focusedBorder: _border(accent, width: 2),
        errorBorder: _border(Colors.red.shade300),
        focusedErrorBorder: _border(Colors.red.shade400, width: 2),
      ),
      validator: validator,
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final TrackingType type;
  final bool selected;
  final VoidCallback onTap;

  const _TrackingCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.tertiary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? accent : Colors.grey.withOpacity(0.22),
              width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: accent.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? accent : accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(type.icon,
                color: selected ? Colors.white : accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: selected ? accent : AppTheme.darkGreen)),
                  const SizedBox(height: 3),
                  Text(type.description,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppTheme.darkGreen.withOpacity(0.6))),
                ]),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, color: accent, size: 20),
          ],
        ]),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool verified;
  final bool verifying;
  final VoidCallback onVerify;

  const _LocationCard({
    required this.verified,
    required this.verifying,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final accent = verified ? AppTheme.primary : AppTheme.tertiary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                  verified ? Icons.check_circle : Icons.location_on_outlined,
                  color: Colors.white,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location Verification',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen)),
                    const SizedBox(height: 2),
                    Text(
                      verified
                          ? 'Location captured ✓'
                          : 'Required to log a contribution',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.55)),
                    ),
                  ]),
            ),
          ]),
          if (!verified) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: verifying ? null : onVerify,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.my_location, size: 18),
                label: Text(verifying ? 'Capturing...' : 'Capture Location',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final int points;
  const _ImpactCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Estimated Impact',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95))),
            const SizedBox(height: 2),
            Text('$points Points',
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5)),
          ]),
        ),
      ]),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primary, AppTheme.tertiary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ── Photo grid ────────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _PhotoGrid({
    required this.photos,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Show all picked photos plus a single trailing "add" tile while there's room.
    final showAdd = photos.length < maxPhotos;
    final itemCount = photos.length + (showAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1, // square tiles
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < photos.length) {
          return _PhotoTile(
            file: photos[index],
            onRemove: () => onRemove(index),
          );
        }
        return _AddPhotoTile(onTap: onAdd);
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _PhotoTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(file.path), fit: BoxFit.cover),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 17),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.lightGreen.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined,
                  color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 10),
            Text('Add photo',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
