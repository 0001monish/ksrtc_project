import 'dart:convert';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class UpdateStatusScreen extends StatefulWidget {
  const UpdateStatusScreen({super.key});

  @override
  State<UpdateStatusScreen> createState() => _UpdateStatusScreenState();
}

class _UpdateStatusScreenState extends State<UpdateStatusScreen> {
  final currentStopController = TextEditingController();
  final remarksController = TextEditingController();

  String selectedStatus = "ON_TIME";
  String? activeBusNumber;
  bool loading = false;

  final List<String> statuses = [
    "ON_TIME",
    "DELAYED",
    "ARRIVED",
    "DEPARTED",
    "CANCELLED",
    "COMPLETED",
  ];

  @override
  void initState() {
    super.initState();
    loadActiveBus();
  }

  Future<void> loadActiveBus() async {
    final bus = await StorageService.getActiveBusNumber();

    setState(() {
      activeBusNumber = bus;
    });
  }

  Future<void> updateStatus() async {
    if (activeBusNumber == null || activeBusNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active bus session found")),
      );
      return;
    }

    if (currentStopController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Current stop is required")));
      return;
    }

    setState(() => loading = true);

    try {
      final response = await ApiService.put(
        "/conductor/update-status",
        body: {
          "bus_number": activeBusNumber,
          "status": selectedStatus,
          "current_stop": currentStopController.text.trim(),
          "remarks": remarksController.text.trim(),
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"] ?? "Status updated"),
          backgroundColor: response.statusCode == 200
              ? Colors.green
              : Colors.red,
        ),
      );

      if (response.statusCode == 200) {
        remarksController.clear();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Server error: $e")));
    }
  }

  @override
  void dispose() {
    currentStopController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Color statusColor(String status) {
    switch (status) {
      case "ON_TIME":
        return Colors.green;
      case "DELAYED":
        return Colors.orange;
      case "ARRIVED":
        return Colors.blue;
      case "DEPARTED":
        return Colors.purple;
      case "CANCELLED":
        return Colors.red;
      case "COMPLETED":
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(selectedStatus);

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: const Text("Update Bus Status"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.update, color: Colors.red, size: 54),
                const SizedBox(height: 14),
                const Text(
                  "Update Active Bus Status",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    activeBusNumber == null
                        ? "No active bus"
                        : "Active Bus: $activeBusNumber",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: "Bus Status",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: statuses.map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value!;
                    });
                  },
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: currentStopController,
                  decoration: InputDecoration(
                    labelText: "Current Stop",
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "Remarks",
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : updateStatus,
                    icon: const Icon(Icons.send),
                    label: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text("Update $selectedStatus"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
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
    );
  }
}
