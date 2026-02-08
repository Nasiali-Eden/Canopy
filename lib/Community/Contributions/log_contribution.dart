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

  // Old fields (keeping for backward compatibility)
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

  // Required location (you can make this dynamic based on activity)
  final double _requiredLatitude = -1.286389; // Example: Nairobi coordinates
  final double _requiredLongitude = 36.817223;
  final double _maxDistanceInMeters = 500; // 500 meters radius

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
      'maxAfterImages': 0, // Only first day, user updates monthly
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
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Location verified successfully!'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
              borderRadius: BorderRadius.circular(10),
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
            borderRadius: BorderRadius.circular(10),
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
          content: Text('Please verify your location first'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // For tree planting, after photos are not required on first day
    if (!_isTreePlanting() && _afterPhotos.length < maxAfter) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add $maxAfter after photos'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
            borderRadius: BorderRadius.circular(10),
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
      backgroundColor: Colors.white,
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Location Verification Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _locationVerified
                              ? Colors.green.shade600.withOpacity(0.1)
                              : Colors.orange.shade600.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _locationVerified
                                ? Colors.green.shade600.withOpacity(0.3)
                                : Colors.orange.shade600.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
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
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Location Verification',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.darkGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _locationVerified
                                            ? 'Location verified ✓'
                                            : 'Required to log contribution',
                                        style: TextStyle(
                                          fontSize: 12,
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
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _verifyingLocation
                                      ? null
                                      : _verifyLocation,
                                  icon: _verifyingLocation
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Icon(Icons.my_location, size: 18),
                                  label: Text(_verifyingLocation
                                      ? 'Verifying...'
                                      : 'Verify Location'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title Field (NEW)
                      Text(
                        'Contribution Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          hintText: 'e.g., Kibera Street Cleanup',
                          hintStyle: TextStyle(
                            color: AppTheme.darkGreen.withOpacity(0.4),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          counterText: '${_titleController.text.length}/50',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Work Type (NEW - replaces contribution type)
                      Text(
                        'Work Type',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _workType,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                        items: _workTypes.map((workType) {
                          return DropdownMenuItem(
                            value: workType['name'] as String,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  workType['icon'] as IconData,
                                  size: 20,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        workType['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        workType['description'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.darkGreen
                                              .withOpacity(0.6),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() {
                          _workType = v ?? 'Cleanup';
                          // Clear photos if switching work type
                          _beforePhotos.clear();
                          _afterPhotos.clear();
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Special note for Tree Planting
                      if (_isTreePlanting())
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.lightGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'For tree planting: Add 3 before images on first day only. Update with after images monthly.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.darkGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Before Photos
                      Text(
                        'Before Photos ($maxBefore required)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PhotoGrid(
                        photos: _beforePhotos,
                        maxPhotos: maxBefore,
                        onAdd: () => _pickPhotos(true),
                        onRemove: (i) => _removePhoto(true, i),
                        isBefore: true,
                      ),
                      const SizedBox(height: 24),

                      // After Photos (conditional for tree planting)
                      if (!_isTreePlanting() || _afterPhotos.isNotEmpty) ...[
                        Text(
                          _isTreePlanting()
                              ? 'After Photos (optional - add monthly updates)'
                              : 'After Photos ($maxAfter required)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PhotoGrid(
                          photos: _afterPhotos,
                          maxPhotos: maxAfter,
                          onAdd: () => _pickPhotos(false),
                          onRemove: (i) => _removePhoto(false, i),
                          isBefore: false,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Notes (Optional)
                      Text(
                        'Notes (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add any additional details...',
                          hintStyle: TextStyle(
                            color: AppTheme.darkGreen.withOpacity(0.4),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppTheme.lightGreen.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Impact Estimate
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.lightGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.eco,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estimated Impact',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$points Points',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Submit Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppTheme.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Submit Contribution',
                              style: TextStyle(
                                fontSize: 16,
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: maxPhotos == 3 ? 3 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9, // Landscape aspect ratio
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.lightGreen.withOpacity(0.4),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Photo $index',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}