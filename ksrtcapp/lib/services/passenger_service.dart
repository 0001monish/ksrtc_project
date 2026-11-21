import 'dart:convert';

import 'package:http/http.dart' as http;

class PassengerService {
  // Android emulator: use 10.0.2.2 to reach your computer's localhost.
  // Physical phone: replace with your computer's local IP address.
  // Production: replace with your Render backend URL.
  static const String baseUrl = 'http://10.0.2.2:5001';

  static Future<List<Map<String, dynamic>>> searchBuses({
    required String source,
    required String destination,
  }) async {
    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: {
        'source': source.trim(),
        'destination': destination.trim(),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final buses = decoded['buses'];

      if (buses is List) {
        return buses.map((bus) => Map<String, dynamic>.from(bus)).toList();
      }

      return [];
    }

    final message = decoded is Map ? decoded['message']?.toString() : null;

    throw Exception(message ?? 'Failed to search buses.');
  }
}
