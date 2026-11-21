import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/storage_service.dart';

// =====================================================
// SCHEDULE FORM MODEL
// =====================================================

class ScheduleFormData {
  final int? scheduleId;

  final TextEditingController routeName;
  final TextEditingController source;
  final TextEditingController destination;
  final TextEditingController distance;
  final TextEditingController departure;
  final TextEditingController arrival;
  final TextEditingController operatingDays;
  final TextEditingController frequency;
  final TextEditingController routeType;

  bool isActive;

  ScheduleFormData({
    this.scheduleId,
    String routeName = '',
    String source = '',
    String destination = '',
    String distance = '',
    String departure = '',
    String arrival = '',
    String operatingDays = 'Daily',
    String frequency = 'Daily',
    String routeType = 'Intercity',
    this.isActive = true,
  }) : routeName = TextEditingController(text: routeName),
       source = TextEditingController(text: source),
       destination = TextEditingController(text: destination),
       distance = TextEditingController(text: distance),
       departure = TextEditingController(text: departure),
       arrival = TextEditingController(text: arrival),
       operatingDays = TextEditingController(text: operatingDays),
       frequency = TextEditingController(text: frequency),
       routeType = TextEditingController(text: routeType);

  factory ScheduleFormData.fromMap(Map<String, dynamic> data) {
    return ScheduleFormData(
      scheduleId: data['schedule_id'] == null
          ? null
          : int.tryParse(data['schedule_id'].toString()),
      routeName: data['route_name']?.toString() ?? '',
      source: data['source']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      distance: data['distance_km']?.toString() ?? '',
      departure: data['departure_time']?.toString() ?? '',
      arrival: data['arrival_time']?.toString() ?? '',
      operatingDays: data['operating_days']?.toString() ?? 'Daily',
      frequency: data['frequency']?.toString() ?? 'Daily',
      routeType: data['route_type']?.toString() ?? 'Intercity',
      isActive: data['schedule_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (scheduleId != null) 'schedule_id': scheduleId,
      'route_name': routeName.text.trim(),
      'source': source.text.trim(),
      'destination': destination.text.trim(),
      'distance_km': double.tryParse(distance.text.trim()),
      'departure_time': departure.text.trim(),
      'arrival_time': arrival.text.trim(),
      'operating_days': operatingDays.text.trim(),
      'frequency': frequency.text.trim(),
      'route_type': routeType.text.trim(),
      'is_active': isActive,
    };
  }

  void dispose() {
    routeName.dispose();
    source.dispose();
    destination.dispose();
    distance.dispose();
    departure.dispose();
    arrival.dispose();
    operatingDays.dispose();
    frequency.dispose();
    routeType.dispose();
  }
}

// =====================================================
// ADMIN BUSES SCREEN
// =====================================================

class AdminBusesScreen extends StatefulWidget {
  const AdminBusesScreen({super.key});

  @override
  State<AdminBusesScreen> createState() => _AdminBusesScreenState();
}

class _AdminBusesScreenState extends State<AdminBusesScreen> {
  bool loadingBuses = true;

