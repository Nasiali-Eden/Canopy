import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../Shared/theme/app_theme.dart';

class EnvTreesScreen extends StatefulWidget {
  const EnvTreesScreen({super.key});

  @override
  State<EnvTreesScreen> createState() => _EnvTreesScreenState();
}

class _EnvTreesScreenState extends State<EnvTreesScreen> {
  bool _showMap = false;

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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildStatStrip(),
            const SizedBox(height: 12),
            _buildMapListToggle(),
            const SizedBox(height: 12),
            _buildCreditProgress(),
            const SizedBox(height: 12),
            Expanded(
              child: _showMap ? _buildMapView() : _buildListView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    _showMap ? 'GPS pin coming soon' : 'Add tree coming soon')),
          );
        },
        backgroundColor: _showMap ? null : AppTheme.tertiary,
        child: Icon(_showMap ? Icons.add_location_alt_outlined : Icons.add),
      ),
    );
  }

  Widget _buildStatStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('Trees Planted', '50'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard('90-Day Survival', '86%'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard('Updates Overdue', '8', isOverdue: true),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {bool isOverdue = false}) {
    Color valueColor = AppTheme.darkGreen;
    if (isOverdue) {
      final overdueCount = int.tryParse(value) ?? 0;
      if (overdueCount > 20) {
        valueColor = Colors.red;
      } else if (overdueCount > 5) {
        valueColor = Colors.amber;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.darkGreen.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapListToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.darkGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showMap = false),
                child: Container(
                  height: 32,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: !_showMap ? AppTheme.darkGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'List',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: !_showMap
                          ? Colors.white
                          : AppTheme.darkGreen.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showMap = true),
                child: Container(
                  height: 32,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _showMap ? AppTheme.darkGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Map',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _showMap
                          ? Colors.white
                          : AppTheme.darkGreen.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Urban Greening Credit',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '43 of 50 trees confirmed',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkGreen.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: 0.86,
                backgroundColor: Color(0xFFF0F0F0),
                valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Confirm 7 more trees at 90 days to unlock your first credit',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.darkGreen.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildTreeCard(
          treeId: '#T-0042',
          species: 'Grevillea robusta',
          lat: -1.3133,
          lng: 36.7862,
          plantedDate: 'Jan 15, 2026',
          confirmedDate: 'May 10, 2026',
          status: TreeStatus.current,
          daysUntilDue: 12,
        ),
        const SizedBox(height: 12),
        _buildTreeCard(
          treeId: '#T-0041',
          species: 'Eucalyptus globulus',
          lat: -1.3145,
          lng: 36.7878,
          plantedDate: 'Jan 12, 2026',
          confirmedDate: 'May 8, 2026',
          status: TreeStatus.current,
          daysUntilDue: 14,
        ),
        const SizedBox(height: 12),
        _buildTreeCard(
          treeId: '#T-0038',
          species: 'Cupressus lusitanica',
          lat: -1.3152,
          lng: 36.7850,
          plantedDate: 'Dec 20, 2025',
          confirmedDate: 'Apr 15, 2026',
          status: TreeStatus.overdue,
          daysUntilDue: -8,
        ),
        const SizedBox(height: 12),
        _buildTreeCard(
          treeId: '#T-0043',
          species: 'Pinus patula',
          lat: -1.3120,
          lng: 36.7885,
          plantedDate: 'Feb 1, 2026',
          confirmedDate: null,
          status: TreeStatus.unconfirmed,
          daysUntilDue: 85,
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-1.3133, 36.7862),
        zoom: 14,
      ),
      onMapCreated: (controller) => controller.setMapStyle(_kCanopyMapStyle),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('tree1'),
          position: const LatLng(-1.3133, 36.7862),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('tree2'),
          position: const LatLng(-1.3145, 36.7878),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('tree3'),
          position: const LatLng(-1.3152, 36.7850),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
        Marker(
          markerId: const MarkerId('tree4'),
          position: const LatLng(-1.3120, 36.7885),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        ),
      },
    );
  }

  Widget _buildTreeCard({
    required String treeId,
    required String species,
    required double lat,
    required double lng,
    required String plantedDate,
    required String? confirmedDate,
    required TreeStatus status,
    required int daysUntilDue,
  }) {
    Color statusColor;
    String statusText;

    switch (status) {
      case TreeStatus.current:
        statusColor = AppTheme.primary;
        statusText = 'Due in ${daysUntilDue} days';
        break;
      case TreeStatus.overdue:
        statusColor = Colors.amber;
        statusText = 'Overdue by ${-daysUntilDue} days';
        break;
      case TreeStatus.critical:
        statusColor = Colors.red;
        statusText = 'Critical: ${-daysUntilDue} days overdue';
        break;
      case TreeStatus.unconfirmed:
        statusColor = Colors.grey;
        statusText = 'Unconfirmed';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        treeId,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkGreen.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        species,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.my_location,
                          size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '$lat, $lng',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.darkGreen.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        plantedDate,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.darkGreen.withOpacity(0.6),
                        ),
                      ),
                      if (confirmedDate != null) ...[
                        const SizedBox(width: 4),
                        Text('·',
                            style: TextStyle(
                                color: AppTheme.darkGreen.withOpacity(0.4))),
                        const SizedBox(width: 4),
                        Text(
                          confirmedDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.darkGreen.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.eco_outlined,
                          color: AppTheme.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      Container(
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.primary],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Update coming soon')),
                            );
                          },
                          child: const Text(
                            'Update',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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

enum TreeStatus { current, overdue, critical, unconfirmed }
