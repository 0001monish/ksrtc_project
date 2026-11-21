import 'package:flutter/material.dart';

import '../services/storage_service.dart';

import 'auth/login_screen.dart';
import 'passenger/passenger_dashboard.dart';
import 'conductor/conductor_dashboard.dart';
import 'admin/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> checkLogin() async {
    final token = await StorageService.getToken();
    final role = await StorageService.getRole();

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (token == null || role == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (role == "PASSENGER") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PassengerDashboard()),
      );
    } else if (role == "CONDUCTOR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ConductorDashboard()),
      );
    } else if (role == "ADMIN") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.red,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
