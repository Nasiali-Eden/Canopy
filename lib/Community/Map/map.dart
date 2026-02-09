import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _showLegend = false;
  String _selectedFilter = 'All';
  late AnimationController _pulseController;
  Map<String, BitmapDescriptor> _customIcons = {};
  bool _iconsLoaded = false;

  // Nairobi Olympic Estate Kibera bounding box
  final LatLngBounds nairobiBounds = LatLngBounds(
    southwest: LatLng(-1.3280, 36.7500), // SW Corner
    northeast: LatLng(-1.2500, 36.8200), // NE Corner
  );

  // Initial camera position - Olympic Estate, Kibera
  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-1.3133, 36.7833), // Olympic Estate, Kibera
    zoom: 14,
  );

  Set<Marker> _markers = {};
  final List<String> _filterOptions = ['All', 'Cleanup', 'Collection', 'Water', 'Schools'];

  // Dummy cleanup activities and collection points
  final List<Map<String, dynamic>> _activities = [
    {
      'id': '1',
      'type': 'cleanup',
      'title': 'Beach Cleanup - Olympic Estate',
      'location': LatLng(-1.3133, 36.7833),
      'description': 'Community beach cleanup activity',
      'participants': 25,
      'waste_collected': '150 kg',
      'status': 'verified',
      'date': '2024-01-20',
    },
    {
      'id': '2',
      'type': 'cleanup',
      'title': 'Street Cleanup - Kibera Drive',
      'location': LatLng(-1.3150, 36.7850),
      'description': 'Weekly street cleaning initiative',
      'participants': 15,
      'waste_collected': '85 kg',
      'status': 'verified',
      'date': '2024-01-19',
    },
    {
      'id': '3',
      'type': 'cleanup',
      'title': 'Park Cleanup - Olympic Park',
      'location': LatLng(-1.3100, 36.7820),
      'description': 'Monthly park maintenance',
      'participants': 30,
      'waste_collected': '200 kg',
      'status': 'pending',
      'date': '2024-01-21',
    },
    {
      'id': '4',
      'type': 'collection',
      'title': 'Kibera Recycling Center',
      'location': LatLng(-1.3120, 36.7810),
      'description': 'Main recycling collection point',
      'materials': ['Plastic', 'Paper', 'Metal', 'Glass'],
      'hours': '8AM - 6PM',
    },
    {
      'id': '5',
      'type': 'collection',
      'title': 'Olympic Estate Drop-off',
      'location': LatLng(-1.3140, 36.7840),
      'description': 'Community drop-off center',
      'materials': ['Plastic', 'Paper'],
      'hours': '9AM - 5PM',
    },
    {
      'id': '6',
      'type': 'collection',
      'title': 'Kibera Road Collection Hub',
      'location': LatLng(-1.3165, 36.7865),
      'description': 'Partner recycler facility',
      'materials': ['Plastic', 'Metal', 'E-waste'],
      'hours': '7AM - 7PM',
    },
    {
      'id': '7',
      'type': 'cleanup',
      'title': 'River Cleanup - Nairobi River',
      'location': LatLng(-1.3175, 36.7875),
      'description': 'Riverbank cleaning project',
      'participants': 40,
      'waste_collected': '320 kg',
      'status': 'verified',
      'date': '2024-01-18',
    },
    {
      'id': '8',
      'type': 'cleanup',
      'title': 'Market Area Cleanup',
      'location': LatLng(-1.3110, 36.7795),
      'description': 'Weekly market cleanup',
      'participants': 12,
      'waste_collected': '95 kg',
      'status': 'verified',
      'date': '2024-01-22',
    },
    {
      'id': '9',
      'type': 'water',
      'title': 'Olympic Community Water Point',
      'location': LatLng(-1.3125, 36.7825),
      'description': 'Clean water access point',
      'capacity': '5000L/day',
      'status': 'active',
      'hours': '6AM - 8PM',
    },
    {
      'id': '10',
      'type': 'water',
      'title': 'Kibera Main Water Station',
      'location': LatLng(-1.3155, 36.7855),
      'description': 'Primary water distribution center',
      'capacity': '10000L/day',
      'status': 'active',
      'hours': '24/7',
    },
    {
      'id': '11',
      'type': 'water',
      'title': 'Community Tap - Lane 4',
      'location': LatLng(-1.3105, 36.7805),
      'description': 'Public water access',
      'capacity': '3000L/day',
      'status': 'active',
      'hours': '6AM - 10PM',
    },
    {
      'id': '12',
      'type': 'school',
      'title': 'Olympic Primary School',
      'location': LatLng(-1.3145, 36.7815),
      'description': 'Public primary school',
      'students': 450,
      'grades': 'Grade 1-8',
      'programs': ['Environmental Club', 'Recycling Program'],
    },
    {
      'id': '13',
      'type': 'school',
      'title': 'Kibera Secondary School',
      'location': LatLng(-1.3170, 36.7870),
      'description': 'Community secondary school',
      'students': 320,
      'grades': 'Form 1-4',
      'programs': ['Green Initiative', 'Waste Management'],
    },
    {
      'id': '14',
      'type': 'school',
      'title': 'Hope Academy',
      'location': LatLng(-1.3115, 36.7790),
      'description': 'Private primary and secondary',
      'students': 280,
      'grades': 'Grade 1 - Form 4',
      'programs': ['Eco Club', 'Community Service'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _loadCustomIcons();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomIcons() async {
    _customIcons['cleanup_verified'] = await _createCustomMarkerIcon(
      Icons.check_circle,
      AppTheme.primary,
      Colors.white,
      80.0, // Reduced size
    );
    _customIcons['cleanup_pending'] = await _createCustomMarkerIcon(
      Icons.access_time,
      AppTheme.tertiary,
      Colors.white,
      80.0,
    );
    _customIcons['collection'] = await _createCustomMarkerIcon(
      Icons.recycling,
      AppTheme.accent,
      Colors.white,
      80.0,
    );
    _customIcons['water'] = await _createCustomMarkerIcon(
      Icons.water_drop,
      Color(0xFF2196F3), // Blue
      Colors.white,
      80.0,
    );
    _customIcons['school'] = await _createCustomMarkerIcon(
      Icons.school,
      Color(0xFFFF9800), // Orange
      Colors.white,
      80.0,
    );
    
    setState(() {
      _iconsLoaded = true;
      _buildMarkers();
    });
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(
    IconData iconData,
    Color backgroundColor,
    Color iconColor,
    double size,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    
    // Draw outer circle (shadow)
    final shadowPaint = Paint()
      ..color = backgroundColor.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 4,
      shadowPaint,
    );
    
    // Draw main circle
    final circlePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 8,
      circlePaint,
    );
    
    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 8,
      borderPaint,
    );
    
    // Draw icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.45,
        fontFamily: iconData.fontFamily,
        color: iconColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _buildMarkers() {
    if (!_iconsLoaded) return;
    
    final filteredActivities = _activities.where((activity) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Cleanup') return activity['type'] == 'cleanup';
      if (_selectedFilter == 'Collection') return activity['type'] == 'collection';
      if (_selectedFilter == 'Water') return activity['type'] == 'water';
      if (_selectedFilter == 'Schools') return activity['type'] == 'school';
      return true;
    }).toList();

    setState(() {
      _markers = filteredActivities.map((activity) {
        return _buildMarker(activity);
      }).toSet();
    });
  }

  BitmapDescriptor _getMarkerIcon(String type, String? status) {
    if (type == 'cleanup') {
      if (status == 'verified') {
        return _customIcons['cleanup_verified']!;
      }
      return _customIcons['cleanup_pending']!;
    } else if (type == 'collection') {
      return _customIcons['collection']!;
    } else if (type == 'water') {
      return _customIcons['water']!;
    } else if (type == 'school') {
      return _customIcons['school']!;
    }
    return _customIcons['collection']!;
  }

  Marker _buildMarker(Map<String, dynamic> activity) {
    final type = activity['type'] as String;
    final status = activity['status'] as String?;
    
    return Marker(
      markerId: MarkerId(activity['id']),
      position: activity['location'] as LatLng,
      icon: _getMarkerIcon(type, status),
      onTap: () => _showActivityPopup(context, activity),
      infoWindow: InfoWindow(
        title: activity['title'],
      ),
    );
  }

  void _showActivityPopup(BuildContext context, Map<String, dynamic> activity) {
    final type = activity['type'] as String;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getGradientColors(type),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _getIconColor(type).withOpacity(0.3),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getTypeIcon(type, activity['status']),
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
                                activity['title'],
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGreen,
                                    ),
                              ),
                              if (activity['status'] != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: activity['status'] == 'verified' || activity['status'] == 'active'
                                        ? AppTheme.primary.withOpacity(0.15)
                                        : AppTheme.tertiary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: activity['status'] == 'verified' || activity['status'] == 'active'
                                          ? AppTheme.primary.withOpacity(0.3)
                                          : AppTheme.tertiary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        activity['status'] == 'verified' || activity['status'] == 'active'
                                            ? Icons.verified
                                            : Icons.schedule,
                                        size: 14,
                                        color: activity['status'] == 'verified' || activity['status'] == 'active'
                                            ? AppTheme.primary
                                            : AppTheme.tertiary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        activity['status'] == 'verified' || activity['status'] == 'active'
                                            ? (activity['status'] == 'active' ? 'Active' : 'Verified')
                                            : 'Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: activity['status'] == 'verified' || activity['status'] == 'active'
                                              ? AppTheme.primary
                                              : AppTheme.tertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.lightGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: AppTheme.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activity['description'],
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.darkGreen.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Details based on type
                    ..._buildTypeSpecificDetails(context, type, activity),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.directions, size: 20),
                            label: Text('Directions'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.share, size: 20),
                            label: Text('Share'),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Color> _getGradientColors(String type) {
    switch (type) {
      case 'cleanup':
        return [AppTheme.primary, AppTheme.secondary];
      case 'collection':
        return [AppTheme.accent, AppTheme.accent.withOpacity(0.7)];
      case 'water':
        return [Color(0xFF2196F3), Color(0xFF1976D2)];
      case 'school':
        return [Color(0xFFFF9800), Color(0xFFF57C00)];
      default:
        return [AppTheme.primary, AppTheme.secondary];
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'cleanup':
        return AppTheme.primary;
      case 'collection':
        return AppTheme.accent;
      case 'water':
        return Color(0xFF2196F3);
      case 'school':
        return Color(0xFFFF9800);
      default:
        return AppTheme.primary;
    }
  }

  IconData _getTypeIcon(String type, String? status) {
    switch (type) {
      case 'cleanup':
        return status == 'verified' ? Icons.check_circle : Icons.access_time;
      case 'collection':
        return Icons.recycling;
      case 'water':
        return Icons.water_drop;
      case 'school':
        return Icons.school;
      default:
        return Icons.place;
    }
  }

  List<Widget> _buildTypeSpecificDetails(BuildContext context, String type, Map<String, dynamic> activity) {
    if (type == 'cleanup') {
      return [
        _ModernDetailCard(
          icon: Icons.groups,
          iconColor: AppTheme.secondary,
          label: 'Participants',
          value: '${activity['participants']} people',
        ),
        const SizedBox(height: 12),
        _ModernDetailCard(
          icon: Icons.delete_outline,
          iconColor: AppTheme.accent,
          label: 'Waste Collected',
          value: activity['waste_collected'],
        ),
        const SizedBox(height: 12),
        _ModernDetailCard(
          icon: Icons.calendar_today,
          iconColor: AppTheme.tertiary,
          label: 'Date',
          value: activity['date'],
        ),
      ];
    } else if (type == 'collection') {
      return [
        _ModernDetailCard(
          icon: Icons.schedule,
          iconColor: AppTheme.tertiary,
          label: 'Operating Hours',
          value: activity['hours'],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.accent.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.category,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Accepted Materials',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (activity['materials'] as List<String>)
                    .map((material) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.accent.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getMaterialIcon(material),
                                size: 16,
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                material,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGreen,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ];
    } else if (type == 'water') {
      return [
        _ModernDetailCard(
          icon: Icons.water,
          iconColor: Color(0xFF2196F3),
          label: 'Daily Capacity',
          value: activity['capacity'],
        ),
        const SizedBox(height: 12),
        _ModernDetailCard(
          icon: Icons.schedule,
          iconColor: AppTheme.tertiary,
          label: 'Operating Hours',
          value: activity['hours'],
        ),
      ];
    } else if (type == 'school') {
      return [
        _ModernDetailCard(
          icon: Icons.people,
          iconColor: Color(0xFFFF9800),
          label: 'Students',
          value: '${activity['students']} enrolled',
        ),
        const SizedBox(height: 12),
        _ModernDetailCard(
          icon: Icons.school,
          iconColor: AppTheme.secondary,
          label: 'Grade Levels',
          value: activity['grades'],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFFF9800).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFFF9800).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.eco,
                    color: Color(0xFFFF9800),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Environmental Programs',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (activity['programs'] as List<String>)
                    .map((program) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFFFF9800).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars,
                                size: 16,
                                color: Color(0xFFFF9800),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                program,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGreen,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ];
    }
    return [];
  }

  IconData _getMaterialIcon(String material) {
    switch (material.toLowerCase()) {
      case 'plastic':
        return Icons.water_drop;
      case 'paper':
        return Icons.description;
      case 'metal':
        return Icons.hardware;
      case 'glass':
        return Icons.lightbulb_outline;
      case 'e-waste':
        return Icons.devices;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            mapType: MapType.normal,
            cameraTargetBounds: CameraTargetBounds(nairobiBounds),
            minMaxZoomPreference: const MinMaxZoomPreference(12, 18),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            zoomControlsEnabled: false,
            style: '''
              [
                {
                  "featureType": "poi",
                  "elementType": "labels",
                  "stylers": [{"visibility": "off"}]
                }
              ]
            ''',
          ),

          // Modern Filter Chips with Glassmorphism
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.15),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterOptions.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFilter = filter;
                              _buildMarkers();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [AppTheme.primary, AppTheme.secondary],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getFilterIcon(filter),
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.darkGreen.withOpacity(0.7),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.darkGreen,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Custom Map Controls
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                // My Location Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (_mapController != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.newCameraPosition(_initialPosition),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        padding: EdgeInsets.all(14),
                        child: Icon(
                          Icons.my_location,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // Legend Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.2),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showLegend = !_showLegend;
                        });
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        padding: EdgeInsets.all(14),
                        child: Icon(
                          _showLegend ? Icons.close : Icons.info_outline,
                          color: AppTheme.accent,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Modern Legend
          if (_showLegend)
            Positioned(
              bottom: 20,
              left: 16,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.98),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.secondary],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.legend_toggle,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Map Legend',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ModernLegendItem(
                      icon: Icons.check_circle,
                      color: AppTheme.primary,
                      label: 'Verified Cleanup',
                    ),
                    const SizedBox(height: 10),
                    _ModernLegendItem(
                      icon: Icons.access_time,
                      color: AppTheme.tertiary,
                      label: 'Pending Cleanup',
                    ),
                    const SizedBox(height: 10),
                    _ModernLegendItem(
                      icon: Icons.recycling,
                      color: AppTheme.accent,
                      label: 'Collection Point',
                    ),
                    const SizedBox(height: 10),
                    _ModernLegendItem(
                      icon: Icons.water_drop,
                      color: Color(0xFF2196F3),
                      label: 'Water Point',
                    ),
                    const SizedBox(height: 10),
                    _ModernLegendItem(
                      icon: Icons.school,
                      color: Color(0xFFFF9800),
                      label: 'School',
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.dashboard;
      case 'Cleanup':
        return Icons.cleaning_services;
      case 'Collection':
        return Icons.recycling;
      case 'Water':
        return Icons.water_drop;
      case 'Schools':
        return Icons.school;
      default:
        return Icons.filter_list;
    }
  }
}

class _ModernDetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _ModernDetailCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
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

class _ModernLegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _ModernLegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGreen,
          ),
        ),
      ],
    );
  }
}