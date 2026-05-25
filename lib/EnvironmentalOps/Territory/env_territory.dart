import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../Shared/theme/app_theme.dart';

class EnvTerritoryScreen extends StatefulWidget {
  const EnvTerritoryScreen({super.key});

  @override
  State<EnvTerritoryScreen> createState() => _EnvTerritoryScreenState();
}

class _EnvTerritoryScreenState extends State<EnvTerritoryScreen> {
  GoogleMapController? _mapController;

  static const LatLng _kiberaCenter = LatLng(-1.3133, 36.7862);

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  static const String _kCanopyMapStyle = '''
  [
    {
      "featureType": "poi",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "road",
      "stylers": [{"saturation": -30}]
    },
    {
      "featureType": "landscape",
      "stylers": [{"color": "#F5F1EB"}]
    },
    {
      "featureType": "water",
      "stylers": [{"color": "#A8C5C0"}]
    },
    {
      "featureType": "park",
      "stylers": [{"color": "#C8DCCA"}]
    }
  ]
  ''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kiberaCenter,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              controller.setMapStyle(_kCanopyMapStyle);
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            polygons: {
              Polygon(
                polygonId: const PolygonId('kibera_zone'),
                points: _getKiberaPolygon(),
                fillColor: AppTheme.primary.withOpacity(0.18),
                strokeColor: AppTheme.primary,
                strokeWidth: 2,
                onTap: () => _showZoneSheet(),
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('hub'),
                position: const LatLng(-1.3140, 36.7840),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueYellow),
                infoWindow: const InfoWindow(title: 'Kibera Hub'),
              ),
              Marker(
                markerId: const MarkerId('dropoff'),
                position: const LatLng(-1.3110, 36.7890),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueCyan),
              ),
              Marker(
                markerId: const MarkerId('collection'),
                position: const LatLng(-1.3160, 36.7870),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
              ),
            },
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.layers_outlined,
                      color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '2 zones  ·  3 sites',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Updated 2h ago',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkGreen.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 104,
            right: 16,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Draw Zone coming soon')),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text(
                '+ Draw Zone',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildHistoryItem(Icons.edit_outlined, 'Zone updated'),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppTheme.lightGreen.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildHistoryItem(
                        Icons.add_location_outlined, 'Site added'),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppTheme.lightGreen.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildHistoryItem(
                        Icons.check_circle_outline, 'Last verified'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 14, color: AppTheme.accent),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.darkGreen.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        const Text(
          '2h ago',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkGreen,
          ),
        ),
      ],
    );
  }

  List<LatLng> _getKiberaPolygon() {
    return const [
      LatLng(-1.3150, 36.7820),
      LatLng(-1.3150, 36.7900),
      LatLng(-1.3110, 36.7900),
      LatLng(-1.3110, 36.7820),
    ];
  }

  void _showZoneSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.2,
        maxChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              const Text(
                'Kibera Collection Zone A',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Mon–Sat  ·  6:00 AM – 2:00 PM',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkGreen.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Materials accepted:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: const [
                  Chip(label: Text('PET')),
                  Chip(label: Text('Carrier Bags')),
                  Chip(label: Text('HDPE')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
