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
import 'services/prayer_times_service.dart';
import 'services/azan_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_scheduler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if app was launched for background alarm rescheduling
  // This happens after device boot or at midnight
  await _handleBackgroundReschedule();

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

  // Initialize prayer services for background notifications and azan
  try {
    await PrayerTimesService.instance.initialize();

    // Note: AzanService and NotificationService are deprecated.
    // Azan and notifications are now handled by native Android code.
    // These initializations are commented out but files kept for reference.
    // await AzanService.instance.initialize();
    // await NotificationService.instance.initialize();

    // Initialize and schedule prayer alarms (uses native Android alarms)
    await AlarmSchedulerService.instance.initialize();
    await AlarmSchedulerService.instance.scheduleAllPrayerAlarms();

    if (kDebugMode) debugPrint('✅ Prayer services initialized successfully');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Failed to initialize prayer services: $e');
    // Continue app startup even if prayer services fail
  }

  runApp(const QuranApp());
}

/// Handle background alarm rescheduling when app is launched by boot or midnight receiver
Future<void> _handleBackgroundReschedule() async {
  try {
    // Check if launched for background rescheduling
    // This would require method channel communication with MainActivity
    // For now, alarm rescheduling happens automatically on app start
    // which is sufficient for boot and midnight scenarios

    if (kDebugMode) debugPrint('🔄 App starting - alarm scheduler will initialize');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Error in background reschedule check: $e');
  }
}

class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Stop azan when app comes to foreground
      if (AzanService.instance.isPlaying) {
        await AnalyticsService.logAzanStopped('app_opened');
        AzanService.instance.stopAzan();
        if (kDebugMode) debugPrint('🕌 Azan stopped: App resumed');
      }
    }
  }

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