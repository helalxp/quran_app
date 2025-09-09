// lib/theme_manager.dart - ENHANCED with beautiful Islamic theme

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design_system/noor_theme.dart';
import 'constants/app_constants.dart';

enum AppTheme { brown, green, blue, islamic }

class ThemeManager extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  static const String _themeModeKey = 'theme_mode';
  static const String _followAyahKey = 'follow_ayah_on_playback';

  AppTheme _currentTheme = AppConstants.defaultTheme;
  ThemeMode _themeMode = AppConstants.defaultThemeMode;
  bool _followAyahOnPlayback = AppConstants.defaultFollowAyahOnPlayback;

  AppTheme get currentTheme => _currentTheme;
  ThemeMode get themeMode => _themeMode;
  bool get followAyahOnPlayback => _followAyahOnPlayback;

  ThemeManager() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme with validation
      final themeIndex = prefs.getInt(_themeKey);
      if (themeIndex != null && themeIndex >= 0 && themeIndex < AppTheme.values.length) {
        _currentTheme = AppTheme.values[themeIndex];
      } else {
        _currentTheme = AppConstants.defaultTheme;
      }
      
      // Load theme mode with validation
      final themeModeIndex = prefs.getInt(_themeModeKey);
      if (themeModeIndex != null && themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeModeIndex];
      } else {
        _themeMode = AppConstants.defaultThemeMode;
      }
      
      // Load follow ayah setting
      _followAyahOnPlayback = prefs.getBool(_followAyahKey) ?? AppConstants.defaultFollowAyahOnPlayback;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
      // Fallback to defaults on error
      _currentTheme = AppConstants.defaultTheme;
      _themeMode = AppConstants.defaultThemeMode;
      _followAyahOnPlayback = AppConstants.defaultFollowAyahOnPlayback;
      notifyListeners();
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme == theme) return;

    _currentTheme = theme;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, theme.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, mode.index);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> toggleFollowAyahOnPlayback() async {
    _followAyahOnPlayback = !_followAyahOnPlayback;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_followAyahKey, _followAyahOnPlayback);
    } catch (e) {
      debugPrint('Error saving follow ayah setting: $e');
    }
  }

  // Light themes with better colors
  static ThemeData get brownLightTheme => _createTheme(
    seedColor: const Color(0xFF8D6E63), // Warmer, softer brown
    brightness: Brightness.light,
    customBackground: const Color(0xFFFAF8F3), // Warm paper-like background
  );

  static ThemeData get greenLightTheme => _createTheme(
    seedColor: const Color(0xFF4CAF50), // Balanced Islamic green
    brightness: Brightness.light,
    customBackground: const Color(0xFFF1F8E9), // Very light green background
  );

  static ThemeData get blueLightTheme => _createTheme(
    seedColor: const Color(0xFF2196F3), // Softer blue
    brightness: Brightness.light,
    customBackground: const Color(0xFFF3F9FF), // Very light blue background
  );

  // Dark themes with better contrast
  static ThemeData get brownDarkTheme => _createTheme(
    seedColor: const Color(0xFFBCAAA4), // Muted brown for dark mode
    brightness: Brightness.dark,
    customBackground: const Color(0xFF1A1A1A), // True dark background
  );

  static ThemeData get greenDarkTheme => _createTheme(
    seedColor: const Color(0xFF81C784), // Softer green for dark mode
    brightness: Brightness.dark,
    customBackground: const Color(0xFF121212), // Material dark background
  );

  static ThemeData get blueDarkTheme => _createTheme(
    seedColor: const Color(0xFF64B5F6), // Softer blue for dark mode
    brightness: Brightness.dark,
    customBackground: const Color(0xFF0F1419), // Deep dark blue-tinted background
  );

  static ThemeData _createTheme({
    required Color seedColor,
    required Brightness brightness,
    Color? customBackground,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Use custom background if provided, otherwise use default
    final backgroundColor = customBackground ?? colorScheme.surface;

    return ThemeData(
      colorScheme: colorScheme.copyWith(
        surface: backgroundColor,
      ),
      brightness: brightness,
      fontFamily: 'Uthmanic',
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,

      // Enhanced card theme for better appearance
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.9)
            : colorScheme.surfaceContainer,
      ),

      // Enhanced app bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 3,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Better surface colors
      dialogTheme: DialogThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  ThemeData getLightTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.brown:
        return brownLightTheme;
      case AppTheme.green:
        return greenLightTheme;
      case AppTheme.blue:
        return blueLightTheme;
      case AppTheme.islamic:
        return NoorDesignSystem.getLightTheme(); // Beautiful Islamic theme!
    }
  }

  ThemeData getDarkTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.brown:
        return brownDarkTheme;
      case AppTheme.green:
        return greenDarkTheme;
      case AppTheme.blue:
        return blueDarkTheme;
      case AppTheme.islamic:
        return NoorDesignSystem.getDarkTheme(); // Beautiful Islamic dark theme!
    }
  }

  String getThemeName(AppTheme theme) {
    switch (theme) {
      case AppTheme.brown:
        return 'البني التقليدي';
      case AppTheme.green:
        return 'الأخضر الإسلامي';
      case AppTheme.blue:
        return 'الأزرق الكلاسيكي';
      case AppTheme.islamic:
        return 'نور - التصميم الإسلامي'; // Noor - Islamic Design
    }
  }
}