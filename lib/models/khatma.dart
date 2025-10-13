// lib/models/khatma.dart

import 'package:flutter/foundation.dart';
import '../constants/juz_mappings.dart';

enum KhatmaMode {
  endDate,    // User sets end date, we calculate pages/day
  pagesPerDay, // User sets pages/day, we calculate end date
  tracking,    // No goals, just tracking (None mode)
}

class Khatma {
  final String id;
  final String name;
  final KhatmaMode mode;
  final int startJuz;
  final int endJuz;
  final DateTime createdAt;
  final DateTime? endDate; // For endDate mode
  final int? pagesPerDay; // For pagesPerDay mode
  final String? notificationTime; // Format: "HH:mm" (24-hour)
  final Map<String, DailyProgress> dailyProgress; // Date string (yyyy-MM-dd) -> progress
  final Set<int> allPagesRead; // GLOBAL: All unique pages ever read across entire Khatma

  Khatma({
    required this.id,
    required this.name,
    required this.mode,
    required this.startJuz,
    required this.endJuz,
    required this.createdAt,
    this.endDate,
    this.pagesPerDay,
    this.notificationTime,
    Map<String, DailyProgress>? dailyProgress,
    Set<int>? allPagesRead,
  }) : dailyProgress = dailyProgress ?? {},
       allPagesRead = allPagesRead ?? {};

  // Calculate total pages for this Khatma
  int get totalPages {
    final startPage = JuzMappings.getJuzStartPage(startJuz) ?? 1;
    final endPageValue = endPage;
    return endPageValue - startPage + 1;
  }

  // Get start page number
  int get startPage => JuzMappings.getJuzStartPage(startJuz) ?? 1;

  // Get end page number
  int get endPage {
    if (endJuz == 30) return 604;
    final nextJuzStart = JuzMappings.getJuzStartPage(endJuz + 1);
    if (nextJuzStart == null) {
      debugPrint('⚠️ ERROR: Invalid endJuz: $endJuz, using page 604 as fallback');
      return 604; // Fallback to last page
    }
    return nextJuzStart - 1;
  }

  // Calculate pages read so far - uses GLOBAL unique pages to prevent double-counting
  int get pagesRead {
    return allPagesRead.length;
  }

  // Calculate remaining pages
  int get pagesRemaining => totalPages - pagesRead;

  // Check if Khatma is completed
  bool get isCompleted => pagesRead >= totalPages;

  // Get current required pages per day (recalculated based on progress)
  int getCurrentPagesPerDay() {
    if (mode == KhatmaMode.tracking) return 0;

    if (mode == KhatmaMode.endDate && endDate != null) {
      final today = DateTime.now();
      final daysRemaining = endDate!.difference(today).inDays + 1;
      if (daysRemaining <= 0) return pagesRemaining;
      return (pagesRemaining / daysRemaining).ceil();
    }

    if (mode == KhatmaMode.pagesPerDay && pagesPerDay != null) {
      return pagesPerDay!;
    }

    return 0;
  }

