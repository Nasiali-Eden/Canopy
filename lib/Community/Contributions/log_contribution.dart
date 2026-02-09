import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

import '../../Models/user.dart';
import '../../Services/Contributions/contribution_service.dart';
import '../../Shared/theme/app_theme.dart';

class LogContributionScreen extends StatefulWidget {
  const LogContributionScreen({super.key});

  @override
  State<LogContributionScreen> createState() => _LogContributionScreenState();
}

class _LogContributionScreenState extends State<LogContributionScreen> {
  final _formKey = GlobalKey<FormState>();

  // New fields
  final _titleController = TextEditingController();
  String _workType = 'Cleanup';

  // Old fields
  String _type = 'Time';
  final _hoursController = TextEditingController();
  final _effortController = TextEditingController();
  final _materialsController = TextEditingController();
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();

  final _picker = ImagePicker();
  final List<XFile> _beforePhotos = [];
  final List<XFile> _afterPhotos = [];

  bool _saving = false;
  bool _verifyingLocation = false;
  bool _locationVerified = false;
  Position? _currentPosition;

  final double _requiredLatitude = -1.286389;
  final double _requiredLongitude = 36.817223;
  final double _maxDistanceInMeters = 500;

  // Work type configurations
  static const List<Map<String, dynamic>> _workTypes = [
    {
      'name': 'Cleanup',
      'icon': Icons.cleaning_services,
      'description': 'Community cleanup initiatives',
      'maxBeforeImages': 4,
      'maxAfterImages': 4,
    },
    {
      'name': 'Tree Planting',
      'icon': Icons.park,
      'description': 'Planting and nurturing trees',
      'maxBeforeImages': 3,
      'maxAfterImages': 0,
    },
    {
      'name': 'School Upgrading',
      'icon': Icons.school,
      'description': 'Improving school facilities',
      'maxBeforeImages': 4,
      'maxAfterImages': 4,
    },
    {
      'name': 'Waste Management',
      'icon': Icons.recycling,
      'description': 'Organizing waste and recycling',
      'maxBeforeImages': 4,
      'maxAfterImages': 4,
    },
    {
      'name': 'Water & Sanitation',
      'icon': Icons.water_drop,
      'description': 'Improving water and sanitation',
      'maxBeforeImages': 4,
      'maxAfterImages': 4,
    },
    {
      'name': 'Infrastructure',
      'icon': Icons.construction,
      'description': 'Community infrastructure projects',
      'maxBeforeImages': 4,
      'maxAfterImages': 4,
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _hoursController.dispose();
    _effortController.dispose();
    _materialsController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  int _getMaxBeforeImages() {
    final config = _workTypes.firstWhere(
      (w) => w['name'] == _workType,
      orElse: () => _workTypes[0],
    );
    return config['maxBeforeImages'] as int;
  }

  int _getMaxAfterImages() {
    final config = _workTypes.firstWhere(
      (w) => w['name'] == _workType,
      orElse: () => _workTypes[0],
    );
    return config['maxAfterImages'] as int;
  }

  bool _isTreePlanting() => _workType == 'Tree Planting';

  List<String> _parseMaterials() {
    final text = _materialsController.text;
    if (text.trim().isEmpty) return const [];
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  double? _parseHours() {
    final v = _hoursController.text.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  int _estimate() {
    return ContributionService().estimateImpactPoints(
      type: _type,
      workType: _workType,
      hours: _parseHours(),
      effort: _effortController.text,
      materials: _parseMaterials(),
    );
  }

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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _requiredLatitude,
        _requiredLongitude,
      );

      if (distance <= _maxDistanceInMeters) {
        setState(() {
          _currentPosition = position;
          _locationVerified = true;
          _locationController.text =
              'Verified (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Location verified successfully!'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        throw Exception(
            'You are ${distance.toStringAsFixed(0)}m away. Please be within ${_maxDistanceInMeters}m of the location.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location verification failed: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _verifyingLocation = false);
      }
    }
  }

  Future<void> _pickPhotos(bool isBefore) async {
    final targetList = isBefore ? _beforePhotos : _afterPhotos;
    final maxImages = isBefore ? _getMaxBeforeImages() : _getMaxAfterImages();
    final remaining = maxImages - targetList.length;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You can only add $maxImages ${isBefore ? 'before' : 'after'} photos for $_workType'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (file != null && mounted) {
      setState(() {
        targetList.add(file);
      });
    }
  }

  void _removePhoto(bool isBefore, int index) {
    setState(() {
      if (isBefore) {
        _beforePhotos.removeAt(index);
      } else {
        _afterPhotos.removeAt(index);
      }
    });
  }

  Future<void> _submit() async {
    final user = Provider.of<F_User?>(context, listen: false);
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_locationVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please verify your location first'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final maxBefore = _getMaxBeforeImages();
    final maxAfter = _getMaxAfterImages();

    if (_beforePhotos.length < maxBefore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add $maxBefore before photos'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (!_isTreePlanting() && _afterPhotos.length < maxAfter) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add $maxAfter after photos'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final points = await ContributionService().createContribution(
        userId: user.uid,
        title: _titleController.text.trim(),
        workType: _workType,
        type: _type,
        hours: _type == 'Time' ? _parseHours() : null,
        effort: _type == 'Effort' ? _effortController.text.trim() : null,
        materials: _type == 'Materials' ? _parseMaterials() : const [],
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        beforePhotos: _beforePhotos,
        afterPhotos: _afterPhotos,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _estimate();
    final maxBefore = _getMaxBeforeImages();
    final maxAfter = _getMaxAfterImages();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Log Contribution',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Location Verification Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _locationVerified
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _locationVerified
                                ? Colors.green.shade300
                                : Colors.orange.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _locationVerified
                                        ? Colors.green.shade600
                                        : Colors.orange.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _locationVerified
                                        ? Icons.check_circle
                                        : Icons.location_on,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Location Verification',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.darkGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _locationVerified
                                            ? 'Location verified ✓'
                                            : 'Required to log contribution',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.darkGreen
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!_locationVerified) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _verifyingLocation
                                      ? null
                                      : _verifyLocation,
                                  icon: _verifyingLocation
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.my_location, size: 20),
                                  label: Text(
                                    _verifyingLocation
                                        ? 'Verifying...'
                                        : 'Verify Location',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title Field
                      _buildSectionLabel(
                        'Contribution Title',
                        Icons.title,
                        AppTheme.primary,
                        badge: 'Max 50 chars',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        maxLength: 50,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Kibera Street Cleanup',
                          hintStyle: TextStyle(
                            color: AppTheme.darkGreen.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          counterText: '${_titleController.text.length}/50',
                          counterStyle: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary.withOpacity(0.7),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 2.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Work Type
                      _buildSectionLabel(
                        'Work Type',
                        Icons.category,
                        AppTheme.lightGreen,
                        badge: '6 categories',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _workType,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 2.5),
                          ),
                        ),
                        items: _workTypes.map((workType) {
                          return DropdownMenuItem(
                            value: workType['name'] as String,
                            child: Row(
                              children: [
                                Icon(
                                  workType['icon'] as IconData,
                                  size: 22,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  workType['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() {
                          _workType = v ?? 'Cleanup';
                          _beforePhotos.clear();
                          _afterPhotos.clear();
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Work Type Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.lightGreen.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _workTypes.firstWhere(
                                  (w) => w['name'] == _workType,
                                )['icon'] as IconData,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _workTypes.firstWhere(
                                  (w) => w['name'] == _workType,
                                )['description'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.darkGreen,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Tree Planting Tip
                      if (_isTreePlanting())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.lightGreen.withOpacity(0.2),
                                  AppTheme.primary.withOpacity(0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.lightGreen.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.tips_and_updates,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tree Planting Tip',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.darkGreen,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Add 3 before images today. Update with after images monthly to track growth.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              AppTheme.darkGreen.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Before Photos
                      _buildSectionLabel(
                        'Before Photos',
                        Icons.camera_alt,
                        AppTheme.primary,
                        badge: '$maxBefore required',
                      ),
                      const SizedBox(height: 14),
                      _PhotoGrid(
                        photos: _beforePhotos,
                        maxPhotos: maxBefore,
                        onAdd: () => _pickPhotos(true),
                        onRemove: (i) => _removePhoto(true, i),
                        isBefore: true,
                      ),
                      const SizedBox(height: 28),

                      // After Photos
                      if (!_isTreePlanting() || _afterPhotos.isNotEmpty) ...[
                        _buildSectionLabel(
                          'After Photos',
                          Icons.check_circle_outline,
                          AppTheme.lightGreen,
                          badge: _isTreePlanting()
                              ? 'Optional - monthly'
                              : '$maxAfter required',
                          badgeColor: _isTreePlanting()
                              ? Colors.orange.shade700
                              : AppTheme.tertiary,
                        ),
                        const SizedBox(height: 14),
                        _PhotoGrid(
                          photos: _afterPhotos,
                          maxPhotos: maxAfter,
                          onAdd: () => _pickPhotos(false),
                          onRemove: (i) => _removePhoto(false, i),
                          isBefore: false,
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Notes
                      _buildSectionLabel(
                        'Notes',
                        Icons.edit_note,
                        AppTheme.darkGreen,
                        badge: 'Optional',
                        badgeColor: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add any additional details...',
                          hintStyle: TextStyle(
                            color: AppTheme.darkGreen.withOpacity(0.4),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 2.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Impact Estimate
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.lightGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.eco,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estimated Impact',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$points Points',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // Submit Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppTheme.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit Contribution',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
    String title,
    IconData icon,
    Color color, {
    String? badge,
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppTheme.tertiary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: badgeColor ?? AppTheme.tertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onAdd;
  final Function(int) onRemove;
  final bool isBefore;

  const _PhotoGrid({
    required this.photos,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
    required this.isBefore,
  });

  @override
  Widget build(BuildContext context) {
    // Always use 2 columns for cleaner, taller tiles
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Always 2 columns for larger tiles
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85, // Taller tiles (portrait-ish)
      ),
      itemCount: maxPhotos,
      itemBuilder: (context, index) {
        if (index < photos.length) {
          return _PhotoTile(
            file: photos[index],
            onRemove: () => onRemove(index),
            index: index + 1,
          );
        } else {
          return _AddPhotoTile(
            onTap: onAdd,
            index: index + 1,
            isBefore: isBefore,
          );
        }
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  final int index;

  const _PhotoTile({
    required this.file,
    required this.onRemove,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.4),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  final int index;
  final bool isBefore;

  const _AddPhotoTile({
    required this.onTap,
    required this.index,
    required this.isBefore,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.lightGreen.withOpacity(0.4),
            width: 2.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                color: AppTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Photo $index',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to add',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkGreen.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}