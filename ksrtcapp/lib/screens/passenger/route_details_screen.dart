import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class RouteDetailsScreen extends StatefulWidget {
  final int routeId;
  final String routeName;

  const RouteDetailsScreen({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  bool loading = true;
  String? errorMessage;

  Map<String, dynamic>? route;
  List<Map<String, dynamic>> stops = [];

  Future<void> fetchRouteDetails() async {
    try {
      final response = await http
          .get(ApiService.url("/route/${widget.routeId}"))
          .timeout(const Duration(seconds: 15));

      final dynamic data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data is Map) {
        final dynamic routeData = data["route"];
        final dynamic stopsData = data["stops"];

        setState(() {
          route = routeData is Map
              ? Map<String, dynamic>.from(routeData)
              : null;

          stops = stopsData is List
              ? stopsData
                    .whereType<Map>()
                    .map((stop) => Map<String, dynamic>.from(stop))
                    .toList()
              : [];

          loading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = data is Map
              ? data["message"]?.toString() ?? "Failed to load route details"
              : "Unexpected server response";
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = "Could not load route details. Please try again.";
      });

      debugPrint("Route details error: $error");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchRouteDetails();
  }

  @override
  Widget build(BuildContext context) {
    final source = route?["source"]?.toString() ?? "";
    final destination = route?["destination"]?.toString() ?? "";
    final distance = route?["distance_km"]?.toString();

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: Text(route?["route_name"]?.toString() ?? widget.routeName),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                if (route != null)
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: ListTile(
                      leading: const Icon(Icons.alt_route, color: Colors.red),
                      title: Text("$source → $destination"),
                      subtitle: Text(
                        "Route: ${route?["route_name"] ?? widget.routeName}"
                        "${distance != null ? "\nDistance: $distance km" : ""}",
                      ),
                    ),
                  ),
                Expanded(
                  child: stops.isEmpty
                      ? const Center(
                          child: Text("No stops available for this route."),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: stops.length,
                          itemBuilder: (context, index) {
                            final stop = stops[index];

                            final stopName =
                                stop["stop_name"]?.toString() ?? "Unknown stop";

                            final city = stop["city"]?.toString() ?? "";
                            final state = stop["state"]?.toString() ?? "";
                            final location = [
                              city,
                              state,
                            ].where((value) => value.isNotEmpty).join(", ");

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    "${stop["stop_sequence"] ?? index + 1}",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(stopName),
                                subtitle: Text(
                                  [
                                    if (location.isNotEmpty) location,
                                    if (stop["stop_type"] != null)
                                      stop["stop_type"].toString(),
                                    if (stop["halt_duration_minutes"] != null)
                                      "Halt: ${stop["halt_duration_minutes"]} min",
                                  ].join(" • "),
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
