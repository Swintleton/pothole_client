import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Map'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const GoogleMapWidget(),
    );
  }
}

class GoogleMapWidget extends StatefulWidget {
  const GoogleMapWidget({super.key});

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(47.494367, 19.060115);

  Set<Marker> _markers = {};  // Set to hold markers for potholes

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _fetchPotholeCoordinates();  // Fetch pothole coordinates when the widget initializes
  }

  // Request location permission from the user
  Future<void> _requestPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  // Fetch pothole coordinates from the server
  Future<void> _fetchPotholeCoordinates() async {
    final response = await http.get(Uri.parse('http://192.168.0.115:5000/potholes'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        // Add a marker for each pothole coordinate
        _markers = data.map((pothole) {
          return Marker(
            markerId: MarkerId(pothole['latitude'].toString() + pothole['longitude'].toString()),
            position: LatLng(pothole['latitude'], pothole['longitude']),
            infoWindow: InfoWindow(title: 'Pothole'),
          );
        }).toSet();
      });
    } else {
      print('Failed to load pothole coordinates');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: _center,
        zoom: 11.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: _markers,  // Show the pothole markers
    );
  }
}
