import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/khatma.dart';
import '../constants/khatma_constants.dart';
import '../utils/date_utils_khatma.dart';
import 'khatma_notification_service.dart';
import 'analytics_service.dart';

class KhatmaManager {
  static final KhatmaManager _instance = KhatmaManager._internal();
  factory KhatmaManager() => _instance;
  KhatmaManager._internal();

  List<Khatma> _khatmas = [];
  final ValueNotifier<List<Khatma>> khatmasNotifier = ValueNotifier([]);

  // Error notifier for UI feedback
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  // Track page reads
  int? _lastTrackedPage;
  DateTime? _lastTrackTime;

  // Debounce saving to reduce disk I/O
  Timer? _saveDebounceTimer;
  static const _saveDebounceDuration = Duration(seconds: KhatmaConstants.saveDebounceDurationSeconds);

  Future<void> loadKhatmas() async {
    try {
      errorNotifier.value = null; // Clear previous errors
      final prefs = await SharedPreferences.getInstance();
      final khatmasJson = prefs.getString('khatmas');

      if (khatmasJson != null) {
        final List<dynamic> decoded = json.decode(khatmasJson);
        _khatmas = decoded.map((json) => Khatma.fromJson(json)).toList();
        khatmasNotifier.value = List.from(_khatmas);
      }
    } catch (e) {
      debugPrint('❌ Error loading khatmas: $e');
      errorNotifier.value = 'فشل تحميل الختمات. الرجاء المحاولة مرة أخرى.';
      // Initialize empty list on error
      _khatmas = [];
      khatmasNotifier.value = [];
    }
  }

  Future<void> saveKhatmas({bool immediate = false}) async {
    if (immediate) {
      // Cancel any pending debounced save
      _saveDebounceTimer?.cancel();
      await _performSave();
    } else {
      // Debounce the save
      _saveDebounceTimer?.cancel();
      _saveDebounceTimer = Timer(_saveDebounceDuration, () async {
        await _performSave();
      });
    }
  }

