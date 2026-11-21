import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'storage_service.dart';

const String notificationChannelId = 'ksrtc_gps_tracking';
const int notificationId = 888;

const Duration trackingInterval = Duration(seconds: 5);

class ConductorLocationService {
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  // --------------------------------------------------
  // 1. INITIALIZE BACKGROUND SERVICE
  // --------------------------------------------------

  static Future<void> initializeService() async {
    // Background service is not supported on Flutter Web.
    if (kIsWeb) {
      debugPrint('Background GPS service is not supported on Web.');
      return;
    }

    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'KSRTC Bus GPS Tracking',
      description: 'Tracks the conductor bus location during an active trip.',
      importance: Importance.low,
    );

    final notifications = FlutterLocalNotificationsPlugin();

    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'KSRTC Bus Tracking',
        initialNotificationContent: 'Starting GPS tracking...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    debugPrint('Background GPS service initialized.');
  }

  // --------------------------------------------------
  // 2. CHECK LOCATION PERMISSIONS
  // --------------------------------------------------

  static Future<bool> _checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint('Please enable GPS on your device.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied.');
      return false;
    }

    return true;
  }

  // --------------------------------------------------
  // 3. START TRACKING
  // --------------------------------------------------

  static Future<bool> startTracking() async {
    if (kIsWeb) {
      debugPrint('Background GPS tracking is unavailable on Web.');
      return false;
    }

    final allowed = await _checkPermission();

    if (!allowed) {
      return false;
    }

    final hasSession = await StorageService.hasActiveBusSession();

    if (!hasSession) {
      debugPrint('No active bus session. GPS not started.');
      return false;
    }

    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final service = FlutterBackgroundService();

    final alreadyRunning = await service.isRunning();

    if (!alreadyRunning) {
      await service.startService();
    }

    _isRunning = true;

    debugPrint('Background GPS tracking started.');

    return true;
  }

  // --------------------------------------------------
  // 4. STOP TRACKING
  // --------------------------------------------------

  static Future<void> stopTracking() async {
    if (kIsWeb) {
      _isRunning = false;
      debugPrint('Background GPS service is unavailable on Web.');
      return;
    }

    final service = FlutterBackgroundService();

    service.invoke('stopService');

    _isRunning = false;

    debugPrint('Background GPS tracking stop requested.');
  }

  // This closes ConductorLocationService.
}
// ======================================================
// BACKGROUND ISOLATE
// ======================================================

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Timer? timer;

  bool isSendingLocation = false;

  // --------------------------------------------------
  // STOP SERVICE EVENT
  // --------------------------------------------------

  service.on('stopService').listen((event) {
    timer?.cancel();
    service.stopSelf();

    debugPrint('Background GPS service stopped.');
  });

  // --------------------------------------------------
  // SEND GPS LOCATION
  // --------------------------------------------------

  Future<void> sendLocation() async {
    if (isSendingLocation) return;

    isSendingLocation = true;

    try {
      debugPrint('========== GPS UPDATE STARTED ==========');

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final busNumber = await StorageService.getActiveBusNumber();
      final sessionId = await StorageService.getActiveSessionId();

      debugPrint('ACTIVE BUS: $busNumber');
      debugPrint('ACTIVE SESSION: $sessionId');

      if (busNumber == null || busNumber.isEmpty || sessionId == null) {
        debugPrint('GPS ERROR: Active bus session missing.');

        timer?.cancel();
        service.stopSelf();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint('GPS POSITION: ${position.latitude}, ${position.longitude}');
      debugPrint('SENDING GPS REQUEST TO BACKEND...');

      final response = await ApiService.post('/conductor/update-location', {
        'bus_number': busNumber,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      debugPrint('GPS API STATUS: ${response.statusCode}');
      debugPrint('GPS API RESPONSE: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('GPS UPDATE SUCCESSFUL');

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'KSRTC GPS Tracking Active',
            content: 'Bus: $busNumber | Location updated',
          );
        }
      } else {
        debugPrint('GPS API REQUEST FAILED');
      }
    } catch (error, stackTrace) {
      debugPrint('BACKGROUND GPS ERROR: $error');
      debugPrint('GPS STACK TRACE: $stackTrace');
    } finally {
      isSendingLocation = false;
    }
  }

  // --------------------------------------------------
  // START PERIODIC GPS UPDATES
  // --------------------------------------------------

  // Send first location immediately.
  await sendLocation();

  timer = Timer.periodic(trackingInterval, (timer) {
    sendLocation();
  });

  debugPrint('Background GPS timer started: 5 seconds.');
}
