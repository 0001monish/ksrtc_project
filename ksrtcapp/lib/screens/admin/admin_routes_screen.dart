import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminRoutesScreen extends StatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  State<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends State<AdminRoutesScreen> {
  List<dynamic> routes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRoutes();
  }

  Future<void> fetchRoutes() async {
    setState(() => isLoading = true);

    try {
      final response = await ApiService.get('/admin/routes');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        setState(() {
          routes = decoded is List ? decoded : decoded['routes'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        showMessage('Failed to load routes: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showMessage('Error loading routes: $e');
    }
  }

  Future<void> showRouteDialog({Map<String, dynamic>? route}) async {
    final isEditing = route != null;

    final nameController = TextEditingController(
      text: route?['route_name']?.toString() ?? '',
    );
    final sourceController = TextEditingController(
      text: route?['source']?.toString() ?? '',
    );
    final destinationController = TextEditingController(
      text: route?['destination']?.toString() ?? '',
    );
    final distanceController = TextEditingController(
      text: route?['distance_km']?.toString() ?? '',
    );
    final typeController = TextEditingController(
      text: route?['route_type']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Route' : 'Add Route'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildField(nameController, 'Route Name'),
                  _buildField(sourceController, 'Source'),
                  _buildField(destinationController, 'Destination'),
                  _buildField(
                    distanceController,
                    'Distance (km)',
                    keyboardType: TextInputType.number,
                  ),
                  _buildField(typeController, 'Route Type'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final distance = int.tryParse(distanceController.text.trim());

                if (distance == null || distance <= 0) {
                  showMessage('Enter a valid positive distance');
                  return;
                }

                final body = {
                  'route_name': nameController.text.trim(),
                  'source': sourceController.text.trim(),
                  'destination': destinationController.text.trim(),
                  'distance_km': distance,
                  'route_type': typeController.text.trim(),
                };

                try {
                  final response = isEditing
                      ? await ApiService.put(
                          '/admin/routes/${route['route_id']}',
                          body: body,
                        )
                      : await ApiService.post('/admin/routes', body);

                  if (response.statusCode == 200 ||
                      response.statusCode == 201) {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }

                    await fetchRoutes();
                    showMessage(
                      isEditing
                          ? 'Route updated successfully'
                          : 'Route added successfully',
                    );
                  } else {
                    showMessage('Request failed: ${response.body}');
                  }
                } catch (e) {
                  showMessage('Error: $e');
                }
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteRoute(Map<String, dynamic> route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text(
          'Are you sure you want to delete "${route['route_name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.delete(
        '/admin/routes/${route['route_id']}',
      );

      if (response.statusCode == 200) {
        await fetchRoutes();
        showMessage('Route deleted successfully');
      } else if (response.statusCode == 409) {
        showMessage('Cannot delete: this route is assigned to a schedule');
      } else {
        showMessage('Delete failed: ${response.body}');
      }
    } catch (e) {
      showMessage('Error deleting route: $e');
    }
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Routes'),
        actions: [
          IconButton(onPressed: fetchRoutes, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRouteDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Route'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : routes.isEmpty
          ? const Center(child: Text('No routes found'))
          : RefreshIndicator(
              onRefresh: fetchRoutes,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = Map<String, dynamic>.from(routes[index] as Map);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.alt_route)),
                      title: Text(
                        route['route_name']?.toString() ?? 'Unnamed Route',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${route['source']} → ${route['destination']}\n'
                        '${route['distance_km']} km • '
                        '${route['route_type']}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            showRouteDialog(route: route);
                          } else if (value == 'delete') {
                            deleteRoute(route);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
