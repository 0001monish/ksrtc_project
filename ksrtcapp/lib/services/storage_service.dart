import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String tokenKey = "token";
  static const String roleKey = "role";
  static const String unreadNotificationKey = "unread_notifications";

  static const String activeBusNumberKey = "active_bus_number";
  static const String activeSessionIdKey = "active_session_id";
  static const String activeScheduleIdKey = "active_schedule_id";
  static const String activeRouteNameKey = "active_route_name";
  static const String activeSourceKey = "active_source";
  static const String activeDestinationKey = "active_destination";

  // AUTH
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(roleKey);
  }

  // NOTIFICATIONS
  static Future<void> setUnreadNotificationCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(unreadNotificationKey, count);
  }

  static Future<int> getUnreadNotificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(unreadNotificationKey) ?? 0;
  }

  static Future<void> incrementNotificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(unreadNotificationKey) ?? 0;
    await prefs.setInt(unreadNotificationKey, current + 1);
  }

  static Future<void> clearNotificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(unreadNotificationKey, 0);
  }

  // ACTIVE BUS SESSION
  static Future<void> saveActiveBusSession({
    required String busNumber,
    required int sessionId,
    required int scheduleId,
    required String routeName,
    required String source,
    required String destination,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(activeBusNumberKey, busNumber);
    await prefs.setInt(activeSessionIdKey, sessionId);
    await prefs.setInt(activeScheduleIdKey, scheduleId);
    await prefs.setString(activeRouteNameKey, routeName);
    await prefs.setString(activeSourceKey, source);
    await prefs.setString(activeDestinationKey, destination);
  }

  static Future<String?> getActiveBusNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeBusNumberKey);
  }

  static Future<int?> getActiveSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(activeSessionIdKey);
  }

  static Future<int?> getActiveScheduleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(activeScheduleIdKey);
  }

  static Future<String?> getActiveRouteName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeRouteNameKey);
  }

  static Future<String?> getActiveSource() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeSourceKey);
  }

  static Future<String?> getActiveDestination() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeDestinationKey);
  }

  static Future<bool> hasActiveBusSession() async {
    final busNumber = await getActiveBusNumber();
    final sessionId = await getActiveSessionId();

    return busNumber != null && busNumber.isNotEmpty && sessionId != null;
  }

  static Future<void> clearActiveBusSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(activeBusNumberKey);
    await prefs.remove(activeSessionIdKey);
    await prefs.remove(activeScheduleIdKey);
    await prefs.remove(activeRouteNameKey);
    await prefs.remove(activeSourceKey);
    await prefs.remove(activeDestinationKey);
  }

  // CLEAR ALL SAVED DATA
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
