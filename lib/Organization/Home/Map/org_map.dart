import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Shared/theme/app_theme.dart';

class OrgMap extends StatefulWidget {
  const OrgMap({Key? key}) : super(key: key);

  @override
  State<OrgMap> createState() => _OrgMapState();
}

class _OrgMapState extends State<OrgMap> {
  GoogleMapController? _mapController;
  bool _showLegend = false;
  String _selectedFilter = 'All';

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
  final List<String> _filterOptions = ['All', 'Cleanup', 'Collection Points', 'Verified'];

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
      'location': LatLng(-1.3110, 37.7795),
      'description': 'Weekly market cleanup',
      'participants': 12,
      'waste_collected': '95 kg',
      'status': 'verified',
      'date': '2024-01-22',
    },
  ];

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  void _buildMarkers() {
    final filteredActivities = _activities.where((activity) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Cleanup') return activity['type'] == 'cleanup';
      if (_selectedFilter == 'Collection Points') return activity['type'] == 'collection';
      if (_selectedFilter == 'Verified') return activity['status'] == 'verified';
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
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      }
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else {
      // Collection points
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: type == 'cleanup' 
                          ? AppTheme.primary.withOpacity(0.1)
                          : AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      type == 'cleanup' ? Icons.cleaning_services : Icons.recycling,
                      color: type == 'cleanup' ? AppTheme.primary : AppTheme.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'],
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen,
                              ),
                        ),
                        if (activity['status'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: activity['status'] == 'verified'
                                  ? AppTheme.primary.withOpacity(0.15)
                                  : AppTheme.tertiary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  activity['status'] == 'verified' 
                                      ? Icons.verified 
                                      : Icons.pending,
                                  size: 14,
                                  color: activity['status'] == 'verified'
                                      ? AppTheme.primary
                                      : AppTheme.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  activity['status'] == 'verified' ? 'Verified' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: activity['status'] == 'verified'
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
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.darkGreen),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                activity['description'],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkGreen.withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 16),
              
              // Details based on type
              if (type == 'cleanup') ...[
                _DetailRow(
                  icon: Icons.people,
                  label: 'Participants',
                  value: '${activity['participants']}',
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.delete_outline,
                  label: 'Waste Collected',
                  value: activity['waste_collected'],
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: activity['date'],
                ),
              ] else ...[
                _DetailRow(
                  icon: Icons.access_time,
                  label: 'Operating Hours',
                  value: activity['hours'],
                ),
                const SizedBox(height: 12),
                Text(
                  'Accepted Materials:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (activity['materials'] as List<String>).map((material) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.accent.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        material,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: type == 'cleanup' 
                        ? AppTheme.primary 
                        : AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    type == 'cleanup' ? 'View Details' : 'Get Directions',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  void _toggleLegend() {
    setState(() {
      _showLegend = !_showLegend;
    });
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final trimmed = name.trim();
    final words = trimmed.split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return (words[0][0] + words[words.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
       appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 68,
        centerTitle: true,
      
        title: Text(
          'Canopy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
        ),
    ),
     body: Stack(
        children: [
          // Google Map
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            cameraTargetBounds: CameraTargetBounds(nairobiBounds),
            minMaxZoomPreference: const MinMaxZoomPreference(12, 18),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            zoomControlsEnabled: false,
          ),

          // Filter chips
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedFilter = filter;
                          _buildMarkers();
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppTheme.primary.withOpacity(0.2),
                      checkmarkColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primary : AppTheme.darkGreen,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected 
                            ? AppTheme.primary 
                            : AppTheme.lightGreen.withOpacity(0.5),
                      ),
                      elevation: 2,
                      shadowColor: AppTheme.primary.withOpacity(0.1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Legend
          if (_showLegend)
            Positioned(
              bottom: 20,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
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
                        Text(
                          'Legend',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGreen,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.info_outline, 
                          size: 16, 
                          color: AppTheme.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: AppTheme.primary,
                      label: 'Verified Cleanup',
                    ),
                    const SizedBox(height: 6),
                    _LegendItem(
                      color: AppTheme.tertiary,
                      label: 'Pending Cleanup',
                    ),
                    const SizedBox(height: 6),
                    _LegendItem(
                      color: AppTheme.accent,
                      label: 'Collection Point',
                    ),
                  ],
                ),
              ),
            ),

          // Stats Card
          Positioned(
            bottom: 20,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco, color: Colors.white, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    '${_activities.where((a) => a['type'] == 'cleanup').length}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    'Cleanups',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGreen,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkGreen.withOpacity(0.7),
              ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.darkGreen,
          ),
        ),
      ],
    );
  }
}
