// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'viewer_screen.dart';
import 'theme_manager.dart';
import 'services/audio_service_handler.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely (non-blocking)
  try {
    await Firebase.initializeApp();
    await AnalyticsService.initialize();
    if (kDebugMode) debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Failed to initialize Firebase: $e');
    // Continue without Firebase - app will still work
  }

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize audio service only on supported platforms
  try {
    if (!kIsWeb) {
      await AudioService.init(
        builder: () => AudioServiceHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.helal.quran.audio',
          androidNotificationChannelName: 'Quran Audio',
          androidNotificationChannelDescription: 'Audio controls for Quran recitation',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationClickStartsActivity: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
      if (kDebugMode) debugPrint('✅ Audio service initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Failed to initialize audio service: $e');
    // Continue app startup even if audio service fails
  }

  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeManager(),
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'Quran by Helal',
            debugShowCheckedModeBanner: false,
            themeMode: themeManager.themeMode,
            theme: themeManager.getLightTheme(themeManager.currentTheme),
            darkTheme: themeManager.getDarkTheme(themeManager.currentTheme),
            navigatorObservers: AnalyticsService.observer != null
                ? [AnalyticsService.observer!]
                : [],
            home: const ViewerScreen(),
          );
        },
      ),
    );
  }
}