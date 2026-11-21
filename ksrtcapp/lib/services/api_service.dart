import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ksrtcapp/services/storage_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5001',
  );

  static Uri url(String endpoint) {
    return Uri.parse("$baseUrl$endpoint");
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await StorageService.getToken();

    debugPrint("API token exists: ${token != null && token.isNotEmpty}");
    debugPrint("API token length: ${token?.length ?? 0}");

    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  static Future<http.Response> get(String endpoint) async {
    return http.get(url(endpoint), headers: await authHeaders());
  }

  static Future<http.Response> post(String endpoint, Object body) async {
    return http
        .post(
          url(endpoint),
          headers: await authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> put(String endpoint, {Object? body}) async {
    return http.put(
      url(endpoint),
      headers: await authHeaders(),
      body: body == null ? null : jsonEncode(body),
    );
  }

  static Future<http.Response> patch(String endpoint, {Object? body}) async {
    return http.patch(
      url(endpoint),
      headers: await authHeaders(),
      body: body == null ? null : jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String endpoint) async {
    return http.delete(url(endpoint), headers: await authHeaders());
  }
}
