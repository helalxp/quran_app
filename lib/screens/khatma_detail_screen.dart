import 'package:flutter/material.dart';
import '../models/khatma.dart';
import '../utils/haptic_utils.dart';
import '../utils/date_utils_khatma.dart';
import '../viewer_screen.dart';
import '../services/khatma_manager.dart';

class KhatmaDetailScreen extends StatefulWidget {
  final Khatma khatma;
  final Function(Khatma) onKhatmaUpdated;

  const KhatmaDetailScreen({
    super.key,
    required this.khatma,
    required this.onKhatmaUpdated,
  });

  @override
  State<KhatmaDetailScreen> createState() => _KhatmaDetailScreenState();
}

class _KhatmaDetailScreenState extends State<KhatmaDetailScreen> {
  late Khatma _khatma;
  final KhatmaManager _khatmaManager = KhatmaManager();

  @override
  void initState() {
    super.initState();
    _khatma = widget.khatma;
    // Listen to khatma changes
    _khatmaManager.khatmasNotifier.addListener(_onKhatmasUpdated);
    // Listen for errors
    _khatmaManager.errorNotifier.addListener(_onError);
  }

  @override
  void dispose() {
    _khatmaManager.khatmasNotifier.removeListener(_onKhatmasUpdated);
    _khatmaManager.errorNotifier.removeListener(_onError);
    super.dispose();
  }

  void _onKhatmasUpdated() {
    // Find the updated Khatma with matching ID
    final updatedKhatmas = _khatmaManager.khatmasNotifier.value;
    final updatedKhatma = updatedKhatmas.firstWhere(
      (k) => k.id == _khatma.id,
      orElse: () => _khatma,
    );

    if (mounted && updatedKhatma.pagesRead != _khatma.pagesRead) {
      setState(() {
        _khatma = updatedKhatma;
      });
    }
  }

