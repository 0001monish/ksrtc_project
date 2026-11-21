import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class AdminSchedulesScreen extends StatefulWidget {
  const AdminSchedulesScreen({super.key});

  @override
  State<AdminSchedulesScreen> createState() => _AdminSchedulesScreenState();
}

class _AdminSchedulesScreenState extends State<AdminSchedulesScreen> {
  bool loading = true;
  List schedules = [];

  Future<void> fetchSchedules() async {
    setState(() => loading = true);

    final token = await StorageService.getToken();

    try {
      final response = await http.get(
        ApiService.url("/admin/schedule"),
        headers: {"Authorization": "Bearer $token"},
      );

      final data = jsonDecode(response.body);

      setState(() {
        loading = false;
        schedules = data is List ? data : [];
      });
    } catch (e) {
      setState(() => loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: const Text("Schedules"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: fetchSchedules,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : schedules.isEmpty
          ? const Center(child: Text("No schedules found"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final item = schedules[index];

                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.only(bottom: 14),
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
                              child: Icon(Icons.schedule, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item["bus_number"] ?? "Bus",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              "ID: ${item["schedule_id"]}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Text("Bus Type: ${item["bus_type"] ?? "N/A"}"),
                        Text("Route: ${item["route_name"] ?? "N/A"}"),
                        Text(
                          "${item["source"] ?? ""} → ${item["destination"] ?? ""}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        const Divider(height: 24),

                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 18),
                            const SizedBox(width: 6),
                            Text("Departure: ${item["departure_time"]}"),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: [
                            const Icon(Icons.flag, size: 18),
                            const SizedBox(width: 6),
                            Text("Arrival: ${item["arrival_time"]}"),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
