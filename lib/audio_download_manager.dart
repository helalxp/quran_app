// lib/audio_download_manager.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/api_constants.dart';
import 'constants/quran_data.dart';
import 'audio_cache_manager.dart';

/// Semaphore for controlling concurrent operations
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.addLast(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Download status for tracking progress
enum DownloadStatus { 
  notStarted,
  inProgress, 
  completed, 
  paused,
  failed,
  cancelled 
}

/// Download task for surah or juz
class DownloadTask {
  final String id;
  final DownloadType type;
  final int number; // Surah number or Juz number
  final String reciter;
  final List<AyahInfo> ayahs;
  
  DownloadStatus status;
  int totalAyahs;
  int downloadedAyahs;
  int failedAyahs;
  double progress;
  String? error;
  DateTime? startTime;
  DateTime? completionTime;
  
  DownloadTask({
    required this.id,
    required this.type,
    required this.number,
    required this.reciter,
    required this.ayahs,
    this.status = DownloadStatus.notStarted,
    this.totalAyahs = 0,
    this.downloadedAyahs = 0,
    this.failedAyahs = 0,
    this.progress = 0.0,
    this.error,
    this.startTime,
    this.completionTime,
  }) {
    totalAyahs = ayahs.length;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'number': number,
    'reciter': reciter,
    'status': status.name,
    'totalAyahs': totalAyahs,
    'downloadedAyahs': downloadedAyahs,
    'failedAyahs': failedAyahs,
    'progress': progress,
    'error': error,
    'startTime': startTime?.millisecondsSinceEpoch,
    'completionTime': completionTime?.millisecondsSinceEpoch,
    'ayahs': ayahs.map((a) => a.toJson()).toList(),
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'],
    type: DownloadType.values.firstWhere((e) => e.name == json['type']),
    number: json['number'],
    reciter: json['reciter'],
    ayahs: (json['ayahs'] as List).map((a) => AyahInfo.fromJson(a)).toList(),
    status: DownloadStatus.values.firstWhere((e) => e.name == json['status']),
    totalAyahs: json['totalAyahs'],
    downloadedAyahs: json['downloadedAyahs'],
    failedAyahs: json['failedAyahs'],
    progress: json['progress'],
    error: json['error'],
    startTime: json['startTime'] != null ? DateTime.fromMillisecondsSinceEpoch(json['startTime']) : null,
    completionTime: json['completionTime'] != null ? DateTime.fromMillisecondsSinceEpoch(json['completionTime']) : null,
  );
}

/// Basic ayah info for download tasks
class AyahInfo {
  final int surah;
  final int ayah;
  
  const AyahInfo({required this.surah, required this.ayah});
  
  Map<String, dynamic> toJson() => {'surah': surah, 'ayah': ayah};
  factory AyahInfo.fromJson(Map<String, dynamic> json) => AyahInfo(
    surah: json['surah'],
    ayah: json['ayah'],
  );
}

enum DownloadType { surah, juz }

/// Comprehensive download manager for Quran audio
class AudioDownloadManager with ChangeNotifier {
  static final AudioDownloadManager _instance = AudioDownloadManager._internal();
  factory AudioDownloadManager() => _instance;
  AudioDownloadManager._internal();

  // Dependencies
  final AudioCacheManager _cacheManager = AudioCacheManager();
  SharedPreferences? _prefs;
  
  // Download state
  final Map<String, DownloadTask> _downloadTasks = {};
  final Map<String, StreamController<DownloadTask>> _progressControllers = {};
  bool _initialized = false;
  
  // Concurrent download control - ultra-fast optimizations
  static const int maxConcurrentDownloads = 10;
  static const int maxConcurrentAyahs = 20; // Ultra-fast concurrent ayah downloads
  int _activeDownloads = 0;
  final List<String> _downloadQueue = [];

  /// Initialize the download manager
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _cacheManager.initialize();
      await _loadDownloadTasks();
      await _resumeIncompleteDownloads();
      _initialized = true;
      debugPrint('✅ AudioDownloadManager initialized');
    } catch (e) {
      debugPrint('❌ Error initializing AudioDownloadManager: $e');
      rethrow;
    }
  }

  /// Load saved download tasks from storage
  Future<void> _loadDownloadTasks() async {
    try {
      final tasksJson = _prefs?.getString('download_tasks');
      if (tasksJson != null) {
        final Map<String, dynamic> tasksData = jsonDecode(tasksJson);
        _downloadTasks.clear();
        
        for (final entry in tasksData.entries) {
          try {
            final task = DownloadTask.fromJson(entry.value);
            _downloadTasks[entry.key] = task;
          } catch (e) {
            debugPrint('⚠️ Invalid download task for ${entry.key}: $e');
          }
        }
        debugPrint('📋 Loaded ${_downloadTasks.length} download tasks');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading download tasks: $e');
      _downloadTasks.clear();
    }
  }

  /// Save download tasks to storage
  Future<void> _saveDownloadTasks() async {
    try {
      final tasksData = <String, dynamic>{};
      for (final entry in _downloadTasks.entries) {
        tasksData[entry.key] = entry.value.toJson();
      }
      await _prefs?.setString('download_tasks', jsonEncode(tasksData));
    } catch (e) {
      debugPrint('⚠️ Error saving download tasks: $e');
    }
  }

  /// Resume incomplete downloads on startup
  Future<void> _resumeIncompleteDownloads() async {
    final incompleteDownloads = _downloadTasks.values
        .where((task) => task.status == DownloadStatus.inProgress || task.status == DownloadStatus.paused)
        .toList();

    for (final task in incompleteDownloads) {
      // Reset to not started for resume
      task.status = DownloadStatus.notStarted;
      _queueDownload(task.id);
    }

    if (incompleteDownloads.isNotEmpty) {
      debugPrint('🔄 Resuming ${incompleteDownloads.length} incomplete downloads');
    }
  }

  /// Create download task for a complete surah and wait for completion
  Future<String> downloadSurah(int surahNumber, String reciter) async {
    if (!_initialized) await initialize();

    final taskId = 'surah_${surahNumber}_$reciter';

    // Check if already exists
    if (_downloadTasks.containsKey(taskId)) {
      final existing = _downloadTasks[taskId]!;
      if (existing.status == DownloadStatus.completed) {
        debugPrint('📚 Surah $surahNumber already downloaded for $reciter');
        return taskId;
      }
    }

    // Get ayah count for surah from QuranData
    final ayahCount = QuranData.getAyahCountForSurah(surahNumber);
    final ayahs = List.generate(ayahCount, (index) => AyahInfo(surah: surahNumber, ayah: index + 1));

    final task = DownloadTask(
      id: taskId,
      type: DownloadType.surah,
      number: surahNumber,
      reciter: reciter,
      ayahs: ayahs,
    );

    _downloadTasks[taskId] = task;
    await _saveDownloadTasks();

    debugPrint('📚 Created download task for Surah $surahNumber ($ayahCount ayahs) - $reciter');

    _queueDownload(taskId);

    // Wait for download to complete and return taskId or throw error
    return await _waitForTaskCompletion(taskId);
  }

  /// Create download task for a complete juz and wait for completion
  Future<String> downloadJuz(int juzNumber, String reciter) async {
    if (!_initialized) await initialize();

    final taskId = 'juz_${juzNumber}_$reciter';

    // Check if already exists
    if (_downloadTasks.containsKey(taskId)) {
      final existing = _downloadTasks[taskId]!;
      if (existing.status == DownloadStatus.completed) {
        debugPrint('📖 Juz $juzNumber already downloaded for $reciter');
        return taskId;
      }
    }

    // Get ayahs for juz from QuranData
    final ayahs = QuranData.getAyahsForJuz(juzNumber);

    final task = DownloadTask(
      id: taskId,
      type: DownloadType.juz,
      number: juzNumber,
      reciter: reciter,
      ayahs: ayahs,
    );

    _downloadTasks[taskId] = task;
    await _saveDownloadTasks();

    debugPrint('📖 Created download task for Juz $juzNumber (${ayahs.length} ayahs) - $reciter');

    _queueDownload(taskId);

    // Wait for download to complete and return taskId or throw error
    return await _waitForTaskCompletion(taskId);
  }

  /// Queue download for processing
  void _queueDownload(String taskId) {
    if (!_downloadQueue.contains(taskId)) {
      _downloadQueue.add(taskId);
      _processDownloadQueue();
    }
  }

  /// Wait for a task to complete and handle errors
  Future<String> _waitForTaskCompletion(String taskId) async {
    final task = _downloadTasks[taskId];
    if (task == null) {
      throw Exception('Task not found: $taskId');
    }

    // If already completed, return immediately
    if (task.status == DownloadStatus.completed) {
      return taskId;
    }

    // Wait for task to complete by polling
    while (task.status == DownloadStatus.notStarted || task.status == DownloadStatus.inProgress) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Check final status
    if (task.status == DownloadStatus.failed) {
      throw Exception(task.error ?? 'Download failed');
    } else if (task.status == DownloadStatus.cancelled) {
      throw Exception('Download cancelled');
    } else if (task.status == DownloadStatus.completed) {
      return taskId;
    } else {
      throw Exception('Download completed with unknown status: ${task.status}');
    }
  }

  /// Get all completed download tasks
  List<DownloadTask> getCompletedDownloads() {
    return _downloadTasks.values.where((task) => task.status == DownloadStatus.completed).toList();
  }

  /// Process download queue with concurrency control
  Future<void> _processDownloadQueue() async {
    while (_downloadQueue.isNotEmpty && _activeDownloads < maxConcurrentDownloads) {
      final taskId = _downloadQueue.removeAt(0);
      final task = _downloadTasks[taskId];
      
      if (task == null) continue;
      
      _activeDownloads++;
      _executeDownload(task).whenComplete(() => _activeDownloads--);
    }
  }

  /// Execute download task
  Future<void> _executeDownload(DownloadTask task) async {
    try {
      task.status = DownloadStatus.inProgress;
      task.startTime = DateTime.now();
      task.error = null;
      _notifyTaskUpdate(task);

      // Handle both Arabic names and API codes for reciter configuration
      ReciterConfig? config = ApiConstants.reciterConfigs[task.reciter] ??
                              ApiConstants.getReciterConfigByApiCode(task.reciter);
      if (config == null) {
        throw Exception('Reciter configuration not found for ${task.reciter}');
      }

      debugPrint('📥 Starting download: ${task.type.name} ${task.number} (${task.totalAyahs} ayahs)');

      // Process downloads in concurrent batches for speed
      final results = await _downloadAyahsConcurrently(task, config);
      final successful = results['successful'] as int;
      final failed = results['failed'] as int;

      // Finalize task
      if (task.status != DownloadStatus.cancelled) {
        if (failed == 0) {
          task.status = DownloadStatus.completed;
          debugPrint('✅ Download completed: ${task.type.name} ${task.number} ($successful/${task.totalAyahs} ayahs)');
        } else if (successful > 0) {
          task.status = DownloadStatus.completed;
          debugPrint('⚠️ Download completed with errors: ${task.type.name} ${task.number} ($successful/${task.totalAyahs} successful, $failed failed)');
        } else {
          task.status = DownloadStatus.failed;
          task.error = 'All downloads failed';
          debugPrint('❌ Download failed: ${task.type.name} ${task.number}');
        }
        task.completionTime = DateTime.now();
      }

    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      debugPrint('❌ Download error for ${task.type.name} ${task.number}: $e');

      // Stop download on critical errors like network issues
      if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
        debugPrint('🚫 Network error detected, stopping download to prevent app freeze');
        return;
      }
    } finally {
      await _saveDownloadTasks();
      _notifyTaskUpdate(task);
      
      // Process next in queue
      Future.delayed(const Duration(milliseconds: 500), () => _processDownloadQueue());
    }
  }

  /// Cancel download task
  Future<void> cancelDownload(String taskId) async {
    final task = _downloadTasks[taskId];
    if (task != null && task.status == DownloadStatus.inProgress) {
      task.status = DownloadStatus.cancelled;
      _notifyTaskUpdate(task);
      await _saveDownloadTasks();
      debugPrint('🚫 Cancelled download: ${task.type.name} ${task.number}');
    }
  }

  /// Pause download task
  Future<void> pauseDownload(String taskId) async {
    final task = _downloadTasks[taskId];
    if (task != null && task.status == DownloadStatus.inProgress) {
      task.status = DownloadStatus.paused;
      _notifyTaskUpdate(task);
      await _saveDownloadTasks();
      debugPrint('⏸️ Paused download: ${task.type.name} ${task.number}');
    }
  }

  /// Resume download task
  Future<void> resumeDownload(String taskId) async {
    final task = _downloadTasks[taskId];
    if (task != null && task.status == DownloadStatus.paused) {
      task.status = DownloadStatus.notStarted;
      _queueDownload(taskId);
      debugPrint('▶️ Resumed download: ${task.type.name} ${task.number}');
    }
  }

  /// Delete download task and cached files
  Future<void> deleteDownload(String taskId) async {
    final task = _downloadTasks[taskId];
    if (task == null) return;

    // Cancel if in progress
    if (task.status == DownloadStatus.inProgress) {
      await cancelDownload(taskId);
      await Future.delayed(const Duration(seconds: 1)); // Wait for cancellation
    }

    // Delete cached files
    for (final ayah in task.ayahs) {
      await _cacheManager.removeCachedAyah(task.reciter, ayah.surah, ayah.ayah);
    }

    _downloadTasks.remove(taskId);
    _progressControllers[taskId]?.close();
    _progressControllers.remove(taskId);
    await _saveDownloadTasks();

    debugPrint('🗑️ Deleted download: ${task.type.name} ${task.number} - ${task.reciter}');
    notifyListeners();
  }

  /// Get download task by ID
  DownloadTask? getDownloadTask(String taskId) => _downloadTasks[taskId];

  /// Get all download tasks
  List<DownloadTask> getAllDownloadTasks() => _downloadTasks.values.toList();

  /// Get download tasks by status
  List<DownloadTask> getDownloadTasksByStatus(DownloadStatus status) {
    return _downloadTasks.values.where((task) => task.status == status).toList();
  }

  /// Check if surah/juz is downloaded
  bool isDownloaded(DownloadType type, int number, String reciter) {
    final taskId = '${type.name}_${number}_$reciter';
    final task = _downloadTasks[taskId];
    return task?.status == DownloadStatus.completed;
  }

  /// Get download progress stream for a task
  Stream<DownloadTask> getDownloadProgress(String taskId) {
    _progressControllers[taskId] ??= StreamController<DownloadTask>.broadcast();
    return _progressControllers[taskId]!.stream;
  }

  /// Notify task update to listeners
  void _notifyTaskUpdate(DownloadTask task) {
    _progressControllers[task.id]?.add(task);
    notifyListeners();
  }

  /// Download ayahs with maximum speed using streaming concurrency
  Future<Map<String, int>> _downloadAyahsConcurrently(DownloadTask task, ReciterConfig config) async {
    final completer = Completer<Map<String, int>>();
    final semaphore = Semaphore(maxConcurrentAyahs);

    int successful = 0;
    int failed = 0;
    int completed = 0;
    final totalCount = task.ayahs.length;

    // Process all downloads concurrently with atomic counters
    for (final ayahInfo in task.ayahs) {
      semaphore.acquire().then((_) async {
        try {
          await _downloadSingleAyah(task, ayahInfo, config);
          successful++;
        } catch (e) {
          failed++;
        } finally {
          semaphore.release();
          completed++;

          // Atomic progress update
          task.downloadedAyahs = successful;
          task.failedAyahs = failed;
          task.progress = (completed / totalCount) * 100;
          _notifyTaskUpdate(task);

          // Complete when all downloads finish
          if (completed == totalCount && !completer.isCompleted) {
            completer.complete({'successful': successful, 'failed': failed});
          }
        }
      });
    }

    return completer.future;
  }

  /// Download a single ayah with ultra-fast optimizations
  Future<void> _downloadSingleAyah(DownloadTask task, AyahInfo ayahInfo, ReciterConfig config) async {
    // Ultra-fast cache check - exit immediately if already cached
    if (_cacheManager.isAyahCached(task.reciter, ayahInfo.surah, ayahInfo.ayah)) {
      return; // No debug print for speed
    }

    // Prepare URLs upfront for faster switching
    final primaryUrl = config.getAyahUrl(ayahInfo.surah, ayahInfo.ayah);
    final fallbackUrl = config.getFallbackAyahUrl(ayahInfo.surah, ayahInfo.ayah);

    // Try primary URL with aggressive timeout
    String? result = await _cacheManager.cacheAyahAudio(
      reciter: task.reciter,
      surah: ayahInfo.surah,
      ayah: ayahInfo.ayah,
      url: primaryUrl,
    );

    // Fast fallback if primary fails and fallback exists
    if (result == null && fallbackUrl != null) {
      result = await _cacheManager.cacheAyahAudio(
        reciter: task.reciter,
        surah: ayahInfo.surah,
        ayah: ayahInfo.ayah,
        url: fallbackUrl,
      );
    }

    // Throw error only if both primary and fallback fail
    if (result == null) {
      throw Exception('Failed to download ${ayahInfo.surah}:${ayahInfo.ayah}');
    }
  }

  /// Get download statistics
  Map<String, dynamic> getDownloadStats() {
    final completed = _downloadTasks.values.where((task) => task.status == DownloadStatus.completed).length;
    final inProgress = _downloadTasks.values.where((task) => task.status == DownloadStatus.inProgress).length;
    final failed = _downloadTasks.values.where((task) => task.status == DownloadStatus.failed).length;

    return {
      'totalTasks': _downloadTasks.length,
      'completed': completed,
      'inProgress': inProgress,
      'failed': failed,
      'queueSize': _downloadQueue.length,
    };
  }

  /// Dispose resources
  @override
  Future<void> dispose() async {
    super.dispose();
    for (final controller in _progressControllers.values) {
      await controller.close();
    }
    _progressControllers.clear();
    await _saveDownloadTasks();
    debugPrint('✅ AudioDownloadManager disposed');
  }
}