  void _onError() {
    final error = _khatmaManager.errorNotifier.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'حسناً',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            HapticUtils.navigation();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_outlined),
        ),
        title: Text(
          _khatma.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Uthmanic',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress header
          _buildProgressHeader(),

          // Daily cards list
          Expanded(
            child: _buildDailyCardsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    final progress = _khatma.pagesRead / _khatma.totalPages;
    final percentage = (progress * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${_khatma.pagesRead} / ${_khatma.totalPages}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mode info
          _buildModeInfo(),
        ],
      ),
    );
  }

  Widget _buildModeInfo() {
    String title = '';
    String subtitle = '';

    switch (_khatma.mode) {
      case KhatmaMode.endDate:
        if (_khatma.endDate != null) {
          final days = _khatma.endDate!.difference(DateTime.now()).inDays;
          title = 'باقي $days يوم';
          subtitle = '${_khatma.getCurrentPagesPerDay()} صفحة/يوم';
        }
        break;
      case KhatmaMode.pagesPerDay:
        final endDate = _khatma.getRecalculatedEndDate();
        if (endDate != null) {
          final days = endDate.difference(DateTime.now()).inDays;
          title = '${_khatma.pagesPerDay} صفحة/يوم';
          subtitle = 'الانتهاء بعد $days يوم';
        }
        break;
      case KhatmaMode.tracking:
        title = 'متابعة فقط';
        subtitle = 'بدون أهداف محددة';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Uthmanic',
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCardsList() {
    if (_khatma.isCompleted) {
      return _buildCompletedView();
    }

    // Generate all day cards (today + future days + past days)
    final allCards = _generateAllDayCards();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: allCards,
    );
  }

  List<Widget> _generateAllDayCards() {
    final List<Widget> cards = [];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Calculate total days needed and generate future cards
    if (_khatma.mode != KhatmaMode.tracking) {
      int totalDaysNeeded;
      if (_khatma.mode == KhatmaMode.endDate && _khatma.endDate != null) {
        totalDaysNeeded = _khatma.endDate!.difference(todayDate).inDays + 1;
      } else if (_khatma.mode == KhatmaMode.pagesPerDay && _khatma.pagesPerDay != null) {
        totalDaysNeeded = (_khatma.pagesRemaining / _khatma.pagesPerDay!).ceil();
      } else {
        totalDaysNeeded = 0;
      }

      // Generate future day cards (upcoming readings)
      if (totalDaysNeeded > 0) {
        cards.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'الأيام القادمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Uthmanic',
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
          ),
        );

        // Start from pages read in PAST days only (not including today)
        // This prevents double-counting today's pages
        final todayKey = DateUtilsKhatma.getTodayKey();
        int cumulativePagesRead = 0;

        // Sum up progress from all past days (before today)
        for (var entry in _khatma.dailyProgress.entries) {
          if (entry.key != todayKey) {
            final entryDate = DateTime.tryParse(entry.key);
            if (entryDate != null && entryDate.isBefore(todayDate)) {
              cumulativePagesRead += entry.value.pagesRead;
            }
          }
        }

        for (int i = 0; i < totalDaysNeeded; i++) {
          final date = todayDate.add(Duration(days: i));
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final isToday = i == 0;

          final existingProgress = _khatma.dailyProgress[dateKey];

          // Calculate how many pages remain to be read
          final remainingPagesToRead = _khatma.totalPages - cumulativePagesRead;

          // Stop generating cards if khatma is completed
          if (remainingPagesToRead <= 0) break;

          // Recalculate pages per day based on current progress and remaining days
          final int pagesPerDayForThisDay;
          if (_khatma.mode == KhatmaMode.endDate && _khatma.endDate != null) {
            // Recalculate based on remaining pages and remaining days
            final remainingDays = _khatma.endDate!.difference(date).inDays + 1;
            pagesPerDayForThisDay = remainingDays > 0 ? (remainingPagesToRead / remainingDays).ceil() : remainingPagesToRead;
          } else if (_khatma.mode == KhatmaMode.pagesPerDay) {
            // Fixed pages per day, but cap at remaining pages
            pagesPerDayForThisDay = (_khatma.pagesPerDay ?? 0).clamp(0, remainingPagesToRead);
          } else {
            pagesPerDayForThisDay = 0;
          }

          // Calculate start and end pages for this day's reading
          final startPage = _khatma.startPage + cumulativePagesRead;
          final endPage = (startPage + pagesPerDayForThisDay - 1).clamp(startPage, _khatma.endPage);

          // Calculate next unread page for today
          int navigationPage = existingProgress?.startPage ?? startPage;
          if (isToday && existingProgress != null && existingProgress.uniquePagesRead.isNotEmpty) {
            // Find first unread page in today's range
            for (int page = existingProgress.startPage; page <= existingProgress.endPage; page++) {
              if (!existingProgress.uniquePagesRead.contains(page)) {
                navigationPage = page;
                break;
              }
            }
            // If all pages in range are read, go to the next page after the range
            if (existingProgress.uniquePagesRead.length >= (existingProgress.endPage - existingProgress.startPage + 1)) {
              navigationPage = existingProgress.endPage + 1;
            }
          }

          cards.add(
            _DailyProgressCard(
              date: date,
              isToday: isToday,
              isFuture: !isToday,
              startPage: existingProgress?.startPage ?? startPage,
              endPage: existingProgress?.endPage ?? endPage,
              targetPages: existingProgress?.targetPages ?? pagesPerDayForThisDay,
              pagesRead: existingProgress?.pagesRead ?? 0,
              uniquePagesReadCount: existingProgress?.uniquePagesRead.length ?? 0,
              isCompleted: existingProgress?.isCompleted ?? false,
              onTap: isToday ? () {
                HapticUtils.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewerScreen(initialPage: navigationPage),
                  ),
                );
              } : null,
              onToggleComplete: null,
            ),
          );
          cards.add(const SizedBox(height: 12));

          // Update cumulative count for projecting future days
          if (isToday && existingProgress != null && existingProgress.pagesRead > 0) {
            // Today: use actual pages read if available
            cumulativePagesRead += existingProgress.pagesRead;
          } else {
            // Today (not started yet) or future days: project target will be met
            cumulativePagesRead += pagesPerDayForThisDay;
          }
        }
      }
    } else {
      // Tracking mode - just show today
      final todayKey = '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';
      final todayProgress = _khatma.dailyProgress[todayKey];
      final startPage = _khatma.startPage + _khatma.pagesRead;

      cards.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'اليوم',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Uthmanic',
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
      );

      // Calculate next unread page for tracking mode
      int navigationPage = todayProgress?.startPage ?? startPage;
      if (todayProgress != null && todayProgress.uniquePagesRead.isNotEmpty) {
        // Find first unread page from start of khatma
        for (int page = _khatma.startPage; page <= _khatma.endPage; page++) {
          if (!_khatma.allPagesRead.contains(page)) {
            navigationPage = page;
            break;
          }
        }
      }

      cards.add(
        _DailyProgressCard(
          date: todayDate,
          isToday: true,
          isFuture: false,
          startPage: todayProgress?.startPage ?? startPage,
          endPage: todayProgress?.endPage ?? _khatma.endPage,
          targetPages: 0, // No target in tracking mode
          pagesRead: todayProgress?.pagesRead ?? 0,
          uniquePagesReadCount: todayProgress?.uniquePagesRead.length ?? 0,
          isCompleted: false,
          onTap: () {
            HapticUtils.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewerScreen(initialPage: navigationPage),
              ),
            );
          },
          onToggleComplete: null,
        ),
      );
      cards.add(const SizedBox(height: 16));
    }

    // Add history section (completed past days)
    final historyCards = _buildHistoryCards();
    if (historyCards.isNotEmpty) {
      cards.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'مكتمل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Uthmanic',
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
      );
      cards.addAll(historyCards);
    }

    return cards;
  }

  List<Widget> _buildHistoryCards() {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayKey = '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';

    final sortedDates = _khatma.dailyProgress.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    return sortedDates.where((dateKey) {
      // Don't show today in history section
      if (dateKey == todayKey) return false;

      final date = DateTime.parse(dateKey);
      // Only show past days (before today)
      return date.isBefore(todayDate);
    }).map((dateKey) {
      final progress = _khatma.dailyProgress[dateKey]!;
      final date = DateTime.parse(dateKey);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _DailyProgressCard(
          date: date,
          isToday: false,
          isFuture: false,
          startPage: progress.startPage,
          endPage: progress.endPage,
          targetPages: progress.targetPages,
          pagesRead: progress.pagesRead,
          uniquePagesReadCount: progress.uniquePagesRead.length,
          isCompleted: progress.isCompleted,
          onTap: null, // History cards are not tappable
          onToggleComplete: null,
        ),
      );
    }).toList();
  }

  Widget _buildCompletedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '!مبروك',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Uthmanic',
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          const Text(
            'لقد أتممت الختمة',
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Uthmanic',
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    HapticUtils.heavyImpact();
    // Pop back to main screen and signal to open edit mode
    Navigator.pop(context, {'action': 'edit', 'khatma': _khatma});
  }
}

