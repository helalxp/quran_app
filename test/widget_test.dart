// This is a Flutter widget test for the Quran Reader app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/main.dart';

void main() {
  testWidgets('Quran app initializes correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QuranApp());
    
    // Pump once to trigger initial build
    await tester.pump();

    // Verify that MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify that the loading screen appears
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('App has proper title configuration', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QuranApp());
    
    // Pump once to get the MaterialApp
    await tester.pump();

    // Verify that the app has the correct title in MaterialApp
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, equals('Quran Reader'));
    expect(materialApp.debugShowCheckedModeBanner, equals(false));
  });
}
