import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/conductor_location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConductorLocationService.initializeService();

  runApp(const KSRTCApp());
}

class KSRTCApp extends StatelessWidget {
  const KSRTCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'KSRTC Smart Bus',
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
