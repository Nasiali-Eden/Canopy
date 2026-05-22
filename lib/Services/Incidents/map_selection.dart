import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSelectionScreen extends StatefulWidget {
  @override
  _MapSelectionScreenState createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

  static const LatLng defaultCenter =
      LatLng(-1.286389, 36.817223); // Example bounds

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Location")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: defaultCenter, zoom: 10),
        onMapCreated: (controller) => _mapController = controller,
        onTap: (LatLng position) {
          setState(() {
            _selectedLocation = position;
          });
        },
        markers: _selectedLocation != null
            ? {
                Marker(
                  markerId: MarkerId("selected"),
                  position: _selectedLocation!,
                ),
              }
            : {},
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'map_selection_confirm_fab',
        child: Icon(Icons.check),
        onPressed: () {
          if (_selectedLocation != null) {
            Navigator.pop(context, _selectedLocation);
          }
        },
      ),
    );
  }
}
