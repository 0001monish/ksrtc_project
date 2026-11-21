import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/storage_service.dart';
import '../../services/conductor_location_service.dart';
import '../../services/api_service.dart';

import '../auth/login_screen.dart';
import 'login_bus_screen.dart';
import 'update_status_screen.dart';

class ConductorDashboard extends StatefulWidget {
  const ConductorDashboard({super.key});

  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard> {
  bool hasActiveBus = false;
  String? busNumber;
  String? routeName;
  String? source;
  String? destination;
  int? sessionId;

  @override
  void initState() {
    super.initState();
    loadActiveSession();
  }

  Future<void> loadActiveSession() async {
    try {
      // Backend is the source of truth.
      final response = await ApiService.get('/conductor/active-session');

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch active session: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);

      final bool active = data['hasActiveSession'] == true;

      if (!active) {
        await StorageService.clearActiveBusSession();

        if (!mounted) return;

        setState(() {
          hasActiveBus = false;
          busNumber = null;
          routeName = null;
          source = null;
          destination = null;
          sessionId = null;
        });

        await ConductorLocationService.stopTracking();

        return;
      }

      // Extract the actual session returned by the backend.
      final session = data['session'];

      final int restoredSessionId = (session['session_id'] as num).toInt();

      final int restoredScheduleId = (session['schedule_id'] as num).toInt();

      final String restoredBusNumber = session['bus_number'] ?? '';

      final String restoredRouteName = session['route_name'] ?? '';

      final String restoredSource = session['source'] ?? '';

      final String restoredDestination = session['destination'] ?? '';

      // Restore the session in local storage.
      await StorageService.saveActiveBusSession(
        busNumber: restoredBusNumber,
        sessionId: restoredSessionId,
        scheduleId: restoredScheduleId,
        routeName: restoredRouteName,
        source: restoredSource,
        destination: restoredDestination,
      );

      if (!mounted) return;

      // Update dashboard UI.
      setState(() {
        hasActiveBus = true;
        busNumber = restoredBusNumber;
        routeName = restoredRouteName;
        source = restoredSource;
        destination = restoredDestination;
        sessionId = restoredSessionId;
      });

      // Resume or verify GPS tracking.
      final trackingStarted = await ConductorLocationService.startTracking();

      if (!trackingStarted && mounted) {
        showMessage(
          'Bus session restored, but GPS tracking could not start. '
          'Please check location permissions.',
        );
      }

      debugPrint('Active bus session restored: $restoredBusNumber');
    } catch (error) {
      debugPrint('Active session restoration error: $error');

      if (!mounted) return;

      showMessage('Could not restore active bus session: $error');
    }
  }

  Future<void> logoutBus() async {
    if (sessionId == null) {
      showMessage("No active bus session found.");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout from bus?"),
        content: const Text(
          "This will stop live GPS tracking and end your active bus session.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Logout Bus"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // End the session on the backend first.
      await ApiLogout.logoutBus(sessionId!);

      // stopTracking() returns void, so do not await it.
      await ConductorLocationService.stopTracking();

      await StorageService.clearActiveBusSession();

      await loadActiveSession();

      if (!mounted) return;

      showMessage(
        "Bus session ended. Live tracking stopped.",
        backgroundColor: Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      showMessage("Bus logout failed: $e");
    }
  }

  Future<void> logoutAccount() async {
    ConductorLocationService.stopTracking();
    await StorageService.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void showMessage(String message, {Color backgroundColor = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Widget activeBusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasActiveBus
              ? [Colors.green, Colors.green.shade700]
              : [Colors.red, const Color(0xffD32F2F)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasActiveBus ? Icons.route : Icons.badge,
            color: Colors.white,
            size: 45,
          ),
          const SizedBox(height: 14),
          Text(
            hasActiveBus ? "Active Bus Session" : "Conductor Panel",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (hasActiveBus) ...[
            Text(
              busNumber ?? "",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${source ?? ""} → ${destination ?? ""}",
              style: const TextStyle(color: Colors.white70),
            ),
            if (routeName != null && routeName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(routeName!, style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 6),
            const Text(
              "Live GPS Tracking: ACTIVE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            const Text(
              "Login to a bus once. Status and live location will use your active bus session.",
              style: TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color color = Colors.red,
  }) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }

  void showNoBusMessage() {
    showMessage("Please login to a bus first.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: const Text("Conductor Dashboard"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: logoutAccount),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadActiveSession,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              activeBusCard(),
              const SizedBox(height: 20),

              buildCard(
                icon: hasActiveBus ? Icons.sync : Icons.login,
                title: hasActiveBus ? "Change Bus" : "Login To Bus",
                subtitle: hasActiveBus
                    ? "End current trip and start another bus session"
                    : "Enter bus number once to start an active trip",
                onTap: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginBusScreen()),
                  );

                  if (changed == true) {
                    await loadActiveSession();
                  }
                },
              ),

              buildCard(
                icon: Icons.update,
                title: "Update Bus Status",
                subtitle: hasActiveBus
                    ? "Update status for $busNumber"
                    : "Login to bus first",
                onTap: hasActiveBus
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UpdateStatusScreen(),
                          ),
                        );
                      }
                    : showNoBusMessage,
              ),

              if (hasActiveBus)
                buildCard(
                  icon: Icons.stop_circle,
                  title: "Logout From Bus",
                  subtitle: "Stop trip and live GPS tracking",
                  color: Colors.red,
                  onTap: logoutBus,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApiLogout {
  static Future<void> logoutBus(int sessionId) async {
    // Backend route is POST /logout-bus/:session_id
    final response = await ApiService.post(
      "/conductor/logout-bus/$sessionId",
      {},
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Logout bus failed (${response.statusCode}): ${response.body}",
      );
    }
  }
}
