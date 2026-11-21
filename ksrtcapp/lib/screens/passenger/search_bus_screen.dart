import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import 'route_details_screen.dart';

class SearchBusScreen extends StatefulWidget {
  const SearchBusScreen({super.key});

  @override
  State<SearchBusScreen> createState() => _SearchBusScreenState();
}

class _SearchBusScreenState extends State<SearchBusScreen> {
  final sourceController = TextEditingController();
  final destinationController = TextEditingController();

  bool loading = false;
  String? message;
  List<Map<String, dynamic>> buses = [];

  @override
  void dispose() {
    sourceController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  // =====================================
  // SEARCH BUSES
  // =====================================
  Future<void> searchBuses() async {
    final source = sourceController.text.trim();
    final destination = destinationController.text.trim();

    if (source.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter source and destination")),
      );
      return;
    }

    setState(() {
      loading = true;
      message = null;
      buses = [];
    });

    try {
      final uri = ApiService.url("/search").replace(
        queryParameters: {"source": source, "destination": destination},
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      final dynamic data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Updated backend response:
        // { "buses": [...] }
        final dynamic busList = data is Map ? data["buses"] : null;

        if (busList is List) {
          setState(() {
            buses = busList
                .whereType<Map>()
                .map((bus) => Map<String, dynamic>.from(bus))
                .toList();

            loading = false;
            message = buses.isEmpty ? "No buses available" : null;
          });
        } else {
          setState(() {
            loading = false;
            message = data is Map
                ? data["message"]?.toString() ?? "No buses available"
                : "Unexpected server response";
          });
        }
      } else {
        final errorMessage = data is Map ? data["message"]?.toString() : null;

        setState(() {
          loading = false;
          message = errorMessage ?? "Failed to search buses";
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
        message = "Could not connect to server";
      });

      debugPrint("Search buses error: $error");
    }
  }

  // =====================================
  // STATUS COLOR
  // =====================================
  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "DELAYED":
        return Colors.orange;
      case "CANCELLED":
        return Colors.red;
      case "ARRIVED":
        return Colors.blue;
      case "DEPARTED":
        return Colors.purple;
      case "COMPLETED":
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  // =====================================
  // SCREEN UI
  // =====================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: const Text("Search Buses"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: sourceController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "From",
                        prefixIcon: Icon(Icons.trip_origin),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: destinationController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "To",
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : searchBuses,
                        icon: const Icon(Icons.search),
                        label: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Search Buses"),
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

          const SizedBox(height: 12),

          if (message != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: buses.length,
              itemBuilder: (context, index) {
                final bus = buses[index];

                final status = bus["current_status"]?.toString() ?? "ON_TIME";

                final statusColor = getStatusColor(status);

                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bus["bus_number"]?.toString() ?? "Unknown Bus",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Text(
                          "${bus["source"] ?? "Unknown"} → "
                          "${bus["destination"] ?? "Unknown"}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text("Route: ${bus["route_name"] ?? "Not available"}"),
                        Text("Type: ${bus["route_type"] ?? "Regular"}"),
                        Text("Total Stops: ${bus["total_stops"] ?? 0}"),
                        Text(
                          "Current Stop: "
                          "${bus["current_stop"] ?? "Not updated"}",
                        ),
                        Text(
                          "Remarks: "
                          "${bus["remarks"] ?? "Running Normally"}",
                        ),

                        const Divider(height: 24),

                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Departure: "
                                "${bus["departure_time"] ?? "--"}",
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Arrival: "
                                "${bus["arrival_time"] ?? "--"}",
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final routeId = bus["route_id"];

                              if (routeId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Route ID is unavailable"),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RouteDetailsScreen(
                                    routeId: routeId,
                                    routeName:
                                        bus["route_name"]?.toString() ??
                                        "Route Details",
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.alt_route),
                            label: const Text("Route Details"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
