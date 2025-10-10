// lib/design_system/blue_theme.dart - Classic Blue Theme

import 'package:flutter/material.dart';

/// Blue Design System - Classic and contemplative blue theme
class BlueDesignSystem {
  // ==================== COLOR PALETTE ====================

  /// Primary blue colors inspired by sky and contemplation
  static const Color skyBlue = Color(0xFF2196F3);          // Main blue
  static const Color deepBlue = Color(0xFF1976D2);         // Darker blue
  static const Color lightBlue = Color(0xFF64B5F6);        // Light blue
  static const Color goldAccent = Color(0xFFD4AF37);       // Gold for accents

  /// Neutral colors for text and backgrounds
  static const Color cloudWhite = Color(0xFFF3F9FF);       // Very light blue background
  static const Color softWhite = Color(0xFFFAFAFA);        // Soft white background
  static const Color navyBlue = Color(0xFF0D47A1);         // Dark blue text
  static const Color oceanBlue = Color(0xFF1565C0);        // Secondary text

  /// Night mode colors
  static const Color deepNight = Color(0xFF0F1419);        // Deep blue-tinted background
  static const Color softNight = Color(0xFF1A2332);        // Card background
  static const Color iceText = Color(0xFFE3F2FD);          // Light text

  // ==================== THEME DATA ====================

  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',

      colorScheme: ColorScheme.fromSeed(
        seedColor: skyBlue,
        brightness: Brightness.light,
        surface: cloudWhite,
        primary: skyBlue,
        secondary: goldAccent,
        tertiary: deepBlue,
      ),

      scaffoldBackgroundColor: cloudWhite,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: navyBlue),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: navyBlue,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFBBDEFB), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: skyBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }

  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',

      colorScheme: ColorScheme.fromSeed(
        seedColor: lightBlue,
        brightness: Brightness.dark,
        surface: softNight,
        primary: lightBlue,
        secondary: goldAccent,
        tertiary: skyBlue,
      ),

      scaffoldBackgroundColor: deepNight,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: iceText),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: iceText,
        ),
      ),

      cardTheme: CardThemeData(
        color: softNight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A3542), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
