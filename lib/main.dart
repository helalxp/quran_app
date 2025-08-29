// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewer_screen.dart';
import 'theme_manager.dart';

void main() {
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
            title: 'Quran Reader',
            debugShowCheckedModeBanner: false,
            themeMode: themeManager.themeMode,
            theme: themeManager.getLightTheme(themeManager.currentTheme),
            darkTheme: themeManager.getDarkTheme(themeManager.currentTheme),
            home: const ViewerScreen(),
          );
        },
      ),
    );
  }
}