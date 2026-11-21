import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/conductor_location_service.dart';

class LoginBusScreen extends StatefulWidget {
  const LoginBusScreen({super.key});

  @override
  State<LoginBusScreen> createState() => _LoginBusScreenState();
}

class _LoginBusScreenState extends State<LoginBusScreen> {
  final busNumberController = TextEditingController();

  bool loading = false;

  Future<void> loginToBus() async {
    final busNumber = busNumberController.text.trim().toUpperCase();

    if (busNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter bus number")));
      return;
    }

    setState(() => loading = true);

    try {
      final response = await ApiService.post("/conductor/login-bus", {
        "bus_number": busNumber,
      });

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception("Invalid server response.");
      }

      final data = decoded;

      // Backend returns 201 when a bus session is created.
      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic sessionData = data["session"];

        if (sessionData is! Map<String, dynamic>) {
          throw Exception("Bus session details are missing from response.");
        }

        // Backend merges session, bus and schedule fields into "session".
        final session = sessionData;

        final dynamic rawSessionId = session["session_id"];
        final dynamic rawScheduleId = session["schedule_id"];

        if (rawSessionId == null) {
          throw Exception("Session ID is missing from server response.");
        }

        if (rawScheduleId == null) {
          throw Exception("Schedule ID is missing from server response.");
        }

        final int parsedSessionId = rawSessionId is int
            ? rawSessionId
            : int.parse(rawSessionId.toString());

        final int parsedScheduleId = rawScheduleId is int
            ? rawScheduleId
            : int.parse(rawScheduleId.toString());

        final String returnedBusNumber = (session["bus_number"] ?? busNumber)
            .toString();

        final String returnedRouteName = (session["route_name"] ?? "")
            .toString();

        final String returnedSource = (session["source"] ?? "").toString();

        final String returnedDestination = (session["destination"] ?? "")
            .toString();

        await StorageService.saveActiveBusSession(
          busNumber: returnedBusNumber,
          sessionId: parsedSessionId,
          scheduleId: parsedScheduleId,
          routeName: returnedRouteName,
          source: returnedSource,
          destination: returnedDestination,
        );

        await ConductorLocationService.startTracking();

        if (!mounted) return;

        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bus session started. Live tracking is active."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        if (!mounted) return;

        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (data["message"] ?? "Login to bus failed").toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Bus login failed: $e")));
    }
  }

  @override
  void dispose() {
    busNumberController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration() {
    return InputDecoration(
      labelText: "Bus Number",
      hintText: "KA-01-F-1234",
      prefixIcon: const Icon(Icons.confirmation_number, color: Colors.red),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: const Text("Login To Bus"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.directions_bus, color: Colors.red, size: 56),
                const SizedBox(height: 14),
                const Text(
                  "Start Bus Session",
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter bus number once. Status and GPS tracking will use this active bus automatically.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: busNumberController,
                  textCapitalization: TextCapitalization.characters,
                  enabled: !loading,
                  decoration: inputDecoration(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : loginToBus,
                    icon: const Icon(Icons.login),
                    label: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Start Trip"),
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
    );
  }
}
