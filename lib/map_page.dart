import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'auth_helper.dart';

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
  final LatLng _center = const LatLng(47.494367, 19.060115); // Centre of Budapest
  Set<Marker> _markers = {};
  LatLng? _lastLongPressedLocation;
  String? userRole;
  int? userId;

  @override
  void initState() {
    super.initState();
    _initializeUserInfo();  // Initialize user information
    _requestPermission();  // Request location permission
    _fetchPotholeCoordinates();
  }

  Future<void> _initializeUserInfo() async {
    userRole = await AuthHelper.getUserRole();
    userId = await AuthHelper.getUserId();

    if (userId == null) {
      print('Error: User ID is null.');
    }
  }

  // Request location permissions
  Future<void> _requestPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  // Fetch pothole coordinates from the server
  Future<void> _fetchPotholeCoordinates() async {
    // Retrieve the authorization token
    final authToken = await AuthHelper.getAuthToken();

    // Send get pothole request
    final response = await http.get(
      Uri.parse('http://192.168.0.115:5000/potholes'),
      headers: {
        'Authorization': '$authToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _markers = data.map((pothole) {
          return Marker(
            markerId: MarkerId(pothole['id'].toString()),
            position: LatLng(pothole['latitude'], pothole['longitude']),
            infoWindow: InfoWindow(
              title: 'Pothole',
              snippet: 'Tap to edit',
              onTap: () => _editPothole(
                pothole['id'],
                pothole['latitude'],
                pothole['longitude'],
                pothole['filename'],
                pothole['user_id'],
              ),
            ),
          );
        }).toSet();
      });
    } else if (response.statusCode == 401) {
      // Invalid token, logout
      AuthHelper.logout(context, mounted);
    } else {
      print('Failed to load pothole coordinates');
    }
  }

  // Handle long press on the map to add a pothole
  void _onMapLongPressed(LatLng latLng) {
    setState(() {
      _lastLongPressedLocation = latLng;
    });
    _showAddPotholeDialog(latLng);
  }

  // Show a dialog to add a new pothole
  Future<void> _showAddPotholeDialog(LatLng latLng) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Pothole'),
          content: Text('Add a pothole at (${latLng.latitude}, ${latLng.longitude})?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _addPothole(latLng);
    }
  }

  // Add pothole by sending the request to the server
  Future<void> _addPothole(LatLng latLng) async {
    final authToken = await AuthHelper.getAuthToken();

    final response = await http.post(
      Uri.parse('http://192.168.0.115:5000/add_pothole'),
      headers: {
        'Authorization': '$authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final int potholeId = data['id'];
      final String filename = data['filename'];

      setState(() {
        _markers.add(Marker(
          markerId: MarkerId(potholeId.toString()),
          position: latLng,
          infoWindow: InfoWindow(
            title: 'New Pothole',
            snippet: 'Tap to edit',
            onTap: () => _editPothole(potholeId, latLng.latitude, latLng.longitude, filename, userId!),
          ),
        ));
      });
    } else if (response.statusCode == 401) {
      // Invalid token
      AuthHelper.logout(context, mounted);
    } else {
      print('Failed to add pothole');
    }
  }

  // Edit an existing pothole
  void _editPothole(int id, double latitude, double longitude, String filename, int creatorId) async {
    _showEditPotholeDialog(id, latitude, longitude, filename, creatorId);
  }

  // Show dialog to edit or delete a pothole
  Future<void> _showEditPotholeDialog(int id, double latitude, double longitude, String filename, int creatorId) async {
    final latitudeController = TextEditingController(text: latitude.toString());
    final longitudeController = TextEditingController(text: longitude.toString());
    String detectedImageUrl = '';

    // Fetch detected image URL for the pothole (if available)
    if (
      filename.isNotEmpty &&
      filename != "manual_entry_detected.jpg" &&
      filename != "manual_entry.jpg"
    ) {
      detectedImageUrl = 'http://192.168.0.115:5000/confirmed/$filename';
    }

    final authToken = await AuthHelper.getAuthToken();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Pothole'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                // Latitude input
                TextField(
                  controller: latitudeController,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                // Longitude input
                TextField(
                  controller: longitudeController,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                const SizedBox(height: 20),
                // Display detected frame image if available
                detectedImageUrl.isNotEmpty
                    ? Column(
                        children: [
                          const Text('Detected Frame:'),
                          const SizedBox(height: 10),
                          Image.network(
                            detectedImageUrl,
                            height: 200,
                            headers: {'Authorization': '$authToken'},
                          ),
                        ],
                      )
                    : const Text('No detected image available.'),
              ],
            ),
          ),
          actions: <Widget>[
            if (userRole == 'Admin' || userId == creatorId) // Only show "Delete" button for admin or creator
              TextButton(
                child: const Text('Delete'),
                onPressed: () async {
                  await _deletePothole(id);
                  Navigator.of(context).pop();
                },
              ),
            if (userRole == 'Admin' || userId == creatorId) // Only show "Save" button for admin or creator
              TextButton(
                child: const Text('Save'),
                onPressed: () async {
                  // Update pothole with new latitude/longitude
                  await _savePothole(
                    id,
                    double.parse(latitudeController.text),
                    double.parse(longitudeController.text),
                    filename,
                  );
                  Navigator.of(context).pop();
                },
              ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePothole(int id, double newLatitude, double newLongitude, String filename) async {
    final authToken = await AuthHelper.getAuthToken();

    final response = await http.put(
      Uri.parse('http://192.168.0.115:5000/edit_pothole/$id'),
      headers: {
        'Authorization': '$authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': newLatitude,
        'longitude': newLongitude,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        // Remove the old marker
        _markers.removeWhere((marker) => marker.markerId.value == id.toString());

        // Add a new marker with updated position but same filename
        _markers.add(Marker(
          markerId: MarkerId(id.toString()),
          position: LatLng(newLatitude, newLongitude),
          infoWindow: InfoWindow(
            title: 'Edited Pothole',
            snippet: 'Pothole updated',
            onTap: () => _editPothole(id, newLatitude, newLongitude, filename, userId!),
          ),
        ));
      });
    } else if (response.statusCode == 401) {
      AuthHelper.logout(context, mounted);
    } else {
      print('Failed to update pothole');
    }
  }

  // Delete pothole function
  Future<void> _deletePothole(int id) async {
    final authToken = await AuthHelper.getAuthToken();

    final response = await http.delete(
      Uri.parse('http://192.168.0.115:5000/delete_pothole/$id'),
      headers: {
        'Authorization': '$authToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        // Remove the marker from the local map by matching with the unique ID
        _markers.removeWhere((marker) => marker.markerId.value == id.toString());
      });
      print('Pothole deleted successfully');
    } else if (response.statusCode == 401) {
      AuthHelper.logout(context, mounted);
    } else {
      print('Failed to delete pothole');
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
      markers: _markers,
      onLongPress: _onMapLongPressed,
    );
  }
}