  Future<void> _performSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('khatmas', json.encode(_khatmas.map((k) => k.toJson()).toList()));
      khatmasNotifier.value = List.from(_khatmas);
    } catch (e) {
      debugPrint('❌ Error saving khatmas: $e');
      errorNotifier.value = 'فشل حفظ البيانات. الرجاء المحاولة مرة أخرى.';
    }
  }

  Future<void> addKhatma(Khatma khatma) async {
    try {
      errorNotifier.value = null;
      _khatmas.add(khatma);
      await saveKhatmas(immediate: true); // Save immediately for user actions

      // Schedule notification if time is set
      if (khatma.notificationTime != null) {
        await KhatmaNotificationService.scheduleKhatmaNotification(khatma);
        // Also schedule progress reminder after the initial notification
        await KhatmaNotificationService.scheduleProgressReminder(khatma, KhatmaConstants.progressReminderDelayHours);
      }
    } catch (e) {
      debugPrint('❌ Error adding khatma: $e');
      errorNotifier.value = 'فشل إضافة الختمة. الرجاء المحاولة مرة أخرى.';
      rethrow;
    }
  }

  Future<void> updateKhatma(String id, Khatma updatedKhatma) async {
    try {
      errorNotifier.value = null;
      final index = _khatmas.indexWhere((k) => k.id == id);
      if (index != -1) {
        _khatmas[index] = updatedKhatma;
        await saveKhatmas(immediate: true); // Save immediately for user actions

        // Reschedule notifications if time is set
        if (updatedKhatma.notificationTime != null) {
          await KhatmaNotificationService.scheduleKhatmaNotification(updatedKhatma);
          await KhatmaNotificationService.scheduleProgressReminder(updatedKhatma, KhatmaConstants.progressReminderDelayHours);
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating khatma: $e');
      errorNotifier.value = 'فشل تحديث الختمة. الرجاء المحاولة مرة أخرى.';
      rethrow;
    }
  }

  Future<void> deleteKhatma(String id) async {
    try {
      errorNotifier.value = null;
      // Cancel notification before deleting
      await KhatmaNotificationService.cancelKhatmaNotification(id);

      _khatmas.removeWhere((k) => k.id == id);
      await saveKhatmas(immediate: true); // Save immediately for user actions
    } catch (e) {
      debugPrint('❌ Error deleting khatma: $e');
      errorNotifier.value = 'فشل حذف الختمة. الرجاء المحاولة مرة أخرى.';
      rethrow;
    }
  }

  List<Khatma> get activeKhatmas => _khatmas.where((k) => !k.isCompleted).toList();

  // Track page view for all active khatmas
  Future<void> trackPageView(int pageNumber) async {
    if (_khatmas.isEmpty) return;

    final now = DateTime.now();
    final today = DateUtilsKhatma.getToday();
    final todayKey = DateUtilsKhatma.getTodayKey();

    // Prevent duplicate tracking for same page in short time
    if (_lastTrackedPage == pageNumber &&
        _lastTrackTime != null &&
        now.difference(_lastTrackTime!).inSeconds < KhatmaConstants.pageTrackingCooldownSeconds) {
      return;
    }

    _lastTrackedPage = pageNumber;
    _lastTrackTime = now;

    bool anyUpdated = false;

    for (var khatma in _khatmas) {
      if (khatma.isCompleted) continue;

      // Check if this page is within khatma range
      if (pageNumber >= khatma.startPage && pageNumber <= khatma.endPage) {
        // Get or create today's progress
        var todayProgress = khatma.dailyProgress[todayKey];

        if (todayProgress == null) {
          // Create new daily progress for today
          final pagesPerDay = khatma.getCurrentPagesPerDay();
          final startPage = khatma.startPage + khatma.pagesRead;
          final int endPage;

          // For tracking mode, track all remaining pages
          if (khatma.mode == KhatmaMode.tracking) {
            endPage = khatma.endPage;
          } else {
            endPage = (startPage + pagesPerDay - 1).clamp(startPage, khatma.endPage);
          }

          todayProgress = DailyProgress(
            pagesRead: 0,
            targetPages: pagesPerDay,
            startPage: startPage,
            endPage: endPage,
            isCompleted: false,
            date: today,
          );
          khatma.dailyProgress[todayKey] = todayProgress;
        }

        // CRITICAL: Check global allPagesRead first to prevent double-counting across days
        if (khatma.allPagesRead.contains(pageNumber)) {
          // User is re-reading a page they already read on a previous day
          // Still add to today's uniquePagesRead for daily stats, but don't count toward total
          final updatedTodayPages = Set<int>.from(todayProgress.uniquePagesRead)..add(pageNumber);

          if (updatedTodayPages.length > todayProgress.uniquePagesRead.length) {
            // Update today's stats (for UI display) but don't increment global count
            khatma.dailyProgress[todayKey] = todayProgress.copyWith(
              uniquePagesRead: updatedTodayPages,
              // pagesRead stays the same - doesn't count toward total
            );
            anyUpdated = true;
          }
          continue; // Don't count this page again
        }

        // This is a NEW page (never read before across entire Khatma)
        final updatedGlobalPages = Set<int>.from(khatma.allPagesRead)..add(pageNumber);
        final updatedTodayPages = Set<int>.from(todayProgress.uniquePagesRead)..add(pageNumber);

        // Calculate how many NEW pages were read today (pages not in global set before today)
        int newPagesReadToday = 0;
        for (var page in updatedTodayPages) {
          // Check if this page was read before today
          bool wasReadBefore = false;
          for (var entry in khatma.dailyProgress.entries) {
            if (entry.key != todayKey && entry.value.uniquePagesRead.contains(page)) {
              wasReadBefore = true;
              break;
            }
          }
          if (!wasReadBefore) {
            newPagesReadToday++;
          }
        }

        final isCompleted = khatma.mode == KhatmaMode.tracking
            ? false  // Tracking mode never marks as completed
            : newPagesReadToday >= todayProgress.targetPages;

        // Update both global and daily tracking
        khatma.dailyProgress[todayKey] = todayProgress.copyWith(
          pagesRead: newPagesReadToday,
          isCompleted: isCompleted,
          uniquePagesRead: updatedTodayPages,
        );

        // CRITICAL: Update global allPagesRead using copyWith
        final updatedKhatma = khatma.copyWith(allPagesRead: updatedGlobalPages);
        final index = _khatmas.indexOf(khatma);

        // Check if khatma was just completed
        final wasCompleted = khatma.isCompleted;
        _khatmas[index] = updatedKhatma;
        final nowCompleted = updatedKhatma.isCompleted;

        // Log analytics for completion
        if (!wasCompleted && nowCompleted) {
          final totalDays = now.difference(khatma.createdAt).inDays + 1;
          AnalyticsService.logKhatmaCompleted(khatma.name, totalDays);
        }

        // Log analytics for progress update
        if (!nowCompleted) {
          AnalyticsService.logKhatmaUpdated(khatma.name, updatedKhatma.pagesRead);
        }

        anyUpdated = true;
      }
    }

    if (anyUpdated) {
      await saveKhatmas();
    }
  }

  // Get active khatmas for a specific page
  List<Khatma> getKhatmasForPage(int pageNumber) {
    return _khatmas.where((k) {
      if (k.isCompleted) return false;
      return pageNumber >= k.startPage && pageNumber <= k.endPage;
    }).toList();
  }

  // Get today's reading goal for a khatma
  ({int startPage, int endPage, int pagesRead, int targetPages})? getTodayGoal(String khatmaId) {
    // Safe null handling - return null if khatma doesn't exist instead of throwing
    final khatma = _khatmas.where((k) => k.id == khatmaId).firstOrNull;
    if (khatma == null) {
      if (kDebugMode) debugPrint('⚠️ Khatma not found: $khatmaId');
      return null;
    }

    if (khatma.isCompleted) return null;

    final todayKey = DateUtilsKhatma.getTodayKey();

    var todayProgress = khatma.dailyProgress[todayKey];

    if (todayProgress == null) {
      final pagesPerDay = khatma.getCurrentPagesPerDay();
      final startPage = khatma.startPage + khatma.pagesRead;
      final endPage = (startPage + pagesPerDay - 1).clamp(startPage, khatma.endPage);

      return (
        startPage: startPage,
        endPage: endPage,
        pagesRead: 0,
        targetPages: pagesPerDay,
      );
    }

    return (
      startPage: todayProgress.startPage,
      endPage: todayProgress.endPage,
      pagesRead: todayProgress.pagesRead,
      targetPages: todayProgress.targetPages,
    );
  }

  void dispose() {
    _saveDebounceTimer?.cancel();
    khatmasNotifier.dispose();
  }
}
