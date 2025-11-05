// lib/universal_search_overlay.dart

import 'package:flutter/material.dart';
import 'models/surah.dart';
import 'models/ayah_marker.dart';
import 'models/quran_ayah.dart';
import 'services/quran_text_service.dart';
import 'utils/arabic_search_utils.dart';
import 'constants/juz_mappings.dart';
import 'utils/animation_utils.dart';

enum UniversalSearchTab { juz, surah, ayah, hizbRub }

class UniversalSearchOverlay extends StatefulWidget {
  final List<Surah> allSurahs;
  final List<AyahMarker> allMarkers;
  final Map<int, int> juzStartPages;
  final Map<String, dynamic> hizbToPages;
  final Map<String, dynamic> rubToPages;
  final int currentPage;
  final Function(Surah) onSurahSelected;
  final Function(int pageNumber) onJuzSelected;
  final Function(Surah surah, int ayahNumber, int pageNumber) onAyahSelected;

  const UniversalSearchOverlay({
    super.key,
    required this.allSurahs,
    required this.allMarkers,
    required this.juzStartPages,
    required this.hizbToPages,
    required this.rubToPages,
    required this.currentPage,
    required this.onSurahSelected,
    required this.onJuzSelected,
    required this.onAyahSelected,
  });

  @override
  State<UniversalSearchOverlay> createState() => _UniversalSearchOverlayState();
}

