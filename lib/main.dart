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
import 'services/native_azan_service.dart';
import 'services/suggestions_service.dart';
import 'package:in_app_update/in_app_update.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup global error boundary
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('❌ Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('❌ Platform Error: $error');
      debugPrint('Stack trace: $stack');
    }
    return true;
  };

  // Check if app was launched for background alarm rescheduling
  // This happens after device boot or at midnight
  await _handleBackgroundReschedule();

  // Initialize Firebase safely (non-blocking)
  try {
    await Firebase.initializeApp();
    await AnalyticsService.initialize();
    await SuggestionsService.initialize();
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

    // Note: AzanService is deprecated - azan is now handled by native Android code.
    // NotificationService is still needed for permission requests!
    // await AzanService.instance.initialize();
    await NotificationService.instance.initialize();

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

    // Check for app updates on Play Store
    _checkForUpdate();
  }

  /// Check for app updates and prompt user if available
  Future<void> _checkForUpdate() async {
    try {
      if (!kIsWeb) {
        final info = await InAppUpdate.checkForUpdate();

        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          if (kDebugMode) debugPrint('📱 Update available! Starting flexible update...');

          // Start flexible update (downloads in background)
          await InAppUpdate.startFlexibleUpdate();

          // Listen for update download completion
          InAppUpdate.completeFlexibleUpdate().then((_) {
            if (kDebugMode) debugPrint('✅ Update downloaded and ready to install');
            // The update will be installed on next app restart
          }).catchError((e) {
            if (kDebugMode) debugPrint('❌ Update installation failed: $e');
          });
        } else {
          if (kDebugMode) debugPrint('✅ App is up to date');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Update check failed: $e');
      // Continue normally - updates are not critical
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Azan stop on app resume is handled natively in MainActivity.onResume()
      if (kDebugMode) debugPrint('🕌 App resumed - native azan will be stopped if playing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeManager(),
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return Listener(
            onPointerDown: (_) {
              // Stop azan when user taps anywhere in the app
              NativeAzanService.stopAzanFromFlutter();
            },
            child: MaterialApp(
              title: 'Quran by Helal',
              debugShowCheckedModeBanner: false,
              themeMode: themeManager.themeMode,
              theme: themeManager.getLightTheme(themeManager.currentTheme),
              darkTheme: themeManager.getDarkTheme(themeManager.currentTheme),
              navigatorObservers: AnalyticsService.observer != null
                  ? [AnalyticsService.observer!]
                  : [],
              home: const ViewerScreen(),
            ),
          );
        },
      ),
    );
  }
}