  // Get recalculated end date (for pagesPerDay mode)
  DateTime? getRecalculatedEndDate() {
    if (mode != KhatmaMode.pagesPerDay || pagesPerDay == null) return null;

    final daysNeeded = (pagesRemaining / pagesPerDay!).ceil();
    return DateTime.now().add(Duration(days: daysNeeded));
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mode': mode.toString().split('.').last,
      'startJuz': startJuz,
      'endJuz': endJuz,
      'createdAt': createdAt.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'pagesPerDay': pagesPerDay,
      'notificationTime': notificationTime,
      'dailyProgress': dailyProgress.map((key, value) => MapEntry(key, value.toJson())),
      'allPagesRead': allPagesRead.toList(), // Serialize Set as List
    };
  }

  factory Khatma.fromJson(Map<String, dynamic> json) {
    KhatmaMode mode;
    switch (json['mode']) {
      case 'endDate':
        mode = KhatmaMode.endDate;
        break;
      case 'pagesPerDay':
        mode = KhatmaMode.pagesPerDay;
        break;
      case 'tracking':
        mode = KhatmaMode.tracking;
        break;
      default:
        mode = KhatmaMode.tracking;
    }

    final dailyProgress = (json['dailyProgress'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, DailyProgress.fromJson(value)),
    ) ?? {};

    // DATA MIGRATION: Build allPagesRead from existing data
    Set<int> allPagesRead;
    if (json['allPagesRead'] != null) {
      // New format - use stored global set
      allPagesRead = (json['allPagesRead'] as List<dynamic>)
          .map((e) => e as int)
          .toSet();
    } else {
      // OLD DATA MIGRATION: Collect all unique pages from daily progress
      allPagesRead = {};
      for (var progress in dailyProgress.values) {
        allPagesRead.addAll(progress.uniquePagesRead);
      }
    }

    return Khatma(
      id: json['id'],
      name: json['name'],
      mode: mode,
      startJuz: json['startJuz'],
      endJuz: json['endJuz'],
      createdAt: DateTime.parse(json['createdAt']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      pagesPerDay: json['pagesPerDay'],
      notificationTime: json['notificationTime'],
      dailyProgress: dailyProgress,
      allPagesRead: allPagesRead,
    );
  }

  // Create a copy with updated fields
  Khatma copyWith({
    String? name,
    DateTime? endDate,
    int? pagesPerDay,
    String? notificationTime,
    Map<String, DailyProgress>? dailyProgress,
    Set<int>? allPagesRead,
  }) {
    return Khatma(
      id: id,
      name: name ?? this.name,
      mode: mode,
      startJuz: startJuz,
      endJuz: endJuz,
      createdAt: createdAt,
      endDate: endDate ?? this.endDate,
      pagesPerDay: pagesPerDay ?? this.pagesPerDay,
      notificationTime: notificationTime ?? this.notificationTime,
      dailyProgress: dailyProgress ?? this.dailyProgress,
      allPagesRead: allPagesRead ?? this.allPagesRead,
    );
  }
}

class DailyProgress {
  final int pagesRead;
  final int targetPages;
  final int startPage;
  final int endPage;
  final bool isCompleted;
  final DateTime date;
  final Set<int> uniquePagesRead; // Track unique pages to prevent duplicates

  DailyProgress({
    required this.pagesRead,
    required this.targetPages,
    required this.startPage,
    required this.endPage,
    required this.isCompleted,
    required this.date,
    Set<int>? uniquePagesRead,
  }) : uniquePagesRead = uniquePagesRead ?? {};

  Map<String, dynamic> toJson() {
    return {
      'pagesRead': pagesRead,
      'targetPages': targetPages,
      'startPage': startPage,
      'endPage': endPage,
      'isCompleted': isCompleted,
      'date': date.toIso8601String(),
      'uniquePagesRead': uniquePagesRead.toList(),
    };
  }

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    return DailyProgress(
      pagesRead: json['pagesRead'],
      targetPages: json['targetPages'],
      startPage: json['startPage'],
      endPage: json['endPage'],
      isCompleted: json['isCompleted'],
      date: DateTime.parse(json['date']),
      uniquePagesRead: (json['uniquePagesRead'] as List<dynamic>?)?.map((e) => e as int).toSet() ?? {},
    );
  }

  DailyProgress copyWith({
    int? pagesRead,
    int? targetPages,
    int? startPage,
    int? endPage,
    bool? isCompleted,
    Set<int>? uniquePagesRead,
  }) {
    return DailyProgress(
      pagesRead: pagesRead ?? this.pagesRead,
      targetPages: targetPages ?? this.targetPages,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      isCompleted: isCompleted ?? this.isCompleted,
      date: date,
      uniquePagesRead: uniquePagesRead ?? this.uniquePagesRead,
    );
  }
}
