// lib/design_system/green_theme.dart - Islamic Green Theme

import 'package:flutter/material.dart';

/// Green Design System - Islamic green inspired theme
class GreenDesignSystem {
  // ==================== COLOR PALETTE ====================

  /// Primary Islamic green colors
  static const Color emeraldGreen = Color(0xFF4CAF50);     // Main green
  static const Color deepGreen = Color(0xFF2E7D32);        // Darker green
  static const Color lightGreen = Color(0xFF81C784);       // Light green
  static const Color goldAccent = Color(0xFFD4AF37);       // Gold for accents

  /// Neutral colors for text and backgrounds
  static const Color mintCream = Color(0xFFF1F8E9);        // Very light green background
  static const Color softCream = Color(0xFFFAFAF8);        // Soft cream background
  static const Color forestGreen = Color(0xFF1B5E20);      // Dark green text
  static const Color mossGreen = Color(0xFF388E3C);        // Secondary text

  /// Night mode colors
  static const Color deepForest = Color(0xFF0F1A0F);       // Deep green-tinted background
  static const Color softForest = Color(0xFF1A2A1A);       // Card background
  static const Color mintText = Color(0xFFE8F5E9);         // Light text

  // ==================== THEME DATA ====================

  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',

      colorScheme: ColorScheme.fromSeed(
        seedColor: emeraldGreen,
        brightness: Brightness.light,
        surface: mintCream,
        primary: emeraldGreen,
        secondary: goldAccent,
        tertiary: deepGreen,
      ),

      scaffoldBackgroundColor: mintCream,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: forestGreen),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: forestGreen,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFDCEDC8), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGreen,
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
        seedColor: lightGreen,
        brightness: Brightness.dark,
        surface: softForest,
        primary: lightGreen,
        secondary: goldAccent,
        tertiary: emeraldGreen,
      ),

      scaffoldBackgroundColor: deepForest,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: mintText),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: mintText,
        ),
      ),

      cardTheme: CardThemeData(
        color: softForest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A3A2A), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightGreen,
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
