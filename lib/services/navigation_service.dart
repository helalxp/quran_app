import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../viewer_screen.dart';
import '../screens/feature_selection_screen.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/qibla_screen.dart';
import '../screens/tasbih_screen.dart';
import '../screens/playlist_screen.dart';
import '../settings_screen.dart';
import '../memorization_manager.dart';

class NavigationService {
  static const String _lastScreenKey = 'last_screen_route';
  static const String _lastPageKey = 'last_page_number';

  // Route names
  static const String routeViewer = 'viewer';
  static const String routeFeatures = 'features';
  static const String routePrayerTimes = 'prayer_times';
  static const String routeQibla = 'qibla';
  static const String routeTasbih = 'tasbih';
  static const String routeReciters = 'reciters';
  static const String routeSettings = 'settings';

  /// Save the current screen route
  static Future<void> saveLastScreen(String routeName, {int? pageNumber}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastScreenKey, routeName);
      if (pageNumber != null) {
        await prefs.setInt(_lastPageKey, pageNumber);
      }
      debugPrint('💾 Saved last screen: $routeName ${pageNumber != null ? "(page $pageNumber)" : ""}');
    } catch (e) {
      debugPrint('❌ Error saving last screen: $e');
    }
  }

  /// Get the last screen route
  static Future<String?> getLastScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastScreenKey);
    } catch (e) {
      debugPrint('❌ Error getting last screen: $e');
      return null;
    }
  }

  /// Get the last page number
  static Future<int?> getLastPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastPageKey);
    } catch (e) {
      debugPrint('❌ Error getting last page: $e');
      return null;
    }
  }

  /// Clear saved screen (used for logout or reset)
  static Future<void> clearLastScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastScreenKey);
      await prefs.remove(_lastPageKey);
      debugPrint('🗑️ Cleared last screen');
    } catch (e) {
      debugPrint('❌ Error clearing last screen: $e');
    }
  }

  /// Build the appropriate widget based on route name
  static Widget buildScreen(String? routeName, MemorizationManager memorizationManager, {int? initialPage}) {
    switch (routeName) {
      case routeViewer:
        return ViewerScreen(initialPage: initialPage);
      case routeFeatures:
        return FeatureSelectionScreen(memorizationManager: memorizationManager);
      case routePrayerTimes:
        return const PrayerTimesScreen();
      case routeQibla:
        return const QiblaScreen();
      case routeTasbih:
        return const TasbihScreen();
      case routeReciters:
        return const PlaylistScreen();
      case routeSettings:
        return SettingsScreen(memorizationManager: memorizationManager);
      default:
        // Default to viewer screen
        return ViewerScreen(initialPage: initialPage);
    }
  }

  /// Get the initial route on app launch (remembers last screen)
  static Future<Widget> getInitialScreen(MemorizationManager memorizationManager) async {
    final lastRoute = await getLastScreen();
    final lastPage = await getLastPage();

    if (lastRoute != null) {
      debugPrint('📱 Restoring last screen: $lastRoute ${lastPage != null ? "(page $lastPage)" : ""}');
      return buildScreen(lastRoute, memorizationManager, initialPage: lastPage);
    }

    // First launch or no saved route - start with viewer
    debugPrint('📱 First launch - starting with ViewerScreen');
    return const ViewerScreen();
  }
}