// Daily Progress Card Widget
class _DailyProgressCard extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isFuture;
  final int startPage;
  final int endPage;
  final int targetPages;
  final int pagesRead;
  final int uniquePagesReadCount;
  final bool isCompleted;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  const _DailyProgressCard({
    required this.date,
    required this.isToday,
    this.isFuture = false,
    required this.startPage,
    required this.endPage,
    required this.targetPages,
    required this.pagesRead,
    required this.uniquePagesReadCount,
    required this.isCompleted,
    this.onTap,
    this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    // Use uniquePagesReadCount for progress calculation (all pages read today)
    // but display pagesRead for text (only new pages, not re-reads)
    final progress = targetPages > 0 ? uniquePagesReadCount / targetPages : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: isToday
            ? LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                ],
              )
            : null,
        color: isToday ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: isToday
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Header
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          isToday ? Icons.today : Icons.calendar_today,
                          size: 20,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isToday ? 'اليوم' : _formatDate(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Theme.of(context).colorScheme.primary : null,
                            fontFamily: 'Uthmanic',
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    if (onToggleComplete != null)
                      IconButton(
                        onPressed: onToggleComplete,
                        icon: Icon(
                          isCompleted ? Icons.check_circle : Icons.circle_outlined,
                          color: isCompleted
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Page range with clearer labels
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'نطاق القراءة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            targetPages == 0 ? 'متابعة حرة' : 'الصفحات $startPage - $endPage',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                    if (targetPages > 0) ...[
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'الهدف',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$targetPages صفحة',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Progress bar (only if not future and has target)
                if (!isFuture && targetPages > 0) ...[
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress text - show only NEW pages read (not re-reads)
                  Text(
                    pagesRead > targetPages
                        ? '✓ رائع! قرأت $pagesRead من $targetPages صفحة (${pagesRead - targetPages}+ إضافية)'
                        : isCompleted
                            ? '✓ مكتمل - قرأت $pagesRead صفحة'
                            : 'قرأت $pagesRead من $targetPages صفحة',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: (isCompleted || pagesRead > targetPages) ? FontWeight.bold : FontWeight.normal,
                      color: pagesRead > targetPages
                          ? Colors.amber.shade700
                          : isCompleted
                              ? Colors.green
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ] else if (!isFuture && targetPages == 0) ...[
                  // Tracking mode - show only NEW pages read
                  Text(
                    pagesRead > 0 ? 'قرأت $pagesRead صفحة اليوم' : 'لم تبدأ القراءة بعد',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
