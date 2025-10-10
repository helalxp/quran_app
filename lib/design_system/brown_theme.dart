// lib/design_system/brown_theme.dart - Traditional Brown Theme

import 'package:flutter/material.dart';

/// Brown Design System - Traditional Islamic manuscript inspired theme
class BrownDesignSystem {
  // ==================== COLOR PALETTE ====================

  /// Primary brown colors inspired by traditional manuscripts and leather bindings
  static const Color warmBrown = Color(0xFF8D6E63);        // Main brown
  static const Color richBrown = Color(0xFF6D4C41);        // Darker brown
  static const Color lightBrown = Color(0xFFBCAAA4);       // Light brown
  static const Color goldAccent = Color(0xFFD4AF37);       // Gold for accents

  /// Neutral colors for text and backgrounds
  static const Color parchment = Color(0xFFFAF8F3);        // Warm paper background
  static const Color warmPaper = Color(0xFFF5EFE7);        // Slightly warmer paper
  static const Color inkBrown = Color(0xFF3E2723);         // Dark brown text
  static const Color sepiaBrown = Color(0xFF5D4037);       // Secondary text

  /// Night mode colors
  static const Color deepBrown = Color(0xFF1A1410);        // Deep brown background
  static const Color softBrown = Color(0xFF2C231E);        // Card background
  static const Color creamText = Color(0xFFF5EFE7);        // Light text

  // ==================== THEME DATA ====================

  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',

      colorScheme: ColorScheme.fromSeed(
        seedColor: warmBrown,
        brightness: Brightness.light,
        surface: parchment,
        primary: warmBrown,
        secondary: goldAccent,
        tertiary: richBrown,
      ),

      scaffoldBackgroundColor: parchment,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: inkBrown),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: inkBrown,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE8E0D5), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: warmBrown,
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
        seedColor: lightBrown,
        brightness: Brightness.dark,
        surface: softBrown,
        primary: lightBrown,
        secondary: goldAccent,
        tertiary: warmBrown,
      ),

      scaffoldBackgroundColor: deepBrown,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: creamText),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: creamText,
        ),
      ),

      cardTheme: CardThemeData(
        color: softBrown,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3E2F28), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightBrown,
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
