import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:ksrtcapp/services/api_service.dart';
import 'package:ksrtcapp/services/storage_service.dart';

import 'package:ksrtcapp/screens/admin/admin_dashboard.dart';
import 'package:ksrtcapp/screens/conductor/conductor_dashboard.dart';
import 'package:ksrtcapp/screens/passenger/passenger_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = "PASSENGER";
  bool loading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage("Please enter email and password.");
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      String endpoint;

      switch (selectedRole) {
        case "ADMIN":
          endpoint = "/auth/admin-login";
          break;
        case "CONDUCTOR":
          endpoint = "/auth/conductor-login";
          break;
        default:
          endpoint = "/auth/login";
      }

      debugPrint("LOGIN STARTED: $selectedRole");
      debugPrint("LOGIN ENDPOINT: $endpoint");

      // Use the common ApiService with a 15-second timeout.
      final response = await ApiService.post(endpoint, {
        "email": email,
        "password": password,
      }).timeout(const Duration(seconds: 15));

      debugPrint("LOGIN STATUS: ${response.statusCode}");
      debugPrint("LOGIN RESPONSE: ${response.body}");

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception("Unexpected server response.");
      }

      final data = Map<String, dynamic>.from(decoded);

      if (response.statusCode != 200) {
        throw Exception(data["message"]?.toString() ?? "Login failed.");
      }

      final token = data["token"]?.toString();
      final role = data["role"]?.toString().toUpperCase();

      if (token == null || token.isEmpty) {
        throw Exception("Server did not return an authentication token.");
      }

      if (role == null || role != selectedRole) {
        throw Exception("Invalid role returned by server.");
      }

      // Save authentication details.
      await StorageService.saveToken(token);
      await StorageService.saveRole(role);

      final savedToken = await StorageService.getToken();

      if (savedToken == null || savedToken.isEmpty) {
        throw Exception("Unable to save authentication token.");
      }

      if (!mounted) return;

      debugPrint("LOGIN SUCCESS: $role");

      // Navigate to the correct dashboard.
      switch (role) {
        case "ADMIN":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
          break;

        case "CONDUCTOR":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ConductorDashboard()),
          );
          break;

        case "PASSENGER":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PassengerDashboard()),
          );
          break;
      }
    } catch (e) {
      debugPrint("LOGIN ERROR: $e");

      if (mounted) {
        showMessage(
          e.toString().contains("TimeoutException")
              ? "Server is taking too long to respond. Check your connection."
              : e.toString().replaceFirst("Exception: ", ""),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void openRegisterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "KSRTC Smart Bus",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 24),

                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: "Login as",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "PASSENGER",
                      child: Text("Passenger"),
                    ),
                    DropdownMenuItem(
                      value: "CONDUCTOR",
                      child: Text("Conductor"),
                    ),
                    DropdownMenuItem(value: "ADMIN", child: Text("Admin")),
                  ],
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              selectedRole = value;
                            });
                          }
                        },
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Login"),
                  ),
                ),

                if (selectedRole == "PASSENGER") ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading ? null : openRegisterScreen,
                    child: const Text("Create Passenger Account"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