  List<Map<String, dynamic>> buses = [];
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchBuses();
    });
  }
  // =====================================================
  // HELPERS
  // =====================================================

  Future<String?> getToken() async {
    return StorageService.getToken();
  }

  Map<String, String> authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<Map<String, dynamic>> parseList(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String displayTime(dynamic value) {
    if (value == null) return 'N/A';

    final time = value.toString();

    // PostgreSQL TIME can return HH:mm:ss.
    final parts = time.split(':');

    if (parts.length < 2) return time;

    final hour = int.tryParse(parts[0]);

    if (hour == null) return time;

    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $period';
  }

  String formatDistance(dynamic value) {
    if (value == null) return 'N/A';

    return '${value.toString()} km';
  }

  // =====================================================
  // GROUP BUS-SCHEDULE ROWS
  // =====================================================

  List<Map<String, dynamic>> groupBuses(List<Map<String, dynamic>> rows) {
    final Map<int, Map<String, dynamic>> grouped = {};

    for (final row in rows) {
      final busId = int.tryParse(row['bus_id'].toString());

      if (busId == null) continue;

      grouped.putIfAbsent(busId, () {
        return {
          'bus_id': busId,
          'bus_number': row['bus_number'],
          'bus_type': row['bus_type'],
          'capacity': row['capacity'],
          'operator_name': row['operator_name'],
          'is_active': row['is_active'],
          'schedules': <Map<String, dynamic>>[],
        };
      });

      if (row['schedule_id'] != null) {
        grouped[busId]!['schedules'].add({
          'schedule_id': row['schedule_id'],
          'route_id': row['route_id'],
          'route_name': row['route_name'],
          'source': row['source'],
          'destination': row['destination'],
          'distance_km': row['distance_km'],
          'route_type': row['route_type'],
          'departure_time': row['departure_time'],
          'arrival_time': row['arrival_time'],
          'operating_days': row['operating_days'],
          'frequency': row['frequency'],
          'schedule_active': row['schedule_active'],
        });
      }
    }

    return grouped.values.toList();
  }

  // =====================================================
  // FETCH BUSES
  // =====================================================

  Future<void> fetchBuses() async {
    if (mounted) {
      setState(() => loadingBuses = true);
    }

    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        ApiService.url('/admin/buses'),
        headers: authHeaders(token),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load buses: ${response.statusCode}\n${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      final rows = decoded is Map
          ? parseList(decoded['buses'])
          : <Map<String, dynamic>>[];

      final groupedBuses = groupBuses(rows);

      if (!mounted) return;

      setState(() {
        buses = groupedBuses;
        loadingBuses = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loadingBuses = false);
      showMessage('Error loading buses: $e');
    }
  }

  Future<void> refreshAll() async {
    await fetchBuses();
  }

  // =====================================================
  // ADD / EDIT BUS FORM
  // =====================================================

  // =====================================================
  // ADD / EDIT BUS FORM
  // =====================================================

  Future<void> showBusForm({Map<String, dynamic>? bus}) async {
    final isEditing = bus != null;

    final busNumberController = TextEditingController(
      text: bus?['bus_number']?.toString() ?? '',
    );

    final capacityController = TextEditingController(
      text: bus?['capacity']?.toString() ?? '',
    );

    final operatorController = TextEditingController(
      text: bus?['operator_name']?.toString() ?? 'KSRTC',
    );

    final formKey = GlobalKey<FormState>();

    const busTypes = ['Ordinary', 'Express', 'Rajahamsa', 'Airavat', 'Other'];

    String selectedBusType = bus?['bus_type']?.toString() ?? 'Express';

    if (!busTypes.contains(selectedBusType)) {
      selectedBusType = 'Other';
    }

    final List<ScheduleFormData> scheduleForms =
        (bus?['schedules'] as List? ?? [])
            .whereType<Map>()
            .map(
              (item) =>
                  ScheduleFormData.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList();

    if (scheduleForms.isEmpty) {
      scheduleForms.add(ScheduleFormData());
    }

    bool savedSuccessfully = false;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool saving = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Text(isEditing ? 'Edit Bus' : 'Add New Bus'),
                content: SizedBox(
                  width: 520,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bus Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller: busNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Bus Number',
                              hintText: 'KA-09-F-1234',
                              prefixIcon: Icon(Icons.directions_bus),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter bus number';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: selectedBusType,
                            decoration: const InputDecoration(
                              labelText: 'Bus Type',
                              prefixIcon: Icon(Icons.category),
                              border: OutlineInputBorder(),
                            ),
                            items: busTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        selectedBusType = value;
                                      });
                                    }
                                  },
                          ),

                          const SizedBox(height: 14),

                          TextFormField(
                            controller: capacityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Capacity',
                              prefixIcon: Icon(Icons.people),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final capacity = int.tryParse(value ?? '');

                              if (capacity == null || capacity <= 0) {
                                return 'Enter a valid capacity';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          TextFormField(
                            controller: operatorController,
                            decoration: const InputDecoration(
                              labelText: 'Operator Name',
                              prefixIcon: Icon(Icons.business),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter operator name';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Routes & Schedules',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          scheduleForms.add(ScheduleFormData());
                                        });
                                      },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Schedule'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          ...List.generate(scheduleForms.length, (index) {
                            final schedule = scheduleForms[index];

                            return _buildScheduleForm(
                              schedule: schedule,
                              index: index,
                              canRemove: schedule.scheduleId == null,
                              saving: saving,
                              onRemove: () {
                                final removed = scheduleForms.removeAt(index);

                                setDialogState(() {});

                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  removed.dispose();
                                });
                              },
                              onActiveChanged: (value) {
                                setDialogState(() {
                                  schedule.isActive = value;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                            });

                            final success = await saveBus(
                              bus: bus,
                              busNumber: busNumberController.text.trim(),
                              busType: selectedBusType,
                              capacity: int.parse(
                                capacityController.text.trim(),
                              ),
                              operatorName: operatorController.text.trim(),
                              schedules: scheduleForms,
                            );

                            if (!dialogContext.mounted) return;

                            if (success) {
                              Navigator.pop(dialogContext, true);
                            } else {
                              setDialogState(() {
                                saving = false;
                              });
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditing ? 'Update Bus' : 'Add Bus'),
                  ),
                ],
              );
            },
          );
        },
      );

      savedSuccessfully = result == true;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        busNumberController.dispose();
        capacityController.dispose();
        operatorController.dispose();

        for (final schedule in scheduleForms) {
          schedule.dispose();
        }
      });
    }

    // Refresh only after the dialog has closed and controllers are disposed.
    if (savedSuccessfully && mounted) {
      await fetchBuses();

      if (mounted) {
        showMessage(
          isEditing ? 'Bus updated successfully' : 'Bus added successfully',
        );
      }
    }
  }

  // =====================================================
  // SCHEDULE FORM WIDGET
  // =====================================================

  Widget _buildScheduleForm({
    required ScheduleFormData schedule,
    required int index,
    required bool canRemove,
    required bool saving,
    required VoidCallback onRemove,
    required ValueChanged<bool> onActiveChanged,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Schedule ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: saving ? null : onRemove,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remove new schedule',
                  ),
              ],
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: schedule.routeName,
              decoration: const InputDecoration(
                labelText: 'Route Name',
                hintText: 'Mysuru - Bengaluru',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter route name';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: schedule.source,
              decoration: const InputDecoration(
                labelText: 'Source',
                prefixIcon: Icon(Icons.trip_origin),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter source';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: schedule.destination,
              decoration: const InputDecoration(
                labelText: 'Destination',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter destination';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: schedule.distance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Distance (km)',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }

                final distance = double.tryParse(value);

                if (distance == null || distance < 0) {
                  return 'Enter a valid distance';
                }

                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: schedule.routeType,
              decoration: const InputDecoration(
                labelText: 'Route Type',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: schedule.departure,
                    decoration: const InputDecoration(
                      labelText: 'Departure',
                      hintText: '06:30',
                      prefixIcon: Icon(Icons.departure_board),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }

                      return _validTime(value.trim()) ? null : 'Use HH:mm';
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: TextFormField(
                    controller: schedule.arrival,
                    decoration: const InputDecoration(
                      labelText: 'Arrival',
                      hintText: '09:30',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }

                      return _validTime(value.trim()) ? null : 'Use HH:mm';
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: schedule.operatingDays,
              decoration: const InputDecoration(
                labelText: 'Operating Days',
                hintText: 'Daily / Monday-Friday',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: schedule.frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                hintText: 'Daily / Every 30 minutes',
                border: OutlineInputBorder(),
              ),
            ),

            if (schedule.scheduleId != null) ...[
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Schedule Active'),
                value: schedule.isActive,
                activeThumbColor: Colors.green,
                onChanged: saving ? null : onActiveChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =====================================================
  // VALIDATE TIME
  // =====================================================

  bool _validTime(String value) {
    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$').hasMatch(value);
  }
  // =====================================================
  // SAVE BUS
  // =====================================================

  // =====================================================
  // SAVE BUS
  // =====================================================

  Future<bool> saveBus({
    Map<String, dynamic>? bus,
    required String busNumber,
    required String busType,
    required int capacity,
    required String operatorName,
    required List<ScheduleFormData> schedules,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      final isEditing = bus != null;

      final body = jsonEncode({
        'bus_number': busNumber,
        'bus_type': busType,
        'capacity': capacity,
        'operator_name': operatorName,
        'schedules': schedules.map((item) {
          return item.toJson();
        }).toList(),
      });

      final response = isEditing
          ? await http.put(
              ApiService.url('/admin/buses/${bus['bus_id']}'),
              headers: authHeaders(token),
              body: body,
            )
          : await http.post(
              ApiService.url('/admin/buses'),
              headers: authHeaders(token),
              body: body,
            );

      debugPrint('BUS SAVE STATUS: ${response.statusCode}');
      debugPrint('BUS SAVE RESPONSE: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      showMessage(
        'Failed to save bus: ${response.statusCode}\n${response.body}',
      );

      return false;
    } catch (e) {
      debugPrint('BUS SAVE ERROR: $e');
      showMessage('Error saving bus: $e');
      return false;
    }
  }

  // =====================================================
  // ACTIVATE / DEACTIVATE BUS
  // =====================================================

  Future<void> toggleBusStatus(Map<String, dynamic> bus) async {
    final busId = bus['bus_id'];
    final isActive = bus['is_active'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isActive ? 'Deactivate Bus?' : 'Activate Bus?'),
          content: Text(
            'Are you sure you want to ${isActive ? 'deactivate' : 'activate'} ${bus['bus_number']}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isActive ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      final response = await http.patch(
        ApiService.url('/admin/buses/$busId/active'),
        headers: authHeaders(token),
        body: jsonEncode({'is_active': !isActive}),
      );

      if (response.statusCode == 200) {
        showMessage(
          isActive
              ? 'Bus deactivated successfully'
              : 'Bus activated successfully',
        );

        await fetchBuses();
      } else {
        showMessage(
          'Failed to update bus: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      showMessage('Error updating bus status: $e');
    }
  }

  // =====================================================
  // BUS CARD
  // =====================================================

  Widget buildBusCard(Map<String, dynamic> bus) {
    final isActive = bus['is_active'] == true;

    final schedules = (bus['schedules'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BUS DETAILS
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isActive ? Colors.red : Colors.grey,
                  child: const Icon(Icons.directions_bus, color: Colors.white),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus['bus_number']?.toString() ?? 'Unknown Bus',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bus['bus_type'] ?? 'N/A'} • ${bus['capacity'] ?? 'N/A'} seats',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Operator: ${bus['operator_name'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                _statusChip(isActive ? 'ACTIVE' : 'INACTIVE', isActive),
              ],
            ),

            const Divider(height: 24),

            // SCHEDULE COUNT
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.red, size: 19),
                const SizedBox(width: 8),
                Text(
                  '${schedules.length} Schedule(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (schedules.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No schedules assigned to this bus.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),

            ...List.generate(schedules.length, (index) {
              return _buildScheduleCard(schedules[index], index);
            }),

            const Divider(height: 24),

            // ACTIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => showBusForm(bus: bus),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),

                const SizedBox(width: 8),

                TextButton.icon(
                  onPressed: () => toggleBusStatus(bus),
                  style: TextButton.styleFrom(
                    foregroundColor: isActive ? Colors.red : Colors.green,
                  ),
                  icon: Icon(
                    isActive ? Icons.block : Icons.check_circle,
                    size: 18,
                  ),
                  label: Text(isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // SCHEDULE CARD
  // =====================================================

  Widget _buildScheduleCard(Map<String, dynamic> schedule, int index) {
    final active = schedule['schedule_active'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Schedule ${index + 1} • ID ${schedule['schedule_id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _statusChip(active ? 'ACTIVE' : 'INACTIVE', active),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            schedule['route_name']?.toString() ?? 'Unnamed Route',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.trip_origin, color: Colors.green, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(schedule['source']?.toString() ?? 'Unknown'),
              ),
              const Icon(Icons.location_on, color: Colors.red, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(schedule['destination']?.toString() ?? 'Unknown'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                Icons.straighten,
                formatDistance(schedule['distance_km']),
              ),
              _infoChip(
                Icons.category,
                schedule['route_type']?.toString() ?? 'N/A',
              ),
              _infoChip(
                Icons.calendar_today,
                schedule['operating_days']?.toString() ?? 'N/A',
              ),
              _infoChip(
                Icons.repeat,
                schedule['frequency']?.toString() ?? 'N/A',
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${displayTime(schedule['departure_time'])} → ${displayTime(schedule['arrival_time'])}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // COMMON UI HELPERS
  // =====================================================

  Widget _statusChip(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Colors.grey.withValues(alpha: 0.10)
            : Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.green : Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // =====================================================
  // BUS LIST
  // =====================================================

  Widget buildBusesList() {
    if (loadingBuses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (buses.isEmpty) {
      return RefreshIndicator(
        onRefresh: fetchBuses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No buses found')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchBuses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: buses.length,
        itemBuilder: (context, index) {
          return buildBusCard(buses[index]);
        },
      ),
    );
  }

  // =====================================================
  // BUILD SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),

      appBar: AppBar(
        title: const Text('Manage Buses'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),

      body: buildBusesList(),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBusForm(),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Bus'),
      ),
    );
  }
}