class _UniversalSearchOverlayState extends State<UniversalSearchOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  String _searchQuery = '';
  UniversalSearchTab _currentTab = UniversalSearchTab.surah;
  List<QuranAyah> _ayahs = [];
  bool _isLoadingAyahs = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadAyahsIfNeeded();

    // Slide-down animation
    _slideController = AnimationController(
      duration: AnimationUtils.normal,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
  }

  Future<void> _loadAyahsIfNeeded() async {
    setState(() {
      _isLoadingAyahs = true;
    });

    try {
      final service = QuranTextService();
      _ayahs = await service.loadAyahs();
    } catch (e) {
      debugPrint('Error loading ayahs: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAyahs = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _searchQuery.isNotEmpty;

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 8,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Container(
            height:
                hasResults ? MediaQuery.of(context).size.height * 0.85 : 160,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _textController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: _getHintText(),
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    prefixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _textController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Tab selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTab(
                        UniversalSearchTab.ayah,
                        'آيات',
                        _getResultCount(UniversalSearchTab.ayah),
                      ),
                      _buildTab(
                        UniversalSearchTab.surah,
                        'سور',
                        _getResultCount(UniversalSearchTab.surah),
                      ),
                      _buildTab(
                        UniversalSearchTab.juz,
                        'أجزاء',
                        _getResultCount(UniversalSearchTab.juz),
                      ),
                      _buildTab(
                        UniversalSearchTab.hizbRub,
                        'أحزاب',
                        _getResultCount(UniversalSearchTab.hizbRub),
                      ),
                    ],
                  ),
                ),
                // Search results
                if (hasResults) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(child: _buildSearchResults()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoadingAyahs && _currentTab == UniversalSearchTab.ayah) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentTab) {
      case UniversalSearchTab.surah:
        return _buildSurahResults();
      case UniversalSearchTab.juz:
        return _buildJuzResults();
      case UniversalSearchTab.ayah:
        return _buildAyahResults();
      case UniversalSearchTab.hizbRub:
        return _buildHizbRubResults();
    }
  }

  Widget _buildSurahResults() {
    final filtered =
        _searchQuery.isEmpty
            ? widget.allSurahs
            : ArabicSearchUtils.filter(
              widget.allSurahs,
              _searchQuery,
              (surah) =>
                  '${surah.nameArabic} ${surah.nameEnglish} ${surah.number}',
            );

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
          textDirection: TextDirection.rtl,
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final surah = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              "${surah.number}. ${surah.nameArabic}",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              textDirection: TextDirection.rtl,
            ),
            subtitle: Text(surah.nameEnglish),
            trailing: Text(
              "ص ${surah.pageNumber}",
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            onTap: () => widget.onSurahSelected(surah),
          ),
        );
      },
    );
  }

  Widget _buildJuzResults() {
    final allJuzData = List.generate(30, (index) {
      final juzNumber = index + 1;
      return {
        'number': juzNumber,
        'name': JuzMappings.getJuzName(juzNumber),
        'fullName': JuzMappings.getJuzFullName(juzNumber),
        'page': widget.juzStartPages[juzNumber],
      };
    });

    final filtered =
        _searchQuery.isEmpty
            ? allJuzData
            : ArabicSearchUtils.filter(
              allJuzData,
              _searchQuery,
              (juz) => '${juz['number']} ${juz['name']} ${juz['fullName']}',
            );

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
          textDirection: TextDirection.rtl,
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final juz = filtered[index];
        final juzNumber = juz['number'] as int;
        final juzName = juz['name'] as String;
        final pageNumber = juz['page'] as int?;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              "الجزء $juzNumber",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              textDirection: TextDirection.rtl,
            ),
            subtitle: Text(juzName, textDirection: TextDirection.rtl),
            trailing:
                pageNumber != null
                    ? Text(
                      "ص $pageNumber",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                    : null,
            onTap: () {
              if (pageNumber != null) {
                widget.onJuzSelected(pageNumber);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildAyahResults() {
    if (_searchQuery.isEmpty) {
      return Center(
        child: Text(
          'اكتب للبحث في الآيات',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
          textDirection: TextDirection.rtl,
        ),
      );
    }

    final filtered =
        ArabicSearchUtils.filter(
          _ayahs,
          _searchQuery,
          (ayah) => ayah.text,
        ).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'لا توجد آيات',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
          textDirection: TextDirection.rtl,
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final ayah = filtered[index];
        final surah = widget.allSurahs.firstWhere(
          (s) => s.number == ayah.surahNumber,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              final marker = widget.allMarkers.firstWhere(
                (m) => m.surah == ayah.surahNumber && m.ayah == ayah.ayahNumber,
                orElse:
                    () => widget.allMarkers.firstWhere(
                      (m) => m.surah == ayah.surahNumber,
                    ),
              );
              widget.onAyahSelected(surah, ayah.ayahNumber, marker.page);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "ص ${surah.pageNumber}",
                          style: TextStyle(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        "${surah.nameArabic} - آية ${ayah.ayahNumber}",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: _buildHighlightedText(ayah.text, _searchQuery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextSpan _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 16,
          height: 1.8,
          fontFamily: 'Uthmanic',
        ),
      );
    }

    // Build character-by-character mapping between normalized and original text
    final List<int> normalizedToOriginalStart = [];
    final List<int> normalizedToOriginalEnd = [];
    final normalizedChars = <String>[];

    for (int i = 0; i < text.length; i++) {
      final normalizedChar = ArabicSearchUtils.normalize(text[i]);
      if (normalizedChar.isNotEmpty) {
        normalizedToOriginalStart.add(i);
        int endPos = i + 1;
        while (endPos < text.length) {
          final nextNormalized = ArabicSearchUtils.normalize(text[endPos]);
          if (nextNormalized.isEmpty) {
            endPos++;
          } else {
            break;
          }
        }
        normalizedToOriginalEnd.add(endPos);
        normalizedChars.add(normalizedChar);
      }
    }

    final normalizedText = normalizedChars.join();
    final normalizedQuery = ArabicSearchUtils.normalize(query);

    // Find all matches in normalized text
    final List<int> matchStarts = [];
    final List<int> matchEnds = [];

    int searchFrom = 0;
    while (searchFrom < normalizedText.length) {
      final matchIndex = normalizedText.indexOf(normalizedQuery, searchFrom);
      if (matchIndex == -1) break;

      matchStarts.add(matchIndex);
      matchEnds.add(matchIndex + normalizedQuery.length);
      searchFrom = matchIndex + 1;
    }

    if (matchStarts.isEmpty) {
      return TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 16,
          height: 1.8,
          fontFamily: 'Uthmanic',
        ),
      );
    }

    // Build TextSpan with highlights
    final List<TextSpan> spans = [];
    int currentPos = 0;

    for (int i = 0; i < matchStarts.length; i++) {
      final matchStart = matchStarts[i];
      final matchEnd = matchEnds[i];

      // Map normalized positions to original text positions
      final originalStart = normalizedToOriginalStart[matchStart];
      final originalEnd = normalizedToOriginalEnd[matchEnd - 1];

      // Add non-highlighted text before match
      if (currentPos < originalStart) {
        spans.add(
          TextSpan(
            text: text.substring(currentPos, originalStart),
            style: const TextStyle(
              fontSize: 16,
              height: 1.8,
              fontFamily: 'Uthmanic',
            ),
          ),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(originalStart, originalEnd),
          style: TextStyle(
            fontSize: 16,
            height: 1.8,
            fontFamily: 'Uthmanic',
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      currentPos = originalEnd;
    }

    // Add remaining text after last match
    if (currentPos < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentPos),
          style: const TextStyle(
            fontSize: 16,
            height: 1.8,
            fontFamily: 'Uthmanic',
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  int _getResultCount(UniversalSearchTab tab) {
    if (_searchQuery.isEmpty) return 0;

    switch (tab) {
      case UniversalSearchTab.surah:
        return ArabicSearchUtils.filter(
          widget.allSurahs,
          _searchQuery,
          (surah) => '${surah.nameArabic} ${surah.nameEnglish} ${surah.number}',
        ).length;

      case UniversalSearchTab.juz:
        final allJuzData = List.generate(30, (index) {
          final juzNumber = index + 1;
          return {
            'number': juzNumber,
            'name': JuzMappings.getJuzName(juzNumber),
            'fullName': JuzMappings.getJuzFullName(juzNumber),
          };
        });
        return ArabicSearchUtils.filter(
          allJuzData,
          _searchQuery,
          (juz) => '${juz['number']} ${juz['name']} ${juz['fullName']}',
        ).length;

      case UniversalSearchTab.ayah:
        return ArabicSearchUtils.filter(
          _ayahs,
          _searchQuery,
          (ayah) => ayah.text,
        ).length;

      case UniversalSearchTab.hizbRub:
        final allHizbData = List.generate(60, (index) {
          final hizbNumber = index + 1;
          return {
            'number': hizbNumber,
            'name': 'الحزب $hizbNumber',
          };
        });
        return ArabicSearchUtils.filter(
          allHizbData,
          _searchQuery,
          (hizb) => '${hizb['number']} ${hizb['name']}',
        ).length;
    }
  }

  Widget _buildTab(UniversalSearchTab tab, String label, int count) {
    final isSelected = _currentTab == tab;
    final hasCount = _searchQuery.isNotEmpty && count > 0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = tab;
            _textController.clear();
            _searchQuery = '';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (hasCount) ...[
                const SizedBox(height: 2),
                Text(
                  '($count)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getHintText() {
    switch (_currentTab) {
      case UniversalSearchTab.juz:
        return 'ابحث برقم أو اسم الجزء...';
      case UniversalSearchTab.surah:
        return 'ابحث عن سورة...';
      case UniversalSearchTab.ayah:
        return 'ابحث في الآيات...';
      case UniversalSearchTab.hizbRub:
        return 'ابحث عن حزب أو ربع...';
    }
  }

  Widget _buildHizbRubResults() {
    final allHizbData = List.generate(60, (index) {
      final hizbNumber = index + 1;
      final pageKey = hizbNumber.toString();
      final pageData = widget.hizbToPages[pageKey];

      // pageData is a List of page numbers, get the first page
      int? startPage;
      if (pageData != null && pageData is List && pageData.isNotEmpty) {
        startPage = pageData[0] as int?;
      }

      return {
        'number': hizbNumber,
        'name': 'الحزب $hizbNumber',
        'page': startPage,
      };
    });

    final filtered = _searchQuery.isEmpty
        ? allHizbData
        : ArabicSearchUtils.filter(
            allHizbData,
            _searchQuery,
            (hizb) => '${hizb['number']} ${hizb['name']}',
          );

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
          textDirection: TextDirection.rtl,
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final hizb = filtered[index];
        final hizbNumber = hizb['number'] as int;
        final hizbName = hizb['name'] as String;
        final pageNumber = hizb['page'] as int?;

        // Calculate which Juz this Hizb is in
        final juzNumber = ((hizbNumber - 1) ~/ 2) + 1;

        // Calculate Rub within this Hizb (1-4)
        final startRub = ((hizbNumber - 1) * 4) + 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              hizbName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              textDirection: TextDirection.rtl,
            ),
            subtitle: Text(
              'الجزء $juzNumber • أرباع $startRub-${startRub + 3}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            trailing: pageNumber != null
                ? Text(
                    "ص $pageNumber",
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  )
                : null,
            onTap: () {
              if (pageNumber != null) {
                widget.onJuzSelected(pageNumber);
              }
            },
          ),
        );
      },
    );
  }
}
