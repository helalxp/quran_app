// lib/design_system/noor_theme.dart - New Islamic-inspired design system

import 'package:flutter/material.dart';

/// Noor Design System - Islamic-inspired UI for Quran apps
/// Based on traditional Islamic art, calligraphy, and geometric patterns
class NoorDesignSystem {
  // ==================== COLOR PALETTE ====================
  
  /// Primary Islamic colors inspired by traditional manuscripts
  static const Color goldPrimary = Color(0xFFD4AF37);  // Islamic gold
  static const Color emeraldGreen = Color(0xFF50C878);  // Islamic green
  static const Color sapphireBlue = Color(0xFF0F4C75);  // Deep contemplative blue
  static const Color crimsonRed = Color(0xFFDC143C);    // Accent red
  
  /// Neutral colors for text and backgrounds
  static const Color parchment = Color(0xFFFAF7F0);     // Light reading background
  static const Color warmPaper = Color(0xFFF5F1E8);     // Warm paper tone
  static const Color inkBlack = Color(0xFF2C2C2C);      // Soft black for Arabic text
  static const Color charcoalGray = Color(0xFF4A4A4A);  // Secondary text
  
  /// Night mode colors
  static const Color deepNight = Color(0xFF0F0F23);     // Deep night background
  static const Color softNight = Color(0xFF1A1A2E);     // Card background
  static const Color moonGlow = Color(0xFFE6E6FA);      // Light text
  
  // ==================== TYPOGRAPHY ====================
  
  /// Arabic text styles optimized for Quran reading
  static const TextStyle arabicLarge = TextStyle(
    fontFamily: 'Uthmanic',
    fontSize: 28,
    height: 2.0,  // Generous line spacing for Arabic
    letterSpacing: 1.2,
    color: inkBlack,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle arabicMedium = TextStyle(
    fontFamily: 'Uthmanic',
    fontSize: 22,
    height: 1.8,
    letterSpacing: 1.0,
    color: inkBlack,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle arabicSmall = TextStyle(
    fontFamily: 'Uthmanic',
    fontSize: 18,
    height: 1.6,
    letterSpacing: 0.8,
    color: inkBlack,
    fontWeight: FontWeight.w400,
  );
  
  /// UI text styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: inkBlack,
    letterSpacing: 0.5,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: charcoalGray,
    height: 1.4,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: charcoalGray,
    letterSpacing: 0.2,
  );
  
  // ==================== SPACING SYSTEM ====================
  
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  
  // ==================== BORDER RADIUS ====================
  
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusRound = 50.0;
  
  // ==================== SHADOWS ====================
  
  static const BoxShadow softShadow = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  
  static const BoxShadow mediumShadow = BoxShadow(
    color: Color(0x15000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  
  // ==================== THEME DATA ====================
  
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter', // For UI elements
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: emeraldGreen,
        brightness: Brightness.light,
        surface: parchment,
        primary: emeraldGreen,
        secondary: goldPrimary,
        tertiary: sapphireBlue,
      ),
      
      scaffoldBackgroundColor: parchment,
      
      // Remove default Material decorations
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: charcoalGray),
        titleTextStyle: heading1,
      ),
      
      // Custom card theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: Color(0xFFE8E8E8), width: 1),
        ),
      ),
      
      // Clean button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
        ),
      ),
      
      // Remove splash colors for cleaner interactions
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
  
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: emeraldGreen,
        brightness: Brightness.dark,
        surface: softNight,
        primary: emeraldGreen,
        secondary: goldPrimary,
        tertiary: sapphireBlue,
      ),
      
      scaffoldBackgroundColor: deepNight,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: moonGlow),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: moonGlow,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: softNight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: Color(0xFF2A2A3E), width: 1),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
        ),
      ),
      
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}

/// Custom colors for different Quran elements
class QuranColors {
  static const Color verseNumber = NoorDesignSystem.goldPrimary;
  static const Color surahName = NoorDesignSystem.emeraldGreen;
  static const Color juzMarker = NoorDesignSystem.sapphireBlue;
  static const Color bookmark = NoorDesignSystem.crimsonRed;
  static const Color currentVerse = Color(0x2050C878); // Light green highlight
  static const Color translation = NoorDesignSystem.charcoalGray;
}

/// Animation constants for smooth interactions
class NoorAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;
}