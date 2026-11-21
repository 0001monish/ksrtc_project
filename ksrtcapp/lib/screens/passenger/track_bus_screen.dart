import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service.dart';
import '../../services/socket_service.dart';

class TrackBusScreen extends StatefulWidget {
  const TrackBusScreen({super.key});

  @override
  State<TrackBusScreen> createState() => _TrackBusScreenState();
}

class _TrackBusScreenState extends State<TrackBusScreen> {
  final busNumberController = TextEditingController();

  bool loading = false;
  bool isTracking = false;

  Map<String, dynamic>? location;
  GoogleMapController? mapController;

  bool get canShowGoogleMap {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();

    SocketService.connect();

    SocketService.off("locationUpdated");
    SocketService.on("locationUpdated", handleLocationUpdate);
  }

  void handleLocationUpdate(dynamic data) {
    if (!mounted || !isTracking || data == null) return;

    try {
      final updatedLocation = Map<String, dynamic>.from(data);

      final currentSchedule = location?["schedule_id"]?.toString();
      final updatedSchedule = updatedLocation["schedule_id"]?.toString();

      if (currentSchedule == null ||
          updatedSchedule == null ||
          currentSchedule != updatedSchedule) {
        return;
      }

      final lat = double.tryParse(
        updatedLocation["latitude"]?.toString() ?? '',
      );

      final lng = double.tryParse(
        updatedLocation["longitude"]?.toString() ?? '',
      );

      if (lat == null || lng == null) {
        debugPrint("Invalid GPS coordinates received: $updatedLocation");
        return;
      }

      setState(() {
        location = {...location!, ...updatedLocation};
      });

      if (canShowGoogleMap) {
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
        );
      }
    } catch (e) {
      debugPrint("Location event parsing error: $e");
    }
  }

  @override
  void dispose() {
    SocketService.off("locationUpdated");
    SocketService.leaveSchedule();

    busNumberController.dispose();

    super.dispose();
  }

  Future<void> fetchLocation() async {
    final busNumber = busNumberController.text.trim().toUpperCase();

    if (busNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter bus number")));
      return;
    }

    setState(() {
      loading = true;
      isTracking = false;
      location = null;
    });

    SocketService.leaveSchedule();

    try {
      final response = await http.get(
        ApiService.url("/live-location/bus/$busNumber"),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(decoded["message"] ?? "No live location found");
      }

      final locationData = Map<String, dynamic>.from(decoded["location"]);

      final lat = double.tryParse(locationData["latitude"]?.toString() ?? '');

      final lng = double.tryParse(locationData["longitude"]?.toString() ?? '');

      if (lat == null || lng == null) {
        throw Exception("Bus GPS location is not available yet");
      }

      final scheduleId = locationData["schedule_id"]?.toString();

      if (scheduleId == null || scheduleId.isEmpty || scheduleId == "null") {
        throw Exception("Bus schedule ID is missing");
      }

      if (!mounted) return;

      setState(() {
        location = locationData;
        loading = false;
        isTracking = true;
      });

      SocketService.joinSchedule(scheduleId);

      if (canShowGoogleMap) {
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        isTracking = false;
        location = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget unsupportedMapView() {
    return Container(
      width: double.infinity,
      color: const Color(0xffFFF3F3),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.phone_android, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          const Text(
            "Live Map Works on Phone",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Google Maps Flutter is supported on Android/iOS. "
            "Run this screen on your phone or emulator to see the live map.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          if (location != null) ...[
            const SizedBox(height: 20),
            Text("Latitude: ${location?["latitude"]}"),
            Text("Longitude: ${location?["longitude"]}"),
          ],
        ],
      ),
    );
  }

  Widget mapView(LatLng busPosition) {
    if (!canShowGoogleMap) {
      return unsupportedMapView();
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: busPosition, zoom: 14),
      onMapCreated: (controller) {
        mapController = controller;
      },
      markers: {
        if (location != null)
          Marker(
            markerId: const MarkerId("bus"),
            position: busPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: location?["bus_number"] ?? "Bus",
              snippet:
                  "${location?["source"] ?? ""} → "
                  "${location?["destination"] ?? ""}",
            ),
          ),
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double lat =
        double.tryParse(location?["latitude"]?.toString() ?? '') ?? 12.4244;

    final double lng =
        double.tryParse(location?["longitude"]?.toString() ?? '') ?? 75.7382;

    final busPosition = LatLng(lat, lng);

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: const Text("Track Bus"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Icon(
                      Icons.directions_bus,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Live Bus Tracking",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Track bus using bus number plate.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: busNumberController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: "Bus Number",
                        hintText: "KA-01-F-1234",
                        prefixIcon: const Icon(
                          Icons.confirmation_number,
                          color: Colors.red,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : fetchLocation,
                        icon: const Icon(Icons.my_location),
                        label: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Start Live Tracking"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: mapView(busPosition),
            ),
          ),
          if (location != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Text(
                    location?["bus_number"] ?? "Bus",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${location?["source"] ?? ""} → "
                    "${location?["destination"] ?? ""}",
                  ),
                  const SizedBox(height: 6),
                  Text("Status: ${location?["current_status"] ?? "Unknown"}"),
                  const SizedBox(height: 6),
                  Text(
                    "Updated: ${location?["updated_at"] ?? "Live"}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
