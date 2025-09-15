// lib/widgets/download_manager_sheet.dart

import 'package:flutter/material.dart';
import '../audio_download_manager.dart';
import '../constants/settings_data.dart';
import '../constants/quran_data.dart';
import '../constants/surah_names.dart';
import '../constants/juz_mappings.dart';
import '../widgets/loading_states.dart';

/// Bottom sheet for managing audio downloads (surahs, juz, and existing downloads)
class DownloadManagerBottomSheet extends StatefulWidget {
  final AudioDownloadManager downloadManager;
  final String selectedReciter;
  final Map<String, ReciterInfo> reciters;

  const DownloadManagerBottomSheet({
    super.key,
    required this.downloadManager,
    required this.selectedReciter,
    required this.reciters,
  });

  @override
  State<DownloadManagerBottomSheet> createState() => _DownloadManagerBottomSheetState();
}

class _DownloadManagerBottomSheetState extends State<DownloadManagerBottomSheet>
    with TickerProviderStateMixin, LoadingStateMixin {
  late TabController _tabController;
  late Stream<List<DownloadTask>> _downloadsStream;

  final List<String> _tabTitles = ['السور', 'الأجزاء', 'التحميلات'];
  final List<IconData> _tabIcons = [Icons.book, Icons.menu_book, Icons.download];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _downloadsStream = Stream.periodic(const Duration(seconds: 1))
        .map((_) => widget.downloadManager.getAllDownloadTasks())
        .asBroadcastStream();
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          // Tab index changed - update UI if needed
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إدارة التحميلات',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: 'Amiri',
                          ),
                        ),
                        Text(
                          'تحميل السور والأجزاء للاستماع دون اتصال',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: List.generate(_tabTitles.length, (index) =>
                    _buildTab(_tabTitles[index], index, _tabIcons[index])),
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Theme.of(context).colorScheme.onPrimary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelStyle: const TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSurahsList(),
                  _buildJuzsList(),
                  _buildDownloadsManagerList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index, IconData icon) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 114, // Number of surahs
      itemBuilder: (context, index) {
        final surahNumber = index + 1;
        final surahName = SurahNames.getArabicName(surahNumber);
        final ayahCount = QuranData.getAyahCountForSurah(surahNumber);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                surahNumber.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              surahName,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '$ayahCount آية',
              style: TextStyle(
                fontFamily: 'Amiri',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.download,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => _downloadSurah(surahNumber),
            ),
            onTap: () => _downloadSurah(surahNumber),
          ),
        );
      },
    );
  }

  Widget _buildJuzsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 30, // Number of juz
      itemBuilder: (context, index) {
        final juzNumber = index + 1;
        final startingPage = JuzMappings.juzToPage[juzNumber] ?? 1;

        // Calculate approximate ayah count for the juz (rough estimation)
        final nextJuzPage = juzNumber < 30 ? JuzMappings.juzToPage[juzNumber + 1] ?? 604 : 604;
        final approximatePages = nextJuzPage - startingPage;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(
                juzNumber.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'الجزء $juzNumber',
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'يبدأ من الصفحة $startingPage • حوالي $approximatePages صفحة',
              style: TextStyle(
                fontFamily: 'Amiri',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.download,
                color: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: () => _downloadJuz(juzNumber),
            ),
            onTap: () => _downloadJuz(juzNumber),
          ),
        );
      },
    );
  }

  Widget _buildDownloadsManagerList() {
    return StreamBuilder<List<DownloadTask>>(
      stream: _downloadsStream, // Real-time updates
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final downloads = snapshot.data ?? widget.downloadManager.getAllDownloadTasks();

        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد تحميلات',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'استخدم علامات التبويب أعلاه لتحميل السور أو الأجزاء',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: downloads.length,
          itemBuilder: (context, index) {
            final download = downloads[index];
            final isJuz = download.type == DownloadType.juz;

            // Parse the number from the download ID
            int identifier = download.number; // Use the number field directly
            final title = isJuz ? 'الجزء $identifier' : SurahNames.getArabicName(identifier);

            // Get reciter name - try multiple ways to find the reciter
            ReciterInfo? reciterInfo;

            // First try to find by apiCode
            try {
              reciterInfo = widget.reciters.values.firstWhere(
                (r) => r.apiCode == download.reciter,
              );
            } catch (e) {
              // If not found by apiCode, try by englishName
              try {
                reciterInfo = widget.reciters.values.firstWhere(
                  (r) => r.englishName == download.reciter,
                );
              } catch (e) {
                // Still not found, use default
                reciterInfo = ReciterInfo('القارئ المحدد', download.reciter);
              }
            }

            final reciterName = reciterInfo.englishName;

            // Create detailed subtitle
            final totalAyahs = download.totalAyahs;
            final completedAyahs = download.downloadedAyahs;
            final progressText = completedAyahs == totalAyahs && download.status == DownloadStatus.completed
                ? 'مكتمل • $totalAyahs آية'
                : 'جاري التحميل • $completedAyahs/$totalAyahs آية';

            final subtitle = '$reciterName • $progressText';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: completedAyahs == totalAyahs
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.tertiary,
                  child: completedAyahs == totalAyahs
                      ? Icon(
                          isJuz ? Icons.menu_book : Icons.book,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      : CircularProgressIndicator(
                          value: totalAyahs > 0 ? completedAyahs / totalAyahs : 0,
                          strokeWidth: 2,
                          backgroundColor: Theme.of(context).colorScheme.onTertiary.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onTertiary,
                          ),
                        ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _deleteDownload(download),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method for real-time updates

  Future<void> _downloadSurah(int surahNumber) async {
    // Check for duplicate downloads
    final existingDownloads = widget.downloadManager.getAllDownloadTasks();
    final isDuplicate = existingDownloads.any((download) =>
        download.type == DownloadType.surah &&
        download.id == surahNumber.toString() &&
        download.reciter == widget.selectedReciter);

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${SurahNames.getArabicName(surahNumber)} تم تحميلها مسبقاً أو جاري تحميلها',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
      return;
    }

    try {
      await widget.downloadManager.downloadSurah(
        surahNumber,
        widget.selectedReciter,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'بدأ تحميل ${SurahNames.getArabicName(surahNumber)}',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تحميل السورة: $e',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadJuz(int juzNumber) async {
    // Check for duplicate downloads
    final existingDownloads = widget.downloadManager.getAllDownloadTasks();
    final isDuplicate = existingDownloads.any((download) =>
        download.type == DownloadType.juz &&
        download.id == juzNumber.toString() &&
        download.reciter == widget.selectedReciter);

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'الجزء $juzNumber مُحمَّل مسبقاً أو قيد التحميل',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
      return;
    }

    try {
      await widget.downloadManager.downloadJuz(
        juzNumber,
        widget.selectedReciter,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'بدأ تحميل الجزء $juzNumber',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تحميل الجزء: $e',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteDownload(DownloadTask download) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'حذف التحميل',
            style: TextStyle(
              fontFamily: 'Amiri',
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: Text(
            'هل تريد حذف هذا التحميل؟ سيتم حذف جميع الملفات الصوتية المرتبطة.',
            style: TextStyle(
              fontFamily: 'Amiri',
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text(
                'حذف',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await widget.downloadManager.deleteDownload(download.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'تم حذف التحميل بنجاح',
                style: TextStyle(fontFamily: 'Amiri'),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطأ في حذف التحميل: $e',
                style: const TextStyle(fontFamily: 'Amiri'),